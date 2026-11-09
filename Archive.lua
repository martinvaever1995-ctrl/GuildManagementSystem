-------------------------------------------------------------------------------
--  Archive.lua -- weeks that left the ledger, kept for good (officers only).
--
--  archive = { v = 1, weeks = { [week] = entry } }, per guild. An entry:
--    c   "raid,bank,honor,dungeon": the caps when it was archived
--    s   { [main] = "raid,bank,honor,dungeon" }: points per category, capped
--    l   { { n, l, r, y, t, by }, ... }: awards: character, item link, response or
--        purpose ("Guild bank", "Disenchant"), award reason, time, officer
--    d   { [itemID] = count }: wanted items deposited (larger source per character)
--    g   { [itemID] = { s = goal start, q = count since then } }: goals that
--        started during the week
--    n   ledger events it was built from; h checksum of all the above
--    by, t   who archived it and when (not in the checksum)
--
--  Each officer archives a week from its own ledger as the week leaves it
--  (Ledger:Enable). An officer who missed events builds a different version;
--  the one built from more events wins (a tie: the higher checksum), so every
--  officer ends up with the same week. Archived weeks are whole: they can't be
--  merged, only replaced by a better version.
--
--  Sync: an officer sends ARCQ { [week] = "n:h" } to the guild after login.
--  Officers with better weeks whisper them (ARC { w, a }) on the bulk lane, and
--  answer with their own ARCQ when the sender has better ones.
-------------------------------------------------------------------------------
local _, AF = ...
local Archive = AF:NewModule("Archive")

local VERSION = 1
local DIGEST_DELAY = 60         -- seconds after login: once the ledger sync has settled
local REPLY_SPREAD = 8          -- answers to ARCQ spread over this many seconds
local EXPORT_VERSION = 1

local function Store()
    local db = AF.db
    if type(db.archive) ~= "table" or type(db.archive.weeks) ~= "table" then
        db.archive = { v = VERSION, weeks = {} }
    end
    return db.archive
end

-------------------------------------------------------------------------------
--  Checksums and validation
-------------------------------------------------------------------------------
local function SortedKeys(t)
    local keys = {}
    for k in pairs(t) do table.insert(keys, k) end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

-- The entry as text in a fixed order, so the same week gives the same checksum
-- on every client.
local function Canonical(a)
    local out = { "c=" .. a.c }
    for _, k in ipairs(SortedKeys(a.s)) do table.insert(out, "s=" .. k .. "=" .. a.s[k]) end
    local loot = {}
    for _, e in ipairs(a.l) do
        table.insert(loot, ("l=%d|%s|%s|%s|%s|%s"):format(e.t, e.n, e.l, e.r or "", e.y or "", e.by or ""))
    end
    table.sort(loot)
    for _, line in ipairs(loot) do table.insert(out, line) end
    for _, k in ipairs(SortedKeys(a.d)) do table.insert(out, ("d=%d=%d"):format(k, a.d[k])) end
    for _, k in ipairs(SortedKeys(a.g)) do table.insert(out, ("g=%d=%d=%d"):format(k, a.g[k].s, a.g[k].q)) end
    table.insert(out, "n=" .. a.n)
    return table.concat(out, "\n")
end

-- Two small rolling hashes (kept under 2^24, so they never overflow).
local function Checksum(text)
    local h1, h2 = 5381, 7
    for i = 1, #text do
        local b = text:byte(i)
        h1 = (h1 * 33 + b) % 16777216
        h2 = (h2 * 31 + b) % 16777213
    end
    return ("%06x%06x"):format(h1, h2)
end

-- a better than b: built from more events, or the higher checksum on a tie.
local function Better(a, b)
    if not a then return false end
    if not b then return true end
    if a.n ~= b.n then return a.n > b.n end
    return a.h > b.h
end

