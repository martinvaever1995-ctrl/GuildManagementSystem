-------------------------------------------------------------------------------
--  Honor.lua -- this week's honor, reported by the player's own client.
--
--  Your client works out this week's honor from whatever the game offers, and
--  takes the highest:
--    - the weekly honor stats (GetPVPThisWeekStats, Classic-style)
--    - honor gains it saw itself (the honor currency going up while you play),
--      kept per character and week in saved data. Clients number the currency
--      differently, so it's found by name: from the known IDs, the currency list
--      and every currency that changes.
--    - the honor currency's own "earned this week", if the client fills it in
--  It reports the number to the guild (HON) when it changes, at most every few
--  minutes. Officers record it as "honor:<player>:<week>#<honor>", so every
--  officer makes the same event; the highest report per player and week counts.
--  A report waits until an officer confirms it (HONACK).
--
--  Honor score = honorMax x min(1, honor / honorTarget).
--
--  Verifying other players' honor by inspecting them needs an inspect-honor API;
--  /gms debug says whether this client has one.
-------------------------------------------------------------------------------
local _, AF = ...
local Honor = AF:NewModule("Honor")

local SEND_GAP = 300            -- seconds between reports while honor keeps changing
local WATCH_DELAY = 15          -- seconds after login: currency amounts can read 0 until then
local KNOWN_CURRENCIES = { 1901, 1792, 392 }    -- Classic, retail and the old honor points

local lastSent = 0
local sendTimer
local currencies = {}           -- honor currency ID -> last amount seen (false until there is one)
local watching = false

local function Mine()
    AF.db.honor = AF.db.honor or {}
    local byChar = AF.db.honor[AF.playerName] or {}
    AF.db.honor[AF.playerName] = byChar
    return byChar
end

-- This week's record for us: { gained = tracked gains, acked = highest confirmed report }.
local function ThisWeek()
    local byChar = Mine()
    local week = AF.Standings.CurrentWeek()
    for w in pairs(byChar) do
        if w < week - 2 then byChar[w] = nil end
    end
    byChar[week] = byChar[week] or { gained = 0, acked = 0 }
    return byChar[week], week
end

local function CurrencyInfo(id)
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
    return ok and type(info) == "table" and info or nil
end

local function Number(value)
    if AF:IsSecret(value) or type(value) ~= "number" then return nil end
    return value
end

local function IsHonorName(name)
    if AF:IsSecret(name) or type(name) ~= "string" or name == "" then return false end
    return name == HONOR or name == HONOR_POINTS or name == "Honor" or name == "Honor Points"
end

-- Starts following a currency if it's honor.
local function Watch(id)
    if currencies[id] ~= nil then return true end
    local info = CurrencyInfo(id)
    if not info or not IsHonorName(info.name) then return false end
    currencies[id] = Number(info.quantity) or false
    return true
end

-- Adds what the honor currency went up by. Several IDs can show the same honor,
-- so it's the biggest rise that counts, not the sum.
local function Sample()
    local gain = 0
    for id, last in pairs(currencies) do
        local amount = Number((CurrencyInfo(id) or {}).quantity)
        if amount then
            if last and amount > last then gain = math.max(gain, amount - last) end
            currencies[id] = amount
        end
    end
    if gain > 0 then
        local record = ThisWeek()
        record.gained = record.gained + gain
    end
end

local function FindCurrencies()
    local consts = Constants and Constants.CurrencyConsts
    if consts then
        if consts.CLASSIC_HONOR_CURRENCY_ID then Watch(consts.CLASSIC_HONOR_CURRENCY_ID) end
        if consts.HONOR_CURRENCY_ID then Watch(consts.HONOR_CURRENCY_ID) end
    end
    for _, id in ipairs(KNOWN_CURRENCIES) do Watch(id) end
    local prefs = AF.db.prefs
    if prefs and prefs.honorCurrency then Watch(prefs.honorCurrency) end
    local api = C_CurrencyInfo
    if api and api.GetCurrencyListSize and api.GetCurrencyListInfo and api.GetCurrencyListLink then
        for i = 1, api.GetCurrencyListSize() or 0 do
            local info = api.GetCurrencyListInfo(i)
            local link = info and IsHonorName(info.name) and api.GetCurrencyListLink(i)
            local id = type(link) == "string" and tonumber(link:match("currency:(%d+)"))
            if id then Watch(id) end
        end
    end
    watching = true
