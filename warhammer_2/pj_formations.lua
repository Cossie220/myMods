PJ_FORMATIONS = PJ_FORMATIONS or {}
local mod = PJ_FORMATIONS

local bm = get_bm();

mod.button_groups = mod.button_groups or {}
mod.formations = mod.formations or {}

mod.script_unit_cache = mod.script_unit_cache or {}

mod.starting_x = 18
mod.starting_y = 60

mod.save_key = function(unit_formation_data_list, unit_key, position, bearing, width)
	table.insert(unit_formation_data_list, {unit_key, {position:get_x(), position:get_y(), position:get_z()}, bearing, width})
end

mod.get_ordered = function(ordered, unit_type)
	for i, data in ipairs(ordered) do
		if data[1] == unit_type then
			local ret = {data[2], data[3], data[4]}
			table.remove(ordered, i)
			return ret
		end
	end
end

table.clone = function(t)
	local clone = {}

	for key, value in pairs(t) do
		if type(value) ~= "table" then
			clone[key] = value
		else
			clone[key] = table.clone(value)
		end
	end

	return clone
end

math.huge = 2^1024

local json = require("pj_formations/json")

mod.load_formations_from_file = function()
	local file = io.open('formations_new.json')
	if file then
		local all = file:read("*a")
		pcall(function()
			mod.formations = json.decode(all)
		end)
		file:close()
	end
	if not mod.formations then
		out("pj_formations: JSON DECODE FAILED!")
	end
end
mod.load_formations_from_file()

mod.add_new_formation = function(formation_index)
	local unit_formation_data_list = mod.pj_save_army()
	mod.formations[formation_index] = unit_formation_data_list

	mod.serialize_formations()
end

mod.serialize_formations = function()
	local file = io.open('formations_new.json', 'w')
	file:write(json.encode(mod.formations))
	file:close()
end

mod.ROTATION_TYPES = {
	["180"] = 1,
	["CW_90"] = 2,
	["CCW_90"] = 3,
	["SMART"] = 4,
}

mod.apply_formation = function(formation, rotation_type)
	local player_army = bm:get_player_army();
	local player_units = player_army:units();

	local camera = bm:camera();
	local order = table.clone(formation)

	local first_unit = player_units:item(1);
	local first_unit_bearing = first_unit:ordered_bearing()
	local first_unit_position = first_unit:ordered_position()

	local first_unit_bearing_in_formation = formation[1][3]

	-- out("first unit bearing in formation:")
	-- out(tostring(first_unit_bearing_in_formation))
	-- out("first unit bearing:")
	-- out(tostring(first_unit_bearing))
	-- out("first unit position in formation:")
	-- out(tostring(first_unit_position:get_x()))
	-- out(tostring(first_unit_position:get_y()))
	-- out(tostring(first_unit_position:get_z()))

	for i = 1, player_units:count() do
		local current_unit = player_units:item(i);
		if current_unit then
			local type_key = current_unit:type();

			local unit_position = current_unit:ordered_position()
			-- if i ~= 1 then
				-- out(string.format("\nUnit %s %s %s position:", i, current_unit:unique_ui_id(), type_key))
				-- out(tostring(unit_position:get_x()))
				-- out(tostring(unit_position:get_y()))
				-- out(tostring(unit_position:get_z()))

				-- out(string.format("\nUnit %s position relative to first:", i))
				-- out(tostring(first_unit_position:get_x()- unit_position:get_x()))
				-- out(tostring(first_unit_position:get_z()- unit_position:get_z()))
			-- end

			pcall(function()
				local su = script_unit:new(player_army, i)

				local c = mod.get_ordered(order, type_key)
				if c then
					local new_v = battle_vector:new(c[1][1], c[1][2], c[1][3])
					local len = new_v:length_xz()

					local staring_angle = 180
					if new_v:get_x() < 0 and new_v:get_z() > 0 then
						staring_angle = 180
					elseif new_v:get_x() > 0 and new_v:get_z() < 0 then
						staring_angle = 0
					elseif new_v:get_x() > 0 and new_v:get_z() > 0 then
						staring_angle = 0
					end

					local angle = 0
					if c[1][3] ~= 0 and c[1][1] ~= 0 then
						angle = math.deg(math.atan(c[1][3]/c[1][1]))+staring_angle+360-(first_unit_bearing-first_unit_bearing_in_formation)
						su:teleport_to_location(battle_vector:new(first_unit_position:get_x()+len*((math.cos(math.rad(angle)))), first_unit_position:get_y(), first_unit_position:get_z()+len*((math.sin(math.rad(angle))))), first_unit_bearing-c[2],c[3])
					end
				end

				su:release_control()
			end)
		end
	end
