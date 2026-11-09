-- RABuffs_core.lua
--  Administrative/core elements.
-- Version 0.13.0

RAB_Lock = 1;

RABuffs_Version = "0.13.1";
RABuffs_DeciVersion = 0.131000;

RAB_DEFAULT_BAR_TEXTURE = "Interface\\AddOns\\Rabuffs\\bar";

RABui_Settings = {};
RABui_DefSettings = {
	Layout = {},
	updateInterval = 0.5,
	barTexture = RAB_DEFAULT_BAR_TEXTURE,
	barHeight = 12,
	barWidth = 122,
	hidetitle = false,
	hidebackground = false,
	hideborder = false,
	firstRun = true,
	currentProfileByChar = {},
	enableGreeting = true,
	lastVersion = RABuffs_Version,
	stoppvp = true,
	castbigbuffs = false,
	alwayscastbigbuffs = false,
	lockwindow = false,
	colorizechat = true,
	dummymode = true,
	partymode = true,
	showsolo = false,
	showparty = true,
	showraid = true,
	hideincombat = false,
	hideactive = false,
	keepversions = false,
	enablefadingfx = true,
	showsampleoutputonclick = false,
	newestVersion = "fresh",
	newestVersionTitle = RABuffs_Version,
	newestVersionPlayer = "Default",
	newestVersionRealm = "Default"
};
RABui_DefBars = {
	{ class = "ALL", buffKey = "alive", label = "Alive", color = { 0.3, 1, 0.3 }, priority = 1, out = "RAID" },
	{ class = "ALL", buffKey = "mana", classes = "pdsa", label = "Healer", color = { 0.4, 0.6, 1 }, priority = 1, out = "RAID" },
	{ class = "ALL", buffKey = "mana", classes = "mlh", label = "DPS", color = { 0.2, 0.2, 1 }, priority = 1, out = "RAID" },
	{ class = "DRUID", buffKey = "motw", label = "Mark", color = { 0.8, 0.2, 1 }, priority = 10, out = "RAID" },
	{ class = "DRUID", buffKey = "thorns", label = "Thorns", color = { 0.8, 0.6, 1 }, priority = 5, out = "RAID" },
	{ class = "PRIEST", buffKey = "pwf", label = "Fortitude", color = { 0.9, 0.9, 0.9 }, priority = 10, out = "RAID" },
	{ class = "PRIEST", buffKey = "sprot", label = "Shadow Protection", color = { 0.6, 0.6, 0.6 }, priority = 5, out = "RAID" },
	{ class = "MAGE", buffKey = "ai", label = "Intellect", color = { 0, 0.6, 1 }, priority = 10, out = "RAID" }
};
RAB_ClassShort = {
	Mage = "m",
	Warlock = "l",
	Priest = "p",
	Rogue = "r",
	Druid = "d",
	Hunter = "h",
	Shaman = "s",
	Warrior = "w",
	Paladin = "a"
};
RABui_CompleteBars = {}; -- track which bars to hide/show

RAB_CastLog = {}; -- Spell targets out of LoS. [unit] = GetTime() when the penalty expires;
RAB_CurrentGroupStatus = -1;

-- Event dispatcher. Subscribers are keyed per event; a subscriber that returns "remove" is dropped.
local dispatcher = CreateFrame("Frame", "RAB_CoreDummy", UIParent);
dispatcher.subscribers = {};
dispatcher:SetScript("OnEvent", function()
	if (RABUFFS_CLASSICAPI_MISSING) then
		return;
	end
	if (this.subscribers[event] ~= nil) then
		local key, val, unsub;
		for key, val in this.subscribers[event] do
			unsub = val();
			if (unsub == "remove") then
				this.subscribers[event][key] = nil;
			end
		end
	end
end);

function RAB_Core_Register(event, key, func)
	if (RAB_CoreDummy.subscribers[event] == nil) then
		RAB_CoreDummy:RegisterEvent(event);
		RAB_CoreDummy.subscribers[event] = {};
	end
	if (RAB_CoreDummy.subscribers[event][key] == nil or RAB_CoreDummy.subscribers[event][key] == func) then
		RAB_CoreDummy.subscribers[event][key] = func;
	else
		RAB_Print("[RABuffs/Core] Register event/key conflict for " .. event .. ":" .. key .. "; ignoring add request.",
				"warn");
	end
end

function RAB_Core_Unregister(event, key)
	if (RAB_CoreDummy.subscribers[event] ~= nil and RAB_CoreDummy.subscribers[event][key] ~= nil) then
		RAB_CoreDummy.subscribers[event][key] = nil;
		local k, v;
		for k, v in RAB_CoreDummy.subscribers[event] do
			return ;
		end
		RAB_CoreDummy.subscribers[event] = nil;
		RAB_CoreDummy:UnregisterEvent(event);
	end
end

