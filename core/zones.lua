------------------------------------------------------------
-- Zone Detection
-- Identifies the current activity type for per-zone tracking
------------------------------------------------------------

local zones = {}

local PIT_QUEST_IDS = { [1815152] = true, [1922713] = true }

-- Returns "horde" | "pit" | "helltide" | "general"
function zones.detect()
    local world = get_current_world()
    if not world then return "general" end

    local zone = world:get_current_zone_name()

    if zone == "S05_BSK_Prototype02" then
        return "horde"
    end

    if is_in_helltide and is_in_helltide() then
        return "helltide"
    end

    local ok, quests = pcall(get_quests)
    if ok and quests then
        for _, quest in pairs(quests) do
            local ok2, id = pcall(function() return quest:get_id() end)
            if ok2 and PIT_QUEST_IDS[id] then
                return "pit"
            end
        end
    end

    return "general"
end

return zones
