# Guild Management System (GMS) — Spec (v3.6.4)

## Goal
A WoW addon that helps officers distribute raid loot by showing each player's **effort**:
raiding, guild bank contributions, honor and end-game dungeons with guildies over the last 4
raid weeks. The addon ranks nothing and decides nothing. It shows information, and the
GM/officers decide who gets each item.
Every guild member installs it. Members report data, and officers' clients are authoritative.
Around that core it has guild tools: wishlists, crafters, attunements, layers, raid check and
raid invites.

## Decisions
- Game version: WoW: Forever (client 1.60.1, interface `16001`). Midnight-style addon
  restrictions apply: values can be secret and addon/chat messages locked down during encounters.
- Officers are guild ranks `0..officerRank` (the GM sets `officerRank`, default 1). Only officers
  record effort, edit config and send snapshots. No officer or public notes are used.
- Any guild can use it. What counts and which features are on is set per guild in guild setup.
- Name: Guild Management System (GMS), formerly AdventForever. Commands `/gms` and
  `/guildmanagement`. Addon message prefixes `GuildMgmtSys` (main lane) and `GuildMgmtSysBk`
  (bulk lane). Folder and SavedVariables: `GuildManagementSystem`, `GuildManagementSystemDB`.
- Distributed on CurseForge, Wago and GitHub Releases (tag `v*` builds and uploads).

## Guild setup
- The GM gets the guild setup window the first time (`/gms setup`, or Options → Guild setup).
  Officers can change it later; only the GM changes `officerRank`.
- It holds:
  - officer ranks
  - effort sources (raids, guild bank, honor, dungeons): on or off, each with its cap
  - features: officer votes, wishlists, crafters, attunements, layers, guild loot, loot
    priorities, award reasons, tier token info, wins shown to raiders (guild loot and wins shown
    to raiders are off by default, the rest on)
- It is part of the shared config, so it reaches every member. `setupDone` is set once saved.
- A switched-off source counts 0 everywhere and shows as "off". A switched-off feature disappears
  from the window, the minimap menu and tooltips.

## Effort score
- Each raid week gets a **weekly score**. The week is keyed to the server's weekly reset.
- **Effort = sum of the last 4 weekly scores.** This is a rolling window: at reset the oldest
  week drops off and a new week starts at 0. There is no decay.
- Weekly score = raids + guild bank + honor + dungeons, each capped. Defaults 50 + 30 + 20 + 20,
  so 120 a week and 480 over 4 weeks. The caps may total at most 200.
  - **Raids (default max 50):** cap × (guild kills the player was present for ÷ guild kills
    that week). The current week's raid score changes as the guild kills more bosses.
    - **Guild kill:** a raid boss kill where at least `guildKillShare` % (default 75) of the
      raid are guild members. The kill event stores the guild members present and the raid size.
    - **Recording:**
      - Every officer in the raid records the kill.
      - A raid leader who isn't an officer sends a report (`KILL`). It's stored and resent
        until an officer confirms it (`KILLACK`).
      - All of them derive the id `kill:<encounter>:<difficulty>:<raid leader>#<week>`, so the
        kill counts once. A repeat kill of the same boss by the same group in a week also
        counts once.
    - **Bench:** officers keep a bench list (`/gms bench`). Each officer recording a kill also
      records bench credit (`bench:<kill id>:<player>#1`) for the players on their list.
    - **Fallback:** if ENCOUNTER_END values are secret, an officer records the kill with
      `/gms kill <boss>`.
  - **Removing events:** officers click an event in the Log tab to record a `void` for it. The
    event stops counting everywhere; nothing is deleted.
  - **Guild bank (default max 30), gold and items combined:**
    - Gold: configurable rate, default 1 point per 50g. Withdrawals count against it.
    - Items: only items on the officer-maintained **wanted list** count. Each entry has an
      item ID and a gold value per unit, converted at the gold rate. Unlisted items give 0.
    - Two sources:
      - **The player's own client:** while the bank is open it counts confirmed gold deposits
        and withdrawals, and wanted items leaving or entering the bags. It reports the net
        when the bank closes (`DEP`). Reports are stored until an officer confirms them
        (`DEPACK`), and resent on login and every 5 minutes.
        - Officers record a report as `dep:<player>#<report number>`, so every officer
          recording it makes the same event.
      - **Officers' clients:** they read the money log and item logs when opening the bank and
        record entries the ledger doesn't have. Entries are matched by player, amount and time
        within 3 hours, because the log only gives times to the hour.
    - Per player, week and kind (gold, or each wanted item), the larger of the two sources'
      net totals counts, never their sum.
  - **Honor (default max 20):** linear from 0 to the cap against a configurable weekly honor
    target (`honorTarget`, default 5,000).
    - Reported by the player's own client (`HON`, confirmed with `HONACK`). It takes the
      highest of:
      - the weekly honor stats (`GetPVPThisWeekStats`)
      - honor-currency gains it saw itself (kept per character and week)
      - the currency's own "earned this week", if the client fills it in
    - **Honor is a currency on Forever.** The client's constants don't give its ID, so it's
      found by name (`HONOR` / `HONOR_POINTS`, plus the English names): from the known IDs
      (1901, 1792, 392), the currency list, and any currency that changes. The ID found is
      remembered (`prefs.honorCurrency`). Gains are the amount going up, never the event's
      change alone, so spending doesn't lower the score and two IDs for the same honor count
      once. Watching starts 15 s after login, because amounts can read 0 until then.
    - Sent when it changes, at most every 5 minutes, until an officer confirms it.
    - Officers record `honor:<player>:<week>#<honor>`; the highest report per player and week
      counts.
    - **Self-reported, no verification (decided).** Forever has `GetInspectHonorData` but no
      `RequestInspectHonorData`. The inspect data holds only today/yesterday/lifetime values, with
      no weekly figure, and in testing it returned zeros. So there is no reliable way to check
      another player's weekly honor.
    - Honor earned before a player runs the addon, or on a client without it, isn't seen.
      Officers can correct it with `/gms adjust <name> honor <points>`.
  - **Dungeons (default max 20):** see build step 11.
  - **Corrections:** `/gms adjust` adds a +/− correction per player, week and category on top
    of the tracked value. The result is clamped to 0..cap.
