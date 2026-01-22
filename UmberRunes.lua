-- UMBERRUNES 1.13.0


local function get_game_version()
	_, _, _, build_version = GetBuildInfo();
	return tonumber(build_version);
end

local game_version = get_game_version();
-- Is this classic game version? Diseases and buffs worked differently back then, no festering wound and bone shield.
-- Legion also changed the way that runes worked (one single type instead of 3 different types).
-- https://warcraft.wiki.gg/wiki/Rune_(game_resource)
local is_classic = game_version < 70000;
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
		
		if is_classic then
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
		if is_classic then
			rune_index = rune_ids[i];
		else
			rune_index = i;
		end
		
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
	
	if is_classic then
		-- Classic runes
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
	runic_text:SetText(""..player_power.." / "..player_max_power.."");
	
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
-- FRAMES
frames[table.getn(frames) + 1] = umber_frame:create("runes", 120, 24, "DEATHKNIGHT", setup_runes, update_runes);
frames[table.getn(frames) + 1] = umber_frame:create("runic", 120, 12, "", setup_runic, update_runic);

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
			for i = 1, table.getn(frames) do
				if get_frame_enabled(frames[i].name) == true and get_frame_class_enabled(frames[i].class) == true then
					if frames[i].frame:IsMouseMotionFocus() then
						frame_selected = i;
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
	end
end)

-- Slash commands
local header_start = "|cFFFFA07AUmberRunes: |cffffffff";
local command_color = "|cFF00FFFF";
local text_color = "|cffffffff";
SLASH_UMBER1 = '/umber';
local function handler(msg, editbox)
local command, args = msg:match("^(%S*)%s*(.-)$")
	arg_iter = args:gmatch("%S+");
	arg_arr = {};
	i = 1;
	for arg in arg_iter do
		arg_arr[i] = arg;
		i = i + 1;
	end
	print();
	if command == "lock" then
		if frame_locked == 1 then frame_locked = 0; print(header_start.."Frame unlocked.") else frame_locked = 1; print(header_start.."Frame locked.") end;
	elseif command == "move" then
		if table.getn(arg_arr) == 2 then
			set_x = tonumber(arg_arr[1]);
			set_y = tonumber(arg_arr[2]);
			if set_x ~= nil and set_y ~= nil then
				umb_x = set_x;
				umb_y = set_y;
			end
		end
	elseif command == "reset" then
		umb_x = 0; umb_y = 0;
		for i = 1, table.getn(frames) do umb_data["frame_"..frames[i].name.."_size"] = 1; end
		for i = 1, table.getn(frames) do umb_data["frame_"..frames[i].name.."_enabled"] = true; end
		print(header_start.."Frame reset.");
	elseif command == "scale" then
		if table.getn(arg_arr) == 1 then
			scale = tonumber(args);
			if scale ~= nil then
				if scale >= 0.5 and scale <= 3 then
					for i = 1, table.getn(frames) do umb_data["frame_"..frames[i].name.."_size"] = scale; end
				else
					print(header_start.."Scale can only be between 0.5 and 3.");
				end
			else
				print(header_start.."Invalid number provided.");
			end
		else
			print(header_start.."No number was provided.");
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
	elseif command == "runic" then
		set_string = "frame_runic_enabled";
		if umb_data[set_string] == true then
			umb_data[set_string] = false;
			print(header_start.."Hiding Runic Power bar.");
		else
			umb_data[set_string] = true;
			print(header_start.."Showing Runic Power bar.");
		end
	else
		print("|cFFFFA07AUmberRunes:");
		print(" |cFFFFFF7APositioning");
		print("  "..command_color.."/umber lock - "..text_color.."Lock/unlock the main frame.");
		print("  "..command_color.."/umber move <x> <y> - "..text_color.."Set the position of the frame to specified X and Y.");
		print("  "..command_color.."/umber reset - "..text_color.."Reset the position of the main frame.");
		print("  "..command_color.."/umber scale <scale> - "..text_color.."Set the scale of all components. (scale between 0.5 and 3, 1 is default).");
		print(" |cFFFFFF7ARunes");
		print("  "..command_color.."/umber combat - "..text_color.."Toggle hiding when out of combat.");
		print("  "..command_color.."/umber sorting - "..text_color.."Toggle Rune sorting on/off.");
		print("  "..command_color.."/umber timers - "..text_color.."Toggle Rune timers on/off.");
		print(" |cFFFFFF7AElements");
		print("  "..command_color.."/umber runic - "..text_color.."Toggle the Runic Power bar on/off.");
	end
end
SlashCmdList["UMBER"] = handler;