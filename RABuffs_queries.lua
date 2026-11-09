-- RABuffs_queries.lua
--  Dictionary between RABuffs_core.lua and user -- provides core-information for queriable effects.
-- Version 0.13.0
-- BLOCK 1: Query functions
-- BLOCK 2: Casting functions
-- BLOCK 3: Query definitions (RABuffs_buffs.lua)


RAB_PendingRes = {}; --Name=expire;
RAB_BuffTimers = {}; -- Name.query = expire (GetTime); filled from CTRA "RN" messages, a fallback only

-- Returns shouldRecast, secondsLeft. The time comes from the aura itself (ClassicAPI records the expiry
-- of your own auras and of every aura whose cast your client saw this session); CTRA's timers are used
-- only when the aura's expiry isn't known.
function RAB_ShouldRecast(unit, buffKey, isbuffed)
	local buff = RAB_Buffs[buffKey];
	if (not isbuffed or buff == nil or buff.recast == nil) then
		return false;
	end
	local expires = RAB_GetBuffExpiry(unit, buffKey);
	if (expires == 0) then
		expires = RAB_BuffTimers[UnitName(unit) .. "." .. buffKey] or 0;
	end
	local fadetime = expires - GetTime();
	if (fadetime > 0) then
		return fadetime < buff.recast * 60, fadetime;
	end
	return false;
end

-- BLOCK 1: Query functions
function RAB_CollectPlayerWeaponBuffs(buffData)
	local results = {}

	-- if it's for a weapon, no need to scan everything
	if buffData.useOn == 'weapon' or buffData.useOn == 'weaponOH' then
		-- there can be 0 1 2 weapons
		for i, slotName in { 'MainHandSlot', 'SecondaryHandSlot' } do
			local slotId = GetInventorySlotInfo(slotName);
			local itemLink = GetInventoryItemLink('player', slotId);
			if itemLink then
				results[slotName] = { name = slotName, texture = 'nomatch1234', buffed = 0 }
			end
		end

		local mh, mhtime, mhcharge, oh, ohtime, ohcharge = GetWeaponEnchantInfo()
		-- RAB_Print(string.format("%s %s %s %s %s %s", tostring(mh), tostring(mhtime), tostring(mhcharge), tostring(oh), tostring(ohtime), tostring(ohcharge)))
		if mh and results['MainHandSlot'] then
			results['MainHandSlot']['buffed'] = 1
		end
		if oh and results['SecondaryHandSlot'] then
			results['SecondaryHandSlot']['buffed'] = 1
		end

		return results
	end

	return results
end

function RAB_WeaponIsBuffed(weaponBuffs, buffData)
	local buffed = 0

	-- custom handling for weapon enchants
	if buffData.useOn == 'weapon' then
		buffed = 1
		local slotName = 'MainHandSlot'
		if weaponBuffs[slotName] == nil then
			buffed = 0
		end                                        -- no wep, thus not buffed
		if weaponBuffs[slotName] ~= nil and weaponBuffs[slotName]['buffed'] == 0 then
			buffed = 0
		end -- wep with no buff on it
		return buffed
	end
	if buffData.useOn == 'weaponOH' then
		buffed = 1
		local slotName = 'SecondaryHandSlot'
		if weaponBuffs[slotName] == nil then
			buffed = 0
		end                                        -- no wep, thus not buffed
		if weaponBuffs[slotName] ~= nil and weaponBuffs[slotName]['buffed'] == 0 then
			buffed = 0
		end -- wep with no buff on it
		return buffed
	end

	return buffed
end

