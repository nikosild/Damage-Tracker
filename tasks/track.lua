------------------------------------------------------------
-- Task: Track Damage
-- Samples enemy health + shield each pulse and records deltas
------------------------------------------------------------

local settings = require 'core.settings'
local tracker  = require 'core.tracker'
local zones    = require 'core.zones'

local last_update    = 0.0
local last_zone      = nil
local pending_zone   = nil   -- zone candidate waiting to be confirmed
local pending_since  = 0.0   -- when we first saw the candidate
local ZONE_DEBOUNCE  = 2.0   -- seconds a new zone must be stable before accepting

local track_task = { name = "Track Damage" }

function track_task.shouldExecute()
    return settings.enabled
end

local function get_effective_hp(actor)
    local hp     = actor:get_current_health()
    local shield = 0
    local ok, val = pcall(function()
        return actor:get_attribute("Damage_Shield")
    end)
    if ok and val and val > 0 then
        shield = val
    end
    return hp, shield, hp + shield
end

function track_task.Execute()
    local now = get_time_since_inject()

    if now - last_update < 0.033 then return end
    last_update = now

    local detected = zones.detect()

    -- Debounce zone changes: only commit after zone is stable for ZONE_DEBOUNCE seconds
    if detected ~= last_zone then
        if detected ~= pending_zone then
            -- New candidate, start timer
            pending_zone  = detected
            pending_since = now
        elseif now - pending_since >= ZONE_DEBOUNCE then
            -- Candidate has been stable long enough — commit
            tracker.reset_zone(detected)
            last_zone    = detected
            pending_zone = nil
        end
        -- During debounce period, keep using last_zone for tracking
    else
        -- Detected zone matches confirmed zone — clear any pending candidate
        pending_zone = nil
    end

    local zone = last_zone or detected
    tracker.current_zone = zone

    local s = tracker.get_session(zone)
    local seen = {}

    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        if target_selector.is_valid_enemy(actor) then
            local id                    = actor:get_id()
            local hp, shield, effective = get_effective_hp(actor)
            seen[id] = true

            local prev = s.last_health[id]

            if prev then
                local delta = prev.effective - effective

                if delta > 0 then
                    tracker.record_damage(zone, delta, now)
                end

                if actor:is_dead() or hp <= 0 then
                    if effective > 0 then
                        tracker.record_damage(zone, effective, now)
                    end
                    tracker.record_kill(zone)
                    s.last_health[id] = nil
                    seen[id] = nil
                else
                    s.last_health[id] = { hp = hp, shield = shield, effective = effective }
                end
            elseif hp > 0 then
                s.last_health[id] = { hp = hp, shield = shield, effective = effective }
            end
        end
    end

    -- Actors that vanished without is_dead() firing (despawn fallback)
    for id, prev in pairs(s.last_health) do
        if not seen[id] then
            if prev.effective > 0 then
                tracker.record_damage(zone, prev.effective, now)
            end
            tracker.record_kill(zone)
            s.last_health[id] = nil
        end
    end

    local dps = tracker.rolling_dps(zone, now, settings.dps_window)
    tracker.update_peak(zone, dps)
end

return track_task