end

-- This week's honor and where it came from.
function Honor.Current()
    local record = ThisWeek()
    local best, source = record.gained, "tracked"
    if type(GetPVPThisWeekStats) == "function" then
        local _, weekly = GetPVPThisWeekStats()
        weekly = Number(weekly)
        if weekly and weekly > best then best, source = weekly, "weekly stats" end
    end
    for id in pairs(currencies) do
        local earned = Number((CurrencyInfo(id) or {}).quantityEarnedThisWeek)
        if earned and earned > best then best, source = earned, "earned this week" end
    end
    return math.floor(best), source
end

-------------------------------------------------------------------------------
--  Reporting
-------------------------------------------------------------------------------
function Honor:Send()
    sendTimer = nil
    if not IsInGuild() or not AF.playerName then return end
    Sample()
    local honor = Honor.Current()
    local record, week = ThisWeek()
    if honor <= record.acked then return end
    lastSent = GetTime()
    AF.Comm:Send("HON", { w = week, h = honor }, "GUILD")
end

-- Honor changed: report soon, but not more often than SEND_GAP.
local function Changed()
    if not AF.playerName then return end
    Sample()
    if sendTimer then return end
    local wait = math.max(5, SEND_GAP - (GetTime() - lastSent))
    sendTimer = C_Timer.NewTimer(wait, function() Honor:Send() end)
end

local function OnCurrency(_, currencyType, _, change)
    if not watching or not AF.playerName then return end
    local id = Number(currencyType)
    if not id then return Sample() end
    if currencies[id] == nil then
        if not Watch(id) then return end
        -- A new one: remember it, and this change is already in its amount.
        AF.db.prefs = AF.db.prefs or {}
        AF.db.prefs.honorCurrency = id
        change = Number(change)
        if change and change > 0 then
            local record = ThisWeek()
            record.gained = record.gained + change
        end
    end
    Changed()
end

AF:RegisterEvent("CURRENCY_DISPLAY_UPDATE", OnCurrency)
AF:RegisterEvent("HONOR_CURRENCY_UPDATE", Changed)
AF:RegisterEvent("PLAYER_PVP_KILLS_CHANGED", Changed)

AF.Comm:On("HON", function(sender, data)
    if type(data) ~= "table" or type(data.w) ~= "number" or type(data.h) ~= "number" then return end
    if not AF.Ledger:CanRecord() or not AF.Standings:All()[sender] then return end
    local honor = math.floor(data.h)
    if honor <= 0 then return end
    AF.Ledger:RecordHonor(sender, data.w, honor)
    AF.Comm:Send("HONACK", { w = data.w, h = honor }, "WHISPER", sender)
end)

AF.Comm:On("HONACK", function(sender, data)
    if type(data) ~= "table" or type(data.w) ~= "number" or type(data.h) ~= "number" then return end
    if not AF.Config:IsOfficer(sender) then return end
    local record = Mine()[data.w]
    if record and data.h > record.acked then record.acked = data.h end
end)

function Honor:Enable()
    C_Timer.After(WATCH_DELAY, FindCurrencies)
    C_Timer.After(40, function() Honor:Send() end)
    C_Timer.NewTicker(SEND_GAP, function() Honor:Send() end)
end

-- This week's honor and the highest an officer confirmed (for /gms selftest).
function Honor.Pending()
    if not AF.playerName then return nil end
    local record = ThisWeek()
    return Honor.Current(), record.acked
end

-- What this client offers (for /gms debug).
function Honor.ApiReport()
    local function Has(name) return type(_G[name]) == "function" end
    local function Event(name)
        if C_EventUtils and C_EventUtils.IsEventValid then return C_EventUtils.IsEventValid(name) end
        return nil
    end
    local honor, source = Honor.Current()
    local found = {}
    for id, amount in pairs(currencies) do
        table.insert(found, ("%d (amount %s)"):format(id, tostring(amount or "?")))
    end
    return {
        weeklyStats = Has("GetPVPThisWeekStats"),
        currency = #found > 0 and table.concat(found, ", ") or "not found",
        inspect = Has("RequestInspectHonorData") and Has("GetInspectHonorData"),
        inspectEvent = Event("INSPECT_HONOR_UPDATE"),
        honor = honor,
        source = source,
    }
end
