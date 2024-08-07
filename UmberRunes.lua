-- UMBERRUNES 1.12.0


local function get_game_version()
	_, _, _, build_version = GetBuildInfo();
	return tonumber(build_version);
end

local game_version = get_game_version();
-- Is this the Wotlk version?
local is_wrath = game_version >= 30000 and game_version < 40000;
-- Absorb UI info availability (added in MoP)
local has_absorbs = game_version >= 50200;
-- GetSpecialization function availability (added in MoP)
local has_spec = game_version >= 50000;

-- Main variables
local current_spec = 2;
local frame_locked = 1;
local current_time = GetTime();
local new_time = GetTime();
local delta_time = 0;
local function calculate_delta_time()
	current_time = GetTime();
	delta_time = current_time - new_time;
	new_time = current_time;
end

local frame_alpha = 1;

-- Create main frames
local umber_drag_frame = CreateFrame("Frame", "Backgroundframe", UIParent);
umber_drag_frame:SetPoint("CENTER", umb_x, umb_y);
umber_drag_frame:SetWidth(1);
umber_drag_frame:SetHeight(1);

local umber_main_frame = CreateFrame("Frame", nil, UIParent);
umber_main_frame:SetPoint("CENTER", umber_drag_frame, "CENTER", 0, 0);
umber_main_frame:SetWidth(1);
umber_main_frame:SetHeight(1);

local drag_position_text = nil;
drag_position_text = umber_main_frame:CreateFontString("Target Name", "ARTWORK", "GameFontNormalSmall");
drag_position_text:SetPoint("CENTER", umber_main_frame, "CENTER", 0, 50);
drag_position_text:SetText("");

local frames = {};
local umber_frame = {};
function umber_frame:create(name, width, height, class, construct, update)
	local self = {};
	self.name = name;
	self.width = width;
	self.height = height;
	self.class = class;
	self.construct = construct;
	self.update = update;
	self.frame = CreateFrame("Frame", "Backgroundframe", umber_main_frame);
	return self;
end

local function get_frame_enabled(name)
	if umb_data["frame_"..name.."_enabled"] == nil then
		umb_data["frame_"..name.."_enabled"] = true;
		return true;
	else
		return umb_data["frame_"..name.."_enabled"];
	end
end
local function get_frame_class_enabled(class)
	if class == nil or class == "" then
		return true;
	else
		return select(2, UnitClass('player')) == class;
	end
end
local function get_frame_size(name)
	if umb_data["frame_"..name.."_size"] == nil then
		umb_data["frame_"..name.."_size"] = 1;
		return 1;
	else
		return umb_data["frame_"..name.."_size"];
	end
end
local function set_frame_enabled(name, value)
	if value == true or value == false then
		umb_data["frame_"..name.."_enabled"] = value;
	end
end
local function set_frame_size(name, value)
	if tonumber(value) ~= nil then
		umb_data["frame_"..name.."_size"] = value;
	end
end

local function get_frame(name)
	for i = 1, table.getn(frames) do
		if frames[i].name == name and get_frame_class_enabled(frames[i].class) == true then
			return i;
		end
	end
	return -1;
end

local function umber_setup()
	frame_creation_height = 0;
	
	if umb_x == nil then umb_x = 0; end
	if umb_y == nil then umb_y = 0; end
	if umb_data == nil then umb_data = {}; end
	if umb_combat == nil then umb_combat = false; end
	if umb_timers == nil then umb_timers = false; end
	if umb_sort == nil then umb_sort = true; end
	
	if umb_combat == true then frame_alpha = 1; else frame_alpha = 0; end
	
	for i = 1, table.getn(frames) do
		frames[i].frame:SetPoint("TOP", umber_main_frame, "TOP", 0, frame_creation_height);
		frame_creation_height = frame_creation_height - frames[i].height;
		frames[i].frame:SetWidth(frames[i].width);
		frames[i].frame:SetHeight(frames[i].height);
		frames[i].frame:SetFrameLevel(15);
		
		if umb_data["frame_"..frames[i].name.."_enabled"] == nil then
			umb_data["frame_"..frames[i].name.."_enabled"] = true;
			umb_data["frame_"..frames[i].name.."_size"] = 1;
		end
	end
end

-- Components
local function update_alpha()
	if umb_combat == true then
		if UnitAffectingCombat("player") == true or frame_locked == 0 then
			frame_alpha = frame_alpha + delta_time * 5;
		else
			frame_alpha = frame_alpha - delta_time;
		end
	else
		frame_alpha = frame_alpha + delta_time * 5;
	end
	
	if frame_alpha < 0 then frame_alpha = 0; end
	if frame_alpha > 1 then frame_alpha = 1; end
	
	umber_main_frame:SetAlpha(frame_alpha);
end

local function format_big_number(value)
	if(value > 99999999) then return math.floor(value / 1000000).." M"; end
	if(value > 99999) then return math.floor(value / 1000).." K"; end
	return value;
end
local function format_percentage_number(value, maximum)
	if value == 0 or maximun == 0 then return 0; end
	return (floor((value / (maximum / 100)) * 10 ^ 0 + 0.5 ) / 10 ^ 0);
end

-------------------------
-- DISEASE TRACKING
-- Blood Plague, Frost Fever, Virulent Plague
local disease_ids = { 55078, 55095, 191587 };
local disease_textures =
{
	"Interface\\Icons\\spell_deathknight_bloodplague",
	"Interface\\Icons\\spell_deathknight_frostfever",
	"Interface\\Icons\\ability_creature_disease_02",
};
local disease_obj = {};
local function create_disease_frame(x_pos, text_dir)
	disease_frame = CreateFrame("Frame", "Backgroundframe", base_frame.frame);
	disease_frame:SetPoint("CENTER", base_frame.frame, "CENTER", x_pos, 0); -- -base_frame.height / 2
	disease_frame:SetWidth(base_frame.height); 
	disease_frame:SetHeight(base_frame.height);
	disease_texture = disease_frame:CreateTexture("ARTWORK");
	disease_texture:SetAllPoints();
	disease_texture:SetAlpha(1);
	disease_text = disease_frame:CreateFontString("Target Name", "ARTWORK", "GameFontNormalSmall");
	disease_text:SetPoint("CENTER", disease_frame, "CENTER", text_dir, 0); -- -base_frame.height
	disease_text:SetText(" ");
	disease_cd = CreateFrame("Cooldown", "DCD", disease_frame, "CooldownFrameTemplate");
	disease_cd:SetHideCountdownNumbers(true);
	disease_cd:SetReverse(true);
	
	return { frame = disease_frame, texture = disease_texture, text = disease_text, cd = disease_cd };