end

mod.get_deployed_army = function()
	local current_army = {}
	local player_army = bm:get_player_army();
	local player_units = player_army:units();
	for i = 1, player_units:count() do
		local current_unit = player_units:item(i);
		if current_unit then
			local type_key = current_unit:type();
			current_army[type_key] = current_army[type_key] and (current_army[type_key]+1) or 1
		end
	end
	return current_army
end

--- Compare the currently deployed army to the formation with index.
mod.get_differences = function(index)
	local current_army = mod.get_deployed_army()
	local diff = {}
	local formation = {}
	for _, unit_formation_data in ipairs(mod.formations[index]) do
		local unit_type = unit_formation_data[1]
		formation[unit_type] = formation[unit_type] and (formation[unit_type]+1) or 1
	end

	for type_key, count in pairs(current_army) do
		if not formation[type_key] then
			diff[type_key] = count
		else
			local signed_diff = formation[type_key] - count
			if signed_diff ~= 0 then
				diff[type_key] = signed_diff<0 and (signed_diff*-1) or signed_diff
			end
			formation[type_key] = nil
		end
	end

	local missing_in_army = {}
	-- what's left in the table is units that don't exist in the current player army
	for type_key, count in pairs(formation) do
		missing_in_army[type_key] = count
	end

	return missing_in_army, diff
end

mod.pj_save_army = function()
	local unit_formation_data_list = {}
	local player_army = bm:get_player_army();
	local player_units = player_army:units();

	local first_unit = player_units:item(1);
	local first_unit_bearing = first_unit:ordered_bearing()
	local first_unit_position = first_unit:ordered_position()

	for i = 1, player_units:count() do
		local current_unit = player_units:item(i);
		if current_unit then
			local type_key = current_unit:type();

			local unit_bearing = (i==1 and first_unit_bearing) or (first_unit_bearing-current_unit:ordered_bearing())
			mod.save_key(unit_formation_data_list, type_key, current_unit:ordered_position()-first_unit_position, unit_bearing, current_unit:ordered_width())
		end
	end
	return unit_formation_data_list
end

local help_button = find_uicomponent(
	core:get_ui_root(),
	"menu_bar",
	"buttongroup",
	"button_help_panel"
)

---@diagnostic disable-next-line: undefined-doc-name
---@type CA_UIC
mod.add_new_formation_button = mod.add_new_formation_button or UIComponent(help_button:CopyComponent("PJ_FORMATIONS_ADD_NEW_FORMATION_BUTTON"))

local root = core:get_ui_root()
root:Adopt(mod.add_new_formation_button:Address())

local function set_tooltip(button, tooltip_text)
	button:SetTooltipText(tooltip_text, true)
end

mod.add_new_formation_button:SetImagePath("ui/skins/default/icon_plus_small.png")
set_tooltip(mod.add_new_formation_button, "Add new formation")

mod.add_new_formation_button:MoveTo(mod.starting_x, mod.starting_y)

