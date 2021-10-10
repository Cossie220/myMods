UI = {}
local menuButton = "root > menu_bar > buttongroup > button_menu"
local concedeDefeat = "root > panel_manager > esc_menu_battle > menu_1 > button_quit"
local confirm = "root > popup_create_room > button_ok"
local startBattle = "root > finish_deployment > deployment_end_sp > button_battle_start"
local endBattleWon = "root > layout > popups_list > battle_won_frame > button_end_battle"
local rematch = "root > panel_manager > in_battle_results_popup > background > button_background > button_parent > button_rematch"

---@return CA_UIC
local function find_ui_component_str(starting_comp, str)
	local has_starting_comp = str ~= nil
	if not has_starting_comp then
		str = starting_comp
	end
	local fields = {}
	local pattern = string.format("([^%s]+)", " > ")
	string.gsub(str, pattern, function(c)
		if c ~= "root" then
			fields[#fields+1] = c
		end
	end)
	return find_uicomponent(has_starting_comp and starting_comp or core:get_ui_root(), unpack(fields))
end

core:remove_listener("rematch")
core:add_listener(
	"rematch",
	"RealTimeTrigger",
	function(context)
			return context.string == "rematch_timer"
	end,
	function()
		local button = find_ui_component_str(rematch)
		button:SimulateLClick()
	end,
	true
)

core:remove_listener("concedeDefeat")
core:add_listener(
	"concedeDefeat",
	"RealTimeTrigger",
	function(context)
			return context.string == "concedeDefeat_timer_part1"
	end,
	function()
		local button = find_ui_component_str(concedeDefeat)
		button:SimulateLClick()
	end,
	true
)

core:remove_listener("confirm")
core:add_listener(
	"confirm",
	"RealTimeTrigger",
	function(context)
			return context.string == "concedeDefeat_timer_part2"
	end,
	function()
		local button = find_ui_component_str(confirm)
		button:SimulateLClick()
	end,
	true
)

core:remove_listener("ai_test_mod_start_battle")
core:add_listener(
	"ai_test_mod_start_battle",
	"RealTimeTrigger",
	function(context)
			return context.string == "startBattle"
	end,
	function()
		local button = find_ui_component_str(startBattle)
		button:SimulateLClick()
	end,
	true
)


function UI.ConcedeDefeat()
	local button = find_ui_component_str(menuButton)
	button:SimulateLClick()
	real_timer.register_singleshot("concedeDefeat",50)
end


function UI.StartBattle()
    real_timer.unregister("ai_test_mod_start_battle")
	real_timer.register_singleshot("startBattle",500)
end


function UI.AutoReset(PlayerWin)
	if PlayerWin then
		local button = find_ui_component_str(endBattleWon)
		button:SimulateLClick()
		real_timer.register_singleshot("rematch",50)
	end
end

return UI
