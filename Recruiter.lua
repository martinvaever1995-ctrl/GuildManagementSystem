-------------------------------------------------------------------------------
--  Recruiter.lua -- finding guildless players and contacting them, one click
--  per step: the game only allows /who searches and guild invites from a click
--  or key press, and one whisper per click keeps it polite.
--
--  Saved per guild (AF.db.recruit):
--    contacted = { [name] = { t = server time, by = recruiter } }  kept KEEP_DAYS
--    blocked   = { [name] = { t = server time, by = recruiter } }  kept for good
--    filters   = { min, max, class (class file or nil), zone, guildless }
--    template  = index into the guild's templates; mode = "whisper" | "both" | "invite"
--  The whisper templates are guild-wide, in the shared config
--  (config.recruit = { { n = name, t = text }, ... }, officers edit).
--
--  Recruiters tell each other whom they contacted or blocked (REC, guild), so
--  two recruiters don't whisper the same player. A recruiter who logs in asks
--  for both lists (RECQ); others answer with theirs (REC list, whispered, bulk).
-------------------------------------------------------------------------------
local _, AF = ...
local Recruiter = AF:NewModule("Recruiter")

local KEEP_DAYS = 14            -- a contacted player is skipped this long
local GAP = 3                   -- seconds between two contacts
local STEP = 5                  -- levels per /who search (a search returns at most 50)
local MAX_REPLIES = 20
local LIST_DELAY = 40           -- seconds after login a recruiter asks for the lists
local WHO_WAIT = 10             -- seconds to wait for /who results
Recruiter.MAX_TEMPLATES = 5
Recruiter.MODES = { "whisper", "both", "invite" }
Recruiter.MODE_TEXT = { whisper = "Whisper", both = "Whisper + invite", invite = "Invite only" }

local results = {}              -- this session's search results, in order: { name, level, class, file, zone, race, done }
local byName = {}
local replies = {}              -- whispers back from contacted players, newest first
local queue = {}                -- level ranges still to search
local lastContact = 0
local waiting                   -- the level range of the /who we're waiting for

local function Store()
    local db = AF.db
    if type(db.recruit) ~= "table" then db.recruit = {} end
    local r = db.recruit
    if type(r.contacted) ~= "table" then r.contacted = {} end
    if type(r.blocked) ~= "table" then r.blocked = {} end
    if type(r.filters) ~= "table" then r.filters = {} end
    local f = r.filters
    f.min = tonumber(f.min) or 10
    f.max = tonumber(f.max) or 60
    if f.guildless == nil then f.guildless = true end
    if not Recruiter.MODE_TEXT[r.mode] then r.mode = "whisper" end
    r.template = tonumber(r.template) or 1
    return r
end

function Recruiter:Settings() return Store() end

-- Whether this character may recruit: the feature is on and the guild lets it invite.
-- (The recruiter isn't released yet: without its guild setup switch this is always false.)
function Recruiter:CanUse()
    if not AF.Config:Feature("recruiter") or not IsInGuild() then return false end
    return CanGuildInvite and CanGuildInvite() and true or false
end

local function ClassName(file)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file]) or file
end
Recruiter.ClassName = ClassName

-------------------------------------------------------------------------------
--  Who is who
-------------------------------------------------------------------------------
local function Recent(entry)
    return entry and type(entry.t) == "number" and GetServerTime() - entry.t < KEEP_DAYS * 86400
end

-- "new", "contacted" (by anyone, in the last KEEP_DAYS), "blocked" or "member".
function Recruiter:Status(name)
    local r = Store()
    if r.blocked[name] then return "blocked" end
    if AF.Standings:All()[name] then return "member" end
    if Recent(r.contacted[name]) then return "contacted" end
    return "new"
end

function Recruiter:Results() return results end
function Recruiter:Replies() return replies end

-- Whether the guild is looking for this class (officers set it in Analytics).
function Recruiter.Needed(classFile)
    return classFile and (AF.Config:Get("needs")[classFile] or 0) > 0 or false
end