function RAB_DefaultQueryHandler(userData, needraw, needtxt)
	local buffData = RAB_Buffs[userData.buffKey]
	local buffed, fading, total, misc, txthead, hashead, txt, hastxt, invert, raw, rawsort, rawgroup = 0, 0, 0, "", "",
	"", "", "", (buffData.invert ~= nil);
	local buffname = buffData.name;
	local i, u, key, val, group, isbuffed;
	local hasSpecialFunc = buffData.sfunc ~= nil
	local sfunc = buffData.sfunc

	if (hasSpecialFunc == false) then
		if (buffData.type ~= "debuff") then
			sfunc = isUnitBuffUp;
		else
			sfunc = isUnitDebuffUp;
		end
	end

	if (needraw or needtxt) then
		raw = {};
		rawsort = "group";
		rawgroup = sRAB_Core_GroupFormat;
	end

	if buffData.useOn == 'weapon' or buffData.useOn == 'weaponOH' then
		local buffs = RAB_CollectPlayerWeaponBuffs(buffData)
		buffed = RAB_WeaponIsBuffed(buffs, buffData)
		total = 1
	else
		for i, u, group in RAB_GroupMembers(userData) do
			local appl, fadetime, isFading = 0;
			if (RAB_IsEligible(u, userData)) then
				isbuffed = false;

				if hasSpecialFunc then
					if sfunc(u) then
						isbuffed = true
					end
				else
					-- check all identifiers; the aura cache also gives the stack count
					for _, identifier in ipairs(buffData.identifiers) do
						local up, count = sfunc(u, identifier);
						if (up) then
							isbuffed = true
							appl = count;
							break ;
						end
					end
				end

				isFading, fadetime = RAB_ShouldRecast(u, userData.buffKey, isbuffed);
				fading = fading + (isFading and 1 or 0);

				if (needraw or needtxt) then
					tinsert(raw,
							{
								unit = u,
								name = UnitName(u) .. ((appl ~= nil and appl > 1) and " [" .. appl .. "]" or ""),
								class = RAB_UnitClass(u),
								group = group,
								buffed = isbuffed,
								fade = fadetime
							});
				end

				if (buffData.unique == nil or (buffData.unique == true and RAB_UnitClass(u) == buffData.class)) then
					total = total + 1;
				end

				buffed = buffed + (isbuffed and 1 or 0);
			end
		end
	end

	if (not (needraw or needtxt)) then
		return buffed, fading, total, "";
	end

	if (total > 1 and UnitInRaid("player") and (needraw or needtxt)) then
		if (buffData.sort == "class") then
			rawsort = "class";
			rawgroup = "%s";
			table.sort(raw, function(a, b)
				return a.class < b.class
			end);
		else
			table.sort(raw, function(a, b)
				return a.group < b.group
			end);
		end
	end

	txthead = ((buffData.missbuff ~= nil) and buffData.missbuff or string.format(sRAB_BuffOutput_MissingOn, buffname)) ..
			":";
	hashead = ((buffData.havebuff ~= nil) and buffData.havebuff or string.format(sRAB_BuffOutput_IsOn, buffname)) ..
			":";

	if (table.getn(raw) > 0) then
		local ub, bb, uc, bc, ident = "", "", 0, 0, false;

		for i = 1, table.getn(raw) do
			if (ident ~= raw[i][rawsort] and ident ~= false) then
				if (uc == 0) then
					if (bc > 1) then
						hastxt = hastxt ..
								(hastxt ~= "" and ", " or "") ..
								(rawsort == "group" and sRAB_BuffOutput_Group or "") ..
								ident .. (rawsort == "class" and "s" or "") .. " [" .. bc .. "]";
					else
						hastxt = hastxt .. (hastxt ~= "" and ", " or "") .. bb;
					end
				elseif (bc == 0) then
					if (uc > 1) then
						txt = txt ..
								(txt ~= "" and ", " or "") ..
								(rawsort == "group" and sRAB_BuffOutput_Group or "") ..
								ident .. (rawsort == "class" and "s" or "") .. " [" .. uc .. "]";
					else
						txt = txt .. (txt ~= "" and ", " or "") .. ub;
					end
				else
					hastxt = hastxt .. (hastxt ~= "" and ", " or "") .. bb;
					txt = txt .. (txt ~= "" and ", " or "") .. ub;
				end
				ub, bb, uc, bc = "", "", 0, 0;
			end

			ident = raw[i][rawsort];

			if (raw[i].buffed) then
				bc = bc + 1;
				bb = bb ..
						((bb ~= "") and ", " or "") .. raw[i].name .. " [" .. raw[i].class .. "; G" .. raw[i].group .. "]";
			else
				uc = uc + 1;
				ub = ub ..
						((ub ~= "") and ", " or "") .. raw[i].name .. " [" .. raw[i].class .. "; G" .. raw[i].group .. "]";
			end
		end

		if (uc == 0) then
			hastxt = hastxt ..
					(hastxt ~= "" and ", " or "") ..
					(rawsort == "group" and sRAB_BuffOutput_Group or "") ..
					ident .. (rawsort == "class" and "s" or "") .. " [" .. bc .. "]";
		elseif (bc == 0) then
			txt = txt ..
					(txt ~= "" and ", " or "") ..
					(rawsort == "group" and sRAB_BuffOutput_Group or "") ..
					ident .. (rawsort == "class" and "s" or "") .. " [" .. uc .. "]";
		else
			hastxt = hastxt .. (hastxt ~= "" and ", " or "") .. bb;
			txt = txt .. (txt ~= "" and ", " or "") .. ub;
		end

		if (buffed == total and total > 0) then
			txt = string.format(sRAB_BuffOutput_EveryoneHas, buffData.name);
			hastxt = txt;
		elseif (buffed > 0) then
			txt = txthead .. " [" .. (total - buffed) .. " / " .. total .. "] " .. txt .. ".";
			hastxt = hashead .. " [" .. buffed .. " / " .. total .. "] " .. hastxt .. ".";
		else
			txt = string.format(sRAB_BuffOutput_EveryoneMissing, buffData.name);
			hastxt = txt;
		end
	else
		txt = buffData.name .. ": not applicable.";
		hastxt = buffData.name .. ": not applicable.";
	end

	return buffed, fading, total, misc, txthead, hashead, txt, hastxt, invert, raw, rawsort, rawgroup;
end

function RAB_QueryStatus(userData)
	-- Overview.
	local out, buffed, total = "", 0, 0;

	-- copy userData
	local data = {}
	for k, v in pairs(userData) do
		data[k] = v
	end

	local buffsToCheck = {
		"ai",
		"pwf",
		"motw",
		"bos",
		"bok",
		"bow",
	}

	for _, buff in ipairs(buffsToCheck) do
		data.buffKey = buff
		buffed, _, total = RAB_CallRaidBuffCheck(data, false, false);
		out = out .. buff .. ": " .. buffed .. "/" .. total .. ", ";
	end

	-- handle ss separately
	data.buffKey = "ss"
	buffed, _, total = RAB_CallRaidBuffCheck(data, false, false);
	out = out .. buffed .. " ss.";

	return 1, 0, 1, "", "", "", out, out;
end

function RAB_QueryBlank()
	return 0, 0, 0, "";
end

-- "Name (spellId) [queryKey]": the spell ID is what RAB_Buffs identifiers use, so this is what you need
-- to add a new consumable.
local function RAB_AuraLabel(e)
	local key = RAB_AuraToBuff(e);
	return e.name .. " (" .. tostring(e.spellId) .. ")" .. (key ~= nil and (" [" .. key .. "]") or "");
end

function RAB_QueryBuffInfo()
	if (not UnitExists("target")) then
		return 0, 0, 0, "", "", "", sRAB_BuffOutput_BuffInfo_NoTarget, sRAB_BuffOutput_BuffInfo_NoTarget, false;
	end
	local cache = RAB_GetAuraCache("target");
	local buffs, debuffs, i = "", "";
	for i = 1, cache.buffs.n do
		buffs = buffs .. (buffs == "" and "" or ", ") .. RAB_AuraLabel(cache.buffs[i]);
	end
	for i = 1, cache.debuffs.n do
		debuffs = debuffs .. (debuffs == "" and "" or ", ") .. RAB_AuraLabel(cache.debuffs[i]);
	end
	local text = string.format(sRAB_BuffOutput_BuffInfo_General, UnitName("target"),
			(buffs == "" and sRAB_BuffOutput_BuffInfo_None or buffs),
			(debuffs == "" and sRAB_BuffOutput_BuffInfo_None or debuffs));
	return 0, 0, 0, "", "", "", text, text;
end