local function Valid(a)
    if type(a) ~= "table" or type(a.c) ~= "string" or type(a.s) ~= "table" or type(a.l) ~= "table"
        or type(a.d) ~= "table" or type(a.g) ~= "table" or type(a.n) ~= "number" or type(a.h) ~= "string" then
        return false
    end
    if (a.by ~= nil and type(a.by) ~= "string") or (a.t ~= nil and type(a.t) ~= "number") then return false end
    for name, v in pairs(a.s) do
        if type(name) ~= "string" or type(v) ~= "string" or not v:match("^%-?%d+,%-?%d+,%-?%d+,%-?%d+$") then return false end
    end
    for _, e in ipairs(a.l) do
        if type(e) ~= "table" or type(e.n) ~= "string" or type(e.l) ~= "string" or type(e.t) ~= "number"
            or (e.r ~= nil and type(e.r) ~= "string") or (e.y ~= nil and type(e.y) ~= "string")
            or (e.by ~= nil and type(e.by) ~= "string") then
            return false
        end
    end
    for k, v in pairs(a.d) do
        if type(k) ~= "number" or type(v) ~= "number" then return false end
    end
    for k, v in pairs(a.g) do
        if type(k) ~= "number" or type(v) ~= "table" or type(v.s) ~= "number" or type(v.q) ~= "number" then return false end
    end
    return Checksum(Canonical(a)) == a.h
end

-------------------------------------------------------------------------------
--  Archiving and reading
-------------------------------------------------------------------------------
local function Finish(entry)
    entry.h = Checksum(Canonical(entry))
    entry.by, entry.t = AF.playerName, GetServerTime()
    return entry
end

-- A week leaving the ledger (Ledger:Enable), from Ledger:WeekSummary.
function Archive:Seal(week, entry)
    Finish(entry)
    local weeks = Store().weeks
    if Better(entry, weeks[week]) then
        weeks[week] = entry
        AF:Fire("ARCHIVE_UPDATED")
    end
end

-- Archived awards from a raid week on, shaped like the ledger's `won` events.
function Archive:Wins(oldest, store)
    local out = {}
    for week, a in pairs((store or Store()).weeks) do
        if week >= oldest then
            for i, e in ipairs(a.l) do
                table.insert(out, { n = e.n, l = e.l, r = e.r, y = e.y, t = e.t, by = e.by, w = week, k = "won",
                    archived = true, id = ("archive:%d:%d"):format(week, i) })
            end
        end
    end
    return out
end

-- Archived deposits of an item since a time (goal progress): whole weeks after
-- the goal started, and the week it started from its start.
function Archive:DepositedSince(itemID, since, store)
    local sinceWeek = AF.Standings.WeekOf(since)
    local total = 0
    for week, a in pairs((store or Store()).weeks) do
        if week > sinceWeek then
            total = total + (a.d[itemID] or 0)
        elseif week == sinceWeek then
            local g = a.g[itemID]
            if g and g.s == since then total = total + g.q end
        end
    end
    return total
end

function Archive:Weeks() return Store().weeks end