end
local function setup_diseases()
	if disease_frame == nil then
		
		base_frame = frames[get_frame("diseases")];
		
		if is_wrath then
			disease_obj = {};
			
			disease_obj[1] = create_disease_frame(-base_frame.height / 2, -base_frame.height);
			disease_obj[2] = create_disease_frame(base_frame.height / 2, base_frame.height);
			
			disease_obj[1].texture:SetTexture(disease_textures[2]);
			disease_obj[2].texture:SetTexture(disease_textures[1]);
		
		else
			disease_obj = create_disease_frame(-base_frame.height / 2, -base_frame.height);
		end
		
	end
end
local function update_diseases()
	
	base_frame = frames[get_frame("diseases")];
	
	if is_wrath then
		for i = 1, 2 do
			disease_obj[i].texture:SetAlpha(0.1);
			disease_obj[i].text:SetText(" ");
			disease_obj[i].cd:SetCooldown(0, 0);
		end
		
		i = 1;
		while true do
			local name, _, _, _, dur, exp, _, _, _, id = UnitDebuff("target", i, "PLAYER");
			if name then
				if id == disease_ids[2] then
					disease_obj[1].texture:SetAlpha(1);
					disease_obj[1].text:SetText(math.floor(exp - GetTime()));
					disease_obj[1].cd:SetCooldown(exp - dur, dur);
				end
				if id == disease_ids[1] then
					disease_obj[2].texture:SetAlpha(1);
					disease_obj[2].text:SetText(math.floor(exp - GetTime()));
					disease_obj[2].cd:SetCooldown(exp - dur, dur);
				end
			else
				break;
			end
			i = i + 1;
		end
		
	else
		disease_obj.frame:SetPoint("CENTER", base_frame.frame, "CENTER", -base_frame.height / 2, 0);
		disease_obj.text:SetPoint("CENTER", disease_frame, "CENTER", base_frame.height, 0);
		disease_obj.texture:SetAlpha(0.1);
		
		disease_obj.text:SetText(" ");
		disease_obj.cd:SetCooldown(0, 0);
		disease_obj.texture:SetTexture(disease_textures[current_spec]);
		
		i = 1;
		while true do
			local name, _, _, _, dur, exp, _, _, _, id = UnitDebuff("target", i, "PLAYER");
			if name then
				if id == disease_ids[current_spec] then
					disease_obj.texture:SetAlpha(1);
					disease_obj.text:SetText(math.floor(exp - GetTime()));
					disease_obj.cd:SetCooldown(exp - dur, dur);
					break;
				end
			else
				break;
			end
			i = i + 1;
		end
	end
	
end

-------------------------
-- TARGET INFO
local target_health_frame = nil;
local target_health_background = nil;
local target_health_bar = nil;
local target_health_text = nil;
local target_health_perc = nil;
local target_absorb_frame = nil;
local target_absorb_texture = nil;
local target_absorb_bar = nil;
local target_overabsorb_frame = nil;
local target_overabsorb_texture = nil;
local target_energy_frame = nil;
local target_energy_background = nil;
local target_energy_bar = nil;
local target_energy_text = nil;
local target_energy_perc = nil;
local target_level_text = nil;
local target_name_frame = nil;
local target_name_text = nil;
local target_class_frame = nil;
local target_class_texture = nil;
local function setup_target()
	if target_health_frame == nil then
		
		base_frame = frames[get_frame("target")];
		
		target_health_frame = CreateFrame("Frame", nil, base_frame.frame);
		target_health_frame:SetPoint("TOP", base_frame.frame, "TOP", 0, 0);
		target_health_frame:SetWidth(base_frame.width); 
		target_health_frame:SetHeight(base_frame.height / 2);
		
		target_health_background = target_health_frame:CreateTexture("ARTWORK");
		target_health_background:SetAllPoints();
		target_health_background:SetColorTexture(0.4, 0, 0, 0.4);
		
		if has_absorbs == true then
			target_absorb_bar = CreateFrame("StatusBar", nil, target_health_frame);
			target_absorb_bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
			target_absorb_bar:GetStatusBarTexture():SetHorizTile(false);
			target_absorb_bar:SetMinMaxValues(0, 100);
			target_absorb_bar:SetWidth(base_frame.width);
			target_absorb_bar:SetHeight(base_frame.height / 2);
			target_absorb_bar:SetPoint("CENTER", target_health_frame, "CENTER", 0, 0); 
			target_absorb_bar:SetStatusBarColor(1, 1, 1);
			target_absorb_bar:SetFrameLevel(19);
			
			target_absorb_frame = CreateFrame("Frame", nil, target_health_frame);
			target_absorb_frame:SetPoint("TOP", target_health_frame, "TOP", 0, 0);
			target_absorb_frame:SetWidth(base_frame.width); 
			target_absorb_frame:SetHeight(base_frame.height / 2);
			target_absorb_frame:SetFrameLevel(20);
			
			target_absorb_texture = target_absorb_frame:CreateTexture("ARTWORK");
			target_absorb_texture:SetAllPoints();
			target_absorb_texture:SetTexture("Interface\\RaidFrame\\Shield-Overlay", true);
			target_absorb_texture:SetTexCoord(0, -2, 0, 1);
			
			target_overabsorb_frame = CreateFrame("Frame", nil, target_health_frame);
			target_overabsorb_frame:SetPoint("TOPRIGHT", target_health_frame, "TOPRIGHT", 3, 0);
			target_overabsorb_frame:SetWidth(16); 
			target_overabsorb_frame:SetHeight(base_frame.height / 2);
			target_overabsorb_frame:SetFrameLevel(22);
			
			target_overabsorb_texture = target_overabsorb_frame:CreateTexture("ARTWORK");
			target_overabsorb_texture:SetAllPoints();
			target_overabsorb_texture:SetTexture("Interface\\RaidFrame\\Absorb-Overabsorb");
			target_overabsorb_texture:SetBlendMode("ADD");
		end
		
		target_health_bar = CreateFrame("StatusBar", nil, target_health_frame);
		target_health_bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
		target_health_bar:GetStatusBarTexture():SetHorizTile(false);
		target_health_bar:SetMinMaxValues(0, 100);
		target_health_bar:SetWidth(base_frame.width);
		target_health_bar:SetHeight(base_frame.height / 2);
		target_health_bar:SetPoint("CENTER", target_health_frame, "CENTER", 0, 0); 
		target_health_bar:SetStatusBarColor(0.6, 0, 0);
		target_health_bar:SetFrameLevel(21);
		
		target_health_text = target_health_bar:CreateFontString("Runic Power Number", "ARTWORK", "TextStatusBarText");
		target_health_text:SetPoint("CENTER", target_health_bar, "CENTER", 0, 0);
		target_health_text:SetText(0);
		
		target_health_perc = target_health_bar:CreateFontString("Hit Points Percentage", "ARTWORK", "GameFontNormalSmall");
		target_health_perc:SetPoint("CENTER", target_health_bar, "CENTER", base_frame.width / 2 + 15, 0);
		target_health_perc:SetText(0);
		
		target_level_text = target_health_bar:CreateFontString("Hit Points Percentage", "ARTWORK", "GameFontNormalSmall");
		target_level_text:SetPoint("CENTER", target_health_bar, "CENTER", -base_frame.width / 2 - 16, -base_frame.height / 4);
		target_level_text:SetText(0);
		
		target_class_frame = CreateFrame("Frame", nil, base_frame.frame);
		target_class_frame:SetPoint("TOP", base_frame.frame, "TOP", -base_frame.width / 2 - 12, 0);
		target_class_frame:SetWidth(base_frame.height); 
		target_class_frame:SetHeight(base_frame.height);
		target_class_texture = target_class_frame:CreateTexture("ARTWORK");
		target_class_texture:SetAllPoints();
		target_class_texture:SetColorTexture(1, 1, 1, 1);
		
		target_energy_frame = CreateFrame("Frame", nil, base_frame.frame);
		target_energy_frame:SetPoint("TOP", base_frame.frame, "TOP", 0, -base_frame.height / 2);
		target_energy_frame:SetWidth(base_frame.width); 
		target_energy_frame:SetHeight(base_frame.height / 2);
		
		target_energy_background = target_energy_frame:CreateTexture("ARTWORK");
		target_energy_background:SetAllPoints();
		target_energy_background:SetColorTexture(0.4, 0.4, 0.4, 0.2);
		
		target_energy_bar = CreateFrame("StatusBar", nil, target_energy_frame);
		target_energy_bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
		target_energy_bar:GetStatusBarTexture():SetHorizTile(false);
		target_energy_bar:SetMinMaxValues(0, 100);
		target_energy_bar:SetWidth(base_frame.width);
		target_energy_bar:SetHeight(base_frame.height / 2);
		target_energy_bar:SetPoint("CENTER", target_energy_frame, "CENTER", 0, 0); 
		target_energy_bar:SetStatusBarColor(0.6, 0.6, 0.6);
		
		target_energy_text = target_energy_bar:CreateFontString("Runic Power Number", "ARTWORK", "TextStatusBarText");
		target_energy_text:SetPoint("CENTER", target_energy_bar, "CENTER", 0, 0);
		target_energy_text:SetText(0);
		
		target_energy_perc = target_energy_bar:CreateFontString("Hit Points Percentage", "ARTWORK", "GameFontNormalSmall");
		target_energy_perc:SetPoint("CENTER", target_energy_bar, "CENTER", base_frame.width / 2 + 15, 0);
		target_energy_perc:SetText(0);
		
		target_name_frame = CreateFrame("Frame", nil, base_frame.frame);
		target_name_frame:SetPoint("TOP", base_frame.frame, "TOP", 0, 0);
		target_name_frame:SetWidth(base_frame.width); 
		target_name_frame:SetHeight(base_frame.height);
		
		target_name_text = target_name_frame:CreateFontString("Runic Power Number", "ARTWORK", "GameFontNormalSmall");
		target_name_text:SetPoint("CENTER", target_name_frame, "CENTER", 0, 20);
		target_name_text:SetText(0);
	end
