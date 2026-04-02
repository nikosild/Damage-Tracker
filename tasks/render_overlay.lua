local settings   = require "core.settings"
local tracker    = require "core.tracker"
local utils      = require "core.utils"
local gui        = require "gui"

-- Zone type → display color for the header
local zone_colors = {
    horde    = function() return color_orange(255) end,
    pit      = function() return color_red(255)    end,
    helltide = function() return color_purple(255) end,
    general  = function() return color_white(220)  end,
}

local render_task = {
    name = "Render Overlay",
}

function render_task.shouldExecute()
    return settings.enabled
end

function render_task.Execute()
    local now  = get_time_since_inject()
    local zone = tracker.current_zone
    local s    = tracker.get_session(zone)
    local dps  = tracker.rolling_dps(zone, now, settings.dps_window)

    local sw   = get_screen_width()
    local sh   = get_screen_height()
    local px   = settings.pos_x * sw
    local py   = settings.pos_y * sh
    local font = settings.font_size
    local lh   = font + 4
    local y    = py

    local function draw(label, value, col)
        local text = label .. value
        graphics.text_2d(text, vec2:new(px + 1, y + 1), font, color_black(150))
        graphics.text_2d(text, vec2:new(px,     y    ), font, col)
        y = y + lh
    end

    -- Header with zone-specific color
    local zone_label  = gui.zone_labels[zone] or "General"
    local header_col  = (zone_colors[zone] or zone_colors.general)()
    draw("", "[ Damage Tracker ]", header_col)

    if settings.show_zone then
        draw("Zone:   ", zone_label, header_col)
    end

    if settings.show_dps then
        local col = (dps > 0 and s.peak_dps > 0 and dps >= s.peak_dps * 0.8)
            and color_yellow(255)
            or  color_white(220)
        draw("DPS:    ", utils.format_number(dps), col)
    end

    if settings.show_peak then
        draw("Peak:   ", utils.format_number(s.peak_dps), color_gold(255))
    end

    if settings.show_total then
        draw("Total:  ", utils.format_number(s.total_damage), color_white(220))
    end

    if settings.show_kills then
        draw("Kills:  ", tostring(s.kills), color_red(220))
    end

    if settings.show_time and s.session_start then
        local elapsed = now - s.session_start
        draw("Time:   ", utils.format_time(elapsed), color_grey(180))
    end
end

return render_task