function RAB_Core_Raise(eve, ar1, ar2, ar3, ar4, ar5, ar6, ar7, ar8, ar9)
	if (RAB_CoreDummy.subscribers[eve] ~= nil) then
		local e, a1, a2, a3, a4, a5, a6, a7, a8, a9 = event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9;
		event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = eve, ar1, ar2, ar3, ar4, ar5, ar6, ar7, ar8, ar9;
		RAB_CoreDummy:GetScript("OnEvent")();
		event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = e, a1, a2, a3, a4, a5, a6, a7, a8, a9;
	end
end

function RAB_Core_List()
	local key, val, k2, v2;
	for key, val in RAB_CoreDummy.subscribers do
		for k2, v2 in val do
			RAB_Print(key .. "." .. k2 .. ":" .. tostring(v2));
		end
	end
end

function RAB_StartUp()
	local key, val;
	for key, val in RABui_Settings do
		if (RABui_DefSettings[key] == nil) then
			RABui_Settings[key] = nil;
		end
	end
	for key, val in RABui_DefSettings do
		if (RABui_Settings[key] == nil) then
			RABui_Settings[key] = RABui_DefSettings[key];
		end
	end
	-- kept (not cleared) so the options page's Defaults button can read it
	RAB_DefaultSettings = RABui_DefSettings;
	RABui_DefSettings = nil;

	-- Migrate old profile system
	RAB_MigrateOldProfiles();

	if (RABui_Bars == nil) then
		-- First run, populate.
		local profileKey = RAB_GetProfileKey();
		if (RABui_Settings.Layout[profileKey] ~= nil) then
			RABui_Bars = RABui_Settings.Layout[profileKey];
		else
			local _, uc = UnitClass("player");
			RABui_Bars = {};
			for key, val in RABui_DefBars do
				if (val.class == uc or val.class == "ALL") then
					tinsert(RABui_Bars, val);
				end
			end
		end
	end

	RABui_Bars = RAB_ValidateBars(RABui_Bars, true);
	RABui_Settings.Layout[RAB_GetProfileKey()] = RABui_Bars;

	RABui_DefBars = nil;

	RAB_Versions = type(RABui_Settings.keepversions) == "table" and RABui_Settings.keepversions or {};

	return "remove"; -- unsubscribe event
end

-- Migrates old bar formats and returns a new list without invalid bars.
-- The list is rebuilt rather than edited in place: setting an entry to nil inside an ipairs loop left a
-- hole, and every later ipairs/getn stopped there, hiding all bars after an invalid one.
function RAB_ValidateBars(bars, warn)
	local valid = {};
	local index, bar;
	-- walk by numeric key: a list saved with a hole by older versions still has bars after the hole
	local maxIndex = 0;
	for index in pairs(bars) do
		if (type(index) == "number" and index > maxIndex) then
			maxIndex = index;
		end
	end
	for index = 1, maxIndex do
		bar = bars[index];
		if (type(bar) == "table") then
			-- default useOnClick to true
			if bar.useOnClick == nil then
				bar.useOnClick = true;
			end
			-- default selfLimit to false
			if not bar.selfLimit then
				bar.selfLimit = false;
			end

			-- convert from old cmd format if necessary
			if bar.cmd then
				local _, _, buffKey, groups, classes = string.find(bar.cmd, "(%a+) ?(%d*) ?(%a*)");
				buffKey = buffKey or "";

				-- remove self from start of name if present and set selfLimit to true
				if string.find(buffKey, "self") == 1 then
					buffKey = string.sub(buffKey, 5);
					bar.selfLimit = true;
				end

				if buffKey == "spiritzanza" then
					buffKey = "spiritofzanza";
				end

				if buffKey == "fortitude" then
					buffKey = "elixirfortitude";
				end

				-- look if old "self" or "selfbuffonly" or "wepbuffonly" type is set on the buff buffKey
				local buff = RAB_Buffs[buffKey];
				if buff and buff.type then
					if buff.type == "self" or buff.type == "selfbuffonly" or buff.type == "wepbuffonly" then
						bar.selfLimit = true;
					end
				end

				bar.buffKey = buffKey; -- key of the buff in RAB_Buffs
				bar.groups = groups;
				bar.classes = classes;
				bar.cmd = nil;
			end

			if not bar.classes then
				bar.classes = "";
			end

			if not bar.groups then
				bar.groups = "";
			end

			if not bar.buffKey or not RAB_Buffs[bar.buffKey] then
				if (warn) then
					RAB_Print("Bar " .. index .. " has an invalid name: " .. tostring(bar.buffKey) .. " please readd that buff", "warn");
				end
			else
				tinsert(valid, bar);
			end
		end
	end
	return valid;
end

function RAB_CleanUp()
	RABui_IsUIShown = (RABFrame:IsShown() == 1);

	local profileKey = RAB_GetProfileKey();
	RABui_Settings.Layout[profileKey] = RABui_Bars;
	RABui_Bars = nil;
	RABui_Settings.keepversions = type(RABui_Settings.keepversions) == "table" and RAB_Versions or false;
end

