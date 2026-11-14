-------------------------------------------------------------------------------
--  Achievements.lua -- guild firsts, PvE and PvP: the first to the level cap (and
--  per class), to max a profession, to an attunement, the first guild kill of
--  each raid boss and run of each dungeon, PvP ranks, honorable kills,
--  battleground wins with guildies, and guild milestones.
--
--  Officers record them as "ach" ledger events (Ledger:RecordAch), so they sync
--  like the rest of the ledger and never expire. Each officer records what it
--  sees; the earliest per achievement wins, so officers can't disagree.
--  Where it comes from:
--    officers' scan    levels (roster), professions (crafters directory),
--                      attunements, members, bank goals, full-score weeks, weekly
--                      honor, first kills and runs (ledger)
--    player reports    level-ups, PvP rank, lifetime honorable kills, battleground
--                      wins (ACHR, resent until an officer confirms with ACHACK)
--  The first scan on an officer's client gives achievements players already had
--  to all of them, marked "before GMS" (pre), instead of to whoever came first.
--  Raiders get them in snapshots (ac). New ones show a card; one officer's
--  client announces them in guild chat (feature achAnnounce).
--  Only members with GMS installed can win (decided): officers know who runs it
--  from its addon messages (AF:HasGMS). Groups (kills, runs, battlegrounds) credit
--  only their members with GMS.
-------------------------------------------------------------------------------
local _, AF = ...
local Achievements = AF:NewModule("Achievements")

local PROF_CAP = 300
local HK_STEPS = { 1000, 5000, 10000, 25000 }
local RANK_STEPS = { 6, 8, 10, 12, 13, 14 }
local MEMBER_STEPS = { 50, 100, 200, 500 }
local RACE_STEPS = { 100, 500, 1000 }
local ALL_STEPS = { 1000, 5000, 10000, 25000 }
local EACH_STEP = 100
local BATTLEGROUNDS = { { 489, "Warsong Gulch" }, { 529, "Arathi Basin" }, { 30, "Alterac Valley" } }
local BG_BY_NAME = {}           -- older reports used the English zone name
for _, bg in ipairs(BATTLEGROUNDS) do BG_BY_NAME[bg[2]] = bg[1] end
local BG_GUILD_MIN = 5
local SCAN_GAP = 10             -- seconds between two scans
local RESEND = 300
local ANNOUNCE_AFTER = 4        -- seconds: let other officers' records arrive first
local FRESH = 600               -- only announce firsts from the last 10 minutes
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

Achievements.GROUPS = { "Levels", "Professions", "Attunements", "Raids", "Dungeons", "PvP", "Guild" }
Achievements.BG_GUILD_MIN = BG_GUILD_MIN

local function LevelCap()
    local cap = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or MAX_PLAYER_LEVEL
    return type(cap) == "number" and cap > 0 and cap or 60
end

local function ClassName(file)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file]) or file
end

local function RankName(rank)
    if GetPVPRankInfo then
        local ok, name = pcall(GetPVPRankInfo, rank + 4, UnitFactionGroup("player"))
        if ok and type(name) == "string" and name ~= "" then return ("%s (rank %d)"):format(name, rank) end
    end
    return ("PvP rank %d"):format(rank)
end

local function Plain(text) return (tostring(text or ""):gsub("[|;]", "")) end

-- The same achievement whatever the client's language: professions by their
-- English name, battlegrounds by instance ID (older records used names).
local function CanonicalKey(key)
    local prof = key:match("^prof:(.+)$")
    if prof then return "prof:" .. (AF.Professions.Canonical(prof) or prof) end
    local bg = key:match("^bg:(.+)$")
    if bg and not tonumber(bg) and BG_BY_NAME[bg] then return "bg:" .. BG_BY_NAME[bg] end
    return key
end

-- Folds records under another language's key into one: the earliest wins, and
-- "before GMS" lists are joined.
local function MergeKeys(won)
    local out = {}
    for key, w in pairs(won) do
        local canon = CanonicalKey(key)
        local have = out[canon]
        if not have then
            out[canon] = w
        elseif w.pre and have.pre then
            local seen = {}
            for _, name in ipairs(have.p or {}) do seen[name] = true end
            for _, name in ipairs(w.p or {}) do
                if not seen[name] then table.insert(have.p, name) end
            end
        elseif w.pre ~= have.pre then
            -- "Before GMS" beats a real record only if it was made first.
            local pre, real = w.pre and w or have, w.pre and have or w
            out[canon] = (pre.bt and pre.bt <= real.t) and pre or real
        elseif w.t < have.t or (w.t == have.t and w.n < have.n) then
            out[canon] = w
        end
    end
    return out
