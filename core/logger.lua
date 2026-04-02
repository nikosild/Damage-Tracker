------------------------------------------------------------
-- Logger
-- damage_tracker_live.txt  — live stats, overwritten every 5s
-- damage_tracker_log.txt   — history per zone, append only
------------------------------------------------------------

local utils = require 'core.utils'

local logger = {}

local LIVE_FILE     = "damage_tracker_live.txt"
local HISTORY_FILE  = "damage_tracker_log.txt"
local SAVE_INTERVAL = 5.0
local last_save     = 0

local zone_names = {
    horde    = "Infernal Horde",
    pit      = "The Pit",
    helltide = "Helltide",
    general  = "General",
}

-- Zone display order
local zone_order = { "horde", "pit", "helltide", "general" }

------------------------------------------------------------
-- Append a completed session to the correct zone section
-- The file is re-read, updated, and re-written each time
------------------------------------------------------------
function logger.save_session(zone, session, now)
    if session.total_damage <= 0 and session.kills <= 0 then return end
    local elapsed = now - (session.session_start or now)
    if elapsed < 1 then return end

    local timestamp = "unknown"
    local ok, t = pcall(os.date, "%Y-%m-%d %H:%M:%S")
    if ok and t then timestamp = t end

    local entry = string.format("  [%s]  Time: %-10s  Total: %-10s  Peak: %-12s  Kills: %d\n",
        timestamp,
        utils.format_uptime(elapsed),
        utils.format_number(session.total_damage),
        utils.format_number(session.peak_dps) .. " DPS",
        session.kills
    )

    -- Read existing file into per-zone tables
    local zone_data = {}
    for _, z in ipairs(zone_order) do zone_data[z] = {} end

    pcall(function()
        local f = io.open(HISTORY_FILE, "r")
        if not f then return end
        local current_zone = nil
        for line in f:lines() do
            local matched = false
            for _, z in ipairs(zone_order) do
                if line == "=== " .. (zone_names[z] or z) .. " ===" then
                    current_zone = z
                    matched = true
                    break
                end
            end
            if not matched and current_zone and line ~= "" then
                table.insert(zone_data[current_zone], line)
            end
        end
        f:close()
    end)

    -- Prepend new entry to the correct zone (newest on top)
    table.insert(zone_data[zone] or zone_data["general"], 1, entry:gsub("\n$", ""))

    -- Re-write the file with all zones grouped
    local ok2, err = pcall(function()
        local f = io.open(HISTORY_FILE, "w")
        if not f then return end
        for _, z in ipairs(zone_order) do
            if #zone_data[z] > 0 then
                f:write("=== " .. (zone_names[z] or z) .. " ===\n")
                for _, line in ipairs(zone_data[z]) do
                    f:write(line .. "\n")
                end
                f:write("\n")
            end
        end
        f:close()
    end)

    if not ok2 then
        console.print("[Damage Tracker | ALiTiS] Could not write history: " .. tostring(err))
    else
        console.print("[Damage Tracker | ALiTiS] Session saved to " .. HISTORY_FILE)
    end
end

------------------------------------------------------------
-- Overwrite live file with current active session stats
------------------------------------------------------------
function logger.live_update(tracker, now)
    if now - last_save < SAVE_INTERVAL then return end
    last_save = now

    local timestamp = "unknown"
    local ok, t = pcall(os.date, "%Y-%m-%d %H:%M:%S")
    if ok and t then timestamp = t end

    local lines = {
        "================================================",
        "  DAMAGE TRACKER | ALiTiS | v1.0",
        "  Last updated : " .. timestamp,
        "================================================",
        "",
    }

    for _, zone in ipairs(zone_order) do
        local s          = tracker.get_session(zone)
        local elapsed    = now - (s.session_start or now)
        local is_current = (tracker.current_zone == zone)
        local status     = is_current and "CURRENT" or "inactive"

        if s.total_damage > 0 or s.kills > 0 or is_current then
            table.insert(lines, string.format("  %-16s [%s]", zone_names[zone], status))
            table.insert(lines, string.format("    Time    : %s", utils.format_uptime(elapsed)))
            table.insert(lines, string.format("    Total   : %s", utils.format_number(s.total_damage)))
            table.insert(lines, string.format("    Peak    : %s DPS", utils.format_number(s.peak_dps)))
            table.insert(lines, string.format("    Kills   : %d", s.kills))
            table.insert(lines, "")
        end
    end

    pcall(function()
        local f = io.open(LIVE_FILE, "w")
        if not f then return end
        f:write(table.concat(lines, "\n"))
        f:write("\n")
        f:close()
    end)
end

------------------------------------------------------------
-- Open history file with OS default app + print to console
------------------------------------------------------------
function logger.open_file()
    local ok, content = pcall(function()
        local f = io.open(HISTORY_FILE, "r")
        if not f then return nil end
        local c = f:read("*a")
        f:close()
        return c
    end)

    if not ok or not content or content == "" then
        console.print("[Damage Tracker | ALiTiS] History log is empty or not found.")
    else
        console.print("[Damage Tracker | ALiTiS] ===== SESSION HISTORY =====")
        for line in content:gmatch("[^\n]+") do
            console.print(line)
        end
        console.print("[Damage Tracker | ALiTiS] ===== END =====")
    end

    pcall(function()
        local cmds = {
            'start "" "' .. HISTORY_FILE .. '"',
            'xdg-open "' .. HISTORY_FILE .. '"',
            'open "' .. HISTORY_FILE .. '"',
        }
        for _, cmd in ipairs(cmds) do
            if pcall(os.execute, cmd) then break end
        end
    end)
end

------------------------------------------------------------
-- Clear both files
------------------------------------------------------------
function logger.clear_log()
    last_save = 0
    pcall(function()
        local f = io.open(HISTORY_FILE, "w") if f then f:close() end
    end)
    pcall(function()
        local f = io.open(LIVE_FILE, "w") if f then f:close() end
    end)
    console.print("[Damage Tracker | ALiTiS] Log files cleared.")
end

return logger