end
local function update_target()
	
	target_health = UnitHealth("target");
	target_max_health = UnitHealthMax("target");
	target_power = UnitPower("target");
	target_max_power = UnitPowerMax("target");
	
	target_health_text:SetText(""..format_big_number(target_health).." / "..format_big_number(target_max_health).."");
	target_health_bar:SetMinMaxValues(0, target_max_health);
	target_health_bar:SetValue(target_health);
	
	base_frame = frames[get_frame("target")];
	
	if UnitIsPlayer("target") == true then
		class, class_token, class_id = UnitClass("target");
		icon_texture = CLASS_ICON_TCOORDS[class_token];
		target_class_texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES");
		target_class_texture:SetTexCoord(unpack(icon_texture));
		target_class_texture:SetAlpha(1);
		target_level_text:SetPoint("CENTER", target_health_bar, "CENTER", -base_frame.width / 2 - 36, -base_frame.height / 4);
	else
		target_class_texture:SetAlpha(0);
		target_level_text:SetPoint("CENTER", target_health_bar, "CENTER", -base_frame.width / 2 - 16, -base_frame.height / 4);
	end
	
	if target_max_power > 0 then
		target_energy_text:SetText(""..format_big_number(target_power).." / "..format_big_number(target_max_power).."");
		target_energy_bar:SetMinMaxValues(0, target_max_power);
		target_energy_bar:SetValue(target_power);
		
		power_type, power_token = UnitPowerType("target");
		power_color = PowerBarColor[power_type];
		
		r = 0.4; g = 0.4; b = 0.4;
		if power_color ~= nil then
			r = power_color["r"];
			g = power_color["g"];
			b = power_color["b"];
		end
		
		target_energy_background:SetColorTexture(r, g, b, 0.2);
		target_energy_bar:SetStatusBarColor(r, g, b);
	else
		target_energy_text:SetText("");
		target_energy_bar:SetValue(0);
		target_energy_background:SetColorTexture(0.4, 0.4, 0.4, 0.2);
		target_energy_bar:SetStatusBarColor(0.6, 0.6, 0.6);
	end
	
	target_health_perc:SetText("");
	target_energy_perc:SetText("");
	
	if target_max_health > 0 then
		if target_health == 0 then
			target_health_perc:SetText("Dead");
		else
			target_health_perc:SetText(format_percentage_number(target_health, target_max_health).."%");
		end
	end
	if target_max_power > 999 then
		target_energy_perc:SetText(format_percentage_number(target_power, target_max_power).."%");
	end
	
	if has_absorbs == true then
		target_absorb = UnitGetTotalAbsorbs("target");
		
		target_absorb_bar:SetMinMaxValues(0, target_max_health);
		target_absorb_bar:SetValue(target_health + target_absorb);
	
		if target_health + target_absorb > target_max_health then
			target_overabsorb_texture:SetAlpha(1);
		else
			target_overabsorb_texture:SetAlpha(0);
		end
	end
	
	if UnitName("target") ~= nil then
		target_name_text:SetText(UnitName("target"));
	else
		target_name_text:SetText("");
	end
	
	tarlvlvalue = UnitLevel("target");
	if tarlvlvalue == -1 then
		target_level_text:SetText("Boss");
	elseif tarlvlvalue == 0 then
		target_level_text:SetText("");
	else
		target_level_text:SetText("L:"..tarlvlvalue.."");
	end
	
	
	other_height = 0;
	local relative_name_scalers = { "diseases" };
	for i = 1, table.getn(relative_name_scalers) do
		other_frame = frames[get_frame(relative_name_scalers[i])];
		if other_frame ~= nil and get_frame_enabled(other_frame.name) == true and get_frame_class_enabled(other_frame.class) == true then
			other_height = other_height + other_frame.height * get_frame_size(other_frame.name);
		end
	end
	
	current_scale = get_frame_size(base_frame.name);
	target_name_text:SetPoint("CENTER", target_name_frame, "CENTER", 0, 20 + other_height / current_scale);
