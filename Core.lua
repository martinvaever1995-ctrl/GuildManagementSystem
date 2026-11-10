-------------------------------------------------------------------------------
--  Core.lua -- namespace, event and message dispatch, saved data, permissions,
--  the audit log and slash commands. Every other module hangs off AF.
-------------------------------------------------------------------------------
local ADDON_NAME, AF = ...
_G.GuildManagementSystem = AF

AF.VERSION = 30400          -- major * 10000 + minor * 100 + patch; bump with ## Version
AF.VERSION_STRING = "3.4.0"
AF.DISCORD = "https://discord.gg/U4UCtfRgmE"
AF.PREFIX = "GuildMgmtSys"  -- addon message prefix (max 16 chars)
AF.PREFIX_BULK = "GuildMgmtSysBk"   -- the slow lane for large data (Comm.lua)

-------------------------------------------------------------------------------
--  Events and internal messages
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local eventHandlers, messageHandlers = {}, {}

local function SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(eventHandlers[event]) do SafeCall(fn, event, ...) end
end)

-- Returns false (and does nothing) for events this client doesn't have.
function AF:RegisterEvent(event, fn)
    if not eventHandlers[event] then
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then return false end
        eventHandlers[event] = {}
    end
    table.insert(eventHandlers[event], fn)
    return true
end

-- Internal messages between modules (e.g. "STANDINGS_UPDATED").
function AF:On(message, fn)
    messageHandlers[message] = messageHandlers[message] or {}
    table.insert(messageHandlers[message], fn)
end

function AF:Fire(message, ...)
    for _, fn in ipairs(messageHandlers[message] or {}) do SafeCall(fn, ...) end
end