core:remove_listener('PJ_FORMATIONS_ON_MOUSE_OVER_APPLY_FORMATION')
core:add_listener(
	'PJ_FORMATIONS_ON_MOUSE_OVER_APPLY_FORMATION',
	'ComponentMouseOn',
	function(context)
		return context.string:starts_with("PJ_FORMATIONS_FORMATION_APPLY_BUTTON_")
		or context.string:starts_with("PJ_FORMATIONS_FORMATION_APPLY_180_BUTTON_")
		or context.string:starts_with("PJ_FORMATIONS_FORMATION_APPLY_SMART_BUTTON_")
		or context.string:starts_with("PJ_FORMATIONS_FORMATION_APPLY_CCW_90_BUTTON_")
		or context.string:starts_with("PJ_FORMATIONS_FORMATION_APPLY_CW_90_BUTTON_")
	end,
	function(context)
		local component_name = context.string
		bm:callback(function()
			local only_index = string.gsub(component_name, "PJ_FORMATIONS_FORMATION_APPLY_BUTTON_", "")
			only_index = string.gsub(only_index, "PJ_FORMATIONS_FORMATION_APPLY_180_BUTTON_", "")
			only_index = string.gsub(only_index, "PJ_FORMATIONS_FORMATION_APPLY_SMART_BUTTON_", "")
			only_index = string.gsub(only_index, "PJ_FORMATIONS_FORMATION_APPLY_CCW_90_BUTTON_", "")
			only_index = string.gsub(only_index, "PJ_FORMATIONS_FORMATION_APPLY_CW_90_BUTTON_", "")
			local index = tonumber(only_index)

			if index and mod.formations[index] then
				local formation_unit_types = {}
				for _, unit_formation_data in ipairs(mod.formations[index]) do
					local unit_type = unit_formation_data[1]
					formation_unit_types[unit_type] = formation_unit_types[unit_type] and (formation_unit_types[unit_type]+1) or 1
				end

				local player_army = bm:get_player_army()
				local player_units = player_army:units()
				for i = 1, player_units:count() do
					local current_unit = player_units:item(i)
					if mod.script_unit_cache[i] then
						mod.script_unit_cache[i]:remove_ping_icon()
					end

					if current_unit then
						local unit_type = current_unit:type()
						if formation_unit_types[unit_type] and formation_unit_types[unit_type] > 0 then
							formation_unit_types[unit_type] = formation_unit_types[unit_type]-1
						else
							pcall(function()
								mod.script_unit_cache[i] = mod.script_unit_cache[i] or script_unit:new(player_army, i)
								local su = mod.script_unit_cache[i]
								su:remove_ping_icon()
								su:add_ping_icon(nil, 3000)
							end)
						end
					end
				end
			end
		end, 0.1)
	end,
	true
)

local function update_differences(index)
	local missing_in_army, other_diffs = mod.get_differences(index)
	local diffs_info = ""

	local function add_to_diffs_info(diff_table, message)
		local wrote_message = false
		for unit_type, count in pairs(diff_table) do
			if not wrote_message then
				diffs_info = diffs_info.."\n\n"..message
				wrote_message = true
			end
			local localized_unit_name = effect.get_localised_string("land_units_onscreen_name_"..tostring(unit_type))
			localized_unit_name = localized_unit_name ~= "" and localized_unit_name or unit_type
			diffs_info = diffs_info
				.."\n"..tostring(localized_unit_name)
				.." x"..tostring(count)
		end
	end

	add_to_diffs_info(missing_in_army, "Units in formation but not in army:")
	add_to_diffs_info(other_diffs, "Units in army but not in formation:")

	local button_group = mod.button_groups[index]
	if not button_group then return end

	-- set_tooltip(button_group.apply_button, "Apply Formation"..diffs_info)
	set_tooltip(button_group.delete_button, "Delete")
	set_tooltip(button_group.replace_button, "Replace")
	-- set_tooltip(button_group.apply_cw_90_button, "Apply rotated 90 degrees clockwise."..diffs_info)
	-- set_tooltip(button_group.apply_ccw_90_button, "Apply rotated 90 degrees counter-clockwise."..diffs_info)
	-- set_tooltip(button_group.apply_180_button, "Apply rotated 180 degrees."..diffs_info)
	set_tooltip(button_group.apply_smart_button, "Apply the formation relative to the Lord's position and orientation"..diffs_info)
end

core:remove_listener('PJ_FORMATIONS_FORMATION_REPLACE_BUTTON_CB')
core:add_listener(
	'PJ_FORMATIONS_FORMATION_REPLACE_BUTTON_CB',
	'ComponentLClickUp',
	function(context)
		return context.string:starts_with("PJ_FORMATIONS_FORMATION_REPLACE_BUTTON_")
	end,
	function(context)
		local component_name = context.string
		bm:callback(
			function()
				local only_index = string.gsub(component_name, "PJ_FORMATIONS_FORMATION_REPLACE_BUTTON_", "")
				local index = tonumber(only_index)
				if index and mod.formations[index] then
					mod.add_new_formation(index)

					update_differences(index)
				end
			end,
			0.1
		)
	end,
	true
)