end

-------------------------
-- RUNES
local rune_english_spec_names = { "Blood", "Frost", "Unholy" };
local rune_texture_names =
{
	"Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Blood",
	"Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Frost",
	"Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Unholy",
	"Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Death"
};
local rune_ids = {1, 2, 5, 6, 3, 4};
local rune_frames = nil;
local rune_background_textures = nil;
local rune_foreground_frames = nil;
local rune_foreground_textures = nil;
local rune_cooldown_frames = nil;
local rune_cooldowns = nil;
local rune_cooldown_textures = nil;
local rune_complete_frame = nil;
local rune_complete_textures = nil;
local rune_texts = nil;
local rune_rings = nil;
local rune_ring_textures = nil;
local rune_anim = {0, 0, 0, 0, 0, 0};
local rune_glow_anim = {0, 0, 0, 0, 0, 0};
local rune_sorting = {0, 0, 0, 0, 0, 0};
local rune_current_spec = -1;
local rune_uv_coord_x = { 0, 0.27, 0 };
local rune_uv_coord_y = { 0.27, 0.53, 0.27 };
local rune_uv_coord_z = { 0, 0, 0.53  };
local rune_uv_coord_w = { 0.27, 0.27, 0.80 };
local runes_list = {};
local function setup_runes()
	if rune_frames == nil then
		
		base_frame = frames[get_frame("runes")];
		
		rune_frames = {};
		rune_background_textures = {};
		rune_foreground_frames = {};
		rune_foreground_textures = {};
		rune_cooldown_frames = {};
		rune_cooldown_textures = {};
		rune_complete_frame = {};
		rune_complete_textures = {};
		rune_texts = {};
		rune_cooldowns = {};
		rune_rings = {};
		rune_ring_textures = {};
		
		if is_wrath then
			for i = 1,6 do
				rune_frames[i] = CreateFrame("Frame", "Rune"..i.."BG", base_frame.frame);
				rune_frames[i]:SetPoint("CENTER", base_frame.frame, "CENTER", -(base_frame.width / 2) - (base_frame.height / 2) * 0.8 + (base_frame.width / 6) * i, 0);
				rune_frames[i]:SetWidth(base_frame.height);
				rune_frames[i]:SetHeight(base_frame.height);
				rune_frames[i]:SetFrameLevel(16);
				
				rune_background_textures[i] = rune_frames[i]:CreateTexture("ARTWORK");
				rune_background_textures[i]:SetAllPoints();
				rune_background_textures[i]:SetTexture(0, 0, 0); 
				rune_background_textures[i]:SetAlpha(1);
				
				rune_cooldowns[i] = CreateFrame("Frame", "Rune"..i.."CD", rune_frames[i]);
				rune_cooldowns[i]:SetPoint("CENTER", rune_frames[i], "CENTER", 0, 1);
				rune_cooldowns[i]:SetWidth(base_frame.height * 0.65);
				rune_cooldowns[i]:SetHeight(base_frame.height * 0.65);
				rune_cooldowns[i]:SetFrameLevel(17);
				rune_cooldown_textures[i] = CreateFrame("Cooldown", "Rune"..i.."CDAnim", rune_cooldowns[i], "CooldownFrameTemplate");
				rune_cooldown_textures[i]:SetHideCountdownNumbers(true);
				rune_cooldown_textures[i]:SetFrameLevel(18);
				
				rune_rings[i] = CreateFrame("Frame", "Rune"..i.."Ring", rune_frames[i]);
				rune_rings[i]:SetPoint("TOPLEFT", rune_frames[i], "TOPLEFT", 0, 0);
				rune_rings[i]:SetWidth(base_frame.height);
				rune_rings[i]:SetHeight(base_frame.height);
				rune_rings[i]:SetFrameLevel(19);
				
				rune_ring_textures[i] = rune_rings[i]:CreateTexture("ARTWORK");
				rune_ring_textures[i]:SetAllPoints();
				rune_ring_textures[i]:SetTexture("Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Ring");
				rune_ring_textures[i]:SetAlpha(1);
				
				rune_texts[i] = rune_rings[i]:CreateFontString("Runic Power Number", "ARTWORK", "TextStatusBarText");
				rune_texts[i]:SetPoint("CENTER", rune_rings[i], "CENTER", 0, 0);
				rune_texts[i]:SetText(0);
			end
		else
			for i = 1,6 do
				rune_frames[i] = CreateFrame("Frame", "Rune"..i.."BG", base_frame.frame);
				rune_frames[i]:SetPoint("CENTER", base_frame.frame, "CENTER", -(base_frame.width / 2) - (base_frame.height / 2) * 0.8 + (base_frame.width / 6) * i, 0);
				rune_frames[i]:SetWidth(base_frame.height);
				rune_frames[i]:SetHeight(base_frame.height);
				rune_frames[i]:SetFrameLevel(16);
				
				rune_background_textures[i] = rune_frames[i]:CreateTexture("ARTWORK");
				rune_background_textures[i]:SetAllPoints();
				rune_background_textures[i]:SetAlpha(0);
				rune_background_textures[i]:SetAtlas("DK-Rune-CD");
				
				rune_foreground_frames[i] = CreateFrame("Frame", "Rune"..i.."CD", rune_frames[i]);
				rune_foreground_frames[i]:SetPoint("CENTER", rune_frames[i], "CENTER", 0, 0);
				rune_foreground_frames[i]:SetWidth(base_frame.height);
				rune_foreground_frames[i]:SetHeight(base_frame.height);
				rune_foreground_frames[i]:SetFrameLevel(18);
				rune_foreground_textures[i] = rune_foreground_frames[i]:CreateTexture("ARTWORK");
				rune_foreground_textures[i]:SetAllPoints();
				rune_foreground_textures[i]:SetAlpha(1);
				rune_foreground_textures[i]:SetTexture("Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-SingleRune");
				
				rune_cooldown_frames[i] = CreateFrame("Frame", "Rune"..i.."CD", rune_frames[i]);
				rune_cooldown_frames[i]:SetPoint("CENTER", rune_frames[i], "CENTER", 0, 0);
				rune_cooldown_frames[i]:SetWidth(base_frame.height);
				rune_cooldown_frames[i]:SetHeight(base_frame.height);
				rune_cooldown_frames[i]:SetFrameLevel(19);
				
				rune_complete_frame[i] = CreateFrame("Frame", "Rune"..i.."Ring", rune_frames[i]);
				rune_complete_frame[i]:SetPoint("TOPLEFT", rune_frames[i], "TOPLEFT", 0, 0);
				rune_complete_frame[i]:SetWidth(base_frame.height);
				rune_complete_frame[i]:SetHeight(base_frame.height);
				rune_complete_frame[i]:SetFrameLevel(20);
				
				rune_cooldown_textures[i] = CreateFrame("Cooldown", "Rune"..i.."CDAnim", rune_cooldown_frames[i], "CooldownFrameTemplate");
				rune_cooldown_textures[i]:SetHideCountdownNumbers(true);
				rune_cooldown_textures[i]:SetFrameLevel(20);
				rune_cooldown_textures[i]:SetEdgeTexture("Interface\\PlayerFrame\\DK-BloodUnholy-Rune-CDSpark");
				rune_cooldown_textures[i]:SetReverse(true);
				rune_cooldown_textures[i]:SetUseCircularEdge(true);
				rune_cooldown_textures[i]:SetDrawBling(false);
				rune_cooldown_textures[i]:SetSwipeTexture("Interface\\PlayerFrame\\DK-Blood-Rune-CDFill");
				rune_cooldown_textures[i]:SetSwipeColor(255, 255, 255);
				
				rune_complete_textures[i] = rune_complete_frame[i]:CreateTexture("OVERLAY");
				rune_complete_textures[i]:SetAllPoints();
				rune_complete_textures[i]:SetAtlas("DK-Rune-Glow");
				rune_complete_textures[i]:SetAlpha(0);
				
				rune_texts[i] = rune_complete_frame[i]:CreateFontString("Runic Power Number", "ARTWORK", "TextStatusBarText");
				rune_texts[i]:SetPoint("CENTER", rune_complete_frame[i], "CENTER", 0, 0);
				rune_texts[i]:SetText(0);
			end
		end
	end