function RAB_QueryHere(userData, needraw, needtxt)
	local buffed, total, misc, txthead, hashead, txt, hastxt, invert, raw, rawsort = 0, 0, "",
	sRAB_BuffOutput_Here_NotHere, sRAB_BuffOutput_Here_Here, sRAB_BuffOutput_Here_NotHere .. " ",
	sRAB_BuffOutput_Here_Here .. " ", false, nil, "append";
	if (needraw) then
		raw = {};
	end
	local inraid = UnitInRaid("player");
	local myzone = "noraid";
	local zone, group;

	if (inraid) then
		for i = 1, 40 do
			if (UnitIsUnit("raid" .. i, "player")) then
				_, _, group, _, _, _, myzone = GetRaidRosterInfo(i);
			end
		end
	end

	local isbuffed, append;
	for i, u, group in RAB_GroupMembers(userData) do
		if (inraid) then
			_, _, group, _, _, _, zone = GetRaidRosterInfo(i);
			zone = tostring(zone);
			group = tonumber(group);
		else
			zone = sRAB_BuffOutput_Here_OK;
			group = 1;
		end
		total = total + 1;
		append = "";
		isbuffed = false;
		if (inraid and RAB_CTRA_IsAFK(UnitName(u))) then
			if (needtxt) then
				txt = txt .. UnitName(u) .. " [" .. sRAB_BuffOutput_Here_AFK .. "], ";
			end
			if (needraw) then
				zone = sRAB_BuffOutput_Here_AFK;
			end
		elseif (not UnitIsConnected(u)) then
			if (needtxt) then
				txt = txt .. UnitName(u) .. " [" .. sRAB_BuffOutput_Here_OFF .. "], ";
			end
			if (needraw) then
				zone = sRAB_BuffOutput_Here_OFF;
			end
		elseif (inraid and (zone ~= myzone and not UnitIsVisible(u))) then
			if (needtxt) then
				txt = txt .. UnitName(u) .. " [" .. zone .. "], ";
			end
		elseif (not UnitIsVisible(u)) then
			if (needtxt) then
				txt = txt .. UnitName(u) .. " [" .. sRAB_BuffOutput_Here_OOS .. "], ";
			end
			if (needraw) then
				zone = sRAB_BuffOutput_Here_OOS;
			end
		else
			if (needtxt) then
				hastxt = hastxt .. UnitName(u) .. ", ";
			end
			buffed = buffed + 1;
			isbuffed = true;
		end
		--		if (UnitInRaid("player")) then append = " [" .. group .. "]"; end
		if (needraw) then
			tinsert(raw,
					{
						name = UnitName(u),
						class = RAB_UnitClass(u),
						group = group,
						buffed = false,
						unit = u,
						append = append,
						buffed = isbuffed,
						zone = zone
					});
		end
	end
	if (total > 1 and needraw and UnitInRaid("player")) then
		table.sort(raw, function(a, b)
			return a.zone < b.zone
		end);
	end
	if (needtxt) then
		if (buffed == total) then
			txt = sRAB_BuffOutput_Here_Everyone;
			hastxt = sRAB_BuffOutput_Here_Everyone;
		else
			txt = strsub(txt, 1, -3) .. ".";
			hastxt = strsub(hastxt, 1, -3) .. ".";
		end
	end
	return buffed, 0, total, misc, txthead, hashead, txt, hastxt, invert, raw, "zone", "%s";
end

function RAB_QueryCTRAVersion(userData, needraw, needtxt)
	local buffed, total, misc, txthead, hashead, txt, hastxt, invert, raw, rawsort = 0, 0, "",
	sRAB_BuffOutput_CTRA_OutOfDate, sRAB_BuffOutput_CTRA_Recent, sRAB_BuffOutput_CTRA_OutOfDate .. " ",
	sRAB_BuffOutput_CTRA_Recent .. " ", false;
	if (needraw) then
		raw = {};
		rawsort = "group";
	end
	if (RAB_CTRA_ResponsibleHandler ~= "CTRA") then
		return 0, 0, 0, sRAB_BuffOutput_CTRA_NoCTRA, "", "", sRAB_BuffOutput_CTRA_NoCTRA, sRAB_BuffOutput_CTRA_NoCTRA;
	end
	local i, pv, isbuffed = 1, RAB_CTRA_GetVersion(UnitName("player"));

	if (not UnitInRaid("player")) then
		txt = sRAB_BuffOutput_CTRA_NotInRaid;
		hastxt = txt;
	else
		for i, u, group in RAB_GroupMembers(userData) do
			local cv = RAB_CTRA_GetVersion(UnitName(u));
			if (cv) then
				total = total + 1;
				isbuffed = false;
				local append = "";
				if (cv >= pv) then
					isbuffed = true;
					buffed = buffed + 1;
					hastxt = hastxt .. UnitName(u) .. ", ";
				else
					txt = txt .. UnitName(u) .. " [" .. cv .. "], ";
				end
				if (needraw) then
					tinsert(raw,
							{
								name = UnitName(u),
								class = RAB_UnitClass(u),
								group = group,
								buffed = isbuffed,
								unit = u,
								version = cv
							});
				end
			end
		end
		if (total > 1 and UnitInRaid("player") and needraw) then
			table.sort(raw, function(a, b)
				return a.version < b.version
			end);
		end
		if (needtxt) then
			if (buffed == total) then
				txt = sRAB_BuffOutput_CTRA_Everyone;
				hastxt = sRAB_BuffOutput_CTRA_Everyone;
			else
				txt = strsub(txt, 1, -3) .. ".";
				hastxt = strsub(hastxt, 1, -3) .. ".";
			end
		end
	end
	return buffed, 0, total, misc, txthead, hashead, txt, hastxt, invert, raw, "version", "%s";
end


function RAB_ScanRaid(userData)
	local scanwhat = RAB_Buffs[userData.buffKey].ext;
	local out, oc, order = "", {}, {};
	for i, u, group in RAB_GroupMembers(userData) do
		local list = RAB_GetAuraCache(u).buffs;
		for j = 1, list.n do
			local e = list[j];
			local buff = RAB_AuraToBuff(e);
			local label;
			if (buff ~= nil and scanwhat == "known") then
				label = RAB_Buffs[buff].name;
			elseif (buff == nil and scanwhat == "unknown") then
				label = e.name .. " (" .. tostring(e.spellId) .. ")";
			end
			if (label ~= nil) then
				if (oc[label] == nil) then
					oc[label] = 0;
					tinsert(order, label);
				end
				oc[label] = oc[label] + 1;
			end
		end
	end
	for _, label in ipairs(order) do
		out = (out == "" and "" or (out .. ", ")) .. "[" .. label .. "]x" .. oc[label];
	end

	out = (scanwhat == "known" and "B" or "Unknown b") .. "uffs: " .. (out == "" and "none" or out) .. ".";
	return 1, 0, 1, "", "", "", out, out;
end