end

-- The names in a list who run GMS.
local function OnlyGMS(names)
    local out = {}
    for _, name in ipairs(names or {}) do
        if AF:HasGMS(name) then table.insert(out, name) end
    end
    return out
end

-------------------------------------------------------------------------------
--  What there is to win
-------------------------------------------------------------------------------
-- { { group, key, name, desc }, ... } in display order. Raid bosses, officer-marked
-- dungeons and other battlegrounds join the list once someone wins them.
function Achievements:Definitions(won)
    won = won or {}
    local cap = LevelCap()
    local list, seen = {}, {}
    local function Add(group, key, name, desc)
        seen[key] = true
        table.insert(list, { group = group, key = key, name = name, desc = desc })
    end
    Add("Levels", "level", ("Level %d"):format(cap), ("The first in the guild to reach level %d."):format(cap))
    for _, file in ipairs(CLASSES) do
        Add("Levels", "level:" .. file, ("%s %d"):format(ClassName(file), cap),
            ("The first %s in the guild to reach level %d."):format(ClassName(file), cap))
    end
    for _, prof in ipairs(AF.Professions.NAMES) do
        local name = AF.Professions.LocalName(prof)
        Add("Professions", "prof:" .. prof, name, ("The first to %d skill in %s."):format(PROF_CAP, name))
    end
    for _, a in ipairs(AF.Attunements:List()) do
        Add("Attunements", "attune:" .. a.key, a.n, ("The first attuned to %s."):format(a.n))
    end
    -- Raid bosses: as they're killed (there's no list of every boss to come).
    local bosses = {}
    for key, w in pairs(won) do
        if key:find("^kill:") then table.insert(bosses, { key = key, w = w }) end
    end
    table.sort(bosses, function(a, b) return a.w.t < b.w.t end)
    for _, b in ipairs(bosses) do
        Add("Raids", b.key, b.w.x or b.key:sub(6), ("The guild's first kill of %s."):format(b.w.x or "this boss"))
    end
    for _, d in ipairs(AF.Dungeons.FinalList()) do
        Add("Dungeons", "run:" .. d.enc, d.dungeon,
            ("The first guild run of %s (%s), with guild members in the group."):format(d.dungeon, d.boss))
    end
    for key, w in pairs(won) do
        if key:find("^run:") and not seen[key] then
            Add("Dungeons", key, w.x or key:sub(5), ("The first guild run of %s."):format(w.x or "this dungeon"))
        end
    end
    Add("PvP", "honor", "Honor bound", "The first to fill the weekly honor score.")
    for _, n in ipairs(HK_STEPS) do
        Add("PvP", "hk:" .. n, ("%s honorable kills"):format(BreakUpLargeNumbers(n)),
            ("The first to %s lifetime honorable kills."):format(BreakUpLargeNumbers(n)))
    end
    for _, rank in ipairs(RANK_STEPS) do
        Add("PvP", "rank:" .. rank, RankName(rank), ("The first to reach PvP rank %d."):format(rank))
    end
    for _, bg in ipairs(BATTLEGROUNDS) do
        Add("PvP", "bg:" .. bg[1], bg[2] .. " win",
            ("The first %s win with %d or more guild members on the team."):format(bg[2], BG_GUILD_MIN))
    end
    for key, w in pairs(won) do
        if key:find("^bg:") and not seen[key] then
            local name = w.x or key:sub(4)
            Add("PvP", key, name .. " win", ("The first %s win with guild members."):format(name))
        end
    end
    -- Killing blows on players, by the whole guild.
    for _, race in ipairs(AF.Hunt.EnemyRaces()) do
        for _, n in ipairs(RACE_STEPS) do
            Add("PvP", ("kills:%s:%d"):format(race, n), ("%s %s slain"):format(BreakUpLargeNumbers(n), AF.Hunt.RaceName(race, true)),
                ("Together, %s killing blows on %s."):format(BreakUpLargeNumbers(n), AF.Hunt.RaceName(race, true)))
        end
    end
    for _, n in ipairs(ALL_STEPS) do
        Add("PvP", "kills:all:" .. n, ("%s players slain"):format(BreakUpLargeNumbers(n)),
            ("Together, %s killing blows on players of any race."):format(BreakUpLargeNumbers(n)))
    end
    Add("PvP", "kills:each:" .. EACH_STEP, "Every race", ("Together, %d killing blows on every enemy race."):format(EACH_STEP))
    -- Race hunts: the current one, and every one the guild finished.
    local hunt = AF.Hunt.Current()
    if hunt then
        local key = "hunt:" .. hunt.k
        Add("PvP", key, ("Hunt: %d %s"):format(hunt.g, AF.Hunt.RaceName(hunt.r, true)),
            ("Together, %d killing blows on %s."):format(hunt.g, AF.Hunt.RaceName(hunt.r, true)))
    end
    for key, w in pairs(won) do
        if key:find("^hunt:") and not seen[key] then
            Add("PvP", key, "Hunt: " .. (w.x or key:sub(6)), ("Together, %s killing blows."):format(w.x or "a race hunt's"))
        end
    end
    for _, n in ipairs(MEMBER_STEPS) do
        Add("Guild", "members:" .. n, ("%d members"):format(n), ("The guild reaches %d members."):format(n))
    end
    Add("Guild", "goal", "Bank goal reached", "The first bank goal the guild completes.")
    Add("Guild", "week", "Perfect week", "The first to score every point there is in a raid week.")
    return list
