--imports

local env = {}

local json = require("script/_lib/mod/_json")
env.ui = require("script/_lib/mod/_UI")

-- set file locations
local ordersFileName = "orders.json"
local observationFile = "observation.json"
local interconnectGameFileName = "interconnectGame.json"
local interconnectEnvFileName = "interconnectEnv.json"

--setup
env.bm = battle_manager:new(empire_battle:new())

-- player army setup
local player_army = env.bm:get_player_army()
local player_units = player_army:units()

-- enemy army setup
local enemy_army = env.bm:get_first_non_player_army()
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

--set global value for json lib
math.huge = 2^1024

-- victory state
local victory = ""

--get a single observation from a defined script unit
local function singleObservation(unit)
    local UID = unit.unit:unique_ui_id()
    local x_position = unit.unit:position():get_x()
    local y_position = unit.unit:position():get_z()
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
    UiD = UID,
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
function env.exportObservation() 
    local file = io.open(observationFile, "w+")
    local observation = {
        allies = {},
        enemies = {},
        win = victory
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
function env.readOrders()
    local file = io.open(ordersFileName, "r")
    if file then
        local File = file:read("*a")
        local all = json.decode(File)
        local orders = all["allies"]
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

function env.playerVictory()
    victory = "player"
end

function env.playerDefeat()
    victory = "enemy"
end

local function waitForAI()
    local notReady = true
    local file = io.open(interconnectGameFileName, "w+")
    local message = {
        envReady = true
    }
    local messageString = json.encode(message)
    file:write(messageString)
    file:close()
    
    while notReady do
        file = io.open(interconnectEnvFileName, "r")
        if file ~= nil then
            messageString = file:read("*a")
            message = json.decode(messageString)
            if message["aiReady"] then
                notReady = false
            end
        end
        
    end
    file:close()
end


function env.setup()
    env.exportObservation()
    waitForAI()
    env.readOrders()
    env.ui.StartBattle()
end

function env.reset()
    
end

return env