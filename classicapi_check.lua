-- First file in RABuffs_ClassicAPI.toc.
-- ClassicAPI selects that TOC, so the DLL is loaded; this checks the DLL is new enough to provide
-- every function the addon calls. If anything is missing, the addon's entry points return early
-- (they check RABUFFS_CLASSICAPI_MISSING) instead of erroring mid-use.
-- Keep REQUIRED in sync with the code: grep the addon for C_ namespaces and other ClassicAPI globals.

local REQUIRED = {
	'C_UnitAuras.UnitAura',
	'C_UnitAuras.GetAuraDataBySpellName',
	'GetSpellInfo',
	'IsUsableSpell',
	'C_Spell.GetSpellCooldown',
	'C_Spell.CastAtUnit',
	'C_Spell.IsSpellInRange',
	'FindSpellBookSlotByID',
	'C_Item.GetItemCount',
	'C_Item.UseAtUnit',
	'C_Item.UseItemByName',
	'C_Item.IsItemInRange',
	'GetInventoryItemID',
	'C_Container.GetContainerItemID',
	'GetItemCooldown',
	'UnitIsFeignDeath',
	'hooksecurefunc',
	'InterfaceOptions_AddCategory',
	'InterfaceOptionsFrame_OpenToCategory',
}

local function resolve(path)
	local value = getfenv(0)
	for part in string.gfind(path, '[^%.]+') do
		if type(value) ~= 'table' then return nil end
		value = value[part]
	end
	return value
end

local missing = {}
if not CLASSIC_API_VERSION then
	tinsert(missing, 'CLASSIC_API_VERSION')
end
for _, path in ipairs(REQUIRED) do
	if type(resolve(path)) ~= 'function' then
		tinsert(missing, path)
	end
end

if getn(missing) > 0 then
	RABUFFS_CLASSICAPI_MISSING = missing
	local f = CreateFrame('Frame')
	f:RegisterEvent('PLAYER_LOGIN')
	f:SetScript('OnEvent', function()
		DEFAULT_CHAT_FRAME:AddMessage('|cffff4040RABuffs: your ClassicAPI is too old. Missing: '
			.. table.concat(missing, ', ') .. '. The addon is disabled.|r')
		if RABFrame then RABFrame:Hide() end
		this:UnregisterAllEvents()
	end)
end