end

-------------------------------------------------------------------------------
--  Who has won what: officers from the ledger, everyone else from the snapshot.
--  key -> { n, t, p (names, officers only), count, x, pre }
-------------------------------------------------------------------------------
function Achievements:Won()
    if AF.Ledger:CanRecord() then
        local out = MergeKeys(AF.Ledger:Achievements())
        for _, w in pairs(out) do
            -- Credit only members with GMS (older records can list others).
            if w.p and w.n ~= "guild" then w.p = OnlyGMS(w.p) end
            w.count = w.p and #w.p or 1
        end
        return out
    end
    local out = {}
    local snap = AF.db.snapshot
    for key, text in pairs(snap and type(snap.ac) == "table" and snap.ac or {}) do
        local t, n, count, x = tostring(text):match("^(%d+);([^;]*);(%d+);(.*)$")
        if t then
            out[key] = { t = tonumber(t), n = n, count = tonumber(count), x = x ~= "" and x or nil, pre = tonumber(t) == 0,
                q = type(snap.aq) == "table" and snap.aq[key] == true or nil }
        end
    end
    return out
end

-- For snapshots: key -> "time;name;count;extra", and the quiet ones (no card).
function Achievements:SnapshotField()
    if not AF.Config:Feature("achievements") then return nil end
    local out, quiet = {}, {}
    for key, w in pairs(self:Won()) do
        out[key] = ("%d;%s;%d;%s"):format(w.t, Plain(w.n), w.count, Plain(w.x))
        if w.q then quiet[key] = true end
    end
    return next(out) and out or nil, next(quiet) and quiet or nil
end

-- "Spnkn Morwick", "the raid (32)", "the guild", "3 players (before GMS)".
function Achievements.WinnerText(w)
    if w.pre then
        if w.n == "guild" then return "the guild (before GMS)" end
        return w.count == 1 and (AF:ShortName((w.p and w.p[1]) or w.n) .. " (before GMS)")
            or ("%d players (before GMS)"):format(w.count)
    end
    if w.n == "guild" then return "the guild" end
    if w.n == "group" then return ("a group of %d"):format(w.count or 0) end
    return AF:ShortName(w.n)
end

-------------------------------------------------------------------------------
--  Officers: looking for new firsts
-------------------------------------------------------------------------------
local lastScan, scanTimer = 0, nil
local scanned = false            -- this session's first scan is done

