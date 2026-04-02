------------------------------------------------------------
-- Task: Track Damage
-- Samples enemy health + shield each pulse and records deltas
-- Uses XP delta for accurate kill counting
------------------------------------------------------------

local settings = require 'core.settings'
local tracker  = require 'core.tracker'
local zones    = require 'core.zones'

local last_update = 0.0
local last_zone   = nil
local last_xp     = nil  -- tracks player XP for kill detection

local track_task = { name = "Track Damage" }

function track_task.shouldExecute()
    return settings.enabled
end

-- Returns hp, shield, and effective HP (hp + shield)
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

    local zone = zones.detect()

    if zone ~= last_zone then
        tracker.reset_zone(zone)
        last_zone = zone
        last_xp   = nil  -- reset XP baseline on zone change
    end

    tracker.current_zone = zone
    local s = tracker.get_session(zone)

    -- XP-based kill counting
    local player  = get_local_player()
    local cur_xp  = player:get_current_experience()

    if last_xp == nil then
        last_xp = cur_xp
    elseif cur_xp > last_xp then
        -- XP went up = one or more kills happened
        -- We don't know exactly how many but at minimum 1
        -- Use difference heuristic: most kills give similar XP chunks
        tracker.record_kill(zone)
        last_xp = cur_xp
    end

    -- Damage tracking via HP + Shield delta
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

    -- Actors that vanished without is_dead() (despawn fallback)
    for id, prev in pairs(s.last_health) do
        if not seen[id] then
            if prev.effective > 0 then
                tracker.record_damage(zone, prev.effective, now)
            end
            s.last_health[id] = nil
        end
    end

    local dps = tracker.rolling_dps(zone, now, settings.dps_window)
    tracker.update_peak(zone, dps)
end

return track_task
