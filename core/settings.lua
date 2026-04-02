------------------------------------------------------------
-- Settings
-- Reads GUI element values into a flat runtime table
------------------------------------------------------------

local gui = require 'gui'

local settings = {
    enabled    = true,
    show_dps   = true,
    bold_dps   = false,
    show_peak  = true,
    bold_peak  = true,
    show_total = true,
    bold_total = false,
    show_kills = true,
    bold_kills = true,
    show_time  = true,
    show_zone  = true,
    dps_window = 30.0,
    font_size  = 19,
    header_gap = 9,
    line_gap   = 4,
    offset_x   = 0,
    offset_y   = 0,
}

function settings:update()
    local el = gui.elements
    settings.enabled    = el.enabled:get()
    settings.show_dps   = el.show_dps:get()
    settings.bold_dps   = el.bold_dps:get()
    settings.show_peak  = el.show_peak:get()
    settings.bold_peak  = el.bold_peak:get()
    settings.show_total = el.show_total:get()
    settings.bold_total = el.bold_total:get()
    settings.show_kills = el.show_kills:get()
    settings.bold_kills = el.bold_kills:get()
    settings.show_time  = el.show_time:get()
    settings.show_zone  = el.show_zone:get()
    settings.dps_window = el.dps_window:get()
    settings.font_size  = el.font_size:get()
    settings.header_gap = el.header_gap:get()
    settings.line_gap   = el.line_gap:get()
    settings.offset_x   = el.offset_x:get()
    settings.offset_y   = el.offset_y:get()
end

return settings