function RAB_QueryHealth(userData, needraw, needtxt)
	local type = RAB_Buffs[userData.buffKey].ext;
	local buffed, fading, total, misc, txthead, hashead, txt, hastxt, invert, raw, rawsort = 0, 0, 0, "",
	sRAB_BuffOutput_Health_Dead, sRAB_BuffOutput_Health_Alive, "", "", false;
	local i, hp_cur, hp_max, hp_alive, hp_dead, hp_deadtext, hp_alivetext = 0, 0, 0, 0, 0, "", "";
	if (needraw) then
		raw = {};
	end
	local group, uinfo, u, isbuffed, append;

	for i, u, group in RAB_GroupMembers(userData) do
		total = total + 1;
		append = "";
		isbuffed = false;
		if (RAB_UnitIsDead(u)) then
			hp_dead = hp_dead + 1;
			hp_deadtext = (hp_dead == 1 and "" or (hp_deadtext .. ", ")) .. UnitName(u);
		else
			hp_alive = hp_alive + 1;
			hp_alivetext = (hp_alive == 1 and "" or (hp_alivetext .. ", ")) .. UnitName(u);
			hp_cur = hp_cur + UnitHealth(u);
			hp_max = hp_max + UnitHealthMax(u);
			buffed = buffed + 1;
			isbuffed = true;
			if (UnitHealth(u) / UnitHealthMax(u) < 0.15) then
				fading = fading + 1;
			end
		end
		if (needraw) then
			tinsert(raw,
					{
						name = UnitName(u),
						class = RAB_UnitClass(u),
						group = group,
						buffed = isbuffed,
						unit = u,
						append = append
					});
		end
	end
	if (total > 1 and UnitInRaid("player") and needraw) then
		table.sort(raw, function(a, b)
			return a.group < b.group
		end);
	end
	if (hp_dead > 0) then
		misc = string.format(sRAB_BuffOutput_Health_Misc, hp_dead);
	end

	if (type == "hp") then
		buffed = hp_cur;
		total = hp_max;
		fading = 0;
	end
	if (needtxt) then
		if (hp_dead > 0) then
			if (hp_alive > 0) then
				txt = string.format(sRAB_BuffOutput_Health_Default, hp_cur, hp_max,
						floor(hp_cur * 100 / (hp_max > 0 and hp_max or 1)),
						string.format(sRAB_BuffOutput_Health_DeadPart, hp_dead, hp_deadtext));
				hastxt = string.format(sRAB_BuffOutput_Health_Default, hp_cur, hp_max,
						floor(hp_cur * 100 / (hp_max > 0 and hp_max or 1)),
						string.format(sRAB_BuffOutput_Health_AlivePart, hp_alive, hp_alivetext));
			else
				txt = sRAB_BuffOutput_Health_EveryoneDead;
				hastxt = sRAB_BuffOutput_Health_EveryoneDead;
			end
		else
			txt = string.format(sRAB_BuffOutput_Health_Default, hp_cur, hp_max,
					floor(hp_cur * 100 / (hp_max > 0 and hp_max or 1)), ".");
			hastxt = txt;
		end
	end
	return buffed, fading, total, misc, txthead, hashead, txt, hastxt, invert, raw, "group", sRAB_Core_GroupFormat;
end

function RAB_QueryInventoryItem(userData, needraw, needtxt)
	local _, _, slot, match = string.find(RAB_Buffs[userData.buffKey].ext, "(%d+):(%d+)");
	slot, match = tonumber(slot), tonumber(match);
	local itemName = GetItemInfo(match);
	if (itemName == nil) then
		itemName = string.format(sRAB_BuffOutput_Item_Unknown, match);
	end

	local buffed, total, misc, txthead, hashead, txt, hastxt, invert, raw, rawsort = 0, 0, "",
	string.format(sRAB_BuffOutput_Item_Missing, itemName), string.format(sRAB_BuffOutput_Item_Have, itemName), "", "",
	false;
	if (needraw) then
		raw = {};
	end
	local i, u, group, isbuffed, item;

	for i, u, group in RAB_GroupMembers(userData) do
		if (CheckInteractDistance(u, 1) and GetInventoryItemID(u, slot)) then
			total = total + 1;
			isbuffed = false;
			item = GetInventoryItemID(u, slot);
			if (item == match) then
				isbuffed = true;
				buffed = buffed + 1;
				hastxt = hastxt .. UnitName(u) .. ", ";
			else
				txt = txt .. UnitName(u) .. ", ";
			end
			if (needraw) then
				tinsert(raw,
						{
							name = UnitName(u),
							class = RAB_UnitClass(u),
							group = group,
							buffed = isbuffed,
							unit = u,
							append = ""
						});
			end
		end
	end
	if (total > 1 and UnitInRaid("player") and needraw) then
		table.sort(raw, function(a, b)
			return a.group < b.group
		end);
	end

	if (needtxt) then
		if (buffed == total) then
			txt = string.format(sRAB_BuffOutput_Item_Everyone, itemName);
			hastxt = string.format(sRAB_BuffOutput_Item_Everyone, itemName);
		elseif (buffed > 0) then
			txt = txthead .. " " .. strsub(txt, 1, -3) .. ".";
			hastxt = hashead .. " " .. strsub(hastxt, 1, -3) .. ".";
		else
			txt = string.format(sRAB_BuffOutput_Item_NoOne, itemName);
			hastxt = string.format(sRAB_BuffOutput_Item_NoOne, itemName);
		end
	end
	return buffed, 0, total, misc, txthead, hashead, txt, hastxt, invert, raw, "group", sRAB_Core_GroupFormat;
end