end
local function update_runes()
	
	-- Disable blizzard runes
	RuneFrame:Hide();
	
	rune_index = 0;
	for i = 1,6 do
		if is_wrath then rune_index = rune_ids[i]; else rune_index = i; end
		
		rune_start, rune_duration = GetRuneCooldown(rune_index);
		if rune_start ~= nil and rune_duration ~= nil then
			runes_list[i] = {index = rune_index, order = i, rune_start = rune_start, rune_duration = rune_duration, rune_end = rune_start + rune_duration};
		else
			runes_list[i] = {index = rune_index, order = i, rune_start = 0, rune_duration = 0, rune_end = 0};
		end
	end
	
	-- Sort runes
	if umb_sort == true then table.sort(runes_list, function(a, b)
		if a.rune_end == b.rune_end then 
			return a.order < b.order;
		else
			return a.rune_end < b.rune_end;
		end
	end); end
	
	-- Update times
	for i = 1,6 do
		local rune = runes_list[i];
	
		if umb_timers == true then
			if rune.rune_start == 0 then
				rune_texts[i]:SetText("");
			else
				rune_time = math.floor(rune.rune_duration - (GetTime() - rune.rune_start));
				if rune_time < 0 then rune_time = 0; end
				rune_texts[i]:SetText(rune_time);
			end
		else
			rune_texts[i]:SetText("");
		end
	end
	
	if is_wrath then
		-- Legacy runes
		for i = 1,6 do
			local rune = runes_list[i];
			
			rune_background_textures[i]:SetTexture(rune_texture_names[GetRuneType(rune.index)]);
			
			if umb_timers == true then
				if rune.rune_start == 0 then
					rune_texts[i]:SetText("");
				else
					rune_texts[i]:SetText(math.floor((rune.rune_duration - (GetTime() - rune.rune_start)) + 0.5));
				end
			else
				rune_texts[i]:SetText("");
			end
			
			if rune.rune_start ~= 0 then
				rune_cooldown_textures[i]:SetCooldown(rune.rune_start, rune.rune_duration);
				rune_anim[i] = 1;
			else
				if rune_anim[i] == 1 then
					rune_anim[i] = 0;
					rune_cooldown_textures[i]:SetCooldown(0, 0);
				end
			end
		end
	else
		-- Retail runes
		for i = 1,6 do
			local rune = runes_list[i];
			
			if rune.rune_start ~= 0 then
				rune_cooldown_textures[i]:SetCooldown(rune.rune_start, rune.rune_duration);
				rune_anim[i] = 1;
				rune_foreground_textures[i]:SetAlpha(0);
				rune_background_textures[i]:SetAlpha(1);
			else
				if rune_anim[i] == 1 then
					rune_anim[i] = 0;
					rune_cooldown_textures[i]:SetCooldown(0, 0);
					rune_foreground_textures[i]:SetAlpha(1);
					rune_background_textures[i]:SetAlpha(0);
					rune_glow_anim[i] = 1;
				end
			end
			
			if rune_glow_anim[i] ~= 0 then
				rune_glow_anim[i] = rune_glow_anim[i] - delta_time * 2;
				if rune_glow_anim[i] < 0 then
					rune_glow_anim[i] = 0;
				end
				rune_complete_textures[i]:SetAlpha(math.sin(rune_glow_anim[i] * math.pi));
			end
		end
		
		-- Set rune icons (on spec change only)
		if rune_current_spec ~= current_spec then
			rune_current_spec = current_spec;
			for i = 1,6 do
				rune_foreground_textures[i]:SetTexture("Interface\\PlayerFrame\\ClassOverlayDeathKnightRunes");
				rune_foreground_textures[i]:SetTexCoord(rune_uv_coord_x[current_spec], rune_uv_coord_y[current_spec], rune_uv_coord_z[current_spec], rune_uv_coord_w[current_spec]);
				rune_cooldown_textures[i]:SetSwipeTexture("Interface\\PlayerFrame\\DK-"..rune_english_spec_names[current_spec].."-Rune-CDFill");
			end
		end
	end
end


