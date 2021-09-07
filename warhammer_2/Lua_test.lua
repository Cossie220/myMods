--setup
local bm = battle_manager:new(empire_battle:new())
local ordersFileName = "orders.json"
local observationFile = "observation.json"

-- player army setup
local player_army = bm:get_player_army()
local player_units = player_army:units()

-- enemy army setup
local enemy_army = bm:get_first_non_player_army()
local enemy_units = enemy_army:units()


--#region script unit setup
-- player
local player_sunits = {}
for i=1,player_units:count() do
    player_sunits[i] = script_unit:new(player_army,i)
end
-- enemy
local enemy_sunits = {}
for i=1,enemy_units:count() do
    enemy_sunits[i] = script_unit:new(enemy_army,i)
end
--#endregion

--#region global values setup
math.huge = 2^1024
--#endregion

-- import the json library
local json = require("AI_test/json")

-- logging 
local function Log(text)
    if type(text) == "string" then 
        local file = io.open('AI_test.txt',"a")
        file:write(text.."\n")
        file:flush()
        file:close()
    end
end

--get a single observation from a defined script unit
local function singleObservation(unit)
    local x_position = unit.unit:position():get_x()
    local y_position = unit.unit:position():get_y()
    local bearing = unit.unit:bearing()
    local width = unit.unit:ordered_width()
    local type = unit.unit:type()
    local can_fly = unit.unit:can_fly()
    local is_flying = unit.unit:is_currently_flying()
    local is_under_missile_attack = unit.unit:is_under_missile_attack()
    local in_melee = unit.unit:is_in_melee()
    local is_wavering = unit.unit:is_wavering()
    local is_routing = unit.unit:is_routing()
    local is_shattered = unit.unit:is_shattered()
    local unary_hitpoints = unit.unit:unary_hitpoints()
    local observation = {
    position = {
        x = x_position,
        y = y_position,
        bearing = bearing,
        width = width},
    type = type,
    can_fly = can_fly,
    is_flying = is_flying,
    is_under_missile_attack = is_under_missile_attack,
    in_melee = in_melee,
    is_wavering = is_wavering,
    is_routing = is_routing,
    is_shattered = is_shattered,
    unary_hitpoints = unary_hitpoints
    }
    return observation
end

--export the entire obeservation to json
local function exportObservation() 
    local file = io.open(observationFile, "w+")
    local observation = {
        allies = {},
        enemies = {}
    }
    for i=1,player_units:count() do
        local test = singleObservation(player_sunits[i])
        table.insert(observation.allies,test)
    end     
    for i=1,enemy_units:count() do
        local test = singleObservation(enemy_sunits[i])
        table.insert(observation.enemies,test)
    end 
    local observationString = json.encode(observation)
    file:write(observationString)
    file:flush()
end

-- reading local json file for orders
local function readJSON()
    local file = io.open(ordersFileName, "r")
    if file then
        local File = file:read("*a")
        local all = json.decode(File)
        local orders = all["alies"]
        for i in ipairs(orders) do
            local order = orders[i]
            local attack = order["attack"]
            if attack["attack"] then
                player_sunits[i].uc:attack_unit(enemy_units:item(attack["unit"]), true, true)
            else
                local go_to = order["goto"] 
                local my_vector = v(go_to["x"], go_to["y"])
                player_sunits[i].uc:goto_location(my_vector,go_to["moveFast"])
            end           
        end
    end
end


-- register callbacks to read the order json and write the observations
bm:register_phase_change_callback(
    "Deployed",
    function()
        bm:repeat_callback(
            function()
                ModLog("____________________")
                ModLog("*******LOOP*********")
                readJSON()
                exportObservation()
            end,
            1000,
            "Actions"
        )
    end
)