mod.hide_buttons = function()
	for _, button_group in ipairs(mod.button_groups) do
		for _, button in pairs(button_group) do
			if button.SetVisible then
				button:SetVisible(false)
			end
		end
	end

	mod.add_new_formation_button:SetVisible(false)
end

mod.realign_buttons = function()
	local i = 0
	for _, button_group in ipairs(mod.button_groups) do
		button_group.delete_button:MoveTo(mod.starting_x, mod.starting_y+(i)*40)
		button_group.replace_button:MoveTo(mod.starting_x+40, mod.starting_y+(i)*40)
		-- button_group.apply_button:MoveTo(mod.starting_x+80, mod.starting_y+(i)*40)
		-- button_group.apply_cw_90_button:MoveTo(mod.starting_x+120, mod.starting_y+(i)*40)
		-- button_group.apply_ccw_90_button:MoveTo(mod.starting_x+120+40, mod.starting_y+(i)*40)
		-- button_group.apply_180_button:MoveTo(mod.starting_x+120+80, mod.starting_y+(i)*40)
		button_group.apply_smart_button:MoveTo(mod.starting_x+100, mod.starting_y+(i)*40)
		i = i + 1
	end

	mod.add_new_formation_button:MoveTo(mod.starting_x, mod.starting_y+(i)*40)
end

mod.create_formation_buttons = function(new_index)
	local new_button_group = {}

	local root = core:get_ui_root()
	local button_prefix = "PJ_FORMATIONS_FORMATION"
	new_button_group.delete_button = UIComponent(help_button:CopyComponent(button_prefix.."_DELETE_BUTTON_"..tostring(new_index)))
	root:Adopt(new_button_group.delete_button:Address())
	new_button_group.replace_button = UIComponent(help_button:CopyComponent(button_prefix.."_REPLACE_BUTTON_"..tostring(new_index)))
	root:Adopt(new_button_group.replace_button:Address())
	-- new_button_group.apply_button = UIComponent(help_button:CopyComponent(button_prefix.."_APPLY_BUTTON_"..tostring(new_index)))
	-- root:Adopt(new_button_group.apply_button:Address())

	-- new_button_group.apply_cw_90_button = UIComponent(help_button:CopyComponent(button_prefix.."_APPLY_CW_90_BUTTON_"..tostring(new_index)))
	-- root:Adopt(new_button_group.apply_cw_90_button:Address())
	-- new_button_group.apply_ccw_90_button = UIComponent(help_button:CopyComponent(button_prefix.."_APPLY_CCW_90_BUTTON_"..tostring(new_index)))
	-- root:Adopt(new_button_group.apply_ccw_90_button:Address())
	-- new_button_group.apply_180_button = UIComponent(help_button:CopyComponent(button_prefix.."_APPLY_180_BUTTON_"..tostring(new_index)))
	-- root:Adopt(new_button_group.apply_180_button:Address())
	new_button_group.apply_smart_button = UIComponent(help_button:CopyComponent(button_prefix.."_APPLY_SMART_BUTTON_"..tostring(new_index)))
	root:Adopt(new_button_group.apply_smart_button:Address())

	local missing_in_army, other_diffs = mod.get_differences(new_index)
	local diffs_info = ""

	local function add_to_diffs_info(diff_table, message)
		local wrote_message = false
		for unit_type, count in pairs(diff_table) do
			if not wrote_message then
				diffs_info = diffs_info.."\n\n"..message
				wrote_message = true
			end
			local localized_unit_name = effect.get_localised_string("land_units_onscreen_name_"..tostring(unit_type))
			localized_unit_name = localized_unit_name ~= "" and localized_unit_name or unit_type
			diffs_info = diffs_info
				.."\n"..tostring(localized_unit_name)
				.." x"..tostring(count)
		end
	end

	add_to_diffs_info(missing_in_army, "Units in saved formation but not in army:")
	add_to_diffs_info(other_diffs, "Units in army but not in saved formation:")

	-- set_tooltip(new_button_group.apply_button, "Apply Formation"..diffs_info)
	set_tooltip(new_button_group.delete_button, "Delete")
	set_tooltip(new_button_group.replace_button, "Replace")
	-- set_tooltip(new_button_group.apply_cw_90_button, "Apply rotated 90 degrees clockwise."..diffs_info)
	-- set_tooltip(new_button_group.apply_ccw_90_button, "Apply rotated 90 degrees counter-clockwise."..diffs_info)
	-- set_tooltip(new_button_group.apply_180_button, "Apply rotated 180 degrees."..diffs_info)
	set_tooltip(new_button_group.apply_smart_button, "Apply the formation relative to the Lord's position and orientation"..diffs_info)
	-- new_button_group.apply_button:SetImagePath("ui/skins/default/icon_formation.png")
	-- new_button_group.apply_cw_90_button:SetImagePath("ui/skins/default/icon_formation.png")
	-- new_button_group.apply_ccw_90_button:SetImagePath("ui/skins/default/icon_formation.png")
	-- new_button_group.apply_180_button:SetImagePath("ui/skins/default/icon_formation.png")
	new_button_group.apply_smart_button:SetImagePath("ui/skins/default/icon_formation.png")
	new_button_group.delete_button:SetImagePath("ui/skins/default/icon_replace.png")
	new_button_group.replace_button:SetImagePath("ui/skins/default/icon_plus_small.png")

	new_button_group.delete_button:MoveTo(mod.starting_x, mod.starting_y+(new_index-1)*40)
	new_button_group.replace_button:MoveTo(mod.starting_x+40, mod.starting_y+(new_index-1)*40)
	-- new_button_group.apply_button:MoveTo(mod.starting_x+80, mod.starting_y+(new_index-1)*40)
	-- new_button_group.apply_cw_90_button:MoveTo(mod.starting_x+120, mod.starting_y+(new_index-1)*40)
	-- new_button_group.apply_ccw_90_button:MoveTo(mod.starting_x+120+40, mod.starting_y+(new_index-1)*40)
	-- new_button_group.apply_180_button:MoveTo(mod.starting_x+120+80, mod.starting_y+(new_index-1)*40)
	new_button_group.apply_smart_button:MoveTo(mod.starting_x+100, mod.starting_y+(new_index-1)*40)

	mod.button_groups[new_index] = new_button_group