function RAB_QueryMana(userData, needraw, needtxt)
	local buffed, fading, total, misc, txthead, hashead, txt, hastxt, invert, raw, rawsort = 0, 0, 0, "",
	sRAB_BuffOutput_Mana_OutOfMana, sRAB_BuffOutput_Mana_Fine, "", "", false;
	local mana_max, mana_cur, mana_dead, mana_oom, mana_oomt = 0, 0, 0, 0, "";
	if (needraw) then
		raw = {};
	end
	local group, u, i, isbuffed, append = 0, "", 0;

	for i, u, group in RAB_GroupMembers(userData) do
		if (UnitPowerType(u) == 0) then
			total = total + 1;
			isbuffed = false;
			append = "";
			if (RAB_UnitIsDead(u)) then
				mana_dead = mana_dead + 1;
				append = sRAB_BuffOutput_Mana_DeadAppend;
			else
				mana_cur = mana_cur + UnitMana(u);
				mana_max = mana_max + UnitManaMax(u);
				if (UnitMana(u) < UnitManaMax(u) * 0.15) then
					mana_oom = mana_oom + 1;
					append = " (" .. UnitMana(u) .. " mana)";
				else
					append = " (" .. floor(UnitMana(u) * 100 / UnitManaMax(u)) .. "%)";
					isbuffed = true;
					if (UnitMana(u) < UnitManaMax(u) * 0.25) then
						fading = fading + UnitMana(u);
					end
				end
			end
			if (needraw) then
				tinsert(raw,
						{
							name = UnitName(u),
							class = RAB_UnitClass(u),
							group = group,
							buffed = isbuffed,
							unit = u,
							append = append
						});
			end
		end
	end
	if (total > 1 and UnitInRaid("player") and needraw) then
		table.sort(raw, function(a, b)
			return a.group < b.group
		end);
	end
	buffed, total = mana_cur, mana_max;

	if (mana_oom > 0 or mana_dead > 0) then
		misc = " (" .. mana_oom .. " oom; " .. mana_dead .. " dead)";
		misc = string.gsub(string.gsub(misc, "; 0 dead", ""), "0 oom; ", "");
	end

	if (needtxt) then
		txt = "Mana: " ..
				mana_cur ..
				" / " ..
				mana_max ..
				" (" ..
				(mana_max > 0 and floor(mana_cur * 100 / mana_max) or "0") ..
				"%); " .. mana_oom .. " oom; " .. mana_dead .. " dead.";
		txt = string.gsub(string.gsub(txt, "; 0 oom", ""), "; 0 dead", "");
		hastxt = txt;
	end
	return buffed, fading, total, misc, txthead, hashead, txt, hastxt, invert, raw, "group", sRAB_Core_GroupFormat;
end

function RAB_QueryWater(userData, needraw, needtxt)
	local buffed, total, misc, txthead, hashead, txt, hastxt, invert, raw, rawsort = 0, 0, "", sRAB_BuffOutput_Water_Out,
	sRAB_BuffOutput_Water_Have, sRAB_BuffOutput_Water_Out .. " ", sRAB_BuffOutput_Water_Have .. " ", false;
	if (needraw) then
		raw = {};
	end

	local isbuffed, append;
	for i, u, group in RAB_GroupMembers(userData) do
		if (UnitIsUnit(u, "player")) then
			RAB_BuffTimers[UnitName(u) .. ".h2oc"] = C_Item.GetItemCount(8079);
		end
		if (RAB_BuffTimers[UnitName(u) .. ".h2oc"] ~= nil) then
			total = total + 1;
			append = " [" .. RAB_BuffTimers[UnitName(u) .. ".h2oc"] .. "]";
			isbuffed = false;
			isbuffed = (RAB_BuffTimers[UnitName(u) .. ".h2oc"] > 3);
			if (needtxt and isbuffed) then
				hastxt = hastxt .. UnitName(u) .. " [" .. RAB_BuffTimers[UnitName(u) .. ".h2oc"] .. "], ";
			elseif (needtxt and not isbuffed) then
				txt = txt .. UnitName(u) .. " [" .. RAB_BuffTimers[UnitName(u) .. ".h2oc"] .. "], ";
			end
			if (isbuffed) then
				buffed = buffed + 1;
			end
			if (needraw) then
				tinsert(raw,
						{
							name = UnitName(u),
							class = RAB_UnitClass(u),
							group = group,
							unit = u,
							append = append,
							buffed = isbuffed
						});
			end
		end
	end
	if (total > 1 and needraw and UnitInRaid("player")) then
		table.sort(raw, function(a, b)
			return a.group < b.group
		end);
	end
	if (needtxt) then
		if (buffed == total) then
			txt = sRAB_BuffOutput_Water_Everyone;
			hastxt = sRAB_BuffOutput_Water_Everyone;
		else
			txt = strsub(txt, 1, -3) .. ".";
			hastxt = strsub(hastxt, 1, -3) .. ".";
		end
	end
	return buffed, 0, total, misc, txthead, hashead, txt, hastxt, invert, raw, rawsort, false;
end


