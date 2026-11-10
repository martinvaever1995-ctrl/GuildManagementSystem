-------------------------------------------------------------------------------
--  Hunt.lua -- the race hunt: officers pick a race and a goal ("500 Gnomes"),
--  and the guild counts its killing blows on players of that race.
--
--  Each client counts its own killing blows from the combat log (PARTY_KILL by
--  us on a player; GetPlayerInfoByGUID gives the race) and reports its total for
--  the current hunt (HUNT, at most every few minutes, resent until HUNTACK).
--  Officers record "hunt" ledger events (the highest report per character
--  counts) and send the leaderboard to raiders in snapshots (hn). Reaching the
--  goal is a guild achievement (Achievements.lua).
--  Killing blows, not honorable kills: an honorable kill is shared by everyone
--  nearby, so one kill would count several times.
--
--  Every killing blow on a player also counts toward all-time totals per race
--  (KB { c = { race = n } }, resent until KBACK). Those are reported often and
--  last forever, so they stay out of the ledger: officers keep the highest per
--  character (AF.db.kbAll) and share them in snapshots (kb), which every client
--  merges. They feed the kill achievements (Achievements.lua).
-------------------------------------------------------------------------------
local _, AF = ...
local Hunt = AF:NewModule("Hunt")

local SEND_GAP = 120            -- seconds between reports while kills keep coming
local RESEND = 300

-- Player races by the game's English token, with a display name and plural.
Hunt.RACES = {
    { "Human", "Human", "Humans" }, { "Dwarf", "Dwarf", "Dwarves" }, { "NightElf", "Night Elf", "Night Elves" },
    { "Gnome", "Gnome", "Gnomes" }, { "Orc", "Orc", "Orcs" }, { "Scourge", "Undead", "Undead" },
    { "Tauren", "Tauren", "Tauren" }, { "Troll", "Troll", "Trolls" },
}
local RACE = {}
for _, r in ipairs(Hunt.RACES) do RACE[r[1]] = r end

function Hunt.RaceName(race, plural)
    local r = RACE[race]
    if not r then return race end
    return plural and r[3] or r[2]
end

Hunt.FACTION_RACES = { Alliance = { "Human", "Dwarf", "NightElf", "Gnome" }, Horde = { "Orc", "Scourge", "Tauren", "Troll" } }

-- The races of the other faction (the ones the guild can kill).
function Hunt.EnemyRaces()
    return UnitFactionGroup("player") == "Horde" and Hunt.FACTION_RACES.Alliance or Hunt.FACTION_RACES.Horde
end

-- The guild's current hunt { k, r, g }, or nil.
function Hunt.Current()
    local h = AF.Config:Get("hunt")
    if h and h.k and h.r then return h end
end

-------------------------------------------------------------------------------
--  Our own count
-------------------------------------------------------------------------------
local lastSeen                  -- the race of our last killing blow on a player (for /gms debug)
local lastSent, sendTimer = 0, nil
local logOK

-- Our all-time killing blows per race: { c = { race = n }, acked = total confirmed }.
local function MyKills()
    if not AF.playerName then return nil end
    if type(AF.db.kbMine) ~= "table" then AF.db.kbMine = {} end
    local record = AF.db.kbMine[AF.playerName] or { c = {}, acked = 0 }
    AF.db.kbMine[AF.playerName] = record
    return record
end

local function Total(counts)
    local total = 0
    for _, n in pairs(counts) do total = total + n end
    return total
end

local function Mine()
    if type(AF.db.huntMine) ~= "table" then AF.db.huntMine = {} end
    local h = Hunt.Current()
    if not h or not AF.playerName then return nil end
    local byKey = AF.db.huntMine
    -- Only the current hunt is kept.
    for key in pairs(byKey) do
        if key ~= h.k then byKey[key] = nil end
    end
    byKey[h.k] = byKey[h.k] or {}
    local record = byKey[h.k][AF.playerName] or { n = 0, acked = 0 }
    byKey[h.k][AF.playerName] = record
    return record, h
