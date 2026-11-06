-------------------------------------------------------------------------------
--  Versions.lua -- who runs which version, and whether the raid is ready.
--
--  Every client says its version to the guild after login and to the raid when
--  it joins one (VER). Hearing a newer version brings up the update card once per
--  session; officers whisper outdated players once (addon message, no chat).
--
--  /gms versions asks the group (VERQ 2). Current clients answer with RDY: their
--  version, durability (repair %, the lowest item) and flask / elixir buffs.
--  Older clients answer VERQ with VER alone, so they show a version but no
--  readiness. Range is checked on our side.
-------------------------------------------------------------------------------
local _, AF = ...
local Versions = AF:NewModule("Versions")

local ANSWER_WAIT = 5           -- seconds to wait for answers before calling someone "not installed"
local REMIND_TEXT = "Your Guild Management System (GMS) addon is out of date (%s; the current one is %s). Please update it through WowUp, CurseForge or Wago."
local INSTALL_TEXT = "Please install the Guild Management System addon (GMS on CurseForge, Wago or WowUp). The guild uses it for effort and loot."

local versions = {}             -- full name -> version number
local ready = {}                -- full name -> { d = repair %, low = lowest item %, f = flask, e = { elixirs }, at = GetTime() }
local queriedAt                 -- GetTime() of the last /gms versions question
local waiting = false
local newest = AF.VERSION       -- highest version seen this session
local replied = {}
local wasInRaid = false

function Versions.String(v)
    return ("%d.%d.%d"):format(math.floor(v / 10000), math.floor(v / 100) % 100, v % 100)
end

function Versions.Newest() return newest end