function RAB_GroupStatusChange()
	local ns = 0;
	if (event == "CHAT_MSG_SYSTEM" and arg1 == ERR_RAID_YOU_JOINED) then
		ns = 2;
	elseif (event == "CHAT_MSG_SYSTEM" and arg1 == ERR_RAID_YOU_LEFT) then
		ns = 0;
	elseif (GetNumRaidMembers() > 0) then
		ns = 2;
	elseif (GetNumPartyMembers() > 0) then
		ns = 1;
	end
	if (ns ~= RAB_CurrentGroupStatus) then
		RABui_UpdateVisibility(ns, RAB_CurrentGroupStatus)
		RAB_Core_Raise("RAB_GROUPSTATUS", ns, RAB_CurrentGroupStatus);
		RAB_CurrentGroupStatus = ns;
	end
	if (event == "PLAYER_ENTERING_WORLD") then
		return "remove";
	end
end

RAB_Core_Register("PLAYER_ENTERING_WORLD", "groupStatus", RAB_GroupStatusChange);
RAB_Core_Register("CHAT_MSG_SYSTEM", "groupStatus", RAB_GroupStatusChange);
RAB_Core_Register("VARIABLES_LOADED", "load", RAB_StartUp);
RAB_Core_Register("PLAYER_LOGOUT", "unload", RAB_CleanUp);

-- Profile Management Functions
function RAB_GetCharKey()
	return GetCVar("realmName") .. "." .. UnitName("player");
end

function RAB_GetCurrentProfile()
	local charKey = RAB_GetCharKey();
	if RABui_Settings.currentProfileByChar and RABui_Settings.currentProfileByChar[charKey] then
		return RABui_Settings.currentProfileByChar[charKey];
	end
	return "Default";
end

function RAB_SetCurrentProfile(profileName)
	if not RABui_Settings.currentProfileByChar then
		RABui_Settings.currentProfileByChar = {};
	end
	RABui_Settings.currentProfileByChar[RAB_GetCharKey()] = profileName;
end

function RAB_GetProfileKey(profileName)
	if not profileName then
		profileName = RAB_GetCurrentProfile();
	end
	return RAB_GetCharKey() .. "." .. profileName;
end