-------------------------------------------------------------------------------
--  Output
-------------------------------------------------------------------------------
function AF:Printf(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99GMS|r: " .. fmt:format(...))
end

function AF:Print(text) self:Printf("%s", tostring(text)) end

-------------------------------------------------------------------------------
--  Secret values (Midnight-style restrictions on the Forever client): anything
--  the game hands us during an encounter may be unreadable.
-------------------------------------------------------------------------------
function AF:IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end

-- True while the game is holding back addon actions (combat / encounter lockdown).
function AF:IsRestricted()
    if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive and Enum.AddOnRestrictionType then
        local ok, active = pcall(C_RestrictedActions.IsAddOnRestrictionActive, Enum.AddOnRestrictionType.Combat)
        if ok and active then return true end
    end
    return InCombatLockdown()
end

function AF:IsChatLocked()
    return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() or false
end

-- Runs fn now, or as soon as restrictions lift (polled; cheap and survives missed events).
function AF:WhenUnrestricted(fn)
    if not self:IsRestricted() then return fn() end
    local ticker
    ticker = C_Timer.NewTicker(1, function()
        if not AF:IsRestricted() then
            ticker:Cancel()
            SafeCall(fn)
        end
    end)
end

-------------------------------------------------------------------------------
--  Names. WoW Forever characters have a surname, and the game spells names
--  differently per source:
--    guild roster / addon message senders: "First Surname", "First-Surname",
--      sometimes with "-Realm" after it
--    UnitFullName(unit): first, surname as two values
--    raid roster: can be the first name alone (so we read units instead)
--  Every character gets one key, "First Surname" (own realm stripped, the first
--  dash read as the separator). That is also what whispers are addressed to.
-------------------------------------------------------------------------------
local DASH = 45

-- Our realm without spaces or dashes. GetNormalizedRealmName can be nil early in
-- the login, so fall back to normalizing GetRealmName ourselves.
local function Realm()
    local realm = GetNormalizedRealmName()
    if realm and realm ~= "" then return realm end
    realm = GetRealmName()
    return realm and realm ~= "" and (realm:gsub("[%s%-]", "")) or nil
end

local function Readable(v)
    return type(v) == "string" and v ~= "" and not AF:IsSecret(v)
end

local function StripRealm(name)
    local realm = Realm()
    if not realm then return name end
    local n, r = #name, #realm
    if n > r + 1 and name:byte(n - r) == DASH and name:sub(n - r + 1) == realm then
        return name:sub(1, n - r - 1)
    end
    return name
end

-- The key for a name from any text source.
function AF:FullName(name)
    if not Readable(name) then return nil end
    return (StripRealm(name):gsub("%-", " ", 1))
end

-- The key for a unit.
function AF:UnitFullName(unit)
    local first, second = UnitFullName(unit)
    if not Readable(first) or self:IsSecret(second) then return nil end
    if Readable(second) and second ~= Realm() then return first .. " " .. second end
    return first
end

-- An item ID from a link, "item:12345", a Wowhead address (".../item=12345/...")
-- or a plain number; nil if there's none.
function AF:ItemID(text)
    if type(text) == "number" then return text end
    if type(text) ~= "string" or self:IsSecret(text) then return nil end
    text = text:match("^%s*(.-)%s*$")
    return tonumber(text:match("item[:=](%d+)") or text:match("^%d+$"))
end

-- Keys are already display names ("First Surname").
function AF:ShortName(name)
    return name or "?"
end

-- Whether two names are the same character, allowing one of them to be the
-- first name alone (some raid APIs on Forever give only that).
function AF:SameName(a, b)
    a, b = self:FullName(a), self:FullName(b)
    if not a or not b then return false end
    if a == b then return true end
    local firstA, firstB = a:match("^[^ ]+"), b:match("^[^ ]+")
    return firstA == firstB and (a == firstA or b == firstB)
end

-- Raid/party unit token for a full name, if they are in our group.
function AF:GroupUnit(fullName)
    if self:UnitFullName("player") == fullName then return "player" end
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, GetNumGroupMembers() do
        local unit = prefix .. i
        if self:UnitFullName(unit) == fullName then return unit end
    end
end

-- Full names of everyone in the raid (or party), including us.
function AF:GroupMembers()
    local out = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = self:UnitFullName("raid" .. i)
            if name then table.insert(out, name) end
        end
    else
        table.insert(out, self.playerName)
        for i = 1, GetNumSubgroupMembers() do
            local name = self:UnitFullName("party" .. i)
            if name then table.insert(out, name) end
        end
    end
    return out
end

-------------------------------------------------------------------------------
--  Permissions and loot authority
-------------------------------------------------------------------------------
function AF:IsGM()
    return IsInGuild() and IsGuildLeader() and true or false
end

function AF:RequestRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster()
    elseif GuildRoster then GuildRoster() end
end

-- The master looter's full name, or nil when master loot isn't on (or doesn't exist).
function AF:GetMasterLooter()
    local method, partyML, raidML
    if C_PartyInfo and C_PartyInfo.GetLootMethod then
        method, partyML, raidML = C_PartyInfo.GetLootMethod()
    elseif GetLootMethod then
        method, partyML, raidML = GetLootMethod()
    else
        return nil
    end
    local isMaster = method == "master"
        or (Enum.LootMethod and Enum.LootMethod.Masterlooter ~= nil and method == Enum.LootMethod.Masterlooter)
    if not isMaster then return nil end
    if raidML then return self:UnitFullName("raid" .. raidML) end
    if partyML == 0 then return self.playerName end
    if partyML then return self:UnitFullName("party" .. partyML) end
end

function AF:HasMasterLoot()
    return GiveMasterLoot ~= nil and self:GetMasterLooter() ~= nil
end

-- Who runs loot and attendance for this group: the master looter when master loot
-- is on, otherwise the group leader.
function AF:GetLootAuthority()
    local ml = self:GetMasterLooter()
    if ml then return ml end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if UnitIsGroupLeader("raid" .. i) then return self:UnitFullName("raid" .. i) end
        end
    elseif IsInGroup() then
        if UnitIsGroupLeader("player") then return self.playerName end
        for i = 1, GetNumSubgroupMembers() do
            if UnitIsGroupLeader("party" .. i) then return self:UnitFullName("party" .. i) end
        end
    end
end

function AF:IsLootAuthority()
    return self:GetLootAuthority() == self.playerName
end

-------------------------------------------------------------------------------
--  Startup
-------------------------------------------------------------------------------
AF.modules = {}

function AF:NewModule(name)
    local module = {}
    self[name] = module
    table.insert(self.modules, module)
    return module
end

-------------------------------------------------------------------------------
--  Saved data. Every guild gets its own compartment, so characters in two guilds
--  never mix their guilds' ledgers, rules or lists:
--    GuildManagementSystemDB = {
--        account = { prefs, ui, characters, main, ... },   -- the whole WoW account
--        guilds = { ["Guild-Realm"] = { events, config, snapshot, ... } },
--        chars = { ["Name-Realm"] = "Guild-Realm" },        -- each character's guild, last seen
--    }
--  AF.db reads and writes the account keys in `account` and everything else in
--  the current guild's compartment. The guild is only certain a moment after
--  login; a character's first login (or a guild change) may need one reload.
-------------------------------------------------------------------------------
local ACCOUNT_KEYS = { prefs = true, ui = true, characters = true, main = true, mainChosenAt = true, linkAcked = true }
local PENDING, NO_GUILD = "?", "-"
local saved, guildKey

local function CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

local function Bucket(key)
    saved.guilds[key] = saved.guilds[key] or {}
    return saved.guilds[key]
end

local function UseGuild(key)
    guildKey = key
    local account, bucket = saved.account, Bucket(key)
    AF.db = setmetatable({}, {
        __index = function(_, k) return (ACCOUNT_KEYS[k] and account or bucket)[k] end,
        __newindex = function(_, k, v) (ACCOUNT_KEYS[k] and account or bucket)[k] = v end,
    })
    bucket.log, bucket.breakdown, bucket.won, bucket.bossAwards, bucket.lastDecay = nil, nil, nil, nil, nil  -- v1 leftovers
    bucket.recruits = nil           -- recruiting was removed
    bucket.bench = bucket.bench or {}
end

-- The guild the game says we're in now: "Guild-Realm", NO_GUILD, or nil while unknown.
local function CurrentGuildKey()
    if not IsInGuild() then return nil end
    local guild = GetGuildInfo("player")
    if not guild or guild == "" then return nil end
    return guild .. "-" .. (GetRealmName() or "?")
end

-- AdventForever's saved data (its last version only keeps it around for us),
-- moved into this guild's compartment once.
local function MigrateAdventForever(key)
    local old = _G.AdventForeverDB
    if saved.migrated or type(old) ~= "table" or next(old) == nil then return false end
    saved.migrated = true
    local bucket = Bucket(key)
    if next(bucket) ~= nil and bucket.events then return false end     -- this guild already has data
    for k, v in pairs(old) do
        if ACCOUNT_KEYS[k] then
            if saved.account[k] == nil then saved.account[k] = v end
        else
            bucket[k] = v
        end
    end
    -- AdventForever had guild loot on and no setup: keep it that way.
    if type(bucket.config) == "table" then
        bucket.config.features = { guildLoot = true }
        bucket.config.setupDone = true
    end
    return true
end

StaticPopupDialogs.GMS_RELOAD = {
    text = "Guild Management System has loaded the data for %s.\nReload your interface to use it.",
    button1 = RELOADUI or "Reload",
    button2 = LATER or "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Once the game knows our guild: switch compartments if it changed.
local guildChecks = 0
local function CheckGuild()
    local key = CurrentGuildKey()
    if not key then
        guildChecks = guildChecks + 1
        if IsInGuild() and guildChecks < 30 then return C_Timer.After(1, CheckGuild) end
        if IsInGuild() then return end
        key = NO_GUILD
    end
    saved.chars[CharKey()] = key
    local migrated = key ~= NO_GUILD and MigrateAdventForever(key)
    if key == guildKey and not migrated then return end
    if guildKey == PENDING and not migrated and not saved.guilds[key] then
        -- First time for this guild: what we gathered so far simply becomes its data.
        saved.guilds[key] = saved.guilds[PENDING]
        saved.guilds[PENDING] = nil
        guildKey = key
        return
    end
    if migrated then AF:Print("Your AdventForever data was moved into Guild Management System.") end
    StaticPopup_Show("GMS_RELOAD", key == NO_GUILD and "no guild" or (GetGuildInfo("player") or key))
end

AF:RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= ADDON_NAME then return end
    GuildManagementSystemDB = GuildManagementSystemDB or {}
    saved = GuildManagementSystemDB
    saved.account = saved.account or {}
    saved.guilds = saved.guilds or {}
    saved.chars = saved.chars or {}
    saved.guilds[PENDING] = nil      -- never carried over from a session that didn't finish
    UseGuild(saved.chars[CharKey()] or PENDING)
    for _, module in ipairs(AF.modules) do
        if module.Init then SafeCall(module.Init, module) end
    end
end)

AF:RegisterEvent("PLAYER_LOGIN", function() C_Timer.After(2, CheckGuild) end)

AF:RegisterEvent("PLAYER_LOGIN", function()
    AF.playerName = AF:UnitFullName("player")
    for _, module in ipairs(AF.modules) do
        if module.Enable then SafeCall(module.Enable, module) end
    end
end)

-- The realm can still be missing at PLAYER_LOGIN; by now the game knows it.
AF:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    local name = AF:UnitFullName("player")
    if name and name ~= AF.playerName then
        AF.playerName = name
        AF:RequestRoster()
    end
end)

-- What the addon thinks of you; for when officer checks or names look wrong.
-- Returns the lines; /gms debug prints them and /gms selftest includes them.
function AF:DebugLines()
    local lines = {}
    local function Add(fmt, ...) table.insert(lines, fmt:format(...)) end
    local _, rankName, rankIndex = GetGuildInfo("player")
    local member = self.Standings:All()[self.playerName]
    local count = 0
    for _ in pairs(self.Standings:All()) do count = count + 1 end
    Add("You: %s | realm: %s / %s", tostring(self.playerName), tostring(GetNormalizedRealmName()), tostring(GetRealmName()))
    local prefs = self.db.prefs
    Add("Look: saved %s | loaded %s | EllesmereUI: %s", tostring(prefs and prefs.style or "modern"),
        self.Theme.IsClassic() and "classic" or "modern", EllesmereUI and "yes" or "no")
    Add("Guild window tab: %s", self.UI.GuildTabStatus())
    local layerMap, layerId, layerZone = self.Layers:Own()
    Add("Layer: %s, map %s, ID %s | guild members known: %d", tostring(layerZone), tostring(layerMap),
        tostring(layerId), #self.Layers:List())
    Add("Guild rank: %s (index %s) | GM: %s | officer ranks 0-%d",
        tostring(rankName), tostring(rankIndex), tostring(self:IsGM()), self.Config:Get("officerRank"))
    local guildRaid, canRoll, rollLines = self.GuildLoot.Status()
    Add("Guild loot: guild raid now: %s | can roll by addon: %s | roll lines understood: %d of 3",
        guildRaid and "yes" or "no", canRoll and "yes" or "NO", rollLines)
    local h = self.Honor.ApiReport()
    Add("Honor: this week %d (from %s) | weekly stats: %s | honor currency: %s | inspect honor: %s (event: %s)",
        h.honor, h.source, h.weeklyStats and "yes" or "no", tostring(h.currency),
        h.inspect and "YES" or "no", tostring(h.inspectEvent))
    local craftApi, craftWindow, myRecipes, crafters = self.Professions.ApiReport()
    Add("Professions: recipe API %s | enchanting window API: %s | your recipes: %d | characters known: %d",
        craftApi, craftWindow and "yes" or "no", myRecipes, crafters)
    local logApi, saved = self.History.ApiReport()
    Add("Guild event log: %s | events saved: %d", logApi and "yes" or "NO (no member history)", saved)
    local whoApi, inviteApi, canInvite = self.Recruiter.ApiReport()
    Add("Recruiter (not released yet): /who API: %s | guild invite API: %s | your rank may invite: %s",
        whoApi and "yes" or "NO", inviteApi and "yes" or "NO", canInvite and "yes" or "no")
    local bankApi, interaction, pendingDeposits = self.Bank.ApiReport()
    Add("Guild bank API: %s | bank window event: %s | your unconfirmed deposit reports: %d",
        bankApi, interaction and "interaction manager" or "GUILDBANKFRAME", pendingDeposits)
    Add("Roster: %d members | you found in roster: %s | officer: %s",
        count, member and ("yes, rank " .. member.rankIndex) or "NO", tostring(self.Ledger:CanRecord()))
    if not member then
        local sample = next(self.Standings:All())
        Add("Example roster name: %s", tostring(sample))
    end
    return lines
end

function AF:Debug()
    for _, line in ipairs(self:DebugLines()) do self:Print(line) end
end

-------------------------------------------------------------------------------
--  Slash commands
-------------------------------------------------------------------------------
local HELP = {
    "/gms - main window (Effort, Me, Rules, Loot, Log, Bank and Options tabs)",
    "/gms history - who won what, by item or by player (Loot tab, officers)",
    "/gms trades - items you have to trade to a winner, and items coming to you",
    "/gms nudge - show the login summary again (turn it off in the Me tab)",
    "/gms main - make this character your main (your other characters on this account become its alts)",
    "/gms link <alt> <main>, /gms unlink <name> - link characters by hand, e.g. across accounts (officers)",
    "/gms me - your own effort, split by category, and what's left this week",
    "/gms rules - how effort is scored, with the guild's current numbers",
    "/gms loot - loot window (master looter / raid leader)",
    "/gms item <shift-click item> - start a loot session for an item by hand",
    "/gms adjust <name> <raid|bank|honor|dungeon> <+/-points> [reason] - correct this week's points in a category (officers)",
    "/gms log - ledger events (Log tab, officers)",
    "/gms bank - guild bank rules and the wanted list (Bank tab)",
    "/gms setup - guild setup: officer ranks, what counts as effort, which features are on (officers edit)",
    "/gms invite - raid invites: everyone online at chosen ranks / minimum effort, and guildies who whisper a keyword",
    "/gms settings - this addon's page in the game's settings (minimap button, login summary)",
    "/gms style modern|classic - the flat GMS look or the game's own Blizzard style (reloads)",
    "/gms scale 70-130 - window size in percent (100 is normal)",
    "/gms welcome - the short guide to what GMS does",
    "/gms discord - need help or found a bug? The link to our Discord",
    "/gms minimap - show or hide the minimap button (left-click opens, right-click for a menu, drag to move)",
    "/gms attune - who in the guild is attuned to which raid (officers add or remove attunements there)",
    "/gms layers - which layer guild members are on, and who to whisper for an invite",
    "/gms analytics (or /gms stats) - the guild in numbers: classes, levels, ranks, professions, attunements, effort",
    "/gms crafters [item] - who in the guild can craft something; without a search, everyone's professions",
    "/gms wish [shift-click item] - your wishlist (up to 10 items, ranked; only officers see it), or add an item to it",
    "/gms bench add|remove <name>, /gms bench list|clear - players on your bench get credit for guild kills you record (officers)",
    "/gms kill <boss> - record a guild kill for your group by hand, if the game hid it (officers)",
    "/gms final - mark (or unmark) the dungeon boss you just killed as the dungeon's final boss (officers)",
    "/gms test [shift-click item] - try the loot popup and loot window alone (nothing is sent)",
    "/gms versions (or /gms check) - who in your group has the addon and which version, with durability, flasks / elixirs and range",
    "/gms options - effort rules (officers edit, everyone can view); /gms config prints them",
    "/gms export, /gms import - copy the ledger out as text / merge a copy back in (officers)",
    "/gms export web - the archive and this ledger as JSON for a website or Discord bot (officers)",
    "/gms archive - weeks kept after they leave the ledger; /gms archive test checks it now (officers)",
    "/gms debug - what the addon can see on this client",
    "/gms selftest - a report to copy and send us when something looks wrong",
}

-- Finds a guild member's full name from what the user typed ("bob" -> "Bob-Realm").
-- Typing the first name is enough when only one guild member has it.
-- Returns the key, or nil plus a message.
function AF:ResolveName(input)
    local wanted = self:FullName(input)
    if not wanted then return nil, "Type a name." end
    wanted = wanted:lower()
    local matches = {}
    for key in pairs(self.Standings:All()) do
        if key:lower() == wanted then return key end
        if key:lower():match("^[^ ]+") == wanted then table.insert(matches, key) end
    end
    if #matches == 1 then return matches[1] end
    if #matches > 1 then
        table.sort(matches)
        return nil, ("More than one %s: %s. Type it as First-Surname."):format(input, table.concat(matches, ", "))
    end
    return nil, input .. " is not in the guild."
end

local function NeedOfficer()
    if AF.Ledger:CanRecord() then return true end
    AF:Print("Only officers can do that (ranks set in /gms options).")
    return false
end

local commands = {}

commands.help = function()
    for _, line in ipairs(HELP) do AF:Print((line:gsub("|", "||"))) end   -- a bare | starts a chat code
end

commands.loot = function() AF.UI:ToggleLootWindow() end

commands.item = function(args)
    local links = {}
    for link in args:gmatch("|c[^|]*|Hitem:.-|h|r") do table.insert(links, link) end
    if #links == 0 then return AF:Print("Usage: /gms item <shift-click one or more items>") end
    AF.Loot:StartSessions(links)
end

commands.adjust = function(args)
    if not NeedOfficer() then return end
    local who, category, points, reason = args:match("^(%S+)%s+(%a+)%s+([%+%-]?%d+)%s*(.*)$")
    category = category and category:lower()
    if not who or not AF.Standings.CATEGORY_TEXT[category] then
        return AF:Print("Usage: /gms adjust <name> <raid||bank||honor||dungeon> <+/- points this week> [reason]  (0 removes the correction)")
    end
    local name, err = AF:ResolveName(who)
    if not name then return AF:Print(err) end
    name = AF.Standings:MainOf(name)     -- corrections belong to the player, i.e. their main
    local cap = AF.Config:Get(category .. "Max")
    points = math.max(-cap, math.min(cap, tonumber(points)))
    if AF.Ledger:SetCategory(name, category, points, reason ~= "" and reason or "manual") then
        local b = AF.Ledger:Breakdown(AF.Standings.CurrentWeek(), name) or {}
        AF:Printf("%s: %s correction %+d this week, %s now %d.", AF:ShortName(name), category, points,
            category, b[category] or 0)
    end
end

commands.bench = function(args)
    local action, who = args:match("^(%S*)%s*(.-)$")
    action = action:lower()
    local bench = AF.db.bench
    if action == "add" or action == "remove" then
        local name, err = AF:ResolveName(who)
        if not name then return AF:Print(err) end
        bench[name] = action == "add" or nil
        AF:Printf("%s %s the bench.", AF:ShortName(name), action == "add" and "added to" or "removed from")
    elseif action == "clear" then
        wipe(bench)
        AF:Print("Bench cleared.")
    else
        local names = {}
        for name in pairs(bench) do table.insert(names, AF:ShortName(name)) end
        table.sort(names)
        AF:Printf("Bench (%d): %s", #names, #names > 0 and table.concat(names, ", ") or "empty")
    end
end

commands.log = function() AF.UI:ShowLog() end
commands.bank = function() AF.UI:ShowBank() end
commands.me = function() AF.UI:ShowMe() end
commands.history = function() AF.UI:ShowLootHistory() end

commands.main = function() AF.Alts:SetMain() end
commands.trades = function() AF.UI:ToggleTrades() end
commands.nudge = function()
    if not AF.UI:ShowNudge() then AF:Print("No numbers yet: wait until an officer is online (or the ledger has synced).") end
end

commands.link = function(args)
    local altInput, mainInput = args:match("^(%S+)%s+(%S+)$")
    if not altInput then return AF:Print("Usage: /gms link <alt> <main>") end
    local alt, err = AF:ResolveName(altInput)
    if not alt then return AF:Print(err) end
    local main, err2 = AF:ResolveName(mainInput)
    if not main then return AF:Print(err2) end
    AF.Alts:OfficerLink(alt, main)
end

commands.unlink = function(args)
    local name, err = AF:ResolveName(args)
    if not name then return AF:Print(err) end
    AF.Alts:OfficerLink(name, name)
end
commands.rules = function() AF.UI:ShowRules() end
commands.attune = function() AF.UI:ShowAttunements() end
commands.layers = function() AF.UI:ShowLayers() end
commands.analytics = function() AF.UI:ShowAnalytics() end
commands.stats = commands.analytics
commands.layer = commands.layers
commands.invite = function() AF.UI:ShowInvites() end
commands.setup = function() AF.UI:ShowSetup() end
commands.settings = function() AF.UI:OpenSettings() end
commands.scale = function(args)
    local percent = tonumber(args and args:match("%d+"))
    if not percent then
        return AF:Printf("Window size: %d%%. /gms scale 70-130 changes it.", AF.Theme.Scale() * 100 + 0.5)
    end
    AF:Printf("Window size: %d%%.", AF.Theme.SetScale(percent / 100) * 100 + 0.5)
end
commands.style = function(args) AF.UI:SetStyle(args:lower()) end
commands.welcome = function() AF.UI:ShowWelcome() end
commands.discord = function() AF.UI:ShowHelp() end
commands.bug = commands.discord
commands.minimap = function() AF.UI:ToggleMinimap() end
commands.crafters = function(args)
    AF.UI:ShowCrafters()
    if args ~= "" then AF.UI:SearchCrafters(args) end
end
commands.wish = function(args)
    if args == "" then return AF.UI:ShowWishlist() end
    local rank, err = AF.Wishlist:Add(args)
    if not rank then return AF:Print(err) end
    AF:Printf("Added to your wishlist at #%d.", rank)
end
commands.kill = function(args) AF.Attendance:Manual(args) end
commands.final = function() AF.Dungeons:ToggleFinal() end

commands.debug = function() AF:Debug() end

-- Everything an officer can send us when something looks wrong. Reads only.
local function Ago(seconds)
    if seconds < 3600 then return ("%d min"):format(seconds / 60) end
    if seconds < 172800 then return ("%.1f h"):format(seconds / 3600) end
    return ("%.1f days"):format(seconds / 86400)
end

local function Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

function AF:Selftest()
    local lines = {}
    local function Add(fmt, ...) table.insert(lines, fmt:format(...)) end
    Add("GMS selftest %s, %s", self.VERSION_STRING, date("%Y-%m-%d %H:%M"))
    local _, build, _, interface = GetBuildInfo()
    Add("Client: %s (interface %s) | look: %s", tostring(build), tostring(interface), self.Theme.IsClassic() and "classic" or "modern")

    local guild, rankName, rankIndex = GetGuildInfo("player")
    local officer = self.Ledger:CanRecord()
    Add("Guild: %s | rank: %s (index %s) | GM: %s | officer ranks 0-%d | officer: %s", tostring(guild), tostring(rankName),
        tostring(rankIndex), tostring(self:IsGM()), self.Config:Get("officerRank"), tostring(officer))

    local features = {}
    for _, f in ipairs(self.Config.FEATURES) do
        table.insert(features, f.key .. (self.Config:Feature(f.key) and " on" or " off"))
    end
    Add("Config: v%d | setup done: %s | caps: raid %d, bank %d, honor %d, dungeon %d", self.Config:Raw("version") or 0,
        tostring(self.Config:Raw("setupDone")), self.Config:Get("raidMax"), self.Config:Get("bankMax"),
        self.Config:Get("honorMax"), self.Config:Get("dungeonMax"))
    Add("Features: %s", table.concat(features, ", "))

    local byWeek, total, voids = self.Ledger:CountsByWeek()
    local current = self.Standings.CurrentWeek()
    local weeks = {}
    local oldest = current
    for w in pairs(byWeek) do oldest = math.min(oldest, w) end
    for w = current + 1, oldest, -1 do
        if byWeek[w] then table.insert(weeks, ("%s: %d"):format(w == current and "this week" or tostring(w - current), byWeek[w])) end
    end
    Add("Ledger: %d events, %d removals | week %d | by week: %s", total, voids, current,
        #weeks > 0 and table.concat(weeks, ", ") or "none")

    local archived, oldestArchived = self.Archive:Summary()
    Add("Archive: %d weeks%s", archived, oldestArchived and (" | oldest: %d weeks ago"):format(current - oldestArchived) or "")

    local by, at = self.Standings:SnapshotInfo()
    if at then
        Add("Snapshot: from %s, %s ago", tostring(by), Ago(math.max(0, GetServerTime() - at)))
    else
        Add("Snapshot: none")
    end

    local honor, acked = self.Honor.Pending()
    Add("Waiting for an officer: deposits %d | dungeon runs %d | kill reports %d | honor %s | main link: %s",
        Count(self.db.pendingDeposits), Count(self.db.pendingRuns), Count(self.db.pendingKills),
        honor and ("%d (confirmed %d)"):format(honor, acked) or "?", self.Alts:LinkStatus())

    table.insert(lines, "--- /gms debug")
    for _, line in ipairs(self:DebugLines()) do table.insert(lines, line) end
    return lines, total
end

commands.selftest = function()
    local lines, total = AF:Selftest()
    for i = 1, 3 do AF:Print(lines[i]) end
    AF.UI:ShowTextWindow("GMS selftest", ("%d lines, %d ledger events. Press Ctrl+A, Ctrl+C and paste it to the GMS Discord (/gms discord)."):format(
        #lines, total), table.concat(lines, "\n"))
end

commands.test = function(args)
    AF.Loot:StartTest(args:match("|c[^|]*|Hitem:.-|h|r"))
end

commands.versions = function() AF.UI:ShowVersions() end
commands.check = commands.versions
commands.config = function() AF.Config:PrintConfig() end
commands.options = function() AF.UI:ToggleOptions() end

commands.export = function(args)
    if not NeedOfficer() then return end
    if args:lower() == "web" then
        local text, weeks = AF.Archive:WebExport()
        return AF.UI:ShowTextWindow("Web export", ("%d weeks as JSON for a website or Discord bot (docs/EXPORT.md). Ctrl+A, Ctrl+C."):format(weeks), text)
    end
    local text, count = AF.Ledger:Export()
    AF.UI:ShowTextWindow("Ledger export", ("%d events. Press Ctrl+A, Ctrl+C and save it somewhere outside the game."):format(count), text)
end

commands.archive = function(args)
    if not NeedOfficer() then return end
    if args:lower() == "test" then return AF.Archive:Test() end
    AF.Archive:PrintStatus()
end

commands.import = function()
    if not NeedOfficer() then return end
    AF.UI:ShowTextWindow("Ledger import", "Paste an export (Ctrl+V), then click Import. Events you already have are skipped.", "",
        function(text)
            local added, err = AF.Ledger:Import(text)
            if not added then return AF:Print(err) end
            AF:Printf("Imported %d new events.", added)
        end)
end

SLASH_GMS1 = "/gms"
SLASH_GMS2 = "/guildmanagement"
SlashCmdList.GMS = function(input)
    local cmd, args = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "" then return AF.UI:ToggleStandings() end
    local fn = commands[cmd]
    if fn then fn(args) else commands.help() end
end