-------------------------------------------------------------------------------
--  Our own readiness
-------------------------------------------------------------------------------
-- Repair % over all equipped items (what the game's durability figure shows) and
-- the lowest single item, or nil with nothing that wears.
local function Durability()
    if type(GetInventoryItemDurability) ~= "function" then return nil end
    local cur, max, low = 0, 0, nil
    for slot = 1, 19 do
        local c, m = GetInventoryItemDurability(slot)
        if type(c) == "number" and type(m) == "number" and m > 0 and not AF:IsSecret(c) then
            cur, max = cur + c, max + m
            local pct = c / m * 100
            if not low or pct < low then low = pct end
        end
    end
    if max == 0 then return nil end
    return math.floor(cur / max * 100 + 0.5), math.floor(low + 0.5)
end

local function BuffNames()
    local out = {}
    for i = 1, 40 do
        local name
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not aura then break end
            name = aura.name
        elseif UnitBuff then
            name = UnitBuff("player", i)
            if not name then break end
        else
            break
        end
        if type(name) == "string" and not AF:IsSecret(name) then table.insert(out, name) end
    end
    return out
end

-- Battle and guardian elixirs whose buff isn't called "... Elixir" / "Elixir of ...".
local ELIXIR_BUFFS = {
    ["Greater Agility"] = true, ["Greater Intellect"] = true, ["Agility"] = true, ["Intellect"] = true,
    ["Greater Armor"] = true, ["Health II"] = true, ["Mana Regeneration"] = true,
    ["Spirit of Zanza"] = true, ["Swiftness of Zanza"] = true, ["Sheen of Zanza"] = true,
}

-- The flask we have up (name) and our elixirs (names).
local function Consumables()
    local flask, elixirs = nil, {}
    for _, name in ipairs(BuffNames()) do
        if name:find("Flask") then
            flask = name
        elseif name:find("Elixir") or ELIXIR_BUFFS[name] then
            table.insert(elixirs, name)
        end
    end
    return flask, elixirs
end

-- The role of our current spec, for clients where the game doesn't assign one.
local function SpecRole()
    if not (GetSpecialization and GetSpecializationRole) then return nil end
    local okSpec, spec = pcall(GetSpecialization)
    if not okSpec or not spec or AF:IsSecret(spec) then return nil end
    local okRole, role = pcall(GetSpecializationRole, spec)
    if okRole and not AF:IsSecret(role) then return role end
end

local function OwnReadiness()
    local d, low = Durability()
    local f, e = Consumables()
    return { v = AF.VERSION, d = d, low = low, f = f, e = e, ro = SpecRole() }
end

-------------------------------------------------------------------------------
--  Messages
-------------------------------------------------------------------------------
local function Seen(sender, version, channel)
    versions[sender] = version
    if version > newest then
        newest = version
        AF:Printf("|cffff5555A newer version (%s) is out; you have %s. Please update.|r",
            Versions.String(version), AF.VERSION_STRING)
        AF:Fire("NEWER_VERSION", version)
    elseif version < AF.VERSION and channel ~= "WHISPER" and AF.Ledger:CanRecord() and not replied[sender] then
        -- Officers tell outdated players directly, once per session.
        replied[sender] = true
        AF.Comm:Send("VER", AF.VERSION, "WHISPER", sender)
    end
    AF:Fire("VERSIONS_UPDATED")
end

AF.Comm:On("VER", function(sender, version, channel)
    if type(version) ~= "number" or sender == AF.playerName then return end
    Seen(sender, version, channel)
end)

AF.Comm:On("RDY", function(sender, r)
    if type(r) ~= "table" or type(r.v) ~= "number" then return end
    ready[sender] = {
        d = type(r.d) == "number" and r.d or nil,
        low = type(r.low) == "number" and r.low or nil,
        f = type(r.f) == "string" and r.f or nil,
        e = type(r.e) == "table" and r.e or {},
        ro = (r.ro == "TANK" or r.ro == "HEALER" or r.ro == "DAMAGER") and r.ro or nil,
        at = GetTime(),
    }
    if sender == AF.playerName then
        versions[sender] = r.v
        return AF:Fire("VERSIONS_UPDATED")
    end
    Seen(sender, r.v, "WHISPER")
end)

-- payload 2: the asker wants readiness too (older askers send true and get VER).
AF.Comm:On("VERQ", function(sender, payload)
    if payload == 2 then
        AF.Comm:Send("RDY", OwnReadiness(), "WHISPER", sender)
    else
        AF.Comm:Send("VER", AF.VERSION, "WHISPER", sender)
    end
end)

-------------------------------------------------------------------------------
--  Asking the group
-------------------------------------------------------------------------------
function Versions:Query()
    if not IsInGroup() then return false end
    queriedAt = GetTime()
    waiting = true
    AF.Comm:Send("VERQ", 2, "RAID")
    AF.Comm:Send("RDY", OwnReadiness(), "WHISPER", AF.playerName)   -- our own row, the same way
    C_Timer.After(ANSWER_WAIT, function()
        waiting = false
        AF:Fire("VERSIONS_UPDATED")
    end)
    AF:Fire("VERSIONS_UPDATED")
    return true
end

function Versions:Waiting() return waiting end

local function InRange(unit)
    if UnitIsUnit(unit, "player") then return true end
    if type(UnitInRange) ~= "function" then return nil end
    local ok, inRange, checked = pcall(UnitInRange, unit)
    if not ok or AF:IsSecret(inRange) or AF:IsSecret(checked) then return nil end
    if checked == false then return nil end
    return inRange and true or false
end

-------------------------------------------------------------------------------
--  Raid composition and class buffs (read from the units, so it covers everyone)
-------------------------------------------------------------------------------
local ALWAYS_DAMAGE = { MAGE = true, ROGUE = true, HUNTER = true, WARLOCK = true }

-- Each counts once someone of that class is in the group. By spell ID where the
-- ranks are known, by English name as a fallback.
local CLASS_BUFFS = {
    { label = "Fortitude", class = "PRIEST", names = { ["Power Word: Fortitude"] = true, ["Prayer of Fortitude"] = true },
      ids = { 1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564 } },
    { label = "Arcane Intellect", class = "MAGE", names = { ["Arcane Intellect"] = true, ["Arcane Brilliance"] = true },
      ids = { 1459, 1460, 1461, 10156, 10157, 23028 } },
    { label = "Mark of the Wild", class = "DRUID", names = { ["Mark of the Wild"] = true, ["Gift of the Wild"] = true },
      ids = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 21849, 21850 } },
}
for _, buff in ipairs(CLASS_BUFFS) do
    buff.spell = {}
    for _, id in ipairs(buff.ids) do buff.spell[id] = true end
end

local BUFF_CACHE = 3        -- seconds: the window refreshes every second
local buffCache = {}

-- { [buff] = true } for what the unit has up, or nil when it can't be read.
local function UnitClassBuffs(name, unit)
    local cached = buffCache[name]
    if cached and GetTime() - cached.at < BUFF_CACHE then return cached.has end
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
    local has = {}
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok then return nil end
        if not aura then break end
        local spell, auraName = aura.spellId, aura.name
        if AF:IsSecret(spell) or AF:IsSecret(auraName) then return nil end
        for _, buff in ipairs(CLASS_BUFFS) do
            if buff.spell[spell] or buff.names[auraName] then has[buff] = true end
        end
    end
    buffCache[name] = { at = GetTime(), has = has }
    return has
end

local function RoleOf(row)
    local role = UnitGroupRolesAssigned and row.unit and UnitGroupRolesAssigned(row.unit)
    if role and not AF:IsSecret(role) and role ~= "NONE" then return role end
    if row.r and row.r.ro then return row.r.ro end
    if ALWAYS_DAMAGE[row.class] then return "DAMAGER" end
end

