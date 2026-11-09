-- RABuffs_options.lua
--  Settings pages in Game Menu > AddOn Options (ClassicAPI's InterfaceOptions), built with ClassicAPIOptionsKit.
--  They replace the old four-tab settings window. The bar layout editor and the query list are the same
--  frames as before (RABuffs.xml), placed on the Bars and Buff list pages.
-- Version 0.13.1

local Kit = ClassicAPIOptionsKit;
local root, profilesPage, textureProbe;

-- Tidies a typed texture path: trims it, turns / into \, drops a .tga or .blp extension; empty means
-- the default. A path that doesn't load is refused (the box goes back to the saved path) with a message.
local function ParseTexture(text)
	local path = string.gsub(string.gsub(text or "", "^%s+", ""), "%s+$", "");
	path = string.gsub(path, "/", "\\");
	path = string.gsub(string.gsub(path, "%.[Tt][Gg][Aa]$", ""), "%.[Bb][Ll][Pp]$", "");
	if (path == "") then
		return RAB_DEFAULT_BAR_TEXTURE;
	end
	if (textureProbe == nil) then
		textureProbe = UIParent:CreateTexture(nil, "BACKGROUND");
		textureProbe:Hide();
	end
	if (not RABui_SetBarTexture(textureProbe, path)) then
		RAB_Print("[RABuffs] Couldn't load the texture " .. path .. ". Check the path; a file added while the game is running needs a client restart.", "warn");
		return nil;
	end
	return path;
end

-- what a settings checkbox did in the old window: re-check when the window should show, redraw the bars
local function ApplySettings()
	RABui_UpdateVisibility(RAB_CurrentGroupStatus, RAB_CurrentGroupStatus);
	RABui_SyncBars();
end

local function Option(page, key)
	return page:Checkbox({
		key = key,
		label = getglobal("sRAB_Settings_Option_" .. key),
		tooltip = getglobal("sRAB_Settings_Option_" .. key .. "_Description"),
	});
end

-- The hosted frames were created under UIParent. The options window sits on a higher frame strata, so
-- the frame and everything in it is moved to the page's strata, or it would draw behind the window.
local function Adopt(frame, strata, level)
	frame:SetFrameStrata(strata);
	frame:SetFrameLevel(level);
	local children = { frame:GetChildren() };
	for _, child in ipairs(children) do
		Adopt(child, strata, level + 1);
	end
end

local function Host(page, frame, height)
	frame:SetParent(page.scrollChild);
	frame:ClearAllPoints();
	frame:SetPoint("TOPLEFT", page.scrollChild, "TOPLEFT", 12, page.y - 4);
	frame:Show();
	page.y = page.y - height;
	page.scrollChild:SetHeight(-page.y + 10);
end

local function ProfileOptions()
	local options, hasDefault = {}, false;
	for _, name in ipairs((RAB_GetAllProfiles())) do
		if (name == "Default") then
			hasDefault = true;
		end
		tinsert(options, { value = name, text = name });
	end
	if (not hasDefault) then
		tinsert(options, 1, { value = "Default", text = "Default" });
	end
	return options;
end

local function PreviewButton(page)
	page:Button({
		label = "Preview bar window",
		tooltip = "Shows the bar window with every bar until you close this window, whatever the group, combat and hide-active settings say. Use it to see appearance changes.",
		onClick = RABui_StartPreview,
	});
end

function RAB_Options_Build()
	if (root ~= nil) then
		return;
	end
	-- the preview ends when the options window closes: a child frame's OnHide runs when its parent hides
	if (InterfaceOptionsFrame ~= nil) then
		local watcher = CreateFrame("Frame", nil, InterfaceOptionsFrame);
		watcher:SetScript("OnHide", function() RABui_EndPreview(); end);
	end
	local bind = Kit.Binder(
			function() return RABui_Settings end,
			function(key) return RAB_DefaultSettings and RAB_DefaultSettings[key] end,
			Kit.Defer(ApplySettings));

	-- RABuffs: the bar window
	root = Kit:NewPage({ name = "RABuffs", subtitle = "Raid and party buff bars. Version " .. RABuffs_Version .. ".", bind = bind });
	root:Header("Bar window");
	Option(root, "showsolo");
	Option(root, "showparty");
	Option(root, "showraid");
	Option(root, "hideincombat");
	Option(root, "hideactive");
	Option(root, "lockwindow");
	Option(root, "enablefadingfx");
	root:Checkbox({ key = "enableGreeting", label = "Login message", tooltip = "Print the version line in chat at login." });
	root:Slider({
		key = "updateInterval",
		label = "Bar update interval",
		tooltip = "How often bars refresh, in seconds. A bar's own update frequency multiplies this.",
		min = 0.2, max = 2, step = 0.1,
		format = function(v) return string.format("%.1f s", v) end,
	});
	PreviewButton(root);
	root:Text("Slash commands: /rab show, /rab hide, /rab info, /rab versioncheck, /rab profile, and /rabq for buff queries.");

	-- Appearance: how the bar window looks
	local appearance = Kit:NewPage({ name = "Appearance", parent = "RABuffs", subtitle = "How the bar window and its bars look.", bind = bind });
	PreviewButton(appearance);
	appearance:Header("Window");
	Option(appearance, "hidetitle");
	Option(appearance, "hidebackground");
	Option(appearance, "hideborder");
	appearance:Header("Bars");
	appearance:EditBox({
		key = "barTexture",
		label = "Bar texture",
		tooltip = "Path to the texture drawn on every bar, without the extension, for example Interface\\TargetingFrame\\UI-StatusBar. Bar colours are applied on top, so light or grey textures work best. Leave it empty for the RABuffs default.",
		width = 360,
		parse = ParseTexture,
	});
	appearance:Slider({
		key = "barHeight",
		label = "Bar height",
		tooltip = "Height of each bar in pixels. 12 is the original size; the label stays centred and the window grows to fit.",
		min = 8, max = 30, step = 1,
		format = function(v) return string.format("%d px", v) end,
	});
	appearance:Slider({
		key = "barWidth",
		label = "Bar width",
		tooltip = "Width of each bar in pixels. 122 is the original size; the window and title bar resize to match.",
		min = 60, max = 300, step = 2,
		format = function(v) return string.format("%d px", v) end,
	});

	-- Buffing
	local buffing = Kit:NewPage({ name = "Buffing", parent = "RABuffs", subtitle = "How clicking a bar casts buffs.", bind = bind });
	buffing:Header(sRAB_Settings_Settings_Buffing);
	Option(buffing, "castbigbuffs");
	Option(buffing, "alwayscastbigbuffs");
	Option(buffing, "partymode");
	Option(buffing, "stoppvp");
	buffing:Header("Tooltips and chat");
	Option(buffing, "dummymode");
	Option(buffing, "showsampleoutputonclick");
	Option(buffing, "colorizechat");

	-- Profiles
	profilesPage = Kit:NewPage({ name = "Profiles", parent = "RABuffs", subtitle = "Bar layouts saved per character." });
	local current = profilesPage:Dropdown({
		label = "Current profile",
		tooltip = "Choose a profile to load its bars.",
		options = ProfileOptions,
		setting = {
			get = RAB_GetCurrentProfile,
			set = function(value) RAB_LoadProfile(value); end,
		},
	});
	-- loading a profile is an action, not a setting: keep it out of the window's Cancel and Defaults
	current.setting = nil;
	profilesPage:Button({ label = "New profile...", tooltip = "Start a profile with no bars.",
		onClick = function() StaticPopup_Show("RAB_PROFILE_CREATE_PROMPT"); end });
	profilesPage:Button({ label = "Save as...", tooltip = "Save the current bars under a new name.",
		onClick = function() StaticPopup_Show("RAB_PROFILE_SAVE_PROMPT"); end });
	profilesPage:Button({ label = "Export...", tooltip = "Show the current bars as text to copy.",
		onClick = function()
			RAB_ExportedProfileData = RAB_ExportProfile();
			if RAB_ExportedProfileData then
				StaticPopup_Show("RAB_PROFILE_EXPORT");
			end
		end });
	profilesPage:Button({ label = "Import...", tooltip = "Paste bars exported from RABuffs.",
		onClick = function() StaticPopup_Show("RAB_PROFILE_IMPORT_DATA"); end });
	profilesPage:Button({ label = "Delete current...", tooltip = "Delete the current profile. Default can't be deleted.",
		onClick = function()
			local name = RAB_GetCurrentProfile();
			if (name == "Default") then
				RAB_Print("Error: Cannot delete the Default profile", "warn");
				return;
			end
			RAB_ProfileToDelete = name;
			StaticPopup_Show("RAB_PROFILE_DELETE_CONFIRM", name);
		end });

	-- Bars: the layout list and bar editor from the old Layout tab
	local bars = Kit:NewPage({
		name = "Bars", parent = "RABuffs", subtitle = sRAB_Settings_Layout_Description,
		onShow = function(page)
			Adopt(RAB_Settings_TabFrame3, page:GetFrameStrata(), page:GetFrameLevel() + 2);
			RABui_Settings_Layout_SyncList();
		end,
	});
	-- the page already shows the header and description; pull the list up to the top
	RAB_Settings_TabFrame3Header:Hide();
	RAB_Settings_TabFrame3Description:Hide();
	RAB_Settings_ClearAllBars:ClearAllPoints();
	RAB_Settings_ClearAllBars:SetPoint("TOPLEFT", RAB_Settings_TabFrame3, "TOPLEFT", 3, -2);
	Host(bars, RAB_Settings_TabFrame3, 355 + 6 + 400);

	-- Buff list: every query key, for bars and /rabq
	local list = Kit:NewPage({
		name = "Buff list", parent = "RABuffs", subtitle = sRAB_Settings_BuffList_Description,
		onShow = function(page)
			Adopt(RAB_Settings_TabFrame2, page:GetFrameStrata(), page:GetFrameLevel() + 2);
			RAB_Settings_BL_Update();
		end,
	});
	RAB_Settings_TabFrame2Header:Hide();
	RAB_Settings_TabFrame2Description:Hide();
	RAB_Settings_BuffList0:ClearAllPoints();
	RAB_Settings_BuffList0:SetPoint("TOPLEFT", RAB_Settings_TabFrame2, "TOPLEFT", 0, -2);
	Host(list, RAB_Settings_TabFrame2, 355 + 6 + 170);
end

function RAB_OpenOptions()
	RAB_Options_Build();
	Kit:Open(root);
end

-- called after a profile is created, loaded, saved or deleted elsewhere
function RAB_Options_RefreshProfiles()
	if (profilesPage ~= nil) then
		profilesPage:Refresh();
	end
end
