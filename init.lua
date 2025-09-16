-- Minetest mod: text_note_interaction
-- Allows players to add/edit text notes on nodes, display first line as floating text, and use 'E' key for interaction
-- Prevents destruction of nodes with non-empty notes, including attached nodes like torches
-- List of nodes to make interactive (add more as needed)
local interactive_nodes = {
	"default:stone" ,
	"default:dirt" ,
	"default:cobble" ,
	"default:goldblock" ,
	-- Add other nodes here
}
-- Table to track last 'E' key press time per player to debounce
local last_press_time = { }
-- Table to prevent restoration loops
local restoration_flags = { }
-- Helper function to check if a value is in a table
function table.contains ( table , element )
	for _ , value in ipairs ( table ) do
		if value == element then
			return true
		end
	end
	return false
end

-- Entity for displaying floating text
minetest.register_entity ( "text_note_interaction:floating_text" , {
		initial_properties = {
			physical = false ,
			collide_with_objects = false ,
			visual = "sprite" ,
			textures = { "[combine:1x1" } , -- Fallback transparent texture
			visual_size = { x = 1 , y = 1 } ,
			nametag = "" ,
			nametag_color = "#FFFFFF" ,
			is_visible = true ,
			static_save = true ,
			pointable = false , -- Make entity non-pointable
		} ,
		on_activate = function ( self , staticdata )
			local pos = self.object : get_pos ( )
			minetest.log ( "action" , "Floating text entity activated at " ..( pos and minetest.pos_to_string ( pos ) or "nil" ) )
		end

		,
		on_step = function ( self , dtime )
			local pos = self.object : get_pos ( )
			if not pos then
				minetest.log ( "warning" , "Floating text entity removed: no position" )
				self.object : remove ( )
				return
			end
			local node_pos = { x = pos.x , y = pos.y -0.5 , z = pos.z }
			local node = minetest.get_node_or_nil ( node_pos )
			if not node or not table.contains ( interactive_nodes , node.name ) then
				minetest.log ( "action" , "Floating text entity removed: invalid node at " ..minetest.pos_to_string ( node_pos ) )
				self.object : remove ( )
				return
			end
			local meta = minetest.get_meta ( node_pos )
			local note = meta : get_string ( "text_note" ) or ""
			local first_line = note : split ( "\n" ) [ 1 ] or ""
			self.object : set_nametag_attributes ( {
					text = first_line ,
					color = "#FFFFFF" ,
				} )
		end

	} )
-- Formspec for viewing/editing the note
local function get_note_formspec ( pos , player )
	local meta = minetest.get_meta ( pos )
	local note = meta : get_string ( "text_note" ) or ""
	local node = minetest.get_node_or_nil ( pos )
	local player_name = player : get_player_name ( )
	local node_name = node and node.name or "unknown"
	local node_def = minetest.registered_nodes [ node_name ] or { }
	local formspec = {
		"formspec_version[4]" ,
		"size[8,8]" ,
		"textarea[0.5,0.5;7,5;note;Note;" ..minetest.formspec_escape ( note ) .."]" ,
		"button_exit[0.5,6;3,1;save;Save]" ,
		"button_exit[4,6;3,1;cancel;Cancel]"
	}
	return table.concat ( formspec , "" )
end

-- Update or create floating text entity for a node
local function update_floating_text ( pos )
	local pos_above = { x = pos.x , y = pos.y + 0.5 , z = pos.z }
	local objects = minetest.get_objects_inside_radius ( pos_above , 0.5 )
	local text_entity = nil
	for _ , obj in ipairs ( objects ) do
		if obj : get_luaentity ( ) and obj : get_luaentity ( ).name == "text_note_interaction:floating_text" then
			text_entity = obj
			break
		end
	end
	local meta = minetest.get_meta ( pos )
	local note = meta : get_string ( "text_note" ) or ""
	local first_line = note : split ( "\n" ) [ 1 ] or ""
	if first_line ~= "" then
		if not text_entity then
			text_entity = minetest.add_entity ( pos_above , "text_note_interaction:floating_text" )
			minetest.log ( "action" , "Created floating text entity at " ..minetest.pos_to_string ( pos_above ) )
		end
		if text_entity then
			text_entity : set_nametag_attributes ( {
					text = first_line ,
					color = "#FFFFFF" ,
				} )
		end
	elseif text_entity then
		minetest.log ( "action" , "Removed floating text entity at " ..minetest.pos_to_string ( pos_above ) )
		text_entity : remove ( )
	end