-- Fills in row.missing (buff labels, or nil when unreadable) for every row.
local function AddBuffs(rows)
    local present = {}
    for _, row in ipairs(rows) do
        if row.class then present[row.class] = true end
    end
    for _, row in ipairs(rows) do
        local has = row.unit and row.state ~= "offline" and UnitClassBuffs(row.name, row.unit)
        if has then
            row.missing = {}
            for _, buff in ipairs(CLASS_BUFFS) do
                if present[buff.class] and not has[buff] then table.insert(row.missing, buff.label) end
            end
        end
    end
end

-- "2 tanks  ·  4 healers  ·  14 DPS  ·  3 unknown  ·  Missing: Fortitude 4, Arcane Intellect 2"
function Versions:SummaryText(rows)
    if #rows == 0 then return "" end
    local count, missing, order = { TANK = 0, HEALER = 0, DAMAGER = 0, unknown = 0 }, {}, {}
    for _, row in ipairs(rows) do
        local role = RoleOf(row) or "unknown"
        count[role] = (count[role] or 0) + 1
        for _, label in ipairs(row.missing or {}) do
            if not missing[label] then
                missing[label] = 0
                table.insert(order, label)
            end
            missing[label] = missing[label] + 1
        end
    end
    local parts = { ("%d tank%s"):format(count.TANK, count.TANK == 1 and "" or "s"),
        ("%d healer%s"):format(count.HEALER, count.HEALER == 1 and "" or "s"), ("%d DPS"):format(count.DAMAGER) }
    if count.unknown > 0 then table.insert(parts, ("%d unknown"):format(count.unknown)) end
    if #order > 0 then
        local list = {}
        for _, label in ipairs(order) do table.insert(list, ("%s %d"):format(label, missing[label])) end
        table.insert(parts, "Missing: " .. table.concat(list, ", "))
    else
        table.insert(parts, "Class buffs: all up")
    end
    return table.concat(parts, "  ·  ")
end

local ORDER = { missing = 1, outdated = 2, offline = 3, waiting = 4, current = 5 }

-- One row per group member:
--   name, class, unit, state ("current", "outdated", "missing", "waiting", "offline"),
--   v (version or nil), r (readiness from this question, or nil), range (true/false/nil)
function Versions:Rows()
    local rows = {}
    for _, name in ipairs(AF:GroupMembers()) do
        local unit = AF:GroupUnit(name)
        local v = name == AF.playerName and AF.VERSION or versions[name]
        local r = ready[name]
        if r and (not queriedAt or r.at < queriedAt) then r = nil end
        local online = not unit or UnitIsConnected(unit)
        local state
        if not online then
            state = "offline"
        elseif not v then
            state = waiting and "waiting" or "missing"
        elseif v < newest then
            state = "outdated"
        else
            state = "current"
        end
        table.insert(rows, {
            name = name, unit = unit, class = unit and select(2, UnitClass(unit)),
            state = state, v = v, r = r, range = unit and online and InRange(unit) or nil,
        })
    end
    AddBuffs(rows)
    table.sort(rows, function(a, b)
        if ORDER[a.state] ~= ORDER[b.state] then return ORDER[a.state] < ORDER[b.state] end
        return a.name < b.name
    end)
    return rows
end

-------------------------------------------------------------------------------
--  Reminders (officers): a whisper to every guild member in the group who is
--  outdated or hasn't got the addon
-------------------------------------------------------------------------------
local function Whisper(text, target)
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    return pcall(send, text, "WHISPER", nil, target)
end

function Versions:Remind()
    if not AF.Ledger:CanRecord() then return AF:Print("Only officers can send reminders.") end
    if AF:IsChatLocked() then return AF:Print("Chat is locked right now (combat); try again after the pull.") end
    local sent = 0
    for _, row in ipairs(self:Rows()) do
        if row.name ~= AF.playerName and AF.Standings:All()[row.name] then
            local text
            if row.state == "outdated" then
                text = REMIND_TEXT:format(Versions.String(row.v), Versions.String(newest))
            elseif row.state == "missing" then
                text = INSTALL_TEXT
            end
            if text and Whisper(text, row.name) then sent = sent + 1 end
        end
    end
    AF:Printf(sent > 0 and "Reminded %d player%s." or "Nobody to remind.", sent, sent == 1 and "" or "s")
end

-------------------------------------------------------------------------------
--  Saying our version
-------------------------------------------------------------------------------
function Versions:Enable()
    C_Timer.After(10, function() AF.Comm:Send("VER", AF.VERSION, "GUILD") end)
    wasInRaid = IsInRaid()
end

AF:RegisterEvent("GROUP_ROSTER_UPDATE", function()
    local inRaid = IsInRaid()
    if inRaid and not wasInRaid then
        C_Timer.After(3, function() AF.Comm:Send("VER", AF.VERSION, "RAID") end)
    end
    wasInRaid = inRaid
    AF:Fire("VERSIONS_UPDATED")
end)