-------------------------
-- PLAYER INFO
local health_frame = nil;
local health_background = nil;
local health_text = nil;
local health_bar = nil;
local health_absorb_frame = nil;
local health_absorb_texture = nil;
local health_absorb_bar = nil;
local health_overabsorb_frame = nil;
local health_overabsorb_texture = nil;
local health_perc = nil;
local function setup_health()
	if health_frame == nil then
		
		base_frame = frames[get_frame("health")];
		
		health_frame = CreateFrame("Frame", nil, base_frame.frame);
		health_frame:SetPoint("TOP", base_frame.frame, "TOP", 0, 0);
		health_frame:SetWidth(base_frame.width); 
		health_frame:SetHeight(base_frame.height);
		
		health_background = health_frame:CreateTexture("ARTWORK");
		health_background:SetAllPoints();
		health_background:SetTexture(0, 0.4, 0, 0.4);
		
		if has_absorbs == true then
			health_absorb_bar = CreateFrame("StatusBar", nil, health_frame);
			health_absorb_bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
			health_absorb_bar:GetStatusBarTexture():SetHorizTile(false);
			health_absorb_bar:SetMinMaxValues(0, 100);
			health_absorb_bar:SetWidth(base_frame.width);
			health_absorb_bar:SetHeight(base_frame.height);
			health_absorb_bar:SetPoint("CENTER", health_frame, "CENTER", 0, 0); 
			health_absorb_bar:SetStatusBarColor(1, 1, 1);
			health_absorb_bar:SetFrameLevel(19);
			
			health_absorb_frame = CreateFrame("Frame", nil, health_frame);
			health_absorb_frame:SetPoint("TOP", health_frame, "TOP", 0, 0);
			health_absorb_frame:SetWidth(base_frame.width); 
			health_absorb_frame:SetHeight(base_frame.height);
			health_absorb_frame:SetFrameLevel(20);
			
			health_absorb_texture = health_absorb_frame:CreateTexture("ARTWORK");
			health_absorb_texture:SetAllPoints();
			health_absorb_texture:SetTexture("Interface\\RaidFrame\\Shield-Overlay", true);
			health_absorb_texture:SetTexCoord(0, -3, 0, 1);
			
			health_overabsorb_frame = CreateFrame("Frame", nil, health_frame);
			health_overabsorb_frame:SetPoint("TOPRIGHT", health_frame, "TOPRIGHT", 3, 0);
			health_overabsorb_frame:SetWidth(16); 
			health_overabsorb_frame:SetHeight(base_frame.height);
			health_overabsorb_frame:SetFrameLevel(22);
			
			health_overabsorb_texture = health_overabsorb_frame:CreateTexture("ARTWORK");
			health_overabsorb_texture:SetAllPoints();
			health_overabsorb_texture:SetTexture("Interface\\RaidFrame\\Absorb-Overabsorb");
			health_overabsorb_texture:SetBlendMode("ADD");
		end
		
		health_bar = CreateFrame("StatusBar", nil, health_frame);
		health_bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
		health_bar:GetStatusBarTexture():SetHorizTile(false);
		health_bar:SetMinMaxValues(0, 100);
		health_bar:SetWidth(base_frame.width);
		health_bar:SetHeight(base_frame.height);
		health_bar:SetPoint("CENTER", health_frame, "CENTER", 0, 0); 
		health_bar:SetStatusBarColor(0, 1, 0);
		health_bar:SetFrameLevel(21);
		
		health_text = health_bar:CreateFontString("Runic Power Number", "ARTWORK", "TextStatusBarText");
		health_text:SetPoint("CENTER", health_bar, "CENTER", 0, 0);
		health_text:SetText(0);
		
		health_perc = health_bar:CreateFontString("Hit Points Percentage", "ARTWORK", "GameFontNormalSmall");
		health_perc:SetPoint("CENTER", health_bar, "CENTER", base_frame.width / 2 + 15, 0);
		health_perc:SetText(0);
		
	end
end
local function update_health()
	
	player_health = UnitHealth("player");
	player_max_health = UnitHealthMax("player");
	
	health_bar:SetMinMaxValues(0, player_max_health);
	health_bar:SetValue(player_health);
	
	health_text:SetText(""..format_big_number(player_health).." / "..format_big_number(player_max_health).."");
	health_perc:SetText(format_percentage_number(player_health, player_max_health).."%");
	
	if has_absorbs == true then
		player_absorb = UnitGetTotalAbsorbs("player");
	
		health_absorb_bar:SetMinMaxValues(0, player_max_health);
		health_absorb_bar:SetValue(player_health + player_absorb);
		
		if player_health + player_absorb > player_max_health then
			health_overabsorb_texture:SetAlpha(1);
		else
			health_overabsorb_texture:SetAlpha(0);
		end
	end
end

-------------------------
-- RUNIC INFO
local runic_frame = nil;
local runic_background = nil;
local runic_bar = nil;
local runic_text = nil;
local runic_perc = nil;
local function setup_runic()
	if runic_frame == nil then
	
		base_frame = frames[get_frame("runic")];
		
		runic_frame = CreateFrame("Frame", nil, base_frame.frame);
		runic_frame:SetPoint("TOP", base_frame.frame, "TOP", 0, 0);
		runic_frame:SetWidth(base_frame.width); 
		runic_frame:SetHeight(base_frame.height);
		
		power_type, power_token = UnitPowerType("player");
		runic_background = runic_frame:CreateTexture("ARTWORK");
		runic_background:SetAllPoints();
		runic_background:SetColorTexture(PowerBarColor[power_type]["r"], PowerBarColor[power_type]["g"], PowerBarColor[power_type]["b"], 0.2);
		
		runic_bar = CreateFrame("StatusBar", nil, runic_frame);
		runic_bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
		runic_bar:GetStatusBarTexture():SetHorizTile(false);
		runic_bar:SetMinMaxValues(0, 100);
		runic_bar:SetWidth(base_frame.width);
		runic_bar:SetHeight(base_frame.height);
		runic_bar:SetPoint("CENTER", runic_frame, "CENTER", 0, 0); 
		runic_bar:SetStatusBarColor(PowerBarColor[power_type]["r"], PowerBarColor[power_type]["g"], PowerBarColor[power_type]["b"]);
		
		runic_text = runic_bar:CreateFontString("Runic Power Number", "ARTWORK", "TextStatusBarText");
		runic_text:SetPoint("CENTER", runic_bar, "CENTER", 0, 0);
		runic_text:SetText(0);
		
		runic_perc = runic_bar:CreateFontString("Energy Points Percentage", "ARTWORK", "GameFontNormalSmall");
		runic_perc:SetPoint("CENTER", runic_bar, "CENTER", base_frame.width / 2 + 15, 0);
		runic_perc:SetText("");
	end
end
local function update_runic()
	player_power = UnitPower("player");
	player_max_power = UnitPowerMax("player");
	
	runic_bar:SetMinMaxValues(0, player_max_power);
	runic_bar:SetValue(player_power);
	runic_text:SetText(""..format_big_number(player_power).." / "..format_big_number(player_max_power).."");
	
	power_type, power_token = UnitPowerType("player");
	power_color = PowerBarColor[power_type];
	r = 0.4; g = 0.4; b = 0.4;
	if power_color ~= nil then
		r = power_color["r"];
		g = power_color["g"];
		b = power_color["b"];
	end
	runic_background:SetColorTexture(r, g, b, 0.2);
	runic_bar:SetStatusBarColor(r, g, b);
	
	if power_type == 0 then
		runic_perc:SetText(format_percentage_number(player_power, player_max_power).."%");
	else
		runic_perc:SetText("");
	end
	
end

