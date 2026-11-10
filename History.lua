-------------------------------------------------------------------------------
--  History.lua -- joins, leaves, kicks, promotions and demotions, from the game's
--  guild event log. The game only keeps a short log; every client that reads it
--  saves what it saw (per guild), so it lasts longer.
--
--  AF.db.history = { { k = kind, a = player, b = other player, r = rank, t = time }, ... }
--  newest first, at most KEEP. The log gives times as "N hours/days ago", so the
--  same event read twice can differ by up to a day: an event matches a saved one
--  with the same kind, players and rank within MATCH seconds.
-------------------------------------------------------------------------------
local _, AF = ...
local History = AF:NewModule("History")

local KEEP = 500
local MATCH = 36 * 3600
local READ_DELAY = 30           -- seconds after login

History.KINDS = { invite = true, join = true, promote = true, demote = true, remove = true, quit = true }

local function Store()
    if type(AF.db.history) ~= "table" then AF.db.history = {} end
    return AF.db.history
end

-- Whether this client gives addons the guild event log.
function History.Available()
    return type(QueryGuildEventLog) == "function" and type(GetNumGuildEvents) == "function"
        and type(GetGuildEventInfo) == "function"
end

-- Saved events, newest first.
function History:List() return Store() end

-- The event as a line of text.
function History.Describe(e)
    local a, b = AF:ShortName(e.a or "?"), AF:ShortName(e.b or "?")
    if e.k == "join" then return ("%s joined the guild"):format(a) end
    if e.k == "quit" then return ("%s left the guild"):format(a) end
    if e.k == "invite" then return ("%s invited %s"):format(a, b) end
    if e.k == "remove" then return ("%s removed %s"):format(a, b) end
    if e.k == "promote" then return ("%s promoted %s to %s"):format(a, b, e.r or "?") end
    if e.k == "demote" then return ("%s demoted %s to %s"):format(a, b, e.r or "?") end
    return e.k
end

-- Joins and leaves (quits and removals) since a time.
function History:Counts(since)
    local joined, left = 0, 0
    for _, e in ipairs(Store()) do
        if e.t >= since then
            if e.k == "join" then joined = joined + 1 end
            if e.k == "quit" or e.k == "remove" then left = left + 1 end
        end
    end
    return joined, left
end

local function Plain(v) return not AF:IsSecret(v) and v or nil end

local function Known(list, e)
    for _, old in ipairs(list) do
        if old.k == e.k and old.a == e.a and old.b == e.b and old.r == e.r and math.abs(old.t - e.t) <= MATCH then
            return true
        end
    end
    return false
end

-- Saves what the game's log holds now.
local function Read()
    if not History.Available() or not IsInGuild() then return end
    local list = Store()
    local now = GetServerTime()
    local added = 0
    for i = 1, GetNumGuildEvents() or 0 do
        local kind, p1, p2, rank, years, months, days, hours = GetGuildEventInfo(i)
        kind, p1, p2, rank = Plain(kind), Plain(p1), Plain(p2), Plain(rank)
        if History.KINDS[kind] and type(p1) == "string" then
            local ago = (tonumber(Plain(years)) or 0) * 365 * 86400 + (tonumber(Plain(months)) or 0) * 30 * 86400
                + (tonumber(Plain(days)) or 0) * 86400 + (tonumber(Plain(hours)) or 0) * 3600
            local e = { k = kind, a = AF:FullName(p1), b = type(p2) == "string" and AF:FullName(p2) or nil,
                r = type(rank) == "string" and rank or nil, t = now - ago }
            if e.a and not Known(list, e) then
                table.insert(list, e)
                added = added + 1
            end
        end
    end
    if added > 0 then
        table.sort(list, function(x, y) return x.t > y.t end)
        for i = #list, KEEP + 1, -1 do list[i] = nil end
        AF:Fire("HISTORY_UPDATED")
    end
end

AF:RegisterEvent("GUILD_EVENT_LOG_UPDATE", Read)

-- Asks the game for its log (the answer arrives as GUILD_EVENT_LOG_UPDATE).
function History:Refresh()
    if History.Available() and IsInGuild() then pcall(QueryGuildEventLog) end
end

-- For /gms debug.
function History.ApiReport()
    return History.Available(), #Store()
end

function History:Enable()
    C_Timer.After(READ_DELAY, function() History:Refresh() end)
end
