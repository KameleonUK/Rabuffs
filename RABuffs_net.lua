-- RABuffs_net.lua
--  Version check over chat/whispers.
-- Version 0.13.0
-- The hourly version channel, the 30 s RAB/BT buff broadcast and the RAB/V addon messages were removed:
-- their receivers had been switched off upstream, and buff timers now come from the auras themselves.

RAB_RequestingVersion = "<RAB> Requesting version.";
RAB_VersionReply_Mask = "<RAB> Version ([%w.]+) V(%d+)[.,](%d+)E";
RAB_VersionReply = "<RAB> Version %s V%sE";
RAB_VersionCheck_RequestsExpire = 0;

function RAB_Chat_VersionCheck()
    if (string.find(arg1, RAB_RequestingVersion) ~= nil) then
        RAB_SendMessage(string.format(RAB_VersionReply, RABuffs_Version, RABuffs_DeciVersion), "WHISPER:" .. arg2);
        if (arg2 ~= UnitName("player")) then
            local checktarget = sRAB_VersionCheck_Requested_You;
            if (event == "CHAT_MSG_RAID") then
                checktarget = sRAB_VersionCheck_Requested_Raid;
            elseif (event == "CHAT_MSG_PARTY") then
                checktarget = sRAB_VersionCheck_Requested_Party;
            elseif (event == "CHAT_MSG_GUILD") then
                checktarget = sRAB_VersionCheck_Requested_Guild;
            end
            RAB_Print(string.format(sRAB_VersionCheck_Requested, arg2, arg2, checktarget));
        end
    end
end

function RAB_Chat_IncomingWhisper()
    if (string.find(arg1, RAB_VersionReply_Mask) ~= nil and RAB_VersionCheck_RequestsExpire > time()) then
        local _, _, display, vers1, vers2 = string.find(arg1, RAB_VersionReply_Mask);
        if (display ~= nil) then
            local version = tonumber(vers1) + tonumber(vers2) / (10 ^ strlen(vers2));
            local out = string.format(sRAB_VersionCheck_Reply, arg2, arg2, display);
            if (version > RABuffs_DeciVersion) then
                RAB_Print(out .. sRAB_VersionCheck_Newer, "warn");
            elseif (version < RABuffs_DeciVersion) then
                RAB_Print(out .. sRAB_VersionCheck_Older, "warn");
            elseif (version == RABuffs_DeciVersion) then
                RAB_Print(out .. sRAB_VersionCheck_Same, "ok");
            end
            RAB_UpdatePeople(arg2, display, version);
        end
    end
end

RAB_Core_Register("CHAT_MSG_GUILD", "versioncheck", RAB_Chat_VersionCheck);
RAB_Core_Register("CHAT_MSG_RAID", "versioncheck", RAB_Chat_VersionCheck);
RAB_Core_Register("CHAT_MSG_RAID_LEADER", "versioncheck", RAB_Chat_VersionCheck);
RAB_Core_Register("CHAT_MSG_PARTY", "versioncheck", RAB_Chat_VersionCheck);
RAB_Core_Register("CHAT_MSG_WHISPER", "versioncheck", RAB_Chat_VersionCheck);
RAB_Core_Register("CHAT_MSG_WHISPER", "incoming", RAB_Chat_IncomingWhisper);