function Archive:PrintStatus()
    local weeks = Store().weeks
    local count, awards, oldest, newest = 0, 0, nil, nil
    local players = {}
    for week, a in pairs(weeks) do
        count = count + 1
        awards = awards + #a.l
        oldest = math.min(oldest or week, week)
        newest = math.max(newest or week, week)
        for name in pairs(a.s) do players[name] = true end
    end
    if count == 0 then
        return AF:Print("Archive: empty. Weeks are archived as they leave the ledger, 8 weeks after they end. /gms archive test checks it now.")
    end
    local people = 0
    for _ in pairs(players) do people = people + 1 end
    local current = AF.Standings.CurrentWeek()
    AF:Printf("Archive: %d weeks (%d to %d weeks ago) | %d players | %d awards | %.1f KB",
        count, current - newest, current - oldest, people, awards, #AF.Comm.Serialize(Store()) / 1024)
end

-- For /gms selftest.
function Archive:Summary()
    local count, oldest = 0, nil
    for week in pairs(Store().weeks) do
        count = count + 1
        oldest = math.min(oldest or week, week)
    end
    return count, oldest
end

-------------------------------------------------------------------------------
--  Sync between officers
-------------------------------------------------------------------------------
local function Digest()
    local d = {}
    for week, a in pairs(Store().weeks) do d[week] = a.n .. ":" .. a.h end
    return d
end

local function ParseDigest(v)
    if type(v) ~= "string" then return nil end
    local n, h = v:match("^(%d+):(%x+)$")
    if n then return { n = tonumber(n), h = h } end
end

function Archive:SendDigest(channel, target)
    if not AF.Ledger:CanRecord() then return end
    AF.Comm:Send("ARCQ", Digest(), channel, target)
end

AF.Comm:On("ARCQ", function(sender, digest, channel)
    if sender == AF.playerName or type(digest) ~= "table" then return end
    if not AF.Ledger:CanRecord() or not AF.Config:IsOfficer(sender) then return end
    local weeks = Store().weeks
    local give, want = {}, false
    for week, a in pairs(weeks) do
        if Better(a, ParseDigest(digest[week])) then table.insert(give, week) end
    end
    for week, v in pairs(digest) do
        local theirs = type(week) == "number" and ParseDigest(v)
        if theirs and Better(theirs, weeks[week]) then want = true end
    end
    -- They have better weeks: tell them ours (only in answer to their guild-wide one).
    if want and channel ~= "WHISPER" then
        C_Timer.After(1 + math.random() * 2, function() Archive:SendDigest("WHISPER", sender) end)
    end
    if #give > 0 then
        table.sort(give, function(a, b) return a > b end)      -- newest first
        C_Timer.After(1 + math.random() * REPLY_SPREAD, function()
            for _, week in ipairs(give) do
                local a = Store().weeks[week]
                if a then AF.Comm:Send("ARC", { w = week, a = a }, "WHISPER", sender, true) end
            end
        end)
    end
end)

AF.Comm:On("ARC", function(sender, data)
    if type(data) ~= "table" or type(data.w) ~= "number" then return end
    if not AF.Ledger:CanRecord() or not AF.Config:IsOfficer(sender) then return end
    -- Only weeks that have left everyone's ledger.
    if data.w >= AF.Standings.CurrentWeek() - AF.Ledger.KEEP_WEEKS then return end
    if not Valid(data.a) then return end
    local weeks = Store().weeks
    if Better(data.a, weeks[data.w]) then
        weeks[data.w] = data.a
        AF:Fire("ARCHIVE_UPDATED")
    end
end)

-------------------------------------------------------------------------------
--  Web export (docs/EXPORT.md)
-------------------------------------------------------------------------------
local function Json(v)
    local t = type(v)
    if v == nil then return "null" end
    if t == "boolean" then return v and "true" or "false" end
    if t == "number" then return tostring(v) end
    local s = tostring(v):gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' end
        if c == "\\" then return "\\\\" end
        if c == "\n" then return "\\n" end
        return ("\\u%04x"):format(c:byte())
    end)
    return '"' .. s .. '"'
end

-- { key, value, key, value, ... } as a JSON object (values already JSON).
local function Object(pairsList)
    local parts = {}
    for i = 1, #pairsList, 2 do table.insert(parts, Json(pairsList[i]) .. ":" .. pairsList[i + 1]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function Array(items) return "[" .. table.concat(items, ",") .. "]" end

local function Numbers(text)
    local out = {}
    for n in tostring(text):gmatch("%-?%d+") do table.insert(out, tonumber(n)) end
    return out
end

local function LootJson(e)
    local link = e.l or ""
    return Object({
        "player", Json(e.n),
        "itemId", Json(tonumber(link:match("item:(%d+)"))),
        "item", Json(link:match("%[(.-)%]")),
        "itemString", Json(link:match("(item:[%-%d:]+)")),
        "response", Json(e.r),
        "reason", Json(AF.Loot.ReasonText(e.y)),
        "forGuild", Json(AF.Ledger.FOR_GUILD[e.r] == true),
        "time", Json(e.t),
        "awardedBy", Json(e.by),
    })
end