end

mod.new_formation_from_file = function(formation_index)
	mod.create_formation_buttons(formation_index)
	mod.add_new_formation_button:MoveTo(mod.starting_x, mod.starting_y+formation_index*40)
end
for i in ipairs(mod.formations) do
	mod.new_formation_from_file(i)
end

core:remove_listener('PJ_FORMATIONS_ADD_NEW_FORMATION_BUTTON_CB')
core:add_listener(
	'PJ_FORMATIONS_ADD_NEW_FORMATION_BUTTON_CB',
	'ComponentLClickUp',
	function(context)
		return context.string == "PJ_FORMATIONS_ADD_NEW_FORMATION_BUTTON"
	end,
	function()
		bm:callback(
			function()
				local new_index = #mod.button_groups+1
				mod.add_new_formation(new_index)

				mod.create_formation_buttons(new_index)

				mod.add_new_formation_button:MoveTo(mod.starting_x, mod.starting_y+new_index*40)
			end,
			0.1
		)
	end,
	true
)

mod.delete_buttons = function()
	local dummy = core:get_or_create_component("pj_formations_dummy", "ui/campaign ui/script_dummy")

	for _, button_group in ipairs(mod.button_groups) do
		for _, button in pairs(button_group) do
			dummy:Adopt(button:Address())
		end
	end

	dummy:DestroyChildren()
end

mod.starting_id_to_rotation = {
	["PJ_FORMATIONS_FORMATION_APPLY_180_BUTTON_"] =  mod.ROTATION_TYPES["180"],
	["PJ_FORMATIONS_FORMATION_APPLY_CCW_90_BUTTON_"] = mod.ROTATION_TYPES["CW_90"],
	["PJ_FORMATIONS_FORMATION_APPLY_CW_90_BUTTON_"] = mod.ROTATION_TYPES["CCW_90"],
	["PJ_FORMATIONS_FORMATION_APPLY_SMART_BUTTON_"] = mod.ROTATION_TYPES["SMART"],
}

