-- RABuffs_strings.lua
--  Non-code storage for various code/title strings, and the spell layer. Do not localize this file.
-- Version 0.13.0

sRAB_DownloadURL = "https://github.com/KameleonUK/Rabuffs/releases";

sRAB_Settings_UIHeader = "RAB";

sRAB_LOCALIZATION, sRAB_Localization_UI, sRAB_Localization_Output, sRAB_Localization_SpellLayer = {}, "", "",
"|c00ff9922Automatic spellbook|r";

sRAB_SpellNames = {}; -- [buffKey] = spell name to cast
sRAB_SpellIDs = {};   -- [buffKey] = spell ID of the highest rank you know

function sRAB_Localize(strings, spells)
	if (strings) then
		-- Only English ships; the language selector was removed with the old settings window.
		sRAB_LOCALIZATION_vui = "enUS";
		sRAB_LOCALIZATION_out = "enUS";
		sRAB_LOCALIZATION["enUS"](true, true, (GetLocale() == "enUS"));
		if (RABui_Localize ~= nil) then
			RABui_Localize();
		end
	end
	if (spells) then
		sRAB_PseudoLocalize();
	end
end

-- Maps each castable buff of the player's class to the spell that casts it.
-- ClassicAPI's GetSpellInfo("name") returns the highest rank you know (or nil), so most buffs resolve by
-- the aura's name, which is also the spell's name. That keeps spells that share an icon apart (Mark of the
-- Wild and Gift of the Wild both use Spell_Nature_Regeneration). A few bars are named after the aura rather
-- than the spell (Soulstone Resurrection is cast by Create Soulstone, Water by Conjure Water); those fall
-- back to the spellbook icon, choosing the costliest spell that uses it, as the old texture scan did.
function sRAB_PseudoLocalize()
	sRAB_SpellLayerLocale = "auto";
	sRAB_SpellNames, sRAB_SpellIDs = {}, {};

	local byIcon, iconCost = {}, {};
	local slot = 1;
	while true do
		local name, _, icon, cost, _, _, _, _, _, spellID = GetSpellInfo(slot, BOOKTYPE_SPELL);
		if (name == nil) then
			break;
		end
		icon = strlower(string.gsub(icon or "", "^.*\\", ""));
		cost = cost or 0;
		if (byIcon[icon] == nil or cost > iconCost[icon]) then
			byIcon[icon] = { name = name, id = spellID };
			iconCost[icon] = cost;
		end
		slot = slot + 1;
	end

	local mc = RAB_UnitClass("player");
	for buffKey, buffData in RAB_Buffs do
		if (buffData.grouping == mc and buffData.identifiers ~= nil) then
			for _, identifier in ipairs(buffData.identifiers) do
				-- group/class versions are stored under their own key (ab, pof, gbok...)
				local key = identifier.bigcast or buffKey;
				if (sRAB_SpellNames[key] == nil) then
					local name, _, _, _, _, _, _, _, _, spellID;
					if (identifier.tooltip) then
						name, _, _, _, _, _, _, _, _, spellID = GetSpellInfo(identifier.tooltip);
					end
					if (name == nil and identifier.texture) then
						local s = byIcon[strlower(identifier.texture)];
						if (s) then
							name, spellID = s.name, s.id;
						end
					end
					if (name ~= nil) then
						sRAB_SpellNames[key], sRAB_SpellIDs[key] = name, spellID;
					end
				end
			end
		end
	end
end