-- The archive (ours, or a test one) and the ledger's weeks as JSON.
function Archive:WebExport(store)
    store = store or Store()
    local current = AF.Standings.CurrentWeek()
    local cats = AF.Standings.CATEGORIES
    local weeks = {}
    for week, a in pairs(store.weeks) do
        table.insert(weeks, { w = week, src = "archive", c = a.c, s = a.s, l = a.l })
    end
    for _, week in ipairs(AF.Ledger:Weeks()) do
        if week <= current and not store.weeks[week] then
            local sum = AF.Ledger:WeekSummary(week)
            table.insert(weeks, { w = week, src = "ledger", c = sum.c, s = sum.s, l = sum.l })
        end
    end
    table.sort(weeks, function(a, b) return a.w < b.w end)

    local names, mains = {}, {}
    local altMap = AF.Ledger:AltMap()
    local function Note(name)
        local main = altMap[name] or name
        if not names[main] then
            names[main] = true
            table.insert(mains, main)
        end
    end
    local weekJson = {}
    for _, wk in ipairs(weeks) do
        local caps = Numbers(wk.c)
        local capTotal = 0
        for _, cap in ipairs(caps) do capTotal = capTotal + cap end
        local scores = {}
        for _, name in ipairs(SortedKeys(wk.s)) do
            Note(name)
            local points = Numbers(wk.s[name])
            local fields, total = { "player", Json(name) }, 0
            for i, category in ipairs(cats) do
                table.insert(fields, category)
                table.insert(fields, Json(points[i] or 0))
                total = total + (points[i] or 0)
            end
            table.insert(fields, "total")
            table.insert(fields, Json(math.min(total, capTotal)))
            table.insert(scores, Object(fields))
        end
        local loot = {}
        local sorted = {}
        for _, e in ipairs(wk.l) do table.insert(sorted, e) end
        table.sort(sorted, function(a, b) return a.t < b.t end)
        for _, e in ipairs(sorted) do
            Note(AF.Ledger:MainOf(e.n))
            table.insert(loot, LootJson(e))
        end
        local capFields = {}
        for i, category in ipairs(cats) do
            table.insert(capFields, category)
            table.insert(capFields, Json(caps[i] or 0))
        end
        table.insert(weekJson, Object({
            "week", Json(wk.w),
            "start", Json(AF.Standings.WeekStart(wk.w)),
            "end", Json(AF.Standings.WeekStart(wk.w + 1)),
            "source", Json(wk.src),
            "caps", Object(capFields),
            "scores", Array(scores),
            "loot", Array(loot),
        }))
    end

    table.sort(mains)
    local alts = {}
    for alt, main in pairs(altMap) do
        alts[main] = alts[main] or {}
        table.insert(alts[main], alt)
    end
    local players = {}
    for _, main in ipairs(mains) do
        local list = alts[main] or {}
        table.sort(list)
        local altJson = {}
        for _, alt in ipairs(list) do table.insert(altJson, Json(alt)) end
        local member = AF.Standings:All()[main]
        table.insert(players, Object({
            "name", Json(main),
            "class", Json(member and member.classFile),
            "alts", Array(altJson),
        }))
    end

    local capFields, features = {}, {}
    for _, category in ipairs(cats) do
        table.insert(capFields, category)
        table.insert(capFields, Json(AF.Config:Get(category .. "Max")))
    end
    for _, f in ipairs(AF.Config.FEATURES) do
        table.insert(features, f.key)
        table.insert(features, Json(AF.Config:Feature(f.key)))
    end
    local catJson = {}
    for _, category in ipairs(cats) do table.insert(catJson, Json(category)) end

    local text = Object({
        "format", Json("gms-web"),
        "version", Json(EXPORT_VERSION),
        "addonVersion", Json(AF.VERSION_STRING),
        "guild", Json(GetGuildInfo("player")),
        "realm", Json(GetRealmName()),
        "exported", Json(GetServerTime()),
        "exportedBy", Json(AF.playerName),
        "currentWeek", Json(current),
        "categories", Array(catJson),
        "config", Object({
            "caps", Object(capFields),
            "goldPerPoint", Json(AF.Config:Get("goldPerPoint")),
            "honorTarget", Json(AF.Config:Get("honorTarget")),
            "guildKillShare", Json(AF.Config:Get("guildKillShare")),
            "dungeonPerRun", Json(AF.Config:Get("dungeonPerRun")),
            "features", Object(features),
        }),
        "players", Array(players),
        "weeks", Array(weekJson),
    })
    return text, #weeks