local function Scan()
    scanTimer = nil
    if not AF.Config:Feature("achievements") or not AF.Ledger:CanRecord() or GetTime() < AF.Ledger.readyAt then return end
    lastScan = GetTime()
    local won = MergeKeys(AF.Ledger:Achievements())
    -- "Before GMS" only when the guild has no achievements yet: an officer who
    -- joins later gets normal (quiet) records instead.
    local baseline = not AF.db.achBaseline and next(won) == nil
    local now = GetServerTime()
    -- A first nobody has yet. pre-able ones go to everyone on the first scan.
    -- What's already true on this session's first scan may be a first another
    -- officer recorded and our sync hasn't brought yet: record it, but quietly
    -- (no card, no guild chat). Kills and runs have their real time, so they're exact.
    local function Try(key, name, t, group, extra, preable, exact)
        if won[key] then return end
        local pre = baseline and preable or nil
        AF.Ledger:RecordAch(key, name, t or now, group, extra, pre, not pre and not scanned and not exact or nil)
    end

    local roster = AF.Standings:All()
    local cap = LevelCap()
    local count = 0
    for name, m in pairs(roster) do
        count = count + 1
        if (m.level or 0) >= cap and AF:HasGMS(name) then
            Try("level", name, now, nil, nil, true)
            if m.classFile then Try("level:" .. m.classFile, name, now, nil, nil, true) end
        end
    end
    for _, n in ipairs(MEMBER_STEPS) do
        if count >= n then Try("members:" .. n, "guild", now, nil, nil, true) end
    end
    if AF.Config:Feature("crafters") then
        for _, p in ipairs(AF.Professions:Players()) do
            if (p.r or 0) >= PROF_CAP and roster[p.name] then Try("prof:" .. p.prof, p.name, now, nil, nil, true) end
        end
    end
    if AF.Config:Feature("attune") then
        for _, a in ipairs(AF.Attunements:List()) do
            for _, name in ipairs(AF.Attunements:Players()) do
                if AF.Attunements:Status(name, a.key) and roster[name] then Try("attune:" .. a.key, name, now, nil, nil, true) end
            end
        end
    end
    for itemID, goal in pairs(AF.Config:Get("goals")) do
        local done = AF.Standings:GoalProgress(itemID)
        if done and done >= goal.n then
            Try("goal", "guild", now, nil, Plain(C_Item.GetItemInfo(itemID) or ("item " .. itemID)))
        end
    end
    -- Weekly firsts: this week and last.
    local current = AF.Standings.CurrentWeek()
    local weekMax = AF.Standings.WeekMax()
    local target = AF.Config:Get("honorTarget")
    for week = current - 1, current do
        for _, main in ipairs(AF.Ledger:WeekPlayers(week)) do
            if AF.Ledger:WeekScore(week, main) >= weekMax then Try("week", main) end
            if AF.Config:Feature("honor") and (AF.Ledger:WeekHonor(week, main) or 0) >= target then Try("honor", main) end
        end
    end
    local byRace, _, killTotal = AF.Hunt:KillTotals()
    local enemies, each = AF.Hunt.EnemyRaces(), true
    for _, race in ipairs(enemies) do
        for _, n in ipairs(RACE_STEPS) do
            if (byRace[race] or 0) >= n then Try(("kills:%s:%d"):format(race, n), "guild", now) end
        end
        if (byRace[race] or 0) < EACH_STEP then each = false end
    end
    for _, n in ipairs(ALL_STEPS) do
        if killTotal >= n then Try("kills:all:" .. n, "guild", now) end
    end
    if each then Try("kills:each:" .. EACH_STEP, "guild", now) end
    local hunt = AF.Hunt.Current()
    if hunt then
        local byMain, total = AF.Ledger:HuntCounts(hunt.k)
        if total >= hunt.g then
            local hunters = {}
            for name in pairs(byMain) do table.insert(hunters, name) end
            table.sort(hunters)
            Try("hunt:" .. hunt.k, "guild", now, hunters, ("%d %s"):format(hunt.g, AF.Hunt.RaceName(hunt.r, true)))
        end
    end
    for key, e in pairs(AF.Ledger:FirstKills()) do
        local group = OnlyGMS(e.p)
        if #group > 0 then Try("kill:" .. key, "group", e.t, group, Plain(e.en), nil, true) end
    end
    for enc, g in pairs(AF.Ledger:FirstRuns()) do
        local members = {}
        for name in pairs(g.members) do table.insert(members, name) end
        members = OnlyGMS(members)
        table.sort(members)
        if #members > 0 then Try("run:" .. enc, "group", g.t, members, Plain(AF.Dungeons.FinalName(enc) or g.mn), nil, true) end
    end
    AF.db.achBaseline = true
    scanned = true
end

local function QueueScan()
    if scanTimer or not AF.Ledger:CanRecord() then return end
    scanTimer = C_Timer.NewTimer(math.max(1, SCAN_GAP - (GetTime() - lastScan)), Scan)