-------------------------
-- BUFF TRACKING
-- Marrowrend, Festering Strike
local tracking_ids = { 195182, 85948 };
-- Bone Shield, Festering Wound
local tracking_buff_ids = { 195181, 194310 };
local tracking_frame = nil;
local tracking_texture = nil;
local tracking_text = nil;
local tracking_cd = nil;
local function setup_tracking()
	if tracking_frame == nil then
		
		base_frame = frames[get_frame("tracking")];
	
		tracking_frame = CreateFrame("Frame", "Backgroundframe", base_frame.frame);
		tracking_frame:SetPoint("CENTER", base_frame.frame, "CENTER", -base_frame.height / 2, 0);
		tracking_frame:SetWidth(base_frame.height); 
		tracking_frame:SetHeight(base_frame.height);
		
		tracking_texture = tracking_frame:CreateTexture("ARTWORK");
		tracking_texture:SetAllPoints();
		tracking_texture:SetTexture("Interface\\Icons\\ability_deathknight_boneshield");

		tracking_text = tracking_frame:CreateFontString("Target Name", "ARTWORK", "GameFontNormalSmall");
		tracking_text:SetPoint("CENTER", tracking_frame, "CENTER", base_frame.height, 0);
		tracking_text:SetText(0);
		
		tracking_cd = CreateFrame("Cooldown", "TRCD", tracking_frame, "CooldownFrameTemplate");
		tracking_cd:SetHideCountdownNumbers(true);
		tracking_cd:SetReverse(true);
	
	end
end
local function update_tracking()

	track_target = "";
	track_id = 0;
	
	if current_spec == 1 then
		track_target = "player";
		track_id = tracking_buff_ids[1];
		tracking_texture:SetTexture("Interface\\Icons\\ability_deathknight_boneshield");
	elseif current_spec == 3 then
		track_target = "target";
		track_id = tracking_buff_ids[2];
		tracking_texture:SetTexture("Interface\\Icons\\spell_yorsahj_bloodboil_purpleoil");
	else
		tracking_frame:Hide();
		return;
	end
	tracking_frame:Show();
	
	stackCount = 0;
	i = 1;
	while true do
		if track_target == "target" then
			name, icon, count, _, dur, exp, _, _, _, id = UnitDebuff(track_target, i, "PLAYER");
		else
			name, icon, count, _, dur, exp, _, _, _, id = UnitBuff(track_target, i);
		end
		if name == nil then break; end
		
		if id == track_id then
			stackCount = count;
			break;
		end
		i = i + 1;
	end
	
	if stackCount == 0 then
		tracking_texture:SetAlpha(0.1);
		tracking_text:SetText("");
		tracking_cd:SetCooldown(0, 0);
	else
		tracking_texture:SetAlpha(1);
		tracking_text:SetText(stackCount);
		tracking_cd:SetCooldown(exp - dur, dur);
	end
		
end


-------------------------
-- FRAMES
frames[table.getn(frames) + 1] = umber_frame:create("diseases", 64, 16, "DEATHKNIGHT", setup_diseases, update_diseases);
frames[table.getn(frames) + 1] = umber_frame:create("target", 120, 24, "", setup_target, update_target);
frames[table.getn(frames) + 1] = umber_frame:create("runes", 120, 24, "DEATHKNIGHT", setup_runes, update_runes);
frames[table.getn(frames) + 1] = umber_frame:create("health", 120, 12, "", setup_health, update_health);
frames[table.getn(frames) + 1] = umber_frame:create("runic", 120, 12, "", setup_runic, update_runic);
if is_wrath == false then
	frames[table.getn(frames) + 1] = umber_frame:create("tracking", 120, 16, "DEATHKNIGHT", setup_tracking, update_tracking);
end

-- On update
local isdragging = false;
local isscaling = false;
local frame_selected = -1;
local x_drag_start = 0;
local y_drag_start = 0;
local x_dist = 0;
local y_dist = 0;
local has_init = false;
umber_main_frame:SetScript("OnUpdate", function(self, elapsed)

	if has_init == false then
		for i = 1, table.getn(frames) do
			if get_frame_class_enabled(frames[i].class) == true then
				frames[i].construct();
			end
		end
		has_init = true;
	end
	
	current_spec = 2;
	if has_spec then
		query_spec = GetSpecialization();
		-- New DKs have no spec selected from creation, and GetSpecialization
		-- will return '5' as of 9.3. Default to frost until they select a spec.
		if query_spec ~= nil and query_spec > 0 and query_spec < 4 then
			current_spec = query_spec;
		end
	end
	
	calculate_delta_time();
	
	update_alpha();

	window_width = GetScreenWidth() * UIParent:GetEffectiveScale();
	window_height = GetScreenHeight() * UIParent:GetEffectiveScale();
	
	if frame_locked == 0 then
		for i = 1, table.getn(frames) do frames[i].frame:EnableMouse(true); end
		
		if isdragging == false and isscaling == false then
			frame_selected = -1;
			foci = GetMouseFoci();
			for i = 1, table.getn(frames) do
				if get_frame_enabled(frames[i].name) == true and get_frame_class_enabled(frames[i].class) == true then
					for k,v in pairs(foci) do
						if v == frames[i].frame then
							frame_selected = i;
							break;
						end
					end
				end
			end
			if IsMouseButtonDown(1) == true then
				if frame_selected ~= -1 then
					x_drag_start, y_drag_start = GetCursorPosition();
					x_drag_start = (x_drag_start - window_width / 2) / UIParent:GetEffectiveScale();
					y_drag_start = (y_drag_start - window_height / 2) / UIParent:GetEffectiveScale();
					x_dist = umb_x - x_drag_start;
					y_dist = umb_y - y_drag_start;
					isdragging = true;
				end
			elseif IsMouseButtonDown(2) == true then
				if frame_selected ~= -1 then
					x_drag_start, y_drag_start = GetCursorPosition();
					isscaling = true;
				end
			end
		end
		
		if isdragging and IsMouseButtonDown(1) == false then isdragging = false end;
		if isscaling and IsMouseButtonDown(2) == false then isscaling = false end;
		
		if isdragging == true then
			new_x, new_y = GetCursorPosition();
			new_x = (new_x - window_width / 2) / UIParent:GetEffectiveScale();
			new_y = (new_y - window_height / 2) / UIParent:GetEffectiveScale();
			umb_x = new_x + x_dist;
			umb_y = new_y + y_dist;
		elseif isscaling == true then
			current_scale = get_frame_size(frames[frame_selected].name);
			xPos, yPos = GetCursorPosition();
			distance = (y_drag_start - yPos) / 50;
			current_scale = current_scale - distance;
			if current_scale < 0.5 then current_scale = 0.5 end
			if current_scale > 3 then current_scale = 3 end
			set_frame_size(frames[frame_selected].name, current_scale);
			x_drag_start, y_drag_start = GetCursorPosition();
		end
	else
		for i = 1, table.getn(frames) do frames[i].frame:EnableMouse(false); end
	end
	
	if umb_x < -GetScreenWidth() / 2 then umb_x = -GetScreenWidth() / 2; end
	if umb_y < -GetScreenHeight() / 2 then umb_y = -GetScreenHeight() / 2; end
	if umb_x > GetScreenWidth() / 2 then umb_x = GetScreenWidth() / 2; end
	if umb_y > GetScreenHeight() / 2 then umb_y = GetScreenHeight() / 2; end
	umb_x = math.floor(umb_x);
	umb_y = math.floor(umb_y);
	
	if frame_locked == 0 then
		drag_position_text:SetText(umb_x .. ", " .. umb_y);
	else
		drag_position_text:SetText("");
	end
	
	largest_width = 1;
	total_height = 1;
	frame_current_height = 0;
	for i = 1, table.getn(frames) do
		if get_frame_enabled(frames[i].name) == true and get_frame_class_enabled(frames[i].class) == true then
		
			frames[i].frame:SetScale(get_frame_size(frames[i].name));
			frames[i].frame:Show();
			
			if frames[i].width >= largest_width then largest_width = frames[i].width; end;
			total_height = total_height + frames[i].height * get_frame_size(frames[i].name);
			frames[i].frame:SetPoint("TOP", umber_main_frame, "TOP", 0, frame_current_height / get_frame_size(frames[i].name));
			frame_current_height = frame_current_height - frames[i].height * get_frame_size(frames[i].name);
			
		else
			frames[i].frame:Hide();
		end
	end
	
	umber_drag_frame:SetWidth(largest_width);
	umber_drag_frame:SetHeight(total_height);
	umber_main_frame:SetPoint("TOP", umber_drag_frame, "TOP", 0, 0);
	
	umber_drag_frame:ClearAllPoints();
	umber_drag_frame:SetPoint("CENTER", umb_x, umb_y);
	
	-- Update frames
	for i = 1, table.getn(frames) do
		if get_frame_enabled(frames[i].name) == true and get_frame_class_enabled(frames[i].class) == true then
			frames[i].update();
		end
	end
	
end)

