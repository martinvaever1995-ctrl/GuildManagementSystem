-------------------------------------------------------------------------------
--  AdventForever is now Guild Management System (GMS).
--
--  This last version does nothing but load its saved data (AdventForeverDB), so
--  that GMS can move it over the first time it starts. Once GMS has done that,
--  AdventForever can be removed. GMS downloads include this folder for a while,
--  so updating from AdventForever to GMS keeps the data.
-------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    C_Timer.After(8, function()
        local text
        if GuildManagementSystemDB and GuildManagementSystemDB.migrated then
            text = "your data is now in Guild Management System. You can remove AdventForever."
        elseif not GuildManagementSystem then
            text = "AdventForever is now Guild Management System (GMS). Install GMS from CurseForge or Wago; keep AdventForever installed until your first login with GMS, which moves your data over."
        end
        if text then DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AdventForever|r: " .. text) end
    end)
end)
