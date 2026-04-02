------------------------------------------------------------
-- Logger
-- damage_tracker_live.txt  — live stats, overwritten every 5s
-- damage_tracker_log.txt   — history per zone, append only
-- Both files are written to the script root (next to main.lua)
------------------------------------------------------------

local logger = {}

------------------------------------------------------------
-- Local format helpers (avoids require-order issues)
------------------------------------------------------------
local function format_number(n)
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return string.format("%.0f", n)
end

local function format_uptime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then return string.format("%dh %dm %ds", h, m, s) end
    if m > 0 then return string.format("%dm %ds", m, s) end
    return string.format("%ds", s)
end

------------------------------------------------------------
-- Resolve script root directory
-- We cannot use debug.getinfo (sandboxed out).  Instead we
-- ask the package loader where it *would* find 'core.logger'
-- — that gives us the absolute path to this very file, from
-- which we strip '/core/logger.lua' to get the plugin root.
------------------------------------------------------------
local function get_script_root()
    -- Try package.searchpath first (Lua 5.2+)
    if package.searchpath then
        local path = package.searchpath('core.logger', package.path)
        if path then
            local norm = path:gsub("\\", "/")
            local root = norm:match("^(.*)/core/logger%.lua$")
            if root then
                local sep = path:match("\\") and "\\" or "/"
                return root:gsub("/", sep) .. sep
            end
        end
    end

    -- Fallback: walk package.path templates and probe for this file
    for template in package.path:gmatch("[^;]+") do
        local try = template:gsub("%?", "core/logger")
        local f = io.open(try, "r")
        if f then
            f:close()
            local norm = try:gsub("\\", "/")
            local root = norm:match("^(.*)/core/logger%.lua$")
            if root then
                local sep = try:match("\\") and "\\" or "/"
                return root:gsub("/", sep) .. sep
            end
        end
    end

    -- Last resort: working directory
    return ""
end

local SCRIPT_ROOT   = get_script_root()
local LIVE_FILE     = SCRIPT_ROOT .. "damage_tracker_live.txt"
local HISTORY_FILE  = SCRIPT_ROOT .. "damage_tracker_log.txt"
local SAVE_INTERVAL = 5.0
local last_save     = 0

-- Print resolved path once at load so you can verify in console
console.print("[Damage Tracker | ALiTiS] Log path: " .. SCRIPT_ROOT)

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
    if session.total_damage <= 0 and session.kills <= 0 then
        console.print("[Damage Tracker | ALiTiS] Skipping save — no damage or kills for " .. (zone_names[zone] or zone))
        return
    end

    local elapsed = now - (session.session_start or now)
    if elapsed < 1 then
        console.print("[Damage Tracker | ALiTiS] Skipping save — session too short for " .. (zone_names[zone] or zone))
        return
    end

    local timestamp = "unknown"
    local ok, t = pcall(os.date, "%Y-%m-%d %H:%M:%S")
    if ok and t then timestamp = t end

    local entry = string.format("  [%s]  Time: %-10s  Total: %-10s  Peak: %-12s  Kills: %d",
        timestamp,
        format_uptime(elapsed),
        format_number(session.total_damage),
        format_number(session.peak_dps) .. " DPS",
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
    local target = zone_data[zone] or zone_data["general"]
    table.insert(target, 1, entry)

    -- Re-write the file with all zones grouped
    local f, open_err = io.open(HISTORY_FILE, "w")
    if not f then
        console.print("[Damage Tracker | ALiTiS] ERROR: Could not open history file: " .. tostring(open_err))
        return
    end

    local write_ok, write_err = pcall(function()
        for _, z in ipairs(zone_order) do
            if #zone_data[z] > 0 then
                f:write("=== " .. (zone_names[z] or z) .. " ===\n")
                for _, line in ipairs(zone_data[z]) do
                    f:write(line .. "\n")
                end
                f:write("\n")
            end
        end
        f:flush()
        f:close()
    end)

    if not write_ok then
        console.print("[Damage Tracker | ALiTiS] ERROR: Failed writing history: " .. tostring(write_err))
        pcall(function() f:close() end)
    else
        console.print("[Damage Tracker | ALiTiS] Session saved | " .. (zone_names[zone] or zone)
            .. " | Total: " .. format_number(session.total_damage)
            .. " | Kills: " .. session.kills)
    end
end

------------------------------------------------------------
-- Overwrite both files with current session stats every 5s
------------------------------------------------------------
function logger.live_update(tracker, now)
    if now - last_save < SAVE_INTERVAL then return end
    last_save = now

    local timestamp = "unknown"
    local ok, t = pcall(os.date, "%Y-%m-%d %H:%M:%S")
    if ok and t then timestamp = t end

    -- ---- Live file (compact dashboard) ----
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
            table.insert(lines, string.format("    Time    : %s", format_uptime(elapsed)))
            table.insert(lines, string.format("    Total   : %s", format_number(s.total_damage)))
            table.insert(lines, string.format("    Peak    : %s DPS", format_number(s.peak_dps)))
            table.insert(lines, string.format("    Kills   : %d", s.kills))
            table.insert(lines, "")
        end
    end

    pcall(function()
        local f = io.open(LIVE_FILE, "w")
        if not f then return end
        f:write(table.concat(lines, "\n"))
        f:write("\n")
        f:flush()
        f:close()
    end)

    -- ---- History file (per-zone, overwritten with current data) ----
    local has_data = false
    for _, zone in ipairs(zone_order) do
        local s = tracker.get_session(zone)
        if s.total_damage > 0 or s.kills > 0 then
            has_data = true
            break
        end
    end

    if has_data then
        pcall(function()
            local f = io.open(HISTORY_FILE, "w")
            if not f then return end

            f:write("================================================\n")
            f:write("  DAMAGE TRACKER | ALiTiS | SESSION HISTORY\n")
            f:write("  Last updated : " .. timestamp .. "\n")
            f:write("================================================\n\n")

            for _, zone in ipairs(zone_order) do
                local s       = tracker.get_session(zone)
                local elapsed = now - (s.session_start or now)

                if s.total_damage > 0 or s.kills > 0 then
                    f:write("=== " .. (zone_names[zone] or zone) .. " ===\n")
                    f:write(string.format("  Time    : %s\n",     format_uptime(elapsed)))
                    f:write(string.format("  Total   : %s\n",     format_number(s.total_damage)))
                    f:write(string.format("  Peak    : %s DPS\n", format_number(s.peak_dps)))
                    f:write(string.format("  Kills   : %d\n",     s.kills))
                    f:write("\n")
                end
            end

            f:flush()
            f:close()
        end)
    end
end

------------------------------------------------------------
-- Force immediate live update (bypasses interval timer)
------------------------------------------------------------
function logger.force_live_update(tracker, now)
    last_save = 0
    logger.live_update(tracker, now)
end

------------------------------------------------------------
-- Open history file with OS default app + print to console
------------------------------------------------------------
function logger.open_file()
    -- Ensure the file exists so Windows doesn't error on open
    local f_check = io.open(HISTORY_FILE, "r")
    if f_check then
        f_check:close()
    else
        local f_create = io.open(HISTORY_FILE, "w")
        if f_create then
            f_create:write("(No sessions recorded yet)\n")
            f_create:flush()
            f_create:close()
        end
    end

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
