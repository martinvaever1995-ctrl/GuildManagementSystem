-------------------------------------------------------------------------------
--  Layers.lua -- which layer guild members are on, so you know who to whisper
--  for a group invite. It only shows; it never invites or moves anyone.
--
--  A creature's GUID names the layer it lives on:
--  "Creature-0-<server>-<map>-<layer ID>-<npcID>-<spawnUID>". Every client reads
--  its own layer from NPCs it hovers, targets or sees a nameplate of.
--
--  Forever's layers are per zone: a layer ID only means something next to others
--  from the same zone. So a report is always (zone, ID), and the list is by zone.
--
--  Clients tell the guild (LAY) when their zone or layer changes. After login, and
--  when someone opens the tab, a client asks (LAYQ); clients that know their layer
--  whisper it back. Reports live in memory only: they go stale too fast to save.
-------------------------------------------------------------------------------
local _, AF = ...
local Layers = AF:NewModule("Layers")

local SEND_DELAY = 5        -- a burst of changes (crossing a border) becomes one message
local ASK_EVERY = 60
local REPLY_SPREAD = 6      -- answers to LAYQ spread over this many seconds

local own = {}              -- { map, id, t }
local reports = {}          -- full name -> { map, id, t }
local pendingId, pendingGuid
local sentKey, sendQueued
local lastAsk = 0

local function Enabled()
    return IsInGuild() and AF.Config:Feature("layers")
end

-- The zone the player is in: caves and city maps count as their parent zone.
local function ZoneMap()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local map = C_Map.GetBestMapForUnit("player")
    if not map or AF:IsSecret(map) then return nil end
    local info = C_Map.GetMapInfo(map)
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    while info and info.mapType and info.mapType > zoneType and info.parentMapID and info.parentMapID > 0 do
        map = info.parentMapID
        info = C_Map.GetMapInfo(map)
    end
    return map
end

local function Payload()
    if not own.id then return {} end
    return { m = own.map, i = own.id, a = math.max(0, time() - (own.t or time())) }
end

local function QueueSend()
    if sendQueued then return end
    sendQueued = true
    C_Timer.After(SEND_DELAY, function()
        sendQueued = false
        if not Enabled() then return end
        local key = own.id and (own.map .. ":" .. own.id) or ""
        if key == sentKey then return end
        sentKey = key
        AF.Comm:Send("LAY", Payload(), "GUILD")
    end)
end

local function Forget(map)
    own.map, own.id, own.t = map, nil, nil
    pendingId, pendingGuid = nil, nil
    QueueSend()
    AF:Fire("LAYERS_UPDATED")
end

local function Moved()
    local map = nil
    if not IsInInstance() then map = ZoneMap() end
    if map ~= own.map then Forget(map) end
end

local function Observe(unit)
    if not unit or not Enabled() or IsInInstance() then return end
    local guid = UnitGUID(unit)
    if not guid or AF:IsSecret(guid) then return end
    local kind, id = guid:match("^(%a+)%-0%-%d+%-%d+%-(%d+)%-")
    if (kind ~= "Creature" and kind ~= "Vehicle") or id == "0" then return end
    local controlled = UnitPlayerControlled(unit)   -- pets and guardians
    if not AF:IsSecret(controlled) and controlled then return end
    local map = ZoneMap()
    if not map then return end
    if map ~= own.map then Forget(map) end

    if id == own.id then
        own.t = time()
        pendingId, pendingGuid = nil, nil
        return
    end
    -- A new ID needs a second NPC to agree when we already had one: an NPC just over
    -- a zone border carries that zone's ID.
    if own.id and not (pendingId == id and pendingGuid ~= guid) then
        pendingId, pendingGuid = id, guid
        return
    end
    own.id, own.t = id, time()
    pendingId, pendingGuid = nil, nil
    QueueSend()
    AF:Fire("LAYERS_UPDATED")
end

-------------------------------------------------------------------------------
--  Other clients
-------------------------------------------------------------------------------
AF.Comm:On("LAY", function(sender, p)
    if sender == AF.playerName or type(p) ~= "table" then return end
    if type(p.m) == "number" and type(p.i) == "string" and #p.i <= 12 and p.i:match("^%d+$") then
        local age = type(p.a) == "number" and math.max(0, p.a) or 0
        reports[sender] = { map = p.m, id = p.i, t = time() - age }
    else
        reports[sender] = nil
    end
    AF:Fire("LAYERS_UPDATED")
end)

AF.Comm:On("LAYQ", function(sender)
    if sender == AF.playerName or not Enabled() or not own.id then return end
    C_Timer.After(math.random() * REPLY_SPREAD, function()
        if own.id then AF.Comm:Send("LAY", Payload(), "WHISPER", sender) end
    end)
end)

-- Asks the guild for its layers (at most once a minute).
function Layers:Ask()
    if not Enabled() or GetTime() - lastAsk < ASK_EVERY then return end
    lastAsk = GetTime()
    AF.Comm:Send("LAYQ", 1, "GUILD")
end

-------------------------------------------------------------------------------
--  Reading it
-------------------------------------------------------------------------------
function Layers.ZoneName(map)
    local info = map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    return info and info.name or "Unknown zone"
end

-- map, layer ID (nil until an NPC has been seen here), zone name.
function Layers:Own()
    return own.map, own.id, own.map and self.ZoneName(own.map) or nil
end

-- Online guild members with a known layer: { name, zone, id, t, me, same }. Your zone
-- first, your layer first within it.
function Layers:List()
    local rows = {}
    local all = AF.Standings:All()
    local function Add(name, r, me)
        rows[#rows + 1] = { name = name, map = r.map, zone = self.ZoneName(r.map), id = r.id, t = r.t, me = me,
            here = r.map == own.map, same = r.map == own.map and r.id == own.id }
    end
    if own.id then Add(AF.playerName, own, true) end
    for name, r in pairs(reports) do
        local member = all[name]
        if member and member.online then Add(name, r, false) end
    end
    table.sort(rows, function(a, b)
        if a.here ~= b.here then return a.here end
        if a.zone ~= b.zone then return a.zone < b.zone end
        if a.same ~= b.same then return a.same end
        if a.id ~= b.id then return a.id < b.id end
        if a.me ~= b.me then return a.me end
        return a.name < b.name
    end)
    return rows
end

function Layers:Enable()
    AF:RegisterEvent("UPDATE_MOUSEOVER_UNIT", function() Observe("mouseover") end)
    AF:RegisterEvent("PLAYER_TARGET_CHANGED", function() Observe("target") end)
    AF:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit) Observe(unit) end)
    AF:RegisterEvent("ZONE_CHANGED_NEW_AREA", Moved)
    AF:RegisterEvent("PLAYER_ENTERING_WORLD", Moved)
    Moved()
    C_Timer.After(30, function() Layers:Ask() end)
end