end

-------------------------------------------------------------------------------
--  Players' own reports (what only their client can see)
-------------------------------------------------------------------------------
local function Pending()
    if type(AF.db.achPending) ~= "table" then AF.db.achPending = {} end
    return AF.db.achPending
end

-- Queues a report (id: what it is, so a newer one replaces it) and sends it.
local function Report(id, data)
    data.id = id
    Pending()[id] = data
    AF.Comm:Send("ACHR", data, "GUILD")
end

function Achievements:SendPending()
    if not AF.Config:Feature("achievements") or not IsInGuild() then return end
    for _, data in pairs(Pending()) do AF.Comm:Send("ACHR", data, "GUILD") end
end

local function CheckPvP()
    if not AF.Config:Feature("achievements") or not IsInGuild() or not AF.playerName then return end
    local mine = AF.db.achMine or {}
    AF.db.achMine = mine
    local key = AF.playerName
    mine[key] = mine[key] or {}
    local me = mine[key]
    if UnitPVPRank then
        local id = UnitPVPRank("player")
        local rank = type(id) == "number" and not AF:IsSecret(id) and id >= 5 and id - 4 or 0
        if rank > (me.rank or 0) then
            me.rank = rank
            Report("rank", { k = "rank", v = rank, t = GetServerTime() })
        end
    end
    if GetPVPLifetimeStats then
        local hk = GetPVPLifetimeStats()
        if type(hk) == "number" and not AF:IsSecret(hk) then
            local step = 0
            for _, n in ipairs(HK_STEPS) do
                if hk >= n then step = n end
            end
            if step > (me.hk or 0) then
                me.hk = step
                Report("hk", { k = "hk", v = hk, t = GetServerTime() })
            end
        end
    end
end

AF:RegisterEvent("PLAYER_LEVEL_UP", function(_, level)
    if AF.Config:Feature("achievements") and type(level) == "number" and not AF:IsSecret(level) and level >= LevelCap() then
        Report("level", { k = "level", v = level, t = GetServerTime() })
    end
end)

-- A battleground won with enough guild members on the team.
local bgReported
AF:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", function()
    if not GetBattlefieldWinner or not AF.Config:Feature("achievements") then return end
    local winner = GetBattlefieldWinner()
    if winner == nil then
        bgReported = nil
        return
    end
    if bgReported or AF:IsSecret(winner) then return end
    bgReported = true
    local mine = UnitFactionGroup("player") == "Alliance" and 1 or 0
    if winner ~= mine then return end
    local guild = {}
    local roster = AF.Standings:All()
    for _, name in ipairs(AF:GroupMembers()) do
        if roster[name] then table.insert(guild, name) end
    end
    if #guild < BG_GUILD_MIN then return end
    local zone = GetRealZoneText and GetRealZoneText() or GetZoneText()
    if type(zone) ~= "string" or AF:IsSecret(zone) or zone == "" then return end
    -- The instance ID is the same in every language; the zone name is for display.
    local instance = GetInstanceInfo and select(8, GetInstanceInfo())
    instance = type(instance) == "number" and not AF:IsSecret(instance) and instance or nil
    Report("bg:" .. (instance or zone), { k = "bg", x = zone:sub(1, 40), i = instance, p = guild, t = GetServerTime() })
end)

AF.Comm:On("ACHR", function(sender, data)
    if type(data) ~= "table" or type(data.id) ~= "string" or type(data.t) ~= "number" then return end
    if not AF.Ledger:CanRecord() or not AF.Config:Feature("achievements") then return end
    local member = AF.Standings:All()[sender]
    if not member then return end
    local now = GetServerTime()
    local t = math.max(now - 7 * 86400, math.min(now, math.floor(data.t)))
    if data.k == "level" and type(data.v) == "number" and data.v >= LevelCap() then
        AF.Ledger:RecordAch("level", sender, t)
        if member.classFile then AF.Ledger:RecordAch("level:" .. member.classFile, sender, t) end
    elseif data.k == "rank" and type(data.v) == "number" then
        for _, rank in ipairs(RANK_STEPS) do
            if data.v >= rank then AF.Ledger:RecordAch("rank:" .. rank, sender, t) end
        end
    elseif data.k == "hk" and type(data.v) == "number" then
        for _, n in ipairs(HK_STEPS) do
            if data.v >= n then AF.Ledger:RecordAch("hk:" .. n, sender, t) end
        end
    elseif data.k == "bg" and type(data.x) == "string" and type(data.p) == "table" then
        local guild = {}
        for _, name in ipairs(data.p) do
            if type(name) == "string" and AF.Standings:All()[name] then table.insert(guild, name) end
        end
        if #guild < BG_GUILD_MIN then return end
        -- 5+ guild members on the team; the win goes to those with GMS.
        guild = OnlyGMS(guild)
        if #guild == 0 then return end
        table.sort(guild)
        local zone = Plain(data.x):sub(1, 40)
        local id = type(data.i) == "number" and math.floor(data.i) or BG_BY_NAME[zone]
        AF.Ledger:RecordAch("bg:" .. (id or zone), "group", t, guild, zone)
    else
        return
    end
    AF.Comm:Send("ACHACK", data.id, "WHISPER", sender)
end)