- Effort is information only. It never decides or blocks loot.
- **Mains and alts:** effort is per player (main + alts).
  - **Counting:** raids count a kill once if any of the player's characters was present or
    benched. Bank gold, honor and corrections add up across characters. The caps apply per
    player.
  - **Linking:**
    - Account-wide saved data tells the addon which characters share an account. The first is
      the main; the player can change it.
    - Each character reports only itself (`LINK`, confirmed with `LINKACK`). Officers record
      `link:<character>#<time the main was chosen>`, so resends dedupe.
    - An officer's client records its own account's characters directly.
    - Officers link and unlink by hand. Officer links beat self reports; the newest wins
      within each. Links never expire.
  - **Raiders:** snapshots carry `m = { alt = main }`. Alts show their main's effort, marked
    "alt", and the Effort tab hides alts by default.

## Storage
An officers' event log is the only real record. Raiders see snapshots of it, and exports
keep a copy outside the game. Nothing is stored in guild notes.

- **Saved data per guild:**
  - `GuildManagementSystemDB = { account, guilds, chars }`:
    - `account`: what belongs to the WoW account: prefs (look, scale, minimap, login summary,
      update card, honor currency), window positions, characters, the chosen main and link
      confirmations.
    - `guilds["Guild-Realm"]`: everything else (ledger, config, snapshot, pending reports,
      bench, wishlists, crafters, attunements, ...), one compartment per guild.
    - `chars["Name-Realm"]`: each character's guild, last seen.
  - `AF.db` reads and writes the account keys in `account` and everything else in the current
    guild's compartment. The guild is only certain a moment after login; a character's first
    login, or a guild change, can ask for one reload (`GMS_RELOAD`).
  - **Migration from AdventForever (once):** `AdventForeverDB` is moved into the guild's
    compartment on the first login, if that compartment has no ledger yet. Guild loot stays on
    for that guild and setup counts as done. v1 leftovers and the removed recruit list are
    dropped when a compartment is opened.
- **Ledger: event log in officers' saved data.**
  - Every officer action is an event: unique id, officer, server time, raid week, kind, details.
    Kinds:
    - `cat`: player, category, correction points (+/−). The latest event per
      week/player/category wins.
    - `won`: player, item, response (or "Guild bank" / "Disenchant" for an item given to the
      guild, step 15), `y` = award reason (step 20, optional). Information only.
    - `dep`: player, source (`self` or `log`), copper or item ID and count (negative =
      withdrawn).
    - `kill`: encounter, boss name, difficulty, guild members present, raid size.
    - `bench`: player, kill id (counts as present).
    - `honor`: player, this week's honor as their client reported it (the highest counts).
    - `link`: character, main, source (`self` or officer), time the main was chosen.
    - `run`: dungeon run report (step 11).
    - `void`: id of an event to ignore.
  - Scores, the per-category breakdown and items won are all worked out from the events.
  - Ids are `<install token>#<sequence>`, or a derived id where several officers record the
    same thing (kills, deposits, honor, links), so a reinstalled client never reuses an id and
    duplicates merge.
  - New events go to the guild as they happen (`EV`). On login an officer sends a digest
    (`SYNCQ`: per week and origin, count and highest sequence). Online officers reply with their
    own digest (`SYNCD`) and the events it is missing (`EVS`, 15 per message), so both sides
    catch up. Events are never edited, so merging is a union.
  - Only events from officers (rank ≤ `officerRank`) are accepted. Events are kept 8 weeks;
    `link` and `void` events never expire.
  - The ledger doubles as the audit log (`/gms log`).
