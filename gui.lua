------------------------------------------------------------
-- GUI
-- All menu elements and the render function
------------------------------------------------------------

local plugin_label   = 'damage_tracker'
local plugin_version = 'Damage Tracker | ALiTiS | v1.0'

local gui = {}
gui.plugin_label   = plugin_label
gui.plugin_version = plugin_version

console.print('Lua Plugin - ' .. plugin_version)

local function cb(value, key)
    return checkbox:new(value, get_hash(plugin_label .. '_' .. key))
end

gui.elements = {
    -- Main
    main_tree    = tree_node:new(0),
    enabled      = cb(true, 'enabled'),
    reset_btn    = button:new(get_hash(plugin_label .. '_reset')),
    open_log_btn = button:new(get_hash(plugin_label .. '_open_log')),
    clear_log_btn = button:new(get_hash(plugin_label .. '_clear_log')),

    -- Display
    display_tree = tree_node:new(1),
    offset_x     = slider_int:new(0, 4000, 0,  get_hash(plugin_label .. '_offset_x')),
    offset_y     = slider_int:new(-200, 1500, 0, get_hash(plugin_label .. '_offset_y')),
    font_size    = slider_int:new(12, 30, 19,  get_hash(plugin_label .. '_font_size')),
    header_gap   = slider_int:new(2, 16,  9,   get_hash(plugin_label .. '_header_gap')),
    line_gap     = slider_int:new(0, 10,  4,   get_hash(plugin_label .. '_line_gap')),

    -- Stats
    stats_tree   = tree_node:new(1),
    show_zone    = cb(true,  'show_zone'),

    dps_tree     = tree_node:new(2),
    show_dps     = cb(true,  'show_dps'),
    bold_dps     = cb(false, 'bold_dps'),
    dps_window   = slider_float:new(1.0, 30.0, 30.0, get_hash(plugin_label .. '_dps_window')),

    peak_tree    = tree_node:new(2),
    show_peak    = cb(true,  'show_peak'),
    bold_peak    = cb(true,  'bold_peak'),

    total_tree   = tree_node:new(2),
    show_total   = cb(true,  'show_total'),
    bold_total   = cb(false, 'bold_total'),

    kills_tree   = tree_node:new(2),
    show_kills   = cb(true,  'show_kills'),
    bold_kills   = cb(true,  'bold_kills'),

    show_time    = cb(true,  'show_time'),

    -- Keybind
    keybind_tree  = tree_node:new(1),
    reset_keybind = keybind:new(0x0A, true, get_hash(plugin_label .. '_reset_keybind')),
}

function gui.render()
    if not gui.elements.main_tree:push(plugin_version) then return end

    gui.elements.enabled:render('Enable', 'Toggle the damage tracker overlay')
    gui.elements.open_log_btn:render('Open Log File', 'Print session log to console and try to open the file', 0.3)
    gui.elements.clear_log_btn:render('Clear Log File', 'Erase all saved session history', 0.3)
    gui.elements.reset_btn:render('Reset All Sessions', 'Clear data for all zones', 0.3)

    -- Display settings
    if gui.elements.display_tree:push('Display Settings') then
        gui.elements.offset_x:render('Offset X', 'Horizontal position of the overlay')
        gui.elements.offset_y:render('Offset Y', 'Vertical position of the overlay')
        gui.elements.font_size:render('Font Size', 'Text size for the overlay')
        gui.elements.header_gap:render('Header Gap', 'Extra spacing after the header')
        gui.elements.line_gap:render('Line Gap', 'Extra spacing between lines')
        gui.elements.display_tree:pop()
    end

    -- Tracked stats
    if gui.elements.stats_tree:push('Tracked Stats') then
        gui.elements.show_zone:render('Show Zone Name', 'Display current activity zone type')

        if gui.elements.dps_tree:push('DPS') then
            gui.elements.show_dps:render('Enable', 'Display rolling DPS')
            gui.elements.bold_dps:render('Bold', 'Render DPS in bold')
            gui.elements.dps_window:render('DPS Window (s)', 'Rolling window in seconds', 1)
            gui.elements.dps_tree:pop()
        end

        if gui.elements.peak_tree:push('Peak DPS') then
            gui.elements.show_peak:render('Enable', 'Display peak DPS this session')
            gui.elements.bold_peak:render('Bold', 'Render Peak DPS in bold')
            gui.elements.peak_tree:pop()
        end

        if gui.elements.total_tree:push('Total Damage') then
            gui.elements.show_total:render('Enable', 'Display total damage dealt')
            gui.elements.bold_total:render('Bold', 'Render Total in bold')
            gui.elements.total_tree:pop()
        end

        if gui.elements.kills_tree:push('Kills') then
            gui.elements.show_kills:render('Enable', 'Display kill count')
            gui.elements.bold_kills:render('Bold', 'Render Kills in bold')
            gui.elements.kills_tree:pop()
        end

        gui.elements.show_time:render('Session Time', 'Display elapsed time for current zone session')

        gui.elements.stats_tree:pop()
    end

    -- Keybinds
    if gui.elements.keybind_tree:push('Keybinds') then
        gui.elements.reset_keybind:render('Reset All Sessions', 'Keybind to reset all zone session data')
        gui.elements.keybind_tree:pop()
    end

    gui.elements.main_tree:pop()
end

return gui