function RAB_GetAllProfiles()
	local profiles = {};
	local playerPrefix = GetCVar("realmName") .. "." .. UnitName("player") .. ".";
	
	-- Safety check: ensure Layout table exists
	if not RABui_Settings or not RABui_Settings.Layout then
		return profiles;
	end
	
	for key, val in pairs(RABui_Settings.Layout) do
		if string.find(key, "^" .. string.gsub(playerPrefix, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) then
			local profileName = string.sub(key, string.len(playerPrefix) + 1);
			if profileName ~= "" then
				table.insert(profiles, profileName);
			end
		end
	end
	
	return profiles;
end

function RAB_SaveProfile(profileName)
	if not profileName or profileName == "" then
		RAB_Print("Error: Profile name cannot be empty");
		return false;
	end
	
	-- Safety check: ensure Layout table exists
	if not RABui_Settings then
		RABui_Settings = {};
	end
	if not RABui_Settings.Layout then
		RABui_Settings.Layout = {};
	end
	
	local profileKey = RAB_GetProfileKey(profileName);
	RABui_Settings.Layout[profileKey] = {};
	
	-- Deep copy current bars
	for i, bar in ipairs(RABui_Bars) do
		RABui_Settings.Layout[profileKey][i] = {};
		for key, val in pairs(bar) do
			RABui_Settings.Layout[profileKey][i][key] = val;
		end
	end
	
	RAB_Print("Profile '" .. profileName .. "' saved");
	return true;
end

function RAB_CreateNewProfile(profileName)
	if not profileName or profileName == "" then
		RAB_Print("Error: Profile name cannot be empty");
		return false;
	end
	
	-- Safety check: ensure Layout table exists
	if not RABui_Settings then
		RABui_Settings = {};
	end
	if not RABui_Settings.Layout then
		RABui_Settings.Layout = {};
	end
	
	local profileKey = RAB_GetProfileKey(profileName);
	
	-- Check if profile already exists
	if RABui_Settings.Layout[profileKey] then
		RAB_Print("Error: Profile '" .. profileName .. "' already exists");
		return false;
	end
	
	-- Create new profile with empty bars
	RABui_Settings.Layout[profileKey] = {};
	
	-- Clear current bars and sync UI
	RABui_Bars = {};
	RABui_SyncBars();
	if RABui_UpdateTitle then
		RABui_UpdateTitle();
	end
	if RABui_Settings_Layout_SyncList then
		RABui_Settings_Layout_SyncList();
	end
	
	RAB_Print("New profile '" .. profileName .. "' created with empty bars");
	return true;
end

function RAB_LoadProfile(profileName)
	if not profileName or profileName == "" then
		RAB_Print("Error: Profile name cannot be empty");
		return false;
	end
	
	-- Safety check: ensure Layout table exists
	if not RABui_Settings or not RABui_Settings.Layout then
		RAB_Print("Error: No profiles available");
		return false;
	end
	
	local profileKey = RAB_GetProfileKey(profileName);
	if not RABui_Settings.Layout[profileKey] then
		RAB_Print("Error: Profile '" .. profileName .. "' does not exist");
		return false;
	end
	
	-- Clear current bars
	RABui_Bars = {};
	
	-- Deep copy profile bars
	for i, bar in ipairs(RABui_Settings.Layout[profileKey]) do
		RABui_Bars[i] = {};
		for key, val in pairs(bar) do
			RABui_Bars[i][key] = val;
		end
	end
	
	-- a profile saved or imported by another version may name buffs that no longer exist
	RABui_Bars = RAB_ValidateBars(RABui_Bars, true);

	RAB_SetCurrentProfile(profileName);
	RAB_Print("Profile '" .. profileName .. "' loaded");
	
	-- Refresh UI
	RABui_SyncBars();
	if RABui_UpdateTitle then
		RABui_UpdateTitle();
	end
	if RAB_Settings_Frame and RAB_Settings_Frame:IsVisible() then
		RABui_Settings_Refresh();
	end
	
	return true;
end

function RAB_DeleteProfile(profileName)
	if not profileName or profileName == "" then
		RAB_Print("Error: Profile name cannot be empty");
		return false;
	end
	
	if profileName == "Default" then
		RAB_Print("Error: Cannot delete the Default profile");
		return false;
	end
	
	-- Safety check: ensure Layout table exists
	if not RABui_Settings or not RABui_Settings.Layout then
		RAB_Print("Error: No profiles available");
		return false;
	end
	
	local profileKey = RAB_GetProfileKey(profileName);
	if not RABui_Settings.Layout[profileKey] then
		RAB_Print("Error: Profile '" .. profileName .. "' does not exist");
		return false;
	end
	
	RABui_Settings.Layout[profileKey] = nil;
	
	-- If we just deleted the current profile, switch to Default
	if RAB_GetCurrentProfile() == profileName then
		RAB_LoadProfile("Default");
	end
	
	RAB_Print("Profile '" .. profileName .. "' deleted");
	return true;
end

function RAB_MigrateOldProfiles()
	local playerPrefix = RAB_GetCharKey() .. ".";
	local oldCurrentKey = playerPrefix .. "current";
	local newDefaultKey = playerPrefix .. "Default";

	-- Migrate .current to Default if Default doesn't exist
	if RABui_Settings.Layout[oldCurrentKey] and not RABui_Settings.Layout[newDefaultKey] then
		RABui_Settings.Layout[newDefaultKey] = RABui_Settings.Layout[oldCurrentKey];
		RABui_Settings.Layout[oldCurrentKey] = nil;
		RAB_Print("Migrated existing profile to 'Default'");
	end

	-- Migrate old global currentProfile to per-character
	if RABui_Settings.currentProfile then
		if not RABui_Settings.currentProfileByChar then
			RABui_Settings.currentProfileByChar = {};
		end
		local charKey = RAB_GetCharKey();
		if not RABui_Settings.currentProfileByChar[charKey] then
			RABui_Settings.currentProfileByChar[charKey] = RABui_Settings.currentProfile;
		end
		RABui_Settings.currentProfile = nil;
	end
end

-- Helper function to serialize a value
function RAB_SerializeValue(val)
	local valType = type(val);
	if valType == "string" then
		return "\"" .. string.gsub(val, "([\"\\])", "\\%1") .. "\"";
	elseif valType == "number" then
		return tostring(val);
	elseif valType == "boolean" then
		return val and "true" or "false";
	elseif valType == "table" then
		local result = "{";
		local first = true;
		for k, v in pairs(val) do
			if not first then
				result = result .. ",";
			end
			first = false;
			if type(k) == "number" then
				result = result .. "[" .. k .. "]=" .. RAB_SerializeValue(v);
			else
				result = result .. "[" .. RAB_SerializeValue(k) .. "]=" .. RAB_SerializeValue(v);
			end
		end
		return result .. "}";
	else
		return "nil";
	end
end

-- Export current profile to a string
function RAB_ExportProfile()
	if not RABui_Bars or table.getn(RABui_Bars) == 0 then
		RAB_Print("Error: No bars to export");
		return nil;
	end

	local serialized = RAB_SerializeValue(RABui_Bars);
	RAB_Print("Profile exported successfully", "ok");
	return serialized;
end

-- Import profile from a string
function RAB_ImportProfile(profileName, profileData)
	if not profileName or profileName == "" then
		RAB_Print("Error: Profile name cannot be empty");
		return false;
	end

	if not profileData or profileData == "" then
		RAB_Print("Error: Profile data cannot be empty");
		return false;
	end

	-- Safety check: ensure Layout table exists
	if not RABui_Settings then
		RABui_Settings = {};
	end
	if not RABui_Settings.Layout then
		RABui_Settings.Layout = {};
	end

	local profileKey = RAB_GetProfileKey(profileName);

	-- Try to deserialize the profile data
	local loadFunc, err = loadstring("return " .. profileData);
	if not loadFunc then
		RAB_Print("Error: Invalid profile data - " .. tostring(err));
		return false;
	end

	local success, bars = pcall(loadFunc);
	if not success or type(bars) ~= "table" then
		RAB_Print("Error: Could not parse profile data");
		return false;
	end

	-- Validate the bars
	for i, bar in ipairs(bars) do
		if not bar.buffKey or not RAB_Buffs[bar.buffKey] then
			RAB_Print("Error: Bar " .. i .. " has invalid buff key: " .. tostring(bar.buffKey));
			return false;
		end
	end

	-- Save the imported profile
	RABui_Settings.Layout[profileKey] = bars;

	RAB_Print("Profile '" .. profileName .. "' imported successfully");
	return true;
end

function RAB_SendMessage(st, target, prefix)
	-- Chunk up at commas.
	if (target == "CONSOLE") then
		RAB_Print(st);
	elseif (strlen(st) < 256) then
		RAB_DoSendMessage(st, target);
	else
		local chunk1 = strsub(st, 1, 250);
		local chunk2 = strsub(st, 251);
		local lcpos = strrpos(chunk1, ",");
		chunk2 = "... " .. strsub(chunk1, lcpos + 1) .. chunk2;
		chunk1 = strsub(chunk1, 1, lcpos) .. " ...";
		RAB_DoSendMessage(chunk1, target);
		RAB_SendMessage((prefix ~= nil and prefix or "") .. chunk2, target);
	end
end

function RAB_DoSendMessage(st, target)
	-- Get a string, send a string
	local autoClearAFK = GetCVar("autoClearAFK");
	SetCVar("autoClearAFK", 0);
	if (target == "RAID" or target == "RAID_WARNING" or target == "GUILD" or target == "OFFICER" or target == "PARTY" or target == "SAY") then
		SendChatMessage(st, target);
	elseif (string.find(target, "CHANNEL:(%w+)") ~= nil) then
		local _, _, chan = string.find(target, "CHANNEL:(%w+)");
		local chanid = GetChannelName(chan);
		if (chanid ~= 0) then
			SendChatMessage(st, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.language, chanid);
		else
			RAB_Print(string.format(sRAB_OutputLayerError_NotInChannel, chan), "warn");
		end
	else
		if (string.find(target, "WHISPER:(.+)") ~= nil) then
			_, _, target = string.find(target, "WHISPER:(.+)");
		end
		SendChatMessage(st, "WHISPER", DEFAULT_CHAT_FRAME.editBox.language, target);
	end
	SetCVar("autoClearAFK", autoClearAFK);
end

function RAB_GroupMembers(userData)
	return RAB_GroupMember, userData, 0
end

function RAB_GroupMember(userData, i)
	local party_prefix, party_max, ok, group, u;
	if (UnitInRaid("player")) then
		party_prefix = "raid";
		party_max = 40;
	else
		party_prefix = "party";
		party_max = 5;
	end
	ok = false;

	while true do
		i = i + 1;
		if (i > party_max) then
			return nil;
		end ;
		u = party_prefix .. i;
		if (u == "party5") then
			u = "player"
		end
		if (party_prefix == "raid") then
			_, _, group = GetRaidRosterInfo(i);
		else
			-- a party has no roster; it is one group, and reports print "G1" rather than failing on nil
			group = 1;
		end
		if (UnitExists(u) and RAB_UnitClass(u) ~= nil) then
			if (userData.groups == "" or string.find(userData.groups, tostring(group)) ~= nil) then
				if (userData.classes == "" or string.find(userData.classes, RAB_ClassShort[RAB_UnitClass(u)]) ~= nil) then
					return i, u, group;
				end
			end
		end
	end
end

-- Turns "motw 12 mp" into a bar-like query table, the shape every query function expects.
-- Returns nil when the text isn't a query. An old "selfX" key selects X limited to yourself.
function RAB_ParseQuery(msg)
	local _, _, buffKey, groups, classes = string.find(msg or "", "^(%a+) ?([1-8]*) ?([mlprdhswa]*)$");
	if (buffKey == nil) then
		return nil;
	end
	local selfLimit = false;
	if (RAB_Buffs[buffKey] == nil and string.find(buffKey, "^self") and RAB_Buffs[string.sub(buffKey, 5)] ~= nil) then
		buffKey = string.sub(buffKey, 5);
		selfLimit = true;
	end
	return { buffKey = buffKey, groups = groups, classes = classes, selfLimit = selfLimit, excludeNames = {} };
end

-- GENERAL BUFF-QUERY CODELINE.
function RAB_BuffCheckOutput(userData, outputTo, invert)
	-- Check query, output results (Called by the /rab handler (command UI), bar clicks (visual UI)).
	local output = (userData.groups ~= "" and userData.groups ~= "12345678") and ("[G" .. userData.groups .. "] ") or "";
	output = output .. (userData.classes ~= "" and strlen(userData.classes) < 8 and "[" .. userData.classes .. "] " or "");

	if (RAB_Buffs[userData.buffKey] ~= nil) then
		local _, _, _, _, _, _, mtext, htext, invert2 = RAB_CallRaidBuffCheck(userData, true, true);
		if (invert2) then
			invert = not invert;
		end
		if (mtext == nil) then
			return ;
		end
		output = output .. ((invert and htext ~= nil) and htext or mtext);
	else
		output = "Unknown buff requested ('" .. tostring(userData.buffKey) .. "').";
		outputTo = "CONSOLE";
	end
	if (outputTo == "RAID" and not UnitInRaid("player")) then
		outputTo = "PARTY";
	end
	output = sRAB_BuffOutputPrefix .. output;
	RAB_SendMessage(output, outputTo, sRAB_BuffOutputPrefix);
end

function RAB_CallRaidBuffCheck(userData, needraw, needtxt)
	-- Check query, return results (UI)
	if (RAB_Lock == 1) then
		-- callers expect values, not a table
		return 0, 0, 0, "", "", "", sRAB_Error_NotReady, sRAB_Error_NotReady;
	end

	if RAB_Buffs ~= nil and RAB_Buffs[userData.buffKey] ~= nil then
		if RAB_Buffs[userData.buffKey].queryFunc ~= nil then
			return RAB_Buffs[userData.buffKey].queryFunc(userData, needraw, needtxt);
		else
			return RAB_DefaultQueryHandler(userData, needraw, needtxt);
		end
	else
		return 0, 0, 0, sRAB_Error_NoBuffDataBar, "", "", sRAB_Error_NoBuffData, sRAB_Error_NoBuffData;
	end
end

function RAB_IsEligible(u, userData)
	if not UnitIsConnected(u) then
		return false;
	end

	if userData.buffKey ~= 'pvp' and RAB_UnitIsDead(u) then
		return false;
	end

	if userData.selfLimit and not UnitIsUnit(u, 'player') then
		return false;
	end

	local unitName = UnitName(u);

	-- If unitname matches anything in the excludeNames list case insensitive, return false
	for _, name in ipairs(userData.excludeNames or {}) do
		if string.lower(name) == string.lower(unitName) then
			return false;
		end
	end

	local buff = RAB_Buffs[userData.buffKey];

	-- check for main tank filtering
	if buff.ignoreMTs ~= nil and RAB_CTRA_IsMT(unitName) then
		return false;
	end

	-- check for ignoreClass
	if buff.ignoreClass ~= nil and string.find(buff.ignoreClass, RAB_ClassShort[RAB_UnitClass(u)]) ~= nil then
		return false;
	end

	-- check for class specific spells
	if buff.class ~= nil and RAB_UnitClass(u) ~= buff.class then
		return false;
	end

	return true;
end

function RAB_IsSanePvP(target)
	return (RABui_Settings.stoppvp ~= true or UnitIsPVP("player")) or not UnitIsPVP(target);
end

-- Casting layer. ClassicAPI's C_Spell.CastAtUnit casts straight at a unit token, so RABuffs no longer
-- clears your target, waits in targeting mode, retargets afterwards, or toggles the autoSelfCast CVar.
function RAB_CastSpell_IsCastable(spellkey, mute, muteobvious)
	local sName, spellID = sRAB_SpellNames[spellkey], sRAB_SpellIDs[spellkey];
	if (sName == nil or spellID == nil) then
		if (not mute) then
			RAB_Print(string.format(sRAB_CastingLayer_NoEntry, spellkey), "warn");
		end
		return false, "What";
	end
	if (RAB_UnitIsDead("player")) then
		if (not muteobvious) then
			RAB_Print(string.format(sRAB_CastingLayer_Dead, sName), "warn");
		end
		return false, "Dead";
	end
	if (UnitOnTaxi("player")) then
		if (not muteobvious) then
			RAB_Print(string.format(sRAB_CastingLayer_Mounted, sName), "warn");
		end
		return false, "Taxi";
	end
	local usable, noMana = IsUsableSpell(spellID);
	if (noMana) then
		if (not muteobvious) then
			RAB_Print(string.format(sRAB_CastingLayer_NoMana, sName), "warn");
		end
		return false, "Mana";
	end
	-- the global cooldown is not a reason to refuse: the click would only fail for a moment
	local cd = C_Spell.GetSpellCooldown(spellID);
	if (cd ~= nil and cd.startTime > 0 and cd.duration > 0 and not cd.isOnGCD) then
		if (not mute) then
			RAB_Print(string.format(sRAB_CastingLayer_Cooldown, sName), "warn");
		end
		return false, "Cooldown", cd.startTime + cd.duration - GetTime();
	end
	if (not usable) then
		if (not muteobvious) then
			RAB_Print(string.format(sRAB_CastingLayer_Unusable, sName), "warn");
		end
		return false, "Unusable";
	end
	return true;
end

-- Casts spellkey's spell at unit. Returns true when the cast went out.
function RAB_CastSpell_AtUnit(spellkey, unit, mute)
	if (not RAB_CastSpell_IsCastable(spellkey, mute, mute)) then
		return false;
	end
	if (not C_Spell.CastAtUnit(sRAB_SpellIDs[spellkey], unit)) then
		if (not mute) then
			RAB_Print(string.format(sRAB_CastBuff_CouldNotCast, sRAB_SpellNames[spellkey]), "warn");
		end
		return false;
	end
	RABui_LastBuffEvent = GetTime();
	RAB_ClearUnitBuffCache(unit);
	if (not UnitIsUnit("player", unit)) then
		-- if the buff doesn't land (line of sight), others get priority for a while
		RAB_CastLog[unit] = GetTime() + 15;
	end
	return true;
end

-- True when spellkey's spell can reach unit now. C_Spell.IsSpellInRange uses the client's own range
-- test, so the tooltip and the click pick the same person (the old tooltip used UnitIsVisible).
function RAB_RangeCheck(u, spellkey)
	if (UnitIsUnit(u, "player")) then
		return true;
	end
	local spellID = spellkey and sRAB_SpellIDs[spellkey];
	if (spellID == nil) then
		return UnitIsVisible(u) and true or false;
	end
	return C_Spell.IsSpellInRange(spellID, u) == true;
end

-- BACKGROUND CORE
function RAB_RaidMemberInfo(name)
	-- Is "Marvin" in raid?
	local i, u;
	for i, u in RAB_GroupMembers({ ["groups"] = "", ["classes"] = "", }) do
		if (UnitName(u) == name) then
			local rank = 0;
			if (UnitInRaid("player")) then
				_, rank = GetRaidRosterInfo(i);
			end
			if (UnitIsPartyLeader(u)) then
				rank = 2;
			end
			return true, u, rank;
		end
	end
	return false, "", -1;
end

function RAB_IsBuffUp(unit, buffKey)
	-- Resolve and check a buff based on its key. Special queries have no single aura and return nil.
	if (RAB_Buffs[buffKey].type == "debuff") then
		for _, identifier in ipairs(RAB_Buffs[buffKey].identifiers) do
			if (isUnitDebuffUp(unit, identifier)) then
				return true;
			end
		end
		return false;
	elseif (RAB_Buffs[buffKey].type == "special") then
		return nil;
	else
		for _, identifier in ipairs(RAB_Buffs[buffKey].identifiers) do
			if (isUnitBuffUp(unit, identifier)) then
				return true;
			end
		end
		return false;
	end
end

function RAB_UnitClass(unit)
	-- Localization/nil workaround.
	local _, ec = UnitClass(unit);
	ec = (ec ~= nil) and ec or "Mage";
	return strsub(ec, 1, 1) .. strlower(strsub(ec, 2));
end

function RAB_UnitIsDead(unit)
	return (UnitIsDeadOrGhost(unit) and not UnitIsFeignDeath(unit));
end

-- Aura cache, read through ClassicAPI's C_UnitAuras.UnitAura. It gives the spell ID, name, stacks,
-- dispel type and expiry time for every unit (no SuperWoW, no tooltip scanning), allocates nothing,
-- and reports Turtle's extra debuffs parked in buff slots as debuffs.
-- Entries are dropped on UNIT_AURA / UNIT_AURA_DELTA and roster changes; AURA_MAX_AGE is a safety net.
local AURA_MAX_AGE = 10;
RAB_AuraCache = {}; -- [unit] = { buffs = { n, [i] = entry }, debuffs = { ... }, updated = GetTime() }

local function IconKey(path)
	local key = string.gsub(path or "", "^.*\\", "");
	return strlower(key);
end

local function ReadAuras(list, unit, filter)
	local n = 0;
	for i = 1, 48 do
		local name, icon, count, dispelType, duration, expirationTime, _, _, _, spellId = C_UnitAuras.UnitAura(unit, i, filter);
		if (name == nil) then
			break;
		end
		n = n + 1;
		local e = list[n];
		if (e == nil) then
			e = {};
			list[n] = e;
		end
		if (e.spellId ~= spellId or e.name ~= name) then
			e.lname = strlower(name);
			e.tex = IconKey(icon);
		end
		e.name, e.icon, e.count, e.dispel, e.duration, e.spellId = name, icon, count, dispelType, duration, spellId;
		e.expires = expirationTime or 0;
	end
	list.n = n;
end

function RAB_GetAuraCache(unit)
	local c = RAB_AuraCache[unit];
	if (c == nil) then
		c = { buffs = { n = 0 }, debuffs = { n = 0 } };
		RAB_AuraCache[unit] = c;
	end
	local now = GetTime();
	if (c.updated == nil or c.updated < now - AURA_MAX_AGE) then
		ReadAuras(c.buffs, unit, "HELPFUL");
		ReadAuras(c.debuffs, unit, "HARMFUL");
		c.updated = now;
	end
	return c;
end

function RAB_ClearUnitBuffCache(unit)
	if (RAB_AuraCache[unit] ~= nil) then
		RAB_AuraCache[unit].updated = nil;
	end
	-- the same player may also be cached under a raid or party token
	if unit == "player" or unit == "target" then
		local i;
		for i = 1, GetNumRaidMembers() do
			if (RAB_AuraCache["raid" .. i] ~= nil and UnitIsUnit("raid" .. i, unit)) then
				RAB_AuraCache["raid" .. i].updated = nil;
			end
		end
		for i = 1, GetNumPartyMembers() do
			if (RAB_AuraCache["party" .. i] ~= nil and UnitIsUnit("party" .. i, unit)) then
				RAB_AuraCache["party" .. i].updated = nil;
			end
		end
	end
end

local function ClearAllAuraCaches()
	local unit, c;
	for unit, c in RAB_AuraCache do
		c.updated = nil;
	end
end

local function OnAuraEvent()
	-- both events fire once per unit token, so only that token needs re-reading
	if (arg1 ~= nil and RAB_AuraCache[arg1] ~= nil) then
		RAB_AuraCache[arg1].updated = nil;
	end
end

RAB_Core_Register("UNIT_AURA", "auraCache", OnAuraEvent);
RAB_Core_Register("UNIT_AURA_DELTA", "auraCache", OnAuraEvent);
RAB_Core_Register("PLAYER_TARGET_CHANGED", "auraCache", function()
	if (RAB_AuraCache.target ~= nil) then
		RAB_AuraCache.target.updated = nil;
	end
end);
-- unit tokens move to other players when the roster changes
RAB_Core_Register("RAID_ROSTER_UPDATE", "auraCache", ClearAllAuraCaches);
RAB_Core_Register("PARTY_MEMBERS_CHANGED", "auraCache", ClearAllAuraCaches);

-- An identifier with a spellId matches that spell only (several buffs share names, e.g. "Increased
-- Stamina"). Otherwise both its icon and its name must match, compared without case.
local function AuraMatches(e, identifier)
	if (identifier.spellId) then
		return e.spellId == identifier.spellId;
	end
	if (identifier.lname == nil) then
		identifier.lname = identifier.tooltip and strlower(identifier.tooltip) or false;
		identifier.ltex = identifier.texture and strlower(identifier.texture) or false;
	end
	if (not identifier.lname and not identifier.ltex) then
		return false;
	end
	if (identifier.ltex and identifier.ltex ~= e.tex) then
		return false;
	end
	if (identifier.lname and identifier.lname ~= e.lname) then
		return false;
	end
	return true;
end

local function FindAura(list, identifier)
	local i;
	for i = 1, list.n do
		if (AuraMatches(list[i], identifier)) then
			return list[i];
		end
	end
	return nil;
end

-- Returns true, stacks, expirationTime (0 when unknown) when unit has the aura.
function isUnitBuffUp(unit, identifier)
	if (unit == nil or identifier == nil or not UnitExists(unit)) then
		return false;
	end
	local e = FindAura(RAB_GetAuraCache(unit).buffs, identifier);
	if (e ~= nil) then
		return true, e.count, e.expires;
	end
	return false;
end

function isUnitDebuffUp(unit, identifier)
	if (unit == nil or identifier == nil or not UnitExists(unit)) then
		return false;
	end
	local e = FindAura(RAB_GetAuraCache(unit).debuffs, identifier);
	if (e ~= nil) then
		return true, e.count, e.expires;
	end
	return false;
end

-- Latest expiry (GetTime() based) of any aura of buffKey on unit, or 0 when unknown.
function RAB_GetBuffExpiry(unit, buffKey)
	local buff = RAB_Buffs[buffKey];
	if (buff == nil or buff.identifiers == nil) then
		return 0;
	end
	local check = (buff.type == "debuff") and isUnitDebuffUp or isUnitBuffUp;
	local best = 0;
	for _, identifier in ipairs(buff.identifiers) do
		local up, _, expires = check(unit, identifier);
		if (up and expires ~= nil and expires > best) then
			best = expires;
		end
	end
	return best;
end

-- True when unit has a debuff of dispel type btype ("Magic", "Curse", "Poison", "Disease"), or any
-- debuff you can remove when btype is "Curable".
function RAB_UnitHasDebuffType(unit, btype)
	if (btype == "Curable") then
		return C_UnitAuras.UnitAura(unit, 1, "HARMFUL|RAID") ~= nil;
	end
	local list = RAB_GetAuraCache(unit).debuffs;
	local i;
	for i = 1, list.n do
		if (list[i].dispel == btype) then
			return true;
		end
	end
	return false;
end

-- The query key of a cached aura entry, or nil.
function RAB_AuraToBuff(e)
	local buffKey, buffData;
	for buffKey, buffData in RAB_Buffs do
		if (buffData.identifiers ~= nil) then
			for _, identifier in ipairs(buffData.identifiers) do
				if (AuraMatches(e, identifier)) then
					return buffKey;
				end
			end
		end
	end
	return nil;
end

function strrpos(str, chr)
	local start = string.find(str, chr, 1, true);
	while string.find(str, chr, start + 1, true) ~= nil do
		start = string.find(str, chr, start + 1, true);
	end
	return start;
end