AF.Comm:On("ACHACK", function(sender, id)
    if type(id) == "string" and AF.Config:IsOfficer(sender) then Pending()[id] = nil end
end)

-------------------------------------------------------------------------------
--  New firsts: a card for everyone, one guild chat line
-------------------------------------------------------------------------------
local known                     -- key -> true: what we've already shown

local function NameOf(key, w)
    for _, d in ipairs(Achievements:Definitions({ [key] = w })) do
        if d.key == key then return d.name end
    end
    return key
end

local function Announce(key, w)
    local text = ("Guild first! %s: %s"):format(NameOf(key, w), Achievements.WinnerText(w))
    AF.UI:AchievementCard(text)
    -- Guild chat: only the officer whose record won says it, once.
    if not AF.Config:Feature("achAnnounce") or w.by ~= AF.playerName or w.pre then return end
    if GetServerTime() - w.t > FRESH then return end
    AF.db.achAnnounced = AF.db.achAnnounced or {}
    if AF.db.achAnnounced[key] then return end
    C_Timer.After(ANNOUNCE_AFTER, function()
        local now = AF.Ledger:Achievements()[key]
        if not now or now.by ~= AF.playerName or AF.db.achAnnounced[key] or AF:IsChatLocked() then return end
        AF.db.achAnnounced[key] = true
        local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
        pcall(send, "[GMS] " .. ("Guild first! %s: %s"):format(NameOf(key, now), Achievements.WinnerText(now)), "GUILD")
    end)
end

local function CheckNew()
    if not AF.Config:Feature("achievements") then return end
    -- Officers: not before the login sync has landed (old firsts arrive with it).
    if AF.Ledger:CanRecord() and GetTime() < AF.Ledger.readyAt then return end
    local won = Achievements:Won()
    if not known then
        known = {}
        for key in pairs(won) do known[key] = true end
        return
    end
    for key, w in pairs(won) do
        if not known[key] then
            known[key] = true
            -- Only fresh ones: not old firsts arriving with a sync or a snapshot, nor
            -- ones an officer found already done when it logged in.
            if not w.pre and not w.q and GetServerTime() - w.t <= FRESH then Announce(key, w) end
        end
    end
    AF:Fire("ACHIEVEMENTS_UPDATED")
end

AF:On("LEDGER_UPDATED", function()
    QueueScan()
    if AF.Ledger:CanRecord() then CheckNew() end
end)
AF:On("STANDINGS_UPDATED", function()
    QueueScan()
    if not AF.Ledger:CanRecord() then CheckNew() end
end)
AF:On("CONFIG_UPDATED", QueueScan)
AF:On("HUNT_UPDATED", QueueScan)

-- For /gms debug.
function Achievements.ApiReport()
    return UnitPVPRank ~= nil, GetPVPLifetimeStats ~= nil, GetBattlefieldWinner ~= nil
end

function Achievements:Enable()
    -- After the ledger sync: the first scan, and what we know so far.
    C_Timer.After(50, function()
        CheckNew()
        QueueScan()
    end)
    C_Timer.After(60, function()
        CheckPvP()
        Achievements:SendPending()
    end)
    C_Timer.NewTicker(RESEND, function() Achievements:SendPending() end)
    AF:RegisterEvent("PLAYER_PVP_RANK_CHANGED", CheckPvP)
    AF:RegisterEvent("PLAYER_PVP_KILLS_CHANGED", CheckPvP)
end