- **Snapshots, saved by every client:** `{ by, t, week W, s = { player = "w1,w2,w3,w4" } }`,
  newest week first, where `W` is the raid week `w1` belongs to.
  - A detail field `sd` adds per player the per-category split for each of the 4 weeks, and
    this week's raw numbers: guild kills attended/total, gold counted, honor, runs. Raiders' Me
    tab uses it. Older 3-number snapshots are still read.
  - `m` carries the alt map, `g` the bank goal progress.
  - An officer sends one to the guild (`SNAP`) 10 s after recording something (several changes
    in a row become one), 45 s after login (once the ledger sync has landed), and after changing
    the caps.
  - A raider who logs in asks for one (`SNAPQ`). One online officer answers on GUILD; the
    others hold back.
  - Clients keep the newest snapshot from an officer. Readers shift it by the resets since `W`,
    so it rolls over at reset.
  - Officers' own views always come from their ledger. Raiders' views come from the snapshot,
    labelled with its time and the officer who sent it.
- **Export / import:** `/gms export` turns the whole ledger into a text string to keep outside
  the game. `/gms import` merges a string back in (duplicates are skipped) and shares the new
  events with online officers.
- **Known limits:**
  - The ledger lives only in officers' WTF folders. Every officer holds a full copy, and
    exports are the backup.
  - Weeks older than 8 weeks keep only what the archive holds (step 19): scores per category,
    awards and wanted-item deposits, not the events behind them.
  - A raider with no saved snapshot sees nothing until an officer is online.
- **Shared config:** guild setup (officer ranks, sources, features), category caps, gold rate,
  wanted list and goals, honor target, guild kill share, dungeon settings, final bosses,
  attunements, loot priorities, popup timeout. Versioned and broadcast to the guild (`CFG`).
  - An officer on an older version drops keys it doesn't know when it saves. Newer clients keep
    their own `prios` and feature switches when an incoming config leaves them out.
  - Editable by officers. Clients accept config only from officers, and accept `officerRank`
    only from the GM.
  - A client asks for newer config on login (`CFGQ`); one online officer answers.

## Communication
- `C_ChatInfo.SendAddonMessage` on GUILD/RAID/PARTY/WHISPER with a compact serializer
  (length-prefixed strings) and chunking to 250 bytes per message.
- A throttled send queue per lane: a burst, then about 1 message a second. The **bulk lane**
  (`GuildMgmtSysBk`, crafters directory) only sends while the main lane is empty, so it never
  delays loot, votes or effort. Sending waits out `C_ChatInfo.InChatMessagingLockdown()`;
  a message that can't go out for 120 s is dropped whole.
- **Players who go offline (step 17):** "has gone offline" (or a "No player named ..." reply to
  one of our whispers) marks them offline: everything queued for them is dropped and no new
  whispers are queued until they come online or message us. "No player named ..." lines for
  our own whispers (within 5 s) are hidden.
- Messages a client doesn't know are ignored, so new message kinds and new fields are safe
  with older clients.

## Loot flow
1. The **loot authority** is the master looter when master loot is on, otherwise the raid leader.
   - With master loot: opening a corpse broadcasts every item at or above the loot threshold
     (`ITEMS`).
   - Without master loot: the authority starts a session by hand, with `/gms item <links>`, for
     items someone is holding. With guild loot on, items the raid leader receives start
     sessions by themselves.
2. Members get a popup: Main spec / Off spec / Pass, with their equipped item(s), the item level
   difference, an optional note, their wishlist rank, a "can't use" warning and their effort.
   Responses go to the council (`RESP`).
3. The loot window lists **every** raid member's response, grouped Main spec → Off spec →
   Pass → no answer, and within each group sorted by effort, highest first. The sort is a
   visual aid only. For each player it shows:
   - effort score and the per-week breakdown (tooltip adds the per-category split)
   - items won this raid week
   - the item they have equipped in that slot, with the item level difference
   - pieces of the item's set they wear (step 15)
   - note, wishlist rank, "can't use", officer votes
4. An officer clicks any player to award; anyone can be awarded anything (`AWARDED`).
   - Master loot gives the item. It is recorded once it reaches the player.
   - Without master loot, the award is recorded and the holder trades it (step 6).
   - Every award is announced in raid chat and recorded in the ledger as `won`.
   - **Guild bank / Disenchant** buttons give the item to whoever banks or disenchants it
     (step 15).

## Windows
- **Main window** (`/gms`): sidebar with Effort, Me, Rules, Bank, Wishlist, Crafters,
  Attunements and Layers; officers also get Loot history, Log and Options. Switched-off features
  are hidden.
- **Effort:** every member with this week, the three previous weeks and total effort.
  Sortable, with a raid-only filter and "Show alts". The tooltip shows the per-category
  breakdown for officers.
- **Me:** the total with a bar; this week per category with what's still available; the last 4
  weeks; reports still waiting for an officer; "Make this my main"; the login summary switch.
- **Rules:** how each category is scored, filled in with the guild's current numbers.
- **Loot history (officers):** every award for the last 4 weeks, 8 weeks, 3 months or all
  (older than 8 weeks from the archive), filterable by player or item.
  - **Items view:** when, player, item and response. Clicking an award removes it.
  - **Players view:** items won, Main/Off spec counts and the latest item. Sortable.
  - The loot window tooltip adds "Won in the last 4 weeks: N" and "Last item: <item>, N weeks
    ago".