-- Group members carrying a debuff of one dispel type (the bar's ext: Magic, Curse, Poison, Disease) or,
-- for "Curable", any debuff you can remove. Rebuilt on C_UnitAuras' dispel type.
function RAB_QueryDebuff(userData, needraw, needtxt)
	local btype = RAB_Buffs[userData.buffKey].ext;
	local bText = getglobal("sRAB_BuffOutput_Debuff_" .. btype) or btype;

	local buffed, total, misc, txthead, hashead, txt, hastxt, invert, raw = 0, 0, "",
	string.format(sRAB_BuffOutput_Debuff_NotHave, bText), string.format(sRAB_BuffOutput_Debuff_Have, bText), "", "",
	true;
	if (needraw) then
		raw = {};
	end
	local i, u, group, isbuffed;
	for i, u, group in RAB_GroupMembers(userData) do
		if (RAB_IsEligible(u, userData)) then
			total = total + 1;
			isbuffed = RAB_UnitHasDebuffType(u, btype);
			if (needtxt and isbuffed) then
				hastxt = hastxt .. UnitName(u) .. ", ";
			elseif (needtxt and not isbuffed) then
				txt = txt .. UnitName(u) .. ", ";
			end
			if (isbuffed) then
				buffed = buffed + 1;
			end
			if (needraw) then
				tinsert(raw,
						{
							name = UnitName(u),
							class = RAB_UnitClass(u),
							group = group,
							unit = u,
							buffed = isbuffed
						});
			end
		end
	end
	if (total > 1 and UnitInRaid("player") and needraw) then
		table.sort(raw, function(a, b)
			return a.group < b.group
		end);
	end

	if (needtxt) then
		if (buffed == total) then
			txt = string.format(sRAB_BuffOutput_Debuff_Everyone, bText);
			hastxt = txt;
		elseif (buffed > 0) then
			txt = txthead .. " " .. strsub(txt, 1, -3) .. ".";
			hastxt = hashead .. " " .. strsub(hastxt, 1, -3) .. ".";
		else
			txt = string.format(sRAB_BuffOutput_Debuff_NoOne, bText);
			hastxt = txt;
		end
	end
	return buffed, 0, total, misc, txthead, hashead, txt, hastxt, invert, raw, "group", sRAB_Core_GroupFormat;
end

-- Bag and slot of the first stack of itemId, or nil.
function RAB_FindItem(itemId)
	itemId = tonumber(itemId);
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			if (C_Container.GetContainerItemID(bag, slot) == itemId) then
				return bag, slot;
			end
		end
	end
	return nil;
end

-- BLOCK 2: Casting functions

-- Items are counted, cooled down and used by item ID through ClassicAPI (C_Item.GetItemCount,
-- GetItemCooldown, C_Item.UseAtUnit / UseItemByName), so nothing parses bag links and nothing clears the
-- target. Weapon oils and stones still go through UseContainerItem + PickupInventoryItem, which is how the
-- client applies an item to a weapon slot.
function RAB_UseItem(mode, userData)
	local buffData = RAB_Buffs[userData.buffKey];
	local itemId = buffData.itemId
	local itemName = buffData.name
	local itemUseOn = buffData.useOn
	local count = C_Item.GetItemCount(itemId);
	if count == 0 then
		if mode == 'tip' then
			return string.format(sRAB_Tooltip_CastFail_NoItem, itemName)
		end
		RAB_Print(string.format(sRAB_CastingLayer_NoItem, itemName), "warn");
		return false
	end
	if mode == 'tip' then
		if userData.useOnClick ~= true then
			return string.format(sRAB_Tooltip_ClickToUseDisabled, itemName)
		end
		return string.format(sRAB_Tooltip_ClickToUse, itemName)
	end

	local start, duration = GetItemCooldown(itemId);
	if (start ~= nil and start > 0 and duration > 0) then
		RAB_Print(string.format(sRAB_CastingLayer_Cooldown, itemName), "warn");
		return false;
	end

	if userData.useOnClick ~= true then
		return false
	end

	local buffs = {}
	if itemUseOn == 'weapon' or itemUseOn == 'weaponOH' then
		buffs = RAB_CollectPlayerWeaponBuffs(buffData)
		local buffed = RAB_WeaponIsBuffed(buffs, buffData)
		if buffed > 0 then
			return false
		end
	end

	for _, identifier in ipairs(buffData.identifiers) do
		if (isUnitBuffUp("player", identifier)) then
			return false; -- don't use again
		end
	end

	if itemUseOn == 'player' then
		-- spell scroll: used straight on yourself, the target stays as it is
		if (not C_Item.UseAtUnit(itemId, "player")) then
			RAB_Print(sRAB_CastingLayer_NoSession, "warn")
			return false;
		end
	elseif itemUseOn == 'weapon' or itemUseOn == 'weaponOH' then
		local slotName = (itemUseOn == 'weapon') and 'MainHandSlot' or 'SecondaryHandSlot'
		if buffs[slotName] == nil then
			RAB_Print(sRAB_CastingLayer_NoWeapon, "warn")
			return false
		end
		local bag, slot = RAB_FindItem(itemId);
		if (bag == nil) then
			RAB_Print(string.format(sRAB_CastingLayer_NoItem, itemName), "warn");
			return false;
		end
		UseContainerItem(bag, slot);
		if (not SpellIsTargeting()) then
			RAB_Print(sRAB_CastingLayer_NoSession, "warn")
			return false;
		end
		PickupInventoryItem(GetInventorySlotInfo(slotName));
	elseif itemUseOn then
		RAB_Print(string.format('unknown useOn %s', itemUseOn), "warn")
		return false
	else
		-- potion, elixir, food
		C_Item.UseItemByName(itemId);
	end
	RAB_ClearUnitBuffCache("player");
	return true;
end

local function CastFailTip(mode, reason, howmuch)
	if (mode ~= "tip") then
		return false;
	end
	if (reason == "Cooldown") then
		return string.format(sRAB_Tooltip_CastFail_Cooldown, floor(howmuch * 10) / 10);
	end
	return getglobal("sRAB_Tooltip_CastFail_" .. tostring(reason)) or false;
end

function RAB_DefaultCastingHandler(mode, userData)
	local buffData = RAB_Buffs[userData.buffKey];
	local clicktocast = sRAB_Tooltip_ClickToCast;
	if userData.useOnClick ~= true then
		clicktocast = sRAB_Tooltip_ClickToCastDisabled
	end

	if (buffData.grouping ~= RAB_UnitClass("player") or sRAB_SpellNames[userData.buffKey] == nil) then
		return false;
	end
	if (mode == "tip" and RAB_IsBuffUp("player", "druidshift")) then
		return sRAB_Tooltip_CastFail_Shapeshift;
	end

	if (buffData.type == "self" or buffData.type == "aura") then
		local isup = RAB_IsBuffUp("player", userData.buffKey);
		if (RAB_ShouldRecast("player", userData.buffKey, isup)) then
			if userData.useOnClick == true then
				clicktocast = sRAB_Tooltip_ClickToRecast;
			end
		elseif (isup) then
			return false;
		end
		local buff = sRAB_SpellNames[userData.buffKey];
		local canbuff, reason, howmuch = RAB_CastSpell_IsCastable(userData.buffKey, true, true);
		if (not canbuff) then
			return CastFailTip(mode, reason, howmuch);
		end
		if (mode == "tip") then
			return string.format(clicktocast, buff, RAB_Chat_Colors[RAB_UnitClass("player")] .. UnitName("player"));
		elseif (mode == "cast") then
			if userData.useOnClick ~= true then
				return false
			end
			CastSpellByName(buff, true);
			RABui_LastBuffEvent = GetTime()
			RAB_ClearUnitBuffCache("player")
			RAB_Print(string.format(sRAB_CastBuff_CastNeutral, buff));
			return true;
		end
	end

	local dogroupbuff, mygroup = IsAltKeyDown(), 0;
	if (RABui_Settings.castbigbuffs) then
		dogroupbuff = not dogroupbuff;
	end
	if (buffData.bigcast == nil or not RAB_CastSpell_IsCastable(buffData.bigcast, true, true)) then
		dogroupbuff = false;
	end

	local canbuff, reason, howmuch = RAB_CastSpell_IsCastable(userData.buffKey, true, true);
	if (not (canbuff or dogroupbuff)) then
		return CastFailTip(mode, reason, howmuch);
	end

	if (mode == "cast" and userData.useOnClick ~= true) then
		return false
	end

	if (UnitInRaid("player") and RABui_Settings.partymode == true) then
		for i = 1, 40 do
			if (UnitIsUnit("raid" .. i, "player")) then
				_, _, mygroup = GetRaidRosterInfo(i);
				break ;
			end
		end
	end

	-- range is measured with the spell that will be cast (group and single versions share a range)
	local rangeKey = canbuff and userData.buffKey or buffData.bigcast;
	local people, faderenew, pvpfail, rangefail = {}, {}, 0, 0;
	local now = GetTime();
	for i, u, g in RAB_GroupMembers(userData) do
		local pri = UnitIsUnit("player", u) and (buffData.selfPriority ~= nil and buffData.selfPriority or 5) or
				1;
		if (g == mygroup) then
			pri = pri + 1;
		end
		if (RAB_CastLog[u] ~= nil and RAB_CastLog[u] >= now) then
			pri = pri / 10;
		end
		if (buffData.priority ~= nil and buffData.priority[strlower(RAB_UnitClass(u))] ~= nil) then
			pri = pri + buffData.priority[strlower(RAB_UnitClass(u))];
		end
		if (pri > 0 and RAB_IsEligible(u, userData)) then
			if (not RAB_IsSanePvP(u)) then
				pvpfail = pvpfail + 1;
			elseif (not RAB_RangeCheck(u, rangeKey)) then
				if (not RAB_IsBuffUp(u, userData.buffKey)) then
					rangefail = rangefail + 1;
				end
			elseif (not RAB_IsBuffUp(u, userData.buffKey)) then
				tinsert(people, { u = u, group = g, class = RAB_UnitClass(u), p = pri });
			else
				local fading, fadetime = RAB_ShouldRecast(u, userData.buffKey, true);
				if (fading) then
					pri = 10000 - fadetime;
					if (RAB_CastLog[u] ~= nil and RAB_CastLog[u] >= now) then
						pri = pri / 10;
					end
					tinsert(faderenew, { u = u, group = g, class = RAB_UnitClass(u), p = pri })
				end
			end
		end
	end

	if (table.getn(people) == 0 and table.getn(faderenew) == 0) then
		if (mode == "cast") then
			if (pvpfail > 0 or rangefail > 0) then
				UIErrorsFrame:AddMessage(
						string.format(sRAB_CastingLayer_NoCast, buffData.name, pvpfail, rangefail), 1, 0, 0, 1, 1.5);
			else
				UIErrorsFrame:AddMessage(string.format(sRAB_CastingLayer_NoNeed, buffData.name), 1, 0, 0, 1, 1.5);
			end
		end
		return false;
	elseif (table.getn(people) == 0) then
		people = faderenew;
		if userData.useOnClick == true then
			clicktocast = sRAB_Tooltip_ClickToRecast;
		end
	end

	if (dogroupbuff and table.getn(people) < buffData.bigthreshold and not RABui_Settings.alwayscastbigbuffs) then
		dogroupbuff = false;
	end
	if (dogroupbuff) then
		local bsort, bsortkeys, stype = {}, {}, buffData.bigsort;
		for _, val in ipairs(people) do
			if (bsortkeys[val[stype]] == nil) then
				tinsert(bsort, { pri = val.p, cast = val.u, heads = 1, key = val[stype] });
				bsortkeys[val[stype]] = table.getn(bsort);
			else
				local ckey = bsortkeys[val[stype]];
				bsort[ckey].pri, bsort[ckey].heads = bsort[ckey].pri + val.p, bsort[ckey].heads + 1;
			end
		end
		table.sort(bsort, function(a, b)
			return (a.heads == b.heads) and (a.pri > b.pri) or (a.heads > b.heads)
		end);
		if (bsort[1].heads >= buffData.bigthreshold or RABui_Settings.alwayscastbigbuffs) then
			local bname = sRAB_SpellNames[buffData.bigcast];
			local who = RAB_Chat_Colors[RAB_UnitClass(bsort[1].cast)] .. UnitName(bsort[1].cast) .. " [" .. bsort[1].key .. "]";
			if (mode == "cast") then
				if (RAB_CastSpell_AtUnit(buffData.bigcast, bsort[1].cast)) then
					RAB_Print(string.format(sRAB_CastBuff_Cast, bname, who));
					return true;
				end
				-- the group version failed: fall through to the single-target buff
			else
				return string.format(clicktocast, bname, who);
			end
		end
	end

	if (not canbuff) then
		return CastFailTip(mode, reason, howmuch);
	end

	table.sort(people, function(a, b)
		return (a.p > b.p)
	end);
	local bname = sRAB_SpellNames[userData.buffKey] ~= nil and sRAB_SpellNames[userData.buffKey] or buffData.name;
	if (mode == "cast") then
		if (RAB_CastSpell_AtUnit(userData.buffKey, people[1].u)) then
			RAB_Print(string.format(sRAB_CastBuff_Cast, bname,
					RAB_Chat_Colors[RAB_UnitClass(people[1].u)] .. UnitName(people[1].u)));
			return true;
		end
		return false;
	elseif (mode == "tip") then
		return string.format(clicktocast, bname, RAB_Chat_Colors[RAB_UnitClass(people[1].u)] .. UnitName(people[1].u));
	end
	return people;
end

function RAB_CastInventoryItem(mode, userData)
	local buffData = RAB_Buffs[userData.buffKey];
	if (buffData == nil or buffData.ext == nil or RAB_UnitIsDead("player")) then
		return ;
	end
	if (UnitAffectingCombat("player")) then
		return (mode == "tip" and sRAB_Tooltip_CastFail_Combat or nil);
	end
	local _, _, inv, iid = string.find(buffData.ext, "(%d+):(%d+)");
	inv, iid = tonumber(inv), tonumber(iid);

	if (GetInventoryItemID("player", inv) == iid) then
		return nil;
	end

	local iname = GetItemInfo(iid);
	if (iname == nil) then
		iname = string.format(sRAB_BuffOutput_Item_Unknown, iid);
	end
	local b, s = RAB_FindItem(iid);
	if (b == nil) then
		return (mode == "tip" and string.format(sRAB_Tooltip_CastFail_NoItem, iname) or nil);
	end
	if (mode == "tip") then
		return string.format(sRAB_Tooltip_ClickToEquip, iname);
	elseif (mode == "cast") then
		PickupContainerItem(b, s);
		AutoEquipCursorItem();
	end
end

-- Major, Greater, Soulstone, Lesser, Minor: the best stone you carry is used first.
local RAB_SoulstoneItems = { 16896, 16895, 5232, 16893, 16892 };

function RAB_CastSoulstone(mode, userData)
	if (sRAB_SpellNames.ss == nil or RAB_UnitClass("player") ~= "Warlock") then
		return false; -- We don't do this, sorry.
	end

	-- Stage 1: Do we have a stone? (counted by ID, so a stone in the backpack, bag 0, is found too)
	local item;
	for _, id in ipairs(RAB_SoulstoneItems) do
		if (C_Item.GetItemCount(id) > 0) then
			item = id;
			break ;
		end
	end

	if (item == nil) then
		-- We need a stone!
		if (mode == "tip") then
			return string.format(sRAB_Tooltip_ClickToCastNeutral, sRAB_SpellNames.ss);
		elseif (mode == "cast" and RAB_CastSpell_IsCastable("ss")) then
			CastSpellByName(sRAB_SpellNames.ss);
			RAB_Print(string.format(sRAB_CastBuff_CastNeutral, sRAB_SpellNames.ss));
			return true;
		end
		return false;
	end

	local itemName = GetItemInfo(item) or RAB_Buffs.ss.name;
	local start, duration = GetItemCooldown(item);
	if (start ~= nil and start > 0 and duration > 0) then
		if (mode == "cast") then
			RAB_Print(string.format(sRAB_CastingLayer_Cooldown, itemName), "warn");
			return false;
		end
		return string.format(sRAB_Tooltip_CastFail_Cooldown, floor((start + duration - GetTime()) * 10) / 10);
	end

	local buffKey, pri = "ss", 0;
	local maxpri, maxpriunit = 0, "";
	local now = GetTime();
	for i, u, g in RAB_GroupMembers(userData) do
		if (RAB_IsEligible(u, userData) and RAB_IsSanePvP(u) and not RAB_IsBuffUp(u, buffKey)) then
			local inRange = UnitIsUnit("player", u) or C_Item.IsItemInRange(item, u);
			if (inRange == nil) then
				inRange = UnitIsVisible(u);
			end
			if (inRange) then
				pri = UnitIsUnit("player", u) and
						(RAB_Buffs[buffKey].selfPriority ~= nil and RAB_Buffs[buffKey].selfPriority or 5) or 1;
				if (RAB_CastLog[u] ~= nil and RAB_CastLog[u] >= now) then
					pri = pri / 10;
				end
				if (RAB_Buffs[buffKey].priority ~= nil and RAB_Buffs[buffKey].priority[strlower(RAB_UnitClass(u))] ~= nil) then
					pri = pri + RAB_Buffs[buffKey].priority[strlower(RAB_UnitClass(u))];
				end
				if (pri > maxpri) then
					maxpri = pri;
					maxpriunit = u;
				end
			end
		end
	end
	if (maxpri <= 0) then
		return false;
	end
	if (mode == "cast") then
		if (not C_Item.UseAtUnit(item, maxpriunit)) then
			RAB_Print(string.format(sRAB_CastBuff_CouldNotCast, itemName), "warn");
			return false;
		end
		if (not UnitIsUnit("player", maxpriunit)) then
			RAB_CastLog[maxpriunit] = now + 15;
		end
		RAB_ClearUnitBuffCache(maxpriunit);
		RAB_Print(string.format(sRAB_CastBuff_Cast, itemName,
				RAB_Chat_Colors[RAB_UnitClass(maxpriunit)] .. UnitName(maxpriunit)));
		return true;
	end
	return string.format(sRAB_Tooltip_ClickToSoulstone,
			RAB_Chat_Colors[RAB_UnitClass(maxpriunit)] .. UnitName(maxpriunit));
end

function RAB_CastResurrect(mode, userData)
	local res, i, u = strlower(RAB_UnitClass("player")) .. "res";

	if (sRAB_SpellNames[res] == nil) then
		return false;
	end

	local toRes = {}; -- {u="",pri=deci};
	local now = GetTime();
	for i, u, group in RAB_GroupMembers(userData) do
		if (not UnitIsUnit(u, "player") and UnitIsVisible(u) and (RAB_UnitIsDead(u) and not UnitIsGhost(u)) and RAB_IsSanePvP(u) and (RAB_CTRA_IsBeingRessed == nil or not RAB_CTRA_IsBeingRessed(UnitName(u)))) then
			local pri = (RAB_UnitClass(u) == "Priest" and 2 or 0) + (RAB_UnitClass(u) == "Paladin" and 2 or 0) +
					(RAB_UnitClass(u) == "Shaman" and 2 or 0) + (RAB_UnitClass(u) == "Mage" and 1 or 0) +
					(RAB_Versions[UnitName(u)] ~= nil and 0.25 or 0);
			if (RAB_CastLog[u] ~= nil and RAB_CastLog[u] > now) then
				pri = pri / 15;
			end
			tinsert(toRes, { u = u, pri = pri });
		end
	end
	if (table.getn(toRes) == 0) then
		return false;
	elseif (table.getn(toRes) > 1) then
		table.sort(toRes, function(a, b)
			return a.pri > b.pri
		end);
	end

	-- the first one in range; the tooltip falls back to the top of the list when nobody is
	local target;
	for i = 1, table.getn(toRes) do
		if (RAB_RangeCheck(toRes[i].u, res)) then
			target = toRes[i].u;
			break ;
		end
	end

	if (mode == "tip") then
		target = target or toRes[1].u;
		return string.format(sRAB_Tooltip_ClickToCast, sRAB_SpellNames[res],
				RAB_Chat_Colors[RAB_UnitClass(target)] .. UnitName(target));
	end

	if (target == nil) then
		UIErrorsFrame:AddMessage(string.format(sRAB_CastingLayer_NoCast, sRAB_SpellNames[res], 0, table.getn(toRes)), 1, 0, 0, 1, 1.5);
		return false;
	end
	if (RAB_CastSpell_AtUnit(res, target)) then
		RAB_Print(string.format(sRAB_CastBuff_Cast, sRAB_SpellNames[res],
				RAB_Chat_Colors[RAB_UnitClass(target)] .. UnitName(target)));
		RAB_PendingRes[UnitName(target)] = GetTime() + 70;
		return true;
	end
	return false;
end

function RAB_CastWater(mode, userData)
	if (not RAB_CastSpell_IsCastable("water", true, true)) then
		return ; -- Lazy.
	end
	if (mode == "tip") then
		return string.format(sRAB_Tooltip_ClickToCastNeutral, sRAB_SpellNames.water);
	elseif (mode == "cast") then
		CastSpellByName(sRAB_SpellNames.water);
		RAB_Print(string.format(sRAB_CastBuff_CastNeutral, sRAB_SpellNames.water));
	end
end