-- The next player to contact, classes the guild needs first; or nil.
function Recruiter:NextCandidate()
    local first
    for _, p in ipairs(results) do
        if self:Status(p.name) == "new" then
            if Recruiter.Needed(p.file) then return p end
            first = first or p
        end
    end
    return first
end

-------------------------------------------------------------------------------
--  Searching (/who)
-------------------------------------------------------------------------------
local function BuildQueue()
    wipe(queue)
    local f = Store().filters
    local low = math.max(1, math.floor(f.min))
    local high = math.max(low, math.floor(f.max))
    for from = low, high, STEP do table.insert(queue, { from, math.min(from + STEP - 1, high) }) end
end

-- The level range the next search covers.
function Recruiter:NextRange()
    if #queue == 0 then BuildQueue() end
    return queue[1]
end

-- Filters changed: start the level ranges again.
function Recruiter:SetFilters(min, max, class, zone, guildless)
    local f = Store().filters
    f.min, f.max = math.max(1, tonumber(min) or f.min), math.max(1, tonumber(max) or f.max)
    if f.max < f.min then f.min, f.max = f.max, f.min end
    f.class = class
    f.zone = zone and zone:match("^%s*(.-)%s*$") or nil
    if f.zone == "" then f.zone = nil end
    if guildless ~= nil then f.guildless = guildless end
    wipe(queue)
    AF:Fire("RECRUIT_UPDATED")
end

local function DoWho(text)
    if C_FriendList and C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, true)
    elseif SetWhoToUI then pcall(SetWhoToUI, 1) end
    -- Keep the game's Who window shut: we read the results ourselves.
    if FriendsFrame then FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE") end
    if C_FriendList and C_FriendList.SendWho then return pcall(C_FriendList.SendWho, text) end
    if _G.SendWho then return pcall(_G.SendWho, text) end
    return false
end

-- One /who for the next level range. Call it from a click or a key press.
function Recruiter:Search()
    if not self:CanUse() then return AF:Print("Recruiting needs the Recruiter feature (guild setup) and a rank that may invite.") end
    local range = self:NextRange()
    table.remove(queue, 1)
    local f = Store().filters
    local parts = { ("%d-%d"):format(range[1], range[2]) }
    if f.class then table.insert(parts, ('c-"%s"'):format(ClassName(f.class))) end
    if f.zone then table.insert(parts, ('z-"%s"'):format(f.zone)) end
    waiting = range
    if not DoWho(table.concat(parts, " ")) then
        waiting = nil
        if FriendsFrame then FriendsFrame:RegisterEvent("WHO_LIST_UPDATE") end
        return AF:Print("This client doesn't let addons search with /who.")
    end
    -- No answer (throttled): give the Who window its event back.
    C_Timer.After(WHO_WAIT, function()
        if waiting ~= range then return end
        waiting = nil
        if FriendsFrame then FriendsFrame:RegisterEvent("WHO_LIST_UPDATE") end
        AF:Print("Recruiter: the search got no answer (searching too fast?). Try again in a few seconds.")
        AF:Fire("RECRUIT_UPDATED")
    end)
    AF:Fire("RECRUIT_UPDATED")
end

function Recruiter:Searching() return waiting ~= nil end

local function WhoResults()
    local out = {}
    local count = (C_FriendList and C_FriendList.GetNumWhoResults and C_FriendList.GetNumWhoResults())
        or (GetNumWhoResults and GetNumWhoResults()) or 0
    for i = 1, count do
        local name, guild, level, race, class, zone, file
        if C_FriendList and C_FriendList.GetWhoInfo then
            local info = C_FriendList.GetWhoInfo(i)
            if type(info) == "table" then
                name, guild, level, race, class, zone, file = info.fullName, info.fullGuildName, info.level,
                    info.raceStr, info.classStr, info.area, info.filename
            end
        elseif GetWhoInfo then
            name, guild, level, race, class, zone, file = GetWhoInfo(i)
        end
        if type(name) == "string" and not AF:IsSecret(name) then
            table.insert(out, { name = AF:FullName(name), guild = not AF:IsSecret(guild) and guild or nil,
                level = level, race = race, class = class, file = file, zone = zone })
        end
    end
    return out