end

function Hunt:Send()
    sendTimer = nil
    if not IsInGuild() then return end
    local kills = MyKills()
    if kills and Total(kills.c) > kills.acked then
        lastSent = GetTime()
        AF.Comm:Send("KB", { c = kills.c }, "GUILD")
    end
    local record, h = Mine()
    if not record or record.n <= record.acked then return end
    lastSent = GetTime()
    AF.Comm:Send("HUNT", { k = h.k, n = record.n }, "GUILD")
end

local function Changed()
    if sendTimer then return end
    sendTimer = C_Timer.NewTimer(math.max(5, SEND_GAP - (GetTime() - lastSent)), function() Hunt:Send() end)
end

local function OnCombatLog()
    if not CombatLogGetCurrentEventInfo or not AF.Config:Feature("achievements") then return end
    local h = Hunt.Current()
    local _, sub, _, source, _, _, _, dest = CombatLogGetCurrentEventInfo()
    if sub ~= "PARTY_KILL" or AF:IsSecret(sub) or AF:IsSecret(source) or AF:IsSecret(dest) then return end
    if source ~= UnitGUID("player") or type(dest) ~= "string" or not dest:find("^Player%-") then return end
    local _, _, _, race = GetPlayerInfoByGUID(dest)
    if AF:IsSecret(race) or type(race) ~= "string" then return end
    lastSeen = race
    local kills = MyKills()
    if kills and RACE[race] then
        kills.c[race] = (kills.c[race] or 0) + 1
        Changed()
    end
    if not h or race ~= h.r then return AF:Fire("HUNT_UPDATED") end
    local record = Mine()
    if not record then return end
    record.n = record.n + 1
    Changed()
    AF:Fire("HUNT_UPDATED")
end

-- The combat log is its own frame: on some clients addons may not listen to it.
local logFrame = CreateFrame("Frame")
logFrame:SetScript("OnEvent", function()
    local ok, err = pcall(OnCombatLog)
    if not ok then geterrorhandler()(err) end
end)

function Hunt:MyCount()
    local record = Mine()
    return record and record.n or 0
end

-------------------------------------------------------------------------------
--  Officers: record reports; everyone: the leaderboard
-------------------------------------------------------------------------------
AF.Comm:On("HUNT", function(sender, data)
    if type(data) ~= "table" or type(data.k) ~= "string" or type(data.n) ~= "number" then return end
    if not AF.Ledger:CanRecord() or not AF.Standings:All()[sender] then return end
    local h = Hunt.Current()
    if not h or data.k ~= h.k then return end
    local n = math.floor(data.n)
    if n < 1 or n > 100000 then return end
    AF.Ledger:RecordHunt(sender, h.k, n)
    AF.Comm:Send("HUNTACK", { k = h.k, n = n }, "WHISPER", sender)
end)

AF.Comm:On("HUNTACK", function(sender, data)
    if type(data) ~= "table" or type(data.n) ~= "number" or not AF.Config:IsOfficer(sender) then return end
    local record, h = Mine()
    if record and data.k == h.k and data.n > record.acked then record.acked = data.n end
end)

-- All-time killing blows: char -> { c = { race = n }, v = total }. Officers fill it
-- from reports; everyone merges what snapshots carry.
local function AllKills()
    if type(AF.db.kbAll) ~= "table" then AF.db.kbAll = {} end
    return AF.db.kbAll
end

-- Keeps the higher of what we know and what came in, per race.
local function Merge(name, counts)
    if type(name) ~= "string" or type(counts) ~= "table" then return false end
    local all = AllKills()
    local entry = all[name] or { c = {} }
    local changed = false
    for race, n in pairs(counts) do
        if RACE[race] and type(n) == "number" and n >= 0 and n <= 1000000 and n > (entry.c[race] or 0) then
            entry.c[race] = math.floor(n)
            changed = true
        end
    end
    entry.v = Total(entry.c)
    all[name] = entry
    return changed
end