core:remove_listener('PJ_NEW_BUTTON_RENAME_THIS_LOAD_CB')
core:add_listener(
	'PJ_NEW_BUTTON_RENAME_THIS_LOAD_CB',
	'ComponentLClickUp',
	function(context)
		return context.string:starts_with("PJ_FORMATIONS_FORMATION_APPLY_BUTTON_")
			or context.string:starts_with("PJ_FORMATIONS_FORMATION_APPLY_180_BUTTON_")
			or context.string:starts_with("PJ_FORMATIONS_FORMATION_APPLY_CCW_90_BUTTON_")
			or context.string:starts_with("PJ_FORMATIONS_FORMATION_APPLY_CW_90_BUTTON_")
			or context.string:starts_with("PJ_FORMATIONS_FORMATION_APPLY_SMART_BUTTON_")
	end,
	function(context)
		local component_name = context.string
		bm:callback(
			function()
				local rotation_type = nil
				for starting_id, formation_rotation in pairs(mod.starting_id_to_rotation) do
					if string.find(component_name, starting_id) then
						rotation_type = formation_rotation
						break
					end
				end

				local only_index = string.gsub(component_name, "PJ_FORMATIONS_FORMATION_APPLY_BUTTON_", "")
				only_index = string.gsub(only_index, "PJ_FORMATIONS_FORMATION_APPLY_180_BUTTON_", "")
				only_index = string.gsub(only_index, "PJ_FORMATIONS_FORMATION_APPLY_SMART_BUTTON_", "")
				only_index = string.gsub(only_index, "PJ_FORMATIONS_FORMATION_APPLY_CCW_90_BUTTON_", "")
				only_index = string.gsub(only_index, "PJ_FORMATIONS_FORMATION_APPLY_CW_90_BUTTON_", "")
				local index = tonumber(only_index)
				if index and mod.formations[index] then
					pcall(function()
						mod.apply_formation(mod.formations[index], rotation_type)
					end)
				end
			end,
			0.1
		)
	end,
	true
)

core:remove_listener('PJ_FORMATIONS_FORMATION_DELETE_BUTTON_CB')
core:add_listener(
	'PJ_FORMATIONS_FORMATION_DELETE_BUTTON_CB',
	'ComponentLClickUp',
	function(context)
		return context.string:starts_with("PJ_FORMATIONS_FORMATION_DELETE_BUTTON_")
	end,
	function(context)
		local component_name = context.string
		bm:callback(
			function()
				local only_index = string.gsub(component_name, "PJ_FORMATIONS_FORMATION_DELETE_BUTTON_", "")
				local index = tonumber(only_index)
				if mod.button_groups[index] then
					table.remove(mod.formations, index)
					mod.serialize_formations()

					mod.delete_buttons()
					mod.button_groups = {}

					for i in ipairs(mod.formations) do
						mod.new_formation_from_file(i)
					end
					mod.realign_buttons()
				end
			end,
			0.1
		)
	end,
	true
)

core:remove_listener("PJ_FORMATIONS_ON_TOGGLE_UI")
core:add_listener(
	"PJ_FORMATIONS_ON_TOGGLE_UI",
	"ShortcutTriggered",
	function(context)
		return context.string == "toggle_ui"
	end,
	function()
		if not mod.add_new_formation_button then return end

		if mod.add_new_formation_button:Visible() then
			mod.hide_buttons()
		else
			mod.show_buttons()
		end
	end,
	true
)

mod.show_buttons = function()
	for _, button_group in ipairs(mod.button_groups) do
		for _, button in pairs(button_group) do
			if button.SetVisible then
				button:SetVisible(true)
			end
		end
	end

	mod.add_new_formation_button:SetVisible(true)
end

bm:register_phase_change_callback(
	"Deployed",
	function()
		core:remove_listener("PJ_FORMATIONS_ON_TOGGLE_UI")
		mod.hide_buttons()
	end
)