- **Loot**, **Trades**, **Check group**, **Raid invites**: see the build steps.
- **Options (officers edit, everyone views):** caps, rates, honor target, guild kill share,
  dungeon settings, popup timeout; guild setup has its own window.
- **Settings page** in the game's settings: open GMS and its windows, minimap button, login
  summary, update card, guild window tab, look and window size.
- **Cards:** the login summary and the update card stack in a corner and fade.
- **Guild window tab:** a GMS tab below the Guild & Communities window's side tabs (step 14).
- **Version check:** on login and raid join; outdated players get the update card once per
  session (it can be turned off) and a chat line.

## Look
- All UI goes through `Theme.lua`: windows, lists, buttons, edit boxes, checkboxes, text,
  sidebar, cards.
- **Modern:** a flat dark theme in the GMS green. With EllesmereUI installed, its skinning styles
  GMS instead, with the EllesmereUI theme, font and accent.
- **Classic (Blizzard):** the game's own frames, buttons, checkboxes, input boxes, status bars
  and font, with gold headings.
- Per player (`prefs.style`, `/gms style`); changing it reloads the interface.
- **Window size:** 70–130 % in 5 % steps (`prefs.scale`, `/gms scale`), applied to every window.

## Build steps
1. Effort storage (officers' ledger, snapshots for raiders, export/import), standings window,
   loot UI, options (caps), manual `/gms adjust`. **Done, awaiting in-game test.**
2. Guild bank: self-reported deposits, officer log reads, gold rate, wanted list (Bank tab).
   **Done, awaiting in-game test.**
3. Raid tracking: guild kills (75% rule), presence per player, bench credit, `/gms kill`,
   removing events from the Log tab. **Done, awaiting in-game test.**
4. Honor: self-reported weekly honor and the honor target. **Done, awaiting in-game test.**
   Self-reported only: Forever can't request another player's weekly honor. (Currency lookup:
   step 16.)
5. Mains and alts. **Done, awaiting in-game test.**
   - The Recruit tab (guildless players found through a hidden realm channel) was removed in
     3.0.0, with its saved list.
6. Trade tracking (no master loot). **Done, awaiting in-game test.**
   - **Holder detection:** `AWARDED` carries the item and a trade flag. The client with the item
     in its bags, looted in the last 2 hours (read from its own "You receive loot" lines),
     becomes the holder and sends `HOLD`.
   - **Trades window:** time left, in range, a Trade button, and the item placed into the trade
     automatically. Warnings at 30 and 10 minutes left.
   - **Done:** the completed trade (`ERR_TRADE_COMPLETE`) sends `TRADED`. The loot window shows
     waiting / delivered / holder unknown. Pending trades survive a reload.
7. Notes and item level difference. **Done, awaiting in-game test.**
   - The popup has an optional note (max 60 characters), sent with the response; chat codes
     are stripped.
   - Item level difference against the weaker equipped item of the slot (rings, trinkets,
     one-handers), or "empty slot". It's shown in the popup and in the loot window's Equipped
     column, and the loot window has a Note column.
8. Officer votes. **Done, awaiting in-game test.**
   - The council is the loot authority plus every officer in the group.
   - Raiders whisper responses to the whole council.
   - Officers keep a copy of each session (from `ITEMS`) and vote (`VOTE`, whispered to the
     council). One vote per officer per item; voting again takes it back.
   - Only the authority awards; for others a row click votes. Votes don't change the sort.
   - `/gms test` adds two fake officers' votes.
9. Goals for wanted items. **Done, awaiting in-game test.**
   - `config.goals[itemID] = { n = target, since }`. Re-adding an item keeps `since`, so progress
     continues; a goal of `0` removes it.
   - Progress = guild-wide deposits since `since` (`Ledger:DepositedSince`, larger source per
     character and week). Raiders get it in snapshots (`g`).
   - The Bank tab shows the Goal column (bar, "120 / 200" or done), with unfinished goals sorted
     first by how much is still needed.
   - Limit: deposits older than 8 weeks fall out of the ledger.
10. Login summary. **Done, awaiting in-game test.**
    - 55 s after login, guild members with numbers (officers' ledger, or a snapshot) get a card:
      - last week, this week and effort
      - open raid, bank, honor and dungeon points
      - the most-needed bank goal
      - pending trades
    - Click opens the Me tab. It fades after 15 s (it stays while hovered).
    - Per-player off switch in the Me tab and the settings page (`prefs.nudge`); `/gms nudge`
      shows it on demand.
11. Dungeons with guildies. **Done, awaiting in-game test.**
    - 4th category, `dungeonMax` 20, so the weekly max is 120 and effort max 480. Caps may total
      up to 200.
    - A run is a final-boss `ENCOUNTER_END` of an end-game dungeon in a party instance with
      ≥ `dungeonGuildMin` (3) guild members. It's worth `dungeonPerRun` (2.5) points, rounded
      down per week.
    - Final bosses: a built-in table of the end-game dungeons (BRD, LBRS, UBRS, Dire Maul
      East/West/North, Scholomance, Stratholme; encounter IDs as Forever reports them), plus
      `config.finals` that officers mark with `/gms final`. Marking also counts a kill from the
      last 15 minutes. Leveling dungeons don't count.
    - Each guild member in the group reports (`RUN`, resent until `RUNACK`); officers record
      `run` events (`dun:<reporter>#<kill time>`).
    - The ledger groups reports into runs: same dungeon, within 10 minutes, a shared player.
      Runs count per player (main + alts).
    - Snapshot detail carries 4 numbers per week plus runs (older 3-number snapshots are
      still read).
12. Guild tools (AdventForever 2.0.1–2.0.5). **Done, awaiting in-game test.**
    - **Guild loot (feature, off by default):** in a guild raid (raid instance, guild share at
      least the guild kill share), raiders auto-pass on Rare and better and the raid leader
      auto-needs; items the leader receives start loot sessions. Officers are warned when
      someone else rolls on or wins such an item.
    - **Versions and raid check** (`/gms check`): every group member's version (`VER`, `VERQ`),
      durability, flasks / elixirs and range (`RDY`). Officers can whisper a reminder to
      outdated players and players without the addon.
    - **Wishlists** (feature): up to 10 ranked items, sent only to officers (`WISH`, `WISHQ`).
      Shown at loot time, in item tooltips (officers; raiders see their own rank) and in a guild
      overview.
    - **Crafters** (feature): the guild's profession directory. Recipes are read when a
      profession window opens and are only ever added; skills at login. Shared on the bulk lane
      (`PROFD` digest, `PROFH` offers, `PROFQ` request, `PROF` data). Characters not updated
      for 120 days are dropped. Item tooltips show "Crafted by".
    - **Attunements** (feature): a grid of who is attuned to what (`ATT`, `ATTQ`). Built in:
      UBRS, Molten Core, Onyxia, Blackwing Lair, Naxxramas. Officers remove built-in ones and
      add new ones (quest IDs or a key item).
    - **Can't use:** armor type, weapon type, shields, relics and class-restricted items, in the
      popup and the loot window.
    - **Minimap button** (left-click window, right-click menu, drag) and **raid invites**
      (`/gms invite`: by rank and minimum effort, or a whisper keyword).
13. GMS for every guild (3.0.0). **Done, awaiting in-game test.**
    - Renamed to GMS (`/gms`, new prefixes; GMS doesn't talk to AdventForever), guild setup,
      per-guild saved data and the one-time AdventForever migration (see Storage).
    - Switched-off categories count 0; switched-off features are hidden.
14. Looks and help (3.0.1–3.1.1).
    - Welcome guide on the first login (`prefs.welcomed`, `/gms welcome`) and the settings page.
      **Awaiting in-game test.**
    - Classic (Blizzard) look. **Tested in game.**
    - GMS tab on the Guild & Communities window: found by position below the lowest side tab
      (Forever's window has a tab beyond the known names), sized like Blizzard's own tabs, shown
      while a guild is selected. Opens GMS docked next to the window (`prefs.guildDock`).
      **Tested in game.**
15. Layers, set pieces, guild awards (3.2.0). **Done, awaiting in-game test.**
    - **Layers** (feature): layers on Forever are per zone. A client reads its layer from the
      GUID of NPCs it hovers, targets or sees on nameplates
      (`Creature-0-<server>-<map>-<zone UID>-<npc>-<spawn>`); a changed ID needs a second NPC to
      confirm it. It shares it (`LAY`, asks with `LAYQ`, at most every 60 s). Reports are kept in
      memory only. The Layers tab lists online guild members by zone and layer; clicking whispers
      them. It only shows; it never invites or moves anyone.
    - **Set pieces:** `RESP` carries `s`, how many pieces of the item's set the player wears (set
      ID from item info, pieces from the loot journal). Shown as "3/8 set".
    - **Guild bank / Disenchant awards:** `AWARDED` and `won` carry `p`. These awards are in the
      loot history but don't count as the player winning the item (`Ledger.FOR_GUILD`).
    - **Raid check:** tanks / healers / DPS count (`RDY` carries the role) and missing class buffs
      (Fortitude, Arcane Intellect, Mark of the Wild).
    - **Window size** (`/gms scale`) and **help** (`/gms discord`: the Discord link, ready to copy).
16. Honor currency by name (3.2.1–3.2.2). **Tested in game.**
    - The honor currency is found by name and tracked by its amount (see Honor). `/gms debug`
      shows the IDs found.
    - The update card can be turned off in the settings (`prefs.updateCard`).
17. Offline players (3.2.3). **Done, awaiting in-game test.**
    - No more whispers to players who went offline, and no "No player named ..." lines for
      GMS's own whispers (see Communication).
18. Housekeeping (3.3.0). **Done, awaiting in-game test.**
    - This spec rewritten for GMS, and `docs/TESTING.md` with a checklist per module.
    - `/gms selftest`: a copyable report for bug reports (version, client, guild, rank, config
      and features, ledger events per week, snapshot age and sender, reports still waiting for
      an officer, and the `/gms debug` lines). It only reads; nothing is changed or sent.

19. Long-term history (3.3.0). **Done, awaiting in-game test.** Swapping weeks
    between officers can only be tested once real weeks leave the ledger, 8 weeks after a week
    ends.
    - **Archive** (`Archive.lua`, officers' saved data, per guild): `archive = { v = 1, weeks }`.
      When a week leaves the 8-week ledger (at login), it is first summarised from the full
      ledger (`Ledger:WeekSummary`), then its events are dropped. An entry holds:
      - `s`: per main, points per category (capped), as `"raid,bank,honor,dungeon"`
      - `l`: every live award: character, link, response or purpose, time, officer
      - `d`: wanted items deposited (larger source per character); `g`: for goals that
        started that week, the deposits from their start
      - `c`: the caps then; `n`: ledger events it was built from; `h`: checksum; `by`, `t`
      - Removed events are left out; alts count under their main.
      - A week that fails to archive keeps its events and is tried again next login.
    - **Scores are kept as they were (decided):** archived weeks keep their points when the caps
      change later. Storing raw numbers to recalculate was 2–3 times bigger and would make old
      weeks shift.
    - **One version per week:** each officer archives from its own ledger. Versions differ only
      when an officer missed events; the one built from more events wins (a tie: the higher
      checksum), so every officer ends up with the same week. Weeks are replaced whole, never
      merged (they hold totals, not events).
    - **Sync:** `ARCQ { [week] = "n:h" }` to the guild 60 s after login. Officers with better
      weeks whisper them (`ARC { w, a }`, bulk lane, spread over 8 s) and answer with their
      own `ARCQ` when the sender has better ones. Only weeks that have left the ledger are
      accepted, only from officers, and the checksum must match.
    - **Loot history:** 4 weeks, 8 weeks, 3 months or all. Archived awards show as archived and
      can't be removed. The loot window tooltip (officers) adds the player's last item.
    - **Bank goals:** `Ledger:DepositedSince` adds archived deposits (`d` for whole weeks after
      the goal started, `g` for the week it started), so goals no longer go backwards.
    - **Web export:** `/gms export web`, JSON format version 1, documented in `docs/EXPORT.md`.
      `/gms export` / `/gms import` (the full ledger backup) are unchanged.
    - `/gms archive` shows what's archived. `/gms archive test` builds a throwaway archive
      from the current ledger, checks it against the ledger (scores, awards, deposits, goals,
      checksum, sending it) and shows it as the web export. Nothing is saved or sent.
    - `/gms selftest` shows the archive's size.

20. Loot council depth (3.3.0). **Done, awaiting in-game test.**
    - **Loot priorities** (feature `lootPrio`, on): `config.prios[itemID] = { o = order, t = note }`,
      up to 100 characters each, no chat codes. In the shared config, not the ledger: they're
      guild rules that last until changed (the ledger keeps 8 weeks), the newest wins, and
      every member gets them. The order is free text ("Warrior tank > Rogue"): class names (the
      client's language, or English class tokens) and the words tank / healer / dps are
      recognised; anything else is shown as written. Officers edit them on the Priorities page
      or from the loot window's Priority button. Shown at the top of the loot window, as
      "prio N" on matching players' rows (the sort doesn't change) and in item tooltips for
      officers.
    - **Award reasons** (feature `awardReasons`, on): the award dialog offers Upgrade, BiS,
      Off spec, Alt, Other (optional). Stored as `y` on the `won` event, sent in `AWARDED`
      and the raid announcement, shown in the loot history (Reason column, tooltips), the
      archive and the web export (`reason`). With the feature off, the plain yes/no popup.
    - **Tier tokens** (feature `tokens`, on): no API says which piece a token becomes, and a
      built-in table (AQ40, Naxxramas) wouldn't cover Forever's own tokens (decided: no
      table). A token is an epic with a "Classes:" line that can't be equipped. The loot window
      shows "Token for: <classes>"; raiders' answers carry `ts` = the sets they wear 2+ pieces
      of ("setID:count", at most 3), shown as "wears N pc" and in the row tooltip with the set
      name and size.
    - **Wins shown to raiders** (feature `winsPublic`, off): snapshots carry
      `wn = { [main] = "itemID,itemID" }`, this week's wins without guild-bank and disenchant
      awards. Raiders see them in the Effort tooltip, the Me tab and the loot window (a raid
      leader who isn't an officer). Read only while the snapshot is from this week.
    - Guild setup is taller (672 since step 22) for the new switches.

21. Guild analytics (3.4.0). **Done, awaiting in-game test.**
    - **Analytics tab** (feature `analytics`, on; everyone sees it, "This week" is officers
      only), `/gms analytics` or `/gms stats`. Two views:
      - **Roster** (the game's guild roster, so every member, with or without GMS): members,
        online now, at the level cap, played in the last 7 / 30 days (only when the client gives
        last-online times); class bars in class colors for all / max level / online; levels in
        steps of 10 with the cap on its own; members per rank. Hovering a bar lists the names.
      - **Guild** (what GMS collects): professions from the crafters directory (members, and how
        many are at the highest skill seen), attunements (attuned of those known), effort per
        player in quarters of the maximum with the average, and for officers this week from the
        ledger (`Ledger:WeekStats`: guild kills, awards, items to the guild, dungeon runs, bank
        deposits, players with points).
    - The roster now keeps level, rank name, zone and days since last online per member.
    - The level cap is the game's (`GetMaxLevelForPlayerExpansion`), or the highest level in the
      guild if that's higher.
    - No new messages and no saved data.
    - `Theme.Bar` takes a fixed color (`bar:SetColor`) for class colors.

22. Recruiter (held back: not in 3.4.0). **Done, awaiting in-game test.** Its guild setup
    switch is commented out in `Config.FEATURES`, so `Recruiter:CanUse()` is always false and
    the page, `/gms recruit` and its messages stay off until it is released. (Recruiting came back after
    3.0.0 removed the hidden-channel Recruit tab; this is a new design.)
    - **Feature `recruiter`, off by default.** The page shows for characters whose rank may
      invite (`CanGuildInvite`); `/gms recruit`.
    - **One click per step (decided):** the game only allows `/who` and guild invites from a
      click or key press, and one whisper per click keeps it polite. At least 3 s between two
      players. `/gms recruit search` / `next` work from a macro key bind.
    - **Search:** level range, class, zone, guildless only. Each search is one `/who` for 5
      levels (it returns at most 50); the next click searches the next 5. Results skip guild
      members, players in a guild (when guildless only), the blacklist and anyone contacted
      in the last 14 days. The game's Who window is kept shut while GMS reads the results.
    - **Contact:** whisper, whisper + invite, or invite only. The whisper comes from a shared
      template (`config.recruit = { { n, t } }`, up to 5, officers edit; `{player}`,
      `{guild}`, `{class}`, `{level}`, `{zone}`). "Next" contacts the next new player; a
      row click contacts that one, shift-click blacklists.
    - **Replies:** whispers back from contacted players (this session) with Invite and Block.
    - **Shared lists** (`AF.db.recruit`, per guild): contacted (14 days) and blacklist.
      `REC { k = "c" | "b", n, t, on }` to the guild as they change; a recruiter logging in
      sends `RECQ`, and other recruiters whisper their lists (`REC { k = "list", c, b }`,
      bulk lane). Lists merge by the newest time; taking someone off the blacklist only
      reaches recruiters online at the time.
    - Newer clients keep `recruit` when an older officer's config leaves it out.
    - `/gms debug` shows whether this client has the /who and guild invite functions and
      whether your rank may invite.

23. More from A.X.I.O.M.'s ideas (3.4.0). **Done, awaiting in-game test.** (Ideas
    only; its code is "All Rights Reserved".)
    - **Members view** in Analytics: every member in a sortable, searchable list (name, level,
      class, rank, last online, effort), alts under their main, "on an alt" when the main is
      offline but an alt is online, and an Export CSV button.
    - **Member history** (`History.lua`): the game's guild event log (joins, leaves, kicks,
      invites, promotions, demotions) saved per guild by every client that reads it, up to 500
      events, so it outlasts the game's short log. The log gives "N hours/days ago", so an event
      matches a saved one with the same kind, players and rank within 36 hours. A History view
      in Analytics and "Last 30 days: N joined, M left" under Members; both only when the
      client has the API (`/gms debug` says).
    - **Class needs:** `config.needs = { classFile = count }` and `needsNote`, set by
      officers with Analytics' Needs button. Analytics shows "need N" on the class bars and a
      "Looking for" line; the recruiter (when released) marks those players "needed" and
      contacts them first.
      Newer clients keep both when an older officer's config leaves them out.
    - **Wowhead links:** item boxes and `/gms wish` take a link, `item:12345`, a Wowhead address
      (`.../item=12345/...`) or an item ID (`AF:ItemID`).
    - **Wishlist card:** when an item on your wishlist drops, a card says so (besides the sound
      and the popup).

24. Guild achievements (3.5.0). **Done, awaiting in-game test.**
    - **Guild firsts, PvE and PvP only (decided: no officer-made ones).** Each is won once, by
      whoever gets there first:
      - Levels: the level cap; the cap per class
      - Professions: `300` in each profession (crafters directory)
      - Attunements: each attunement in the Attunements tab
      - Raids: the first guild kill of each boss, as bosses are killed (no list of future bosses)
      - Dungeons: the first counted run of each end-game dungeon
      - PvP: the weekly honor score full; 1,000 / 5,000 / 10,000 / 25,000 lifetime honorable
        kills; PvP ranks 6, 8, 10, 12, 13, 14; a win in Warsong Gulch, Arathi Basin, Alterac
        Valley (and any other battleground) with 5+ guild members on the team
      - Guild: 50 / 100 / 200 / 500 members, the first bank goal reached, the first full-score week
    - **Recording:** officers record `ach` ledger events (never expire). Origin
      `ach:<key>:<who>`, sequence = time, so each candidate is its own event; the earliest per
      key wins (ties: by name). Officers can't disagree once synced.
    - **Sources:** officers' clients scan (at most every 10 s, after the login sync) the roster,
      crafters, attunements, bank goals, this and last week's scores and honor, and the
      ledger's first kills and runs. What only the player's client sees is reported with
      `ACHR` (level-up to the cap with its exact time, PvP rank, lifetime honorable kills,
      battleground wins with the guild members on the team), resent until `ACHACK`.
    - **Before GMS:** an officer client's first scan gives achievements players already had
      (levels, professions, attunements, member counts) to all of them, `pre` with time 0,
      shown as "before GMS". Kills, runs, weeks and goals come from the ledger, so they're real
      firsts.
    - **Raiders:** snapshots carry `ac = { [key] = "time;who;count;extra" }` (no group names, to
      keep it small).
    - **New firsts** (from the last 10 minutes): a card for everyone with GMS online (click opens
      the tab), and one guild chat line "[GMS] Guild first! ..." from the officer whose record
      won (feature `achAnnounce`, on), once per achievement.
    - **Achievements tab** (feature `achievements`, on; everyone): by group, earned or "Nobody
      yet", with who, when and the group in the tooltip; filter all / earned / still open.
      `/gms achievements` or `/gms ach`.
    - `/gms debug` says whether this client has the PvP rank, honorable kill and battleground
      winner functions.
    - **"Before GMS" fixed (3.6.4):** the first scan only gives "before GMS" records when the
      guild has no achievements at all (not on every officer's first scan). They carry `bt`,
      when they were made, and win only if `bt` is before the first real record; older ones
      without `bt` lose to any real record.
    - **Quiet records (3.6.3):** an officer's first scan after login may find firsts other
      officers recorded but its sync hasn't brought yet. What's already true then is recorded
      with `q` (no card, no guild chat line; snapshots list them in `aq`); the earliest record
      still wins. Kills and runs (exact times, same ids on every officer) and players' own
      reports are announced as before.
    - **One achievement whatever the language (3.6.2):** professions are stored under their
      English name (`Professions.Canonical`: the skill line ID where the client gives it,
      otherwise the name in French, German, Spanish, Italian, Portuguese or Russian), saved and
      received crafter data is converted, and achievement keys merge (`prof:<English>`,
      `bg:<instance ID>`; the earliest record wins). Names are shown in the client's language
      (`Professions.LocalName`).
    - **Only members with GMS installed can win (decided, 3.6.1).** Every client remembers
      the guild members it has had an addon message from (`AF.db.gmsUsers`, `AF:HasGMS`);
      the level scan skips the rest, and kills, runs and battleground wins credit only their
      members with GMS (older records are filtered when shown). Guild milestones stay guild-wide.

25. Race hunt and PvP kills (3.6.0). **Done, awaiting in-game test.**
    - **Counting** (`Hunt.lua`): each client counts its own killing blows on players from
      the combat log (`PARTY_KILL` by us on a `Player-` GUID; `GetPlayerInfoByGUID` gives
      the race). Killing blows, not honorable kills: an honorable kill is shared by everyone
      nearby. Only guild members with GMS count. If the client blocks the combat log for
      addons, nothing is counted; `/gms debug` says ("Race hunt ... combat log: yes/NO").
    - **Race hunt (decided: a guild total with a leaderboard):** officers pick an enemy race
      and a goal (Achievements → Race hunt; `config.hunt = { k, r, g }`, a new race gets a
      new key and starts at 0). Clients report their count for the current hunt (`HUNT`,
      every 2 min at most, resent until `HUNTACK`); officers record `hunt` ledger events
      (`hunt:<key>:<player>`, sequence = count, the highest counts), kept while that hunt is
      current. Raiders get the counts in snapshots (`hn`). Reaching the goal is a guild
      achievement "Hunt: 500 Gnomes".
    - **All-time kills per race:** reported as `KB { c = { race = n } }` (resent until
      `KBACK`). They're reported often and last forever, so they stay out of the ledger:
      officers keep the highest count per character (`AF.db.kbAll`) and share them in
      snapshots (`kb`), which every client merges (the highest wins).
    - **Achievements (guild totals):** 100 / 500 / 1,000 of each enemy race; 1,000 / 5,000 /
      10,000 / 25,000 players of any race; 100 of every enemy race.
    - **Achievements tab:** the hunt's progress with a bar, and the guild's killing blows;
      hovering either shows the top 10 (and the per-race totals). Officers start, change or
      end the hunt there.

## Later
Planned:
1. Smaller items: localization, discretionary points, a weekly Discord summary.

Dropped (decided): raid attendance (raid nights, join/leave times, attendance %). Raid
signups and attendance stay in Discord; GMS only counts presence at guild kills.

## Technical notes
- Lua 5.1 addon, no external calls.
- Officer checks are client-side: the sender's guild rank against `officerRank`.
- Secret values from the game (`issecretvalue`, `AF:IsSecret`) are never stored or sent.
- Modules (load order): Core, Comm, Config, Standings, Ledger, Archive, Bank, Attendance, Honor, Alts,
  Dungeons, Trade, Versions, Wishlist, Professions, Attunements, Layers, Invites, GuildLoot,
  Loot, Theme, UI. Modules register with `AF:NewModule`; `Init` runs at ADDON_LOADED, `Enable` at
  PLAYER_LOGIN.
- In-game test checklists: `docs/TESTING.md`.