AF.Comm:On("KB", function(sender, data)
    if type(data) ~= "table" or type(data.c) ~= "table" then return end
    if not AF.Ledger:CanRecord() or not AF.Standings:All()[sender] then return end
    if Merge(sender, data.c) then
        AF.Standings:QueueSnapshot()
        AF:Fire("HUNT_UPDATED")
    end
    AF.Comm:Send("KBACK", Total(AllKills()[sender].c), "WHISPER", sender)
end)

AF.Comm:On("KBACK", function(sender, total)
    if type(total) ~= "number" or not AF.Config:IsOfficer(sender) then return end
    local kills = MyKills()
    if kills and total > kills.acked then kills.acked = total end
end)

-- Snapshot field: char -> "Gnome:12,Human:5".
function Hunt:KillsField()
    local out = {}
    for name, entry in pairs(AllKills()) do
        local parts = {}
        for race, n in pairs(entry.c) do
            if n > 0 then table.insert(parts, race .. ":" .. n) end
        end
        if #parts > 0 then out[name] = table.concat(parts, ",") end
    end
    return next(out) and out or nil
end

-- A snapshot arrived (from an officer): take its counts.
function Hunt:MergeField(field)
    if type(field) ~= "table" then return end
    local changed = false
    for name, text in pairs(field) do
        if type(name) == "string" and type(text) == "string" then
            local counts = {}
            for race, n in text:gmatch("(%a+):(%d+)") do counts[race] = tonumber(n) end
            if Merge(name, counts) then changed = true end
        end
    end
    if changed then AF:Fire("HUNT_UPDATED") end
end

-- The guild's all-time killing blows: race -> total, main -> { total, race -> n }, and the grand total.
function Hunt:KillTotals()
    local byRace, byMain, total = {}, {}, 0
    local roster = AF.Standings:All()
    for name, entry in pairs(AllKills()) do
        if roster[name] or not next(roster) then
            local main = AF.Standings:MainOf(name)
            local m = byMain[main] or { total = 0, c = {} }
            byMain[main] = m
            for race, n in pairs(entry.c) do
                byRace[race] = (byRace[race] or 0) + n
                m.c[race] = (m.c[race] or 0) + n
                m.total = m.total + n
                total = total + n
            end
        end
    end
    return byRace, byMain, total
end

-- { { name, n }, ... } highest first, and the guild's total: officers from the
-- ledger, everyone else from the snapshot.
function Hunt:Board()
    local h = Hunt.Current()
    if not h then return {}, 0 end
    local byMain, total = {}, 0
    if AF.Ledger:CanRecord() then
        byMain, total = AF.Ledger:HuntCounts(h.k)
    else
        local snap = AF.db.snapshot
        local hn = snap and type(snap.hn) == "table" and snap.hn
        if hn and hn.k == h.k and type(hn.c) == "table" then
            for name, n in pairs(hn.c) do
                byMain[name] = n
                total = total + n
            end
        end
    end
    local list = {}
    for name, n in pairs(byMain) do table.insert(list, { name = name, n = n }) end
    table.sort(list, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.name < b.name
    end)
    return list, total
end

-- For snapshots: { k = key, c = { main = count } }.
function Hunt:SnapshotField()
    local h = Hunt.Current()
    if not h then return nil end
    local byMain = AF.Ledger:HuntCounts(h.k)
    return next(byMain) and { k = h.k, c = byMain } or nil
end

-- For /gms debug: can we read the combat log, and what did our last killing blow hit.
function Hunt.ApiReport()
    return logOK, GetPlayerInfoByGUID ~= nil, lastSeen
end

function Hunt:Enable()
    local valid = not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid("COMBAT_LOG_EVENT_UNFILTERED")
    logOK = valid and CombatLogGetCurrentEventInfo ~= nil and pcall(logFrame.RegisterEvent, logFrame, "COMBAT_LOG_EVENT_UNFILTERED") or false
    C_Timer.After(45, function() Hunt:Send() end)
    C_Timer.NewTicker(RESEND, function() Hunt:Send() end)
end