end

-------------------------------------------------------------------------------
--  /gms archive test: archive the ledger's weeks into a throwaway archive and
--  check it against the ledger. Nothing is saved or sent.
-------------------------------------------------------------------------------
function Archive:Test()
    if not AF.Ledger:CanRecord() then return AF:Print("Only officers keep the ledger and the archive.") end
    local current = AF.Standings.CurrentWeek()
    local scratch = { v = VERSION, weeks = {} }
    local problems = {}
    local function Problem(fmt, ...) table.insert(problems, fmt:format(...)) end
    local weekCount, players, awards = 0, 0, 0
    for _, week in ipairs(AF.Ledger:Weeks()) do
        if week <= current then
            weekCount = weekCount + 1
            local a = Finish(AF.Ledger:WeekSummary(week))
            if Checksum(Canonical(AF.Ledger:WeekSummary(week))) ~= a.h then
                Problem("week %d: a different checksum when built twice", week)
            end
            local copy = AF.Comm.Deserialize(AF.Comm.Serialize(a))
            if not Valid(copy) then Problem("week %d: doesn't survive being sent to another officer", week) end
            for _, main in ipairs(AF.Ledger:WeekPlayers(week)) do
                local b = AF.Ledger:Breakdown(week, main)
                local want = b and ("%d,%d,%d,%d"):format(b.raid or 0, b.bank or 0, b.honor or 0, b.dungeon or 0)
                if want ~= a.s[main] then Problem("week %d: %s has %s, the ledger says %s", week, main, tostring(a.s[main]), tostring(want)) end
                if want then players = players + 1 end
            end
            awards = awards + #a.l
            if #a.l ~= #AF.Ledger:WeekWins(week) then Problem("week %d: %d awards, the ledger has %d", week, #a.l, #AF.Ledger:WeekWins(week)) end
            scratch.weeks[week] = a
        end
    end
    -- Deposits and goals: the archive alone must give what the ledger gives.
    local items = {}
    for _, a in pairs(scratch.weeks) do
        for itemID in pairs(a.d) do items[itemID] = true end
    end
    for itemID in pairs(AF.Config:Get("wanted")) do items[itemID] = true end
    for itemID in pairs(items) do
        local archived, ledger = 0, AF.Ledger:LedgerDepositedSince(itemID, 0)
        for _, a in pairs(scratch.weeks) do archived = archived + (a.d[itemID] or 0) end
        if archived ~= ledger then Problem("item %d: %d deposited in the archive, %d in the ledger", itemID, archived, ledger) end
    end
    local goals = 0
    for itemID, goal in pairs(AF.Config:Get("goals")) do
        goals = goals + 1
        local archived = self:DepositedSince(itemID, goal.since, scratch)
        local ledger = AF.Ledger:LedgerDepositedSince(itemID, goal.since)
        if archived ~= ledger then Problem("goal %d: %d from the archive, %d from the ledger", itemID, archived, ledger) end
    end

    AF:Printf("Archive test: %d weeks, %d player-weeks, %d awards, %d goals checked.", weekCount, players, awards, goals)
    if #problems == 0 then
        AF:Print("|cff50e0a0OK: the archive matches the ledger.|r Nothing was saved or sent.")
    else
        AF:Printf("|cffff5555%d problem(s):|r", #problems)
        for i = 1, math.min(#problems, 10) do AF:Print(problems[i]) end
    end
    local text = self:WebExport(scratch)
    AF.UI:ShowTextWindow("Archive test (web export)", "What the archive would hold, as the web export. Test only: nothing was saved.", text)
end

function Archive:Enable()
    Store()
    C_Timer.After(DIGEST_DELAY, function() Archive:SendDigest("GUILD") end)
end