end

AF:RegisterEvent("WHO_LIST_UPDATE", function()
    if not waiting then return end
    local range = waiting
    waiting = nil
    local guildless = Store().filters.guildless
    local added = 0
    for _, p in ipairs(WhoResults()) do
        local hasGuild = type(p.guild) == "string" and p.guild ~= ""
        if p.name and not byName[p.name] and not (guildless and hasGuild) and not AF.Standings:All()[p.name] then
            byName[p.name] = p
            table.insert(results, p)
            added = added + 1
        end
    end
    C_Timer.After(0, function()
        if FriendsFrame then FriendsFrame:RegisterEvent("WHO_LIST_UPDATE") end
    end)
    AF:Printf("Recruiter: levels %d-%d, %d new player%s found.", range[1], range[2], added, added == 1 and "" or "s")
    AF:Fire("RECRUIT_UPDATED")
end)

-------------------------------------------------------------------------------
--  Contacting
-------------------------------------------------------------------------------
function Recruiter:Templates() return AF.Config:Get("recruit") end

-- The whisper for a player, from the chosen template, or nil if there's none.
function Recruiter:Message(p)
    local templates = self:Templates()
    local template = templates[Store().template] or templates[1]
    if not template then return nil end
    local values = {
        player = (p.name or ""):match("^[^ %-]+") or p.name,
        guild = GetGuildInfo("player") or "",
        class = p.class or "",
        level = tostring(p.level or ""),
        zone = p.zone or "",
    }
    local text = template.t:gsub("{(%a+)}", function(key) return values[key:lower()] end)
    return text:sub(1, 255)
end

local function Share(kind, name, entry)
    AF.Comm:Send("REC", { k = kind, n = name, t = entry and entry.t, on = entry ~= nil }, "GUILD")
end

local function MarkContacted(name)
    local entry = { t = GetServerTime(), by = AF.playerName }
    Store().contacted[name] = entry
    Share("c", name, entry)
end

-- Whispers and/or invites one player (by the chosen mode). Call it from a click.
function Recruiter:Contact(name, mode)
    if not self:CanUse() then return AF:Print("Recruiting needs the Recruiter feature (guild setup) and a rank that may invite.") end
    local p = byName[name] or { name = name }
    local status = self:Status(name)
    if status == "blocked" then return AF:Printf("%s is on the blacklist.", AF:ShortName(name)) end
    if status == "member" then return AF:Printf("%s is already in the guild.", AF:ShortName(name)) end
    local wait = GAP - (GetTime() - lastContact)
    if wait > 0 then return AF:Printf("Wait %d more second%s between players.", math.ceil(wait), wait > 1 and "s" or "") end
    mode = mode or Store().mode
    local did = {}
    if mode ~= "invite" then
        local text = self:Message(p)
        if not text then return AF:Print("There's no whisper template yet. Officers add one with the Templates button.") end
        if AF:IsChatLocked() then return AF:Print("Chat is locked right now (combat or an encounter). Try again in a moment.") end
        local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
        local ok = pcall(send, text, "WHISPER", nil, name)
        if not ok then return AF:Print("The whisper couldn't be sent.") end
        table.insert(did, "whispered")
    end
    if mode ~= "whisper" then
        local invite = (C_GuildInfo and C_GuildInfo.Invite) or GuildInvite
        if invite and pcall(invite, name) then table.insert(did, "invited") end
    end
    if #did == 0 then return AF:Print("Nothing could be sent to " .. AF:ShortName(name) .. ".") end
    lastContact = GetTime()
    p.done = table.concat(did, " + ")
    MarkContacted(name)
    AF:Fire("RECRUIT_UPDATED")
end

-- The next new player in the results. For the Next button and /gms recruit next.
function Recruiter:Next()
    local p = self:NextCandidate()
    if not p then
        local range = self:NextRange()
        return AF:Printf("Nobody new left. Search again for levels %d-%d, or change the filters.", range[1], range[2])
    end
    self:Contact(p.name)
end

