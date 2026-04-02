------------------------------------------------------------
-- Main
-- Entry point: wires update, render, and menu callbacks
------------------------------------------------------------

local gui      = require 'gui'
local settings = require 'core.settings'
local tracker  = require 'core.tracker'
local drawing  = require 'core.drawing'
local logger   = require 'core.logger'
local track    = require 'tasks.track'

on_update(function()
    settings:update()

    local now = get_time_since_inject()

    -- Live log update every 5s
    logger.live_update(tracker, now)

    -- Reset button
    if gui.elements.reset_btn:get() then
        tracker.reset_all()
        logger.force_live_update(tracker, now)
    end

    -- Reset keybind
    if gui.elements.reset_keybind:get_state() == 1 then
        tracker.reset_all()
        logger.force_live_update(tracker, now)
    end

    -- Open log button
    if gui.elements.open_log_btn:get() then
        logger.open_file()
    end

    -- Clear log button — also resets all in-memory sessions
    if gui.elements.clear_log_btn:get() then
        logger.clear_log()
        tracker.reset_all_silent()
    end

    if not settings.enabled then return end
    if track.shouldExecute() then track.Execute() end
end)

on_render(function()
    if not settings.enabled then return end
    drawing.draw_overlay()
end)

on_render_menu(gui.render)
