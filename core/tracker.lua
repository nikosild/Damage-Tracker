------------------------------------------------------------
-- Tracker
-- Holds per-zone session state: damage log, kills, peak DPS
------------------------------------------------------------

local tracker = {}

-- logger loaded lazily to avoid circular require
local _logger = nil
local function get_logger()
    if not _logger then
        local ok, l = pcall(require, 'core.logger')
        if ok then _logger = l end
    end
    return _logger
end

local function new_session()
    return {
        damage_log    = {},
        total_damage  = 0,
        kills         = 0,
        peak_dps      = 0,
        session_start = get_time_since_inject(),
        last_health   = {},
    }
end

local sessions = {
    horde    = new_session(),
    pit      = new_session(),
    helltide = new_session(),
    general  = new_session(),
}

tracker.current_zone = "general"

function tracker.get_session(zone)
    return sessions[zone] or sessions["general"]
end

function tracker.reset_all()
    local now = get_time_since_inject()
    local log = get_logger()
    for zone in pairs(sessions) do
        if log then log.save_session(zone, sessions[zone], now) end
        sessions[zone] = new_session()
    end
    console.print('[Damage Tracker | ALiTiS] All sessions reset.')
end

-- Reset all sessions without saving to log (used by Clear Log)
function tracker.reset_all_silent()
    for zone in pairs(sessions) do
        sessions[zone] = new_session()
    end
    console.print('[Damage Tracker | ALiTiS] All sessions cleared.')
end

function tracker.reset_zone(zone)
    local now = get_time_since_inject()
    local log = get_logger()
    if log then log.save_session(zone, sessions[zone], now) end
    sessions[zone] = new_session()
end

function tracker.rolling_dps(zone, now, window)
    local s      = tracker.get_session(zone)
    local log    = s.damage_log
    local cutoff = now - window

    local first = 1
    while first <= #log and log[first].t < cutoff do
        first = first + 1
    end
    if first > 1 then
        for i = 1, #log - first + 1 do log[i] = log[i + first - 1] end
        for i = #log - first + 2, #log do log[i] = nil end
    end

    local sum = 0
    for _, e in ipairs(log) do sum = sum + e.dmg end

    local elapsed = math.min(now - s.session_start, window)
    if elapsed <= 0 then return 0 end
    return sum / elapsed
end

function tracker.record_damage(zone, dmg, now)
    local s = tracker.get_session(zone)
    s.total_damage = s.total_damage + (dmg * 15000)
    table.insert(s.damage_log, { t = now, dmg = dmg * 15000 })
end

function tracker.record_kill(zone)
    local s = tracker.get_session(zone)
    s.kills = s.kills + 1
end

function tracker.update_peak(zone, dps)
    local s = tracker.get_session(zone)
    if dps > s.peak_dps then s.peak_dps = dps end
end

return tracker