-- Adds a player to (on) or takes them off the blacklist, for every recruiter.
function Recruiter:Block(name, on)
    local entry = on and { t = GetServerTime(), by = AF.playerName } or nil
    Store().blocked[name] = entry
    Share("b", name, entry)
    if on then
        for i = #replies, 1, -1 do
            if replies[i].n == name then table.remove(replies, i) end
        end
    end
    AF:Fire("RECRUIT_UPDATED")
end

-- Invites someone who answered (from the Replies list).
function Recruiter:Invite(name)
    if not self:CanUse() then return AF:Print("Your rank can't invite to the guild.") end
    local invite = (C_GuildInfo and C_GuildInfo.Invite) or GuildInvite
    if not invite or not pcall(invite, name) then return AF:Print("The invite couldn't be sent.") end
    AF:Printf("Invited %s to the guild.", AF:ShortName(name))
end

-- Whispers back from players we contacted.
AF:RegisterEvent("CHAT_MSG_WHISPER", function(_, text, sender)
    if AF:IsSecret(text) or AF:IsSecret(sender) or not Recruiter:CanUse() then return end
    local name = AF:FullName(sender)
    local r = Store()
    if not name or not Recent(r.contacted[name]) or r.blocked[name] or AF.Standings:All()[name] then return end
    table.insert(replies, 1, { n = name, text = text:gsub("|", ""), t = time() })
    while #replies > MAX_REPLIES do table.remove(replies) end
    AF:Fire("RECRUIT_UPDATED")
end)

-------------------------------------------------------------------------------
--  Sharing between recruiters
-------------------------------------------------------------------------------
-- Keeps the newer of two entries.
local function Merge(list, name, t, by)
    if type(name) ~= "string" or type(t) ~= "number" then return end
    local current = list[name]
    if not current or current.t < t then list[name] = { t = t, by = type(by) == "string" and by or nil } end
end

AF.Comm:On("REC", function(sender, data)
    if sender == AF.playerName or type(data) ~= "table" or not AF.Standings:All()[sender] then return end
    if not AF.Config:Feature("recruiter") then return end
    local r = Store()
    if data.k == "c" then
        Merge(r.contacted, data.n, data.t, sender)
    elseif data.k == "b" and type(data.n) == "string" then
        if data.on then Merge(r.blocked, data.n, data.t, sender) else r.blocked[data.n] = nil end
    elseif data.k == "list" then
        for name, t in pairs(type(data.c) == "table" and data.c or {}) do
            if GetServerTime() - (tonumber(t) or 0) < KEEP_DAYS * 86400 then Merge(r.contacted, name, t) end
        end
        for name, t in pairs(type(data.b) == "table" and data.b or {}) do Merge(r.blocked, name, t) end
    else
        return
    end
    AF:Fire("RECRUIT_UPDATED")
end)

-- A recruiter logged in: send them our lists.
AF.Comm:On("RECQ", function(sender)
    if sender == AF.playerName or not Recruiter:CanUse() or not AF.Standings:All()[sender] then return end
    local r = Store()
    local c, b = {}, {}
    for name, e in pairs(r.contacted) do
        if Recent(e) then c[name] = e.t end
    end
    for name, e in pairs(r.blocked) do b[name] = e.t end
    if not next(c) and not next(b) then return end
    C_Timer.After(1 + math.random() * 6, function()
        AF.Comm:Send("REC", { k = "list", c = c, b = b }, "WHISPER", sender, true)
    end)
end)

-------------------------------------------------------------------------------
-- What this client allows (for /gms debug).
function Recruiter.ApiReport()
    local who = (C_FriendList and C_FriendList.SendWho) or _G.SendWho
    local invite = (C_GuildInfo and C_GuildInfo.Invite) or GuildInvite
    return who ~= nil, invite ~= nil, CanGuildInvite and CanGuildInvite() and true or false
end

function Recruiter:Enable()
    local r = Store()
    for name, e in pairs(r.contacted) do
        if not Recent(e) then r.contacted[name] = nil end
    end
    C_Timer.After(LIST_DELAY, function()
        if Recruiter:CanUse() then AF.Comm:Send("RECQ", 1, "GUILD") end
    end)
end
