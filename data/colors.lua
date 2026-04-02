------------------------------------------------------------
-- Color Theme
-- Centralised color definitions for the damage tracker overlay
------------------------------------------------------------

local colors = {}

-- Zone header colors
colors.zone = {
    horde    = function() return color_orange(255) end,
    pit      = function() return color_red(255)    end,
    helltide = function() return color_purple(255) end,
    general  = function() return color_white(220)  end,
}

-- Stat line colors
colors.stat = {
    separator = function() return color_white(255)   end,
    dps       = function() return color_green(220)   end,
    dps_high  = function() return color_yellow(220)  end,  -- when near peak
    peak      = function() return color_gold(255)    end,
    total     = function() return color.new(255, 105, 180, 255)   end,
    kills     = function() return color_red(220)     end,
    time      = function() return color_white(200)    end,
    zone_name = function() return color_cyan(200)    end,
}

-- Which stats get bold treatment
colors.bold = {
    peak  = true,
    kills = true,
}

return colors