-- On events
umber_main_frame:RegisterEvent("ADDON_LOADED");
umber_main_frame:SetScript("OnEvent", function(self, event, ...)
	
	if event == "ADDON_LOADED" then
		umber_main_frame:UnregisterEvent("ADDON_LOADED");
		umber_setup();
		umber_main_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	end
	
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, type, _, sourceGUID, _, _, _, destGUID, _, _, _ = ...;
		if type == "SWING_DAMAGE" and sourceGUID == UnitGUID("player") and destGUID == UnitGUID("target") then
			swingtimer_value = GetTime();
		end
	end
end)

-- Slash commands
local header_start = "|cFFFFA07AUmberRunes: |cffffffff";
local command_color = "|cFF00FFFF";
local text_color = "|cffffffff";
SLASH_UMBER1 = '/umber';
local function handler(msg, editbox)
local command, rest = msg:match("^(%S*)%s*(.-)$")
	if command == "lock" then
		if frame_locked == 1 then frame_locked = 0; print(header_start.."Frame unlocked.") else frame_locked = 1; print(header_start.."Frame locked.") end;
	elseif command == "reset" then
		umb_x = 0; umb_y = 0;
		for i = 1, table.getn(frames) do umb_data["frame_"..frames[i].name.."_size"] = 1; end
		for i = 1, table.getn(frames) do umb_data["frame_"..frames[i].name.."_enabled"] = true; end
		print(header_start.."Frame reset.");
	elseif command == "scale" then
		scale = tonumber(rest);
		if scale ~= nil then
			if scale >= 0.5 and scale <= 3 then
				for i = 1, table.getn(frames) do umb_data["frame_"..frames[i].name.."_size"] = scale; end
			else
				print(header_start.."Use a number between 0.5 and 3 to set the scale.");
			end
		else
			print(header_start.."Use a number between 0.5 and 3 to set the scale.");
		end
	elseif command == "combat" then
		if umb_combat == true then
			umb_combat = false;
			print(header_start.."Will remain visible while out of combat.");
		else
			umb_combat = true;
			print(header_start.."Will hide while out of combat.");
		end
	elseif command == "sorting" then
		if umb_sort == true then
			umb_sort = false;
			print(header_start.."Rune sorting disabled.");
		else
			umb_sort = true;
			print(header_start.."Rune sorting enabled.");
		end
	elseif command == "timers" then
		if umb_timers == true then
			umb_timers = false;
			print(header_start.."Hiding Rune timers.");
		else
			umb_timers = true;
			print(header_start.."Showing Rune timers.");
		end
	elseif command == "health" then
		set_string = "frame_health_enabled";
		if umb_data[set_string] == true then
			umb_data[set_string] = false;
			print(header_start.."Hiding Health bar.");
		else
			umb_data[set_string] = true;
			print(header_start.."Showing Health bar.");
		end
	elseif command == "runic" then
		set_string = "frame_runic_enabled";
		if umb_data[set_string] == true then
			umb_data[set_string] = false;
			print(header_start.."Hiding Runic Power bar.");
		else
			umb_data[set_string] = true;
			print(header_start.."Showing Runic Power bar.");
		end
	elseif command == "target" then
		set_string = "frame_target_enabled";
		if umb_data[set_string] == true then
			umb_data[set_string] = false;
			print(header_start.."Hiding target info.");
		else
			umb_data[set_string] = true;
			print(header_start.."Showing target info.");
		end
	elseif command == "diseases" then
		set_string = "frame_diseases_enabled";
		if umb_data[set_string] == true then
			umb_data[set_string] = false;
			print(header_start.."Hiding diseases tracking.");
		else
			umb_data[set_string] = true;
			print(header_start.."Showing diseases tracking.");
		end
	elseif command == "tracking" and is_wrath == false then
		set_string = "frame_tracking_enabled";
		if umb_data[set_string] == true then
			umb_data[set_string] = false;
			print(header_start.."Hiding buff/debuff tracking.");
		else
			umb_data[set_string] = true;
			print(header_start.."Showing buff/debuff tracking.");
		end
	else
		print("|cFFFFA07AUmberRunes:");
		print(" |cFFFFFF7APositioning");
		print("  "..command_color.."/umber lock - "..text_color.."Lock/unlock the main frame.");
		print("  "..command_color.."/umber reset - "..text_color.."Reset the position of the main frame.");
		print("  "..command_color.."/umber scale - "..text_color.."Set the scale of all components. (Value between 0.5 and 3, 1 is default).");
		print(" |cFFFFFF7ARunes");
		print("  "..command_color.."/umber combat - "..text_color.."Toggle hiding when out of combat.");
		print("  "..command_color.."/umber sorting - "..text_color.."Toggle Rune sorting on/off.");
		print("  "..command_color.."/umber timers - "..text_color.."Toggle Rune timers on/off.");
		print(" |cFFFFFF7AElements");
		print("  "..command_color.."/umber health - "..text_color.."Toggle the Player Health bar on/off.");
		print("  "..command_color.."/umber runic - "..text_color.."Toggle the Runic Power bar on/off.");
		print("  "..command_color.."/umber target - "..text_color.."Toggle the target info on/off.");
		print("  "..command_color.."/umber diseases - "..text_color.."Toggle the disease tracking on/off.");
		if is_wrath == false then
			print("  "..command_color.."/umber tracking - "..text_color.."Toggle buff/debuff tracking on/off.");
		end
	end
end
SlashCmdList["UMBER"] = handler;