end

-- Handle formspec submission
minetest.register_on_player_receive_fields ( function ( player , formname , fields )
		minetest.log ( "action" , "Formspec received: formname=" ..formname ..", fields=" ..minetest.serialize ( fields ) )
		if not formname : match ( "^text_note_interaction:edit_note:" ) then
			return false
		end
		local player_name = player : get_player_name ( )
		local pos_str = formname : match ( "text_note_interaction:edit_note:(.+)" )
		if not pos_str then
			minetest.chat_send_player ( player_name , "Error: Invalid form position." )
			minetest.log ( "error" , "Failed to extract pos from formname: " ..formname )
			return false
		end
		local pos = minetest.string_to_pos ( pos_str )
		if not pos then
			minetest.chat_send_player ( player_name , "Error: Invalid position format." )
			minetest.log ( "error" , "Failed to parse pos: " ..pos_str )
			return false
		end
		if fields.save and fields.note then
			local meta = minetest.get_meta ( pos )
			meta : set_string ( "text_note" , fields.note )
			minetest.chat_send_player ( player_name , "Note saved successfully!" )
			minetest.log ( "action" , "Note saved for node at " ..minetest.pos_to_string ( pos ) .." by " ..player_name )
			update_floating_text ( pos )
		elseif fields.cancel then
			minetest.chat_send_player ( player_name , "Note editing canceled." )
		else
			minetest.log ( "warning" , "No action taken for fields: " ..minetest.serialize ( fields ) )
		end
		return true
	end

)
-- Override nodes for right-click interaction and dig protection
for _ , node_name in ipairs ( interactive_nodes ) do
	minetest.override_item ( node_name , {
			on_rightclick = function ( pos , node , player , itemstack , pointed_thing )
				local player_name = player : get_player_name ( )
				local formspec = get_note_formspec ( pos , player )
				minetest.show_formspec ( player_name , "text_note_interaction:edit_note:" ..minetest.pos_to_string ( pos ) , formspec )
				minetest.log ( "action" , "Showing formspec for node at " ..minetest.pos_to_string ( pos ) .." to " ..player_name .." via right-click" )
				return itemstack
			end

			,
			can_dig = function ( pos , player )
				local meta = minetest.get_meta ( pos )
				local note = meta : get_string ( "text_note" ) or ""
				if note ~= "" then
					local player_name = player and player : get_player_name ( ) or "unknown"
					minetest.chat_send_player ( player_name , "Cannot dig node at " ..minetest.pos_to_string ( pos ) ..": it contains a note." )
					minetest.log ( "action" , "Dig attempt blocked for node at " ..minetest.pos_to_string ( pos ) .." by " ..player_name ..": has note" )
					return false
				end
				return true
			end

		} )
end
-- Update floating text when nodes are placed
minetest.register_on_placenode ( function ( pos , node )
		if table.contains ( interactive_nodes , node.name ) then
			update_floating_text ( pos )
			minetest.log ( "action" , "Node placed at " ..minetest.pos_to_string ( pos ) ..", updating floating text" )
		end
	end

)
-- Initialize floating text for existing nodes with non-empty notes
minetest.register_lbm ( {
		label = "Initialize floating text for interactive nodes with notes" ,
		name = "text_note_interaction:init_floating_text" ,
		nodenames = interactive_nodes ,
		run_at_every_load = true ,
		action = function ( pos , node )
			local meta = minetest.get_meta ( pos )
			local note = meta : get_string ( "text_note" ) or ""
			if note ~= "" then
				update_floating_text ( pos )
				minetest.log ( "action" , "LBM: Initialized floating text at " ..minetest.pos_to_string ( pos ) .." (has note)" )
			end
		end

	} ) 
