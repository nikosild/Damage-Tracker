------------------------------------------------------------
-- Drawing
-- Renders the on-screen overlay using tracker data
------------------------------------------------------------

local settings = require 'core.settings'
local tracker  = require 'core.tracker'
local utils    = require 'core.utils'
local colors   = require 'data.colors'

local drawing = {}

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function draw_text(text, x, y, fs, col)
    graphics.text_2d(text, vec2:new(x, y), fs, col)
end

local function draw_bold(text, x, y, fs, col)
    graphics.text_2d(text, vec2:new(x,     y), fs, col)
    graphics.text_2d(text, vec2:new(x + 1, y), fs, col)
end

local function draw_line(text, x, y, fs, col, bold)
    if bold then
        draw_bold(text, x, y, fs, col)
    else
        draw_text(text, x, y, fs, col)
    end
end

------------------------------------------------------------
-- Main overlay
------------------------------------------------------------
function drawing.draw_overlay()
    local fs   = settings.font_size
    local lh   = fs + settings.line_gap
    local hgap = settings.header_gap
    local x    = settings.offset_x
    local y    = settings.offset_y

    local now  = get_time_since_inject()
    local zone = tracker.current_zone
    local s    = tracker.get_session(zone)
    local dps  = tracker.rolling_dps(zone, now, settings.dps_window)

    local zone_names = {
        horde    = "Infernal Horde",
        pit      = "The Pit",
        helltide = "Helltide",
        general  = "General",
    }

    local zone_col = (colors.zone[zone] or colors.zone.general)()

    -- Header
    draw_bold('-- Damage Tracker | ALiTiS --', x, y, fs, zone_col)
    y = y + fs + hgap

    -- Zone name
    if settings.show_zone then
        draw_text('Zone   : ' .. (zone_names[zone] or "General"), x, y, fs, colors.stat.zone_name())
        y = y + lh
    end

    -- DPS
    if settings.show_dps then
        local is_high = dps > 0 and s.peak_dps > 0 and dps >= s.peak_dps * 0.8
        local col     = is_high and colors.stat.dps_high() or colors.stat.dps()
        draw_line('DPS    : ' .. utils.format_number(dps), x, y, fs, col, settings.bold_dps)
        y = y + lh
    end

    -- Peak DPS
    if settings.show_peak then
        draw_line('Peak   : ' .. utils.format_number(s.peak_dps), x, y, fs, colors.stat.peak(), settings.bold_peak)
        y = y + lh
    end

    -- Total damage
    if settings.show_total then
        draw_line('Total  : ' .. utils.format_number(s.total_damage), x, y, fs, colors.stat.total(), settings.bold_total)
        y = y + lh
    end

    -- Kills
    if settings.show_kills then
        draw_line('Kills  : ' .. tostring(s.kills), x, y, fs, colors.stat.kills(), settings.bold_kills)
        y = y + lh
    end

    -- Session time
    if settings.show_time and s.session_start then
        local elapsed = now - s.session_start
        draw_text('Time   : ' .. utils.format_uptime(elapsed), x, y, fs, colors.stat.time())
        y = y + lh
    end
end

return drawing
