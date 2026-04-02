------------------------------------------------------------
-- Logger
-- Saves session summaries to a log file and can open it
------------------------------------------------------------

local utils  = require 'core.utils'

local logger = {}

local LOG_FILE    = "damage_tracker_log.txt"
local SAVE_INTERVAL = 5.0  -- seconds between live updates
local last_save   = 0

local zone_names = {
    horde    = "Infernal Horde",
    pit      = "The Pit",
    helltide = "Helltide",
    general  = "General",
}

------------------------------------------------------------
-- Internal: format a session block as a string
------------------------------------------------------------
local function format_session(zone, session, now, label)
    local elapsed = now - (session.session_start or now)
    local lines = {
        "========================================",
        string.format("  Zone    : %s", zone_names[zone] or zone),
        string.format("  Status  : %s", label or "active"),
        string.format("  Time    : %s", utils.format_uptime(elapsed)),
        string.format("  Total   : %s", utils.format_number(session.total_damage)),
        string.format("  Peak    : %s DPS", utils.format_number(session.peak_dps)),
        string.format("  Kills   : %d", session.kills),
        "========================================",
        "",
    }
    return table.concat(lines, "\n")
end

------------------------------------------------------------
-- Write a completed session summary to the log file
------------------------------------------------------------
function logger.save_session(zone, session, now)
    if session.total_damage <= 0 and session.kills <= 0 then return end
    if (now - (session.session_start or now)) < 1 then return end

    local timestamp = ""
    local ok, t = pcall(os.date, "%Y-%m-%d %H:%M:%S")
    if ok and t then timestamp = "  Date    : " .. t .. "\n" else timestamp = "" end

    local block = "========================================\n"
        .. string.format("  Zone    : %s\n", zone_names[zone] or zone)
        .. timestamp
        .. string.format("  Time    : %s\n", utils.format_uptime(now - (session.session_start or now)))
        .. string.format("  Total   : %s\n", utils.format_number(session.total_damage))
        .. string.format("  Peak    : %s DPS\n", utils.format_number(session.peak_dps))
        .. string.format("  Kills   : %d\n", session.kills)
        .. "========================================\n\n"

    local ok2, err = pcall(function()
        local f = io.open(LOG_FILE, "a")
        if not f then return end
        f:write(block)
        f:close()
    end)

    if not ok2 then
        console.print("[Damage Tracker | ALiTiS] Could not write log: " .. tostring(err))
    else
        console.print("[Damage Tracker | ALiTiS] Session saved to " .. LOG_FILE)
    end
end

------------------------------------------------------------
-- Live update: rewrite the file with current active sessions
-- Called every SAVE_INTERVAL seconds from on_update
------------------------------------------------------------
function logger.live_update(tracker, now)
    if now - last_save < SAVE_INTERVAL then return end
    last_save = now

    local timestamp = ""
    local ok, t = pcall(os.date, "%Y-%m-%d %H:%M:%S")
    if ok and t then timestamp = t else timestamp = "unknown" end

    local lines = {
        "================================================",
        "  DAMAGE TRACKER | ALiTiS | v1.0",
        "  Last updated: " .. timestamp,
        "  (This file updates every " .. SAVE_INTERVAL .. " seconds)",
        "================================================",
        "",
        "[ ACTIVE SESSIONS ]",
        "",
    }

    local zones = { "horde", "pit", "helltide", "general" }
    for _, zone in ipairs(zones) do
        local s = tracker.get_session(zone)
        local elapsed = now - (s.session_start or now)
        local is_current = (tracker.current_zone == zone)
        local status = is_current and "CURRENT" or "inactive"

        if s.total_damage > 0 or s.kills > 0 or is_current then
            table.insert(lines, string.format("  %-14s [%s]", zone_names[zone], status))
            table.insert(lines, string.format("    Time    : %s", utils.format_uptime(elapsed)))
            table.insert(lines, string.format("    Total   : %s", utils.format_number(s.total_damage)))
            table.insert(lines, string.format("    Peak    : %s DPS", utils.format_number(s.peak_dps)))
            table.insert(lines, string.format("    Kills   : %d", s.kills))
            table.insert(lines, "")
        end
    end

    table.insert(lines, "================================================")
    table.insert(lines, "[ SESSION HISTORY ]")
    table.insert(lines, "(appended below after each reset or zone change)")
    table.insert(lines, "================================================")
    table.insert(lines, "")

    -- Read existing history (everything after the previous header)
    local history = ""
    local ok2, content = pcall(function()
        local f = io.open(LOG_FILE, "r")
        if not f then return "" end
        local c = f:read("*a")
        f:close()
        return c
    end)
    if ok2 and content then
        -- Extract only the history section
        local hist_start = content:find("======+\n%[%s*SESSION HISTORY")
        if hist_start then
            local after = content:find("\n", hist_start + 1)
            local after2 = after and content:find("\n", after + 1)
            local after3 = after2 and content:find("\n", after2 + 1)
            local after4 = after3 and content:find("\n", after3 + 1)
            if after4 then
                history = content:sub(after4 + 1)
            end
        end
    end

    local ok3, err = pcall(function()
        local f = io.open(LOG_FILE, "w")
        if not f then return end
        f:write(table.concat(lines, "\n"))
        f:write("\n")
        if history and history ~= "" then
            f:write(history)
        end
        f:close()
    end)

    if not ok3 then
        console.print("[Damage Tracker | ALiTiS] Live update failed: " .. tostring(err))
    end
end

------------------------------------------------------------
-- Print log contents to console
------------------------------------------------------------
function logger.print_log()
    local ok, content = pcall(function()
        local f = io.open(LOG_FILE, "r")
        if not f then return nil end
        local c = f:read("*a")
        f:close()
        return c
    end)

    if not ok or not content or content == "" then
        console.print("[Damage Tracker | ALiTiS] Log file is empty or not found: " .. LOG_FILE)
        return
    end

    console.print("[Damage Tracker | ALiTiS] ===== SESSION LOG =====")
    for line in content:gmatch("[^\n]+") do
        console.print(line)
    end
    console.print("[Damage Tracker | ALiTiS] ===== END OF LOG =====")
end

------------------------------------------------------------
-- Try to open the log file with the OS default app
------------------------------------------------------------
function logger.open_file()
    logger.print_log()

    pcall(function()
        local cmds = {
            'start "" "' .. LOG_FILE .. '"',
            'xdg-open "' .. LOG_FILE .. '"',
            'open "' .. LOG_FILE .. '"',
        }
        for _, cmd in ipairs(cmds) do
            local ok = pcall(os.execute, cmd)
            if ok then break end
        end
    end)
end

------------------------------------------------------------
-- Clear only the history section, keep active sessions
------------------------------------------------------------
function logger.clear_log()
    local ok, err = pcall(function()
        local f = io.open(LOG_FILE, "w")
        if f then f:close() end
    end)
    -- Force a live update on next tick
    last_save = 0
    if ok then
        console.print("[Damage Tracker | ALiTiS] Log file cleared.")
    end
end

return logger
