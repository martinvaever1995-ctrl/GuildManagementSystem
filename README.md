# Guild Management System (GMS)

Shows officers each player's **effort** when handing out raid loot. The addon ranks and
decides nothing; officers pick who gets each item.

Effort is the sum of the last 4 weekly scores. A week's score adds up the effort sources
your guild uses; by default raids (max 50) + guild bank (max 30) + honor (max 20) +
dungeons (max 20), so 120 a week and 480 over 4 weeks. Each guild picks its sources and
caps in guild setup (`/gms setup`).

Made for **WoW: Forever**. Wago: https://addons.wago.io/addons/guildmanagementsystem

## Installation
- **CurseForge or Wago:** search for "Guild Management System" in the CurseForge app, WowUp
  or the Wago app, or download it from the [Wago page](https://addons.wago.io/addons/guildmanagementsystem).
- **By hand:** download the zip (Wago, CurseForge or GitHub Releases) and unpack it into your
  WoW: Forever `Interface/AddOns/` folder. You should end up with
  `Interface/AddOns/GuildManagementSystem/GuildManagementSystem.toc`.
- Restart the game (a `/reload` isn't enough for a newly installed addon).
- Everyone in the guild should install it.
- **Coming from AdventForever?** On Wago it updates to GMS by itself. The download includes
  AdventForever's last version, which hands your data to GMS on your first login.

## Guild setup
- The GM gets the guild setup window the first time (or `/gms setup`):
  - which ranks count as officers (default ranks 0–1)
  - which effort sources count and their points per week
  - which features are on
- Settings reach every member automatically. Officers can change them later in Options.

## Mains and alts
Effort counts per player: a main and all their alts together, with the weekly caps applying
to the player as a whole. A raid kill counts once even if two of your characters were there.
- **Automatic:** characters you log in on the same WoW account link themselves. The first one
  is your main; change it with "Make this my main" in the Me tab (or `/gms main`).
- **Officers:** an officer's client records links for its own account straight away. Other
  players' characters link when they log in while an officer is online.
- **By hand:** officers can use `/gms link <alt> <main>` and `/gms unlink <name>`, e.g. for
  someone on two accounts. An officer's link always wins.
- **Display:** alts show "alt" and their main's effort. The Effort tab hides alts unless
  "Show alts" is ticked.

## Raids
A boss kill counts as a **guild kill** when at least 75% of the raid are guild members
(configurable). Raid points for a week = raid cap × guild kills you were at ÷ all guild kills.
- Officers in the raid record the kill automatically. A raid leader who isn't an officer
  sends it to the officers; if none are online, it's resent until one confirms it.
- Players on an officer's bench (`/gms bench add <name>`) get credit for the kills that officer
  records.
- If the game hides the encounter result, an officer records it with `/gms kill <boss>`.
- Mistakes (a test kill, a wrong deposit): click the event in the Log tab to remove it.

## Guild bank
Gold and items on the wanted list count toward the bank score at 1 point per 50 gold
(configurable). Wanted items count at their gold value each. Withdrawals count against it.
- Your own client reports your deposits when you close the guild bank. If no officer is
  online, the report waits and is resent until one confirms it.
- Officers' clients read the guild bank logs when they open the bank. That catches deposits
  from players without the addon.
- Both sources can see the same deposit. Per player, week and item, the larger of the two
  totals counts, never both.
- **Bank goals:** officers can give a wanted item a target (e.g. 200 Arcanite Bars). The Bank
  tab shows the guild's progress.

## Honor
Honor points = honor cap × this week's honor ÷ the weekly honor target (set in Options), at
most the cap. Your own client works out this week's honor and reports it to the officers when
it changes, at most every 5 minutes. A report waits until an officer confirms it.
`/gms debug` shows your honor this week, where the number comes from, and whether this
client can inspect other players' honor.

## Dungeons
A dungeon run counts when the **final boss of an end-game dungeon** dies with at least
**3 guild members** in the group, you included (officers can set 2–5). Each run gives 2.5
points (configurable), up to the dungeon cap.
- End-game dungeons are built in: Blackrock Depths, Lower and Upper Blackrock Spire,
  Dire Maul (East, West, North), Scholomance and Stratholme. Leveling dungeons don't count.
- Every guild member's client in the group reports the run; reports of the same run (same
  dungeon, within 10 minutes, a shared player) count once.
- New WoW: Forever dungeons: an officer kills the final boss once and types `/gms final`.
  That marks it for the whole guild and also counts that run.

## Loot
The **loot authority** is the master looter when master loot is on, otherwise the raid leader.
- **Raiders** get a popup: Main spec / Off spec / Pass, with the item level difference, an
  optional note, and a warning when their class can't use the item.
- **The loot window** groups responses Main spec → Off spec → Pass → no answer and sorts by
  effort within each group, purely as a visual aid. Each row shows effort, the 4 weekly
  scores, items won this raid week (officers' clients only), the equipped item, the note,
  the wishlist rank and "can't use". Hover a row for details. Click anyone to award.
- **Officer votes:** every officer in the raid sees the responses and can vote. Whoever
  hands out the loot still decides.
- **Guild loot (optional, off by default):** in guild raids, raiders automatically pass on
  Rare and better items and the raid leader needs, so the leader can hand them out.
- **Loot history:** officers see who won what in the last 4 or 8 weeks (`/gms history`).

## Trades (no master loot)
When an item is awarded by trade, the client that has it in its bags (and looted it recently)
becomes the holder and tells the raid.
- **Holder:** the Trades window (`/gms trades`) shows each item to trade, the winner, the time
  left of the 2-hour trade window and whether they're in range. There are warnings at 30 and
  10 minutes left.
- **Trading:** opening a trade with the winner puts the item in; you check it and accept.
- **Winner:** sees "[item] from <holder>".
- **Done:** a completed trade is detected and shows as "delivered" in the officers' loot window.

## More for the guild
- **Wishlists** (`/gms wish`): rank up to 10 items you want. Only officers see them: at loot
  time, in item tooltips and in a guild overview.
- **Crafters** (`/gms crafters`): search who in the guild can craft something, and see
  everyone's professions. Item tooltips show "Crafted by".
- **Attunements** (`/gms attune`): a grid of who is attuned to what. Officers can add new ones.
- **Check group** (`/gms check`): addon versions, repair, flasks/elixirs and range for
  everyone in the group.
- **Raid invites** (`/gms invite`): invite everyone online at chosen ranks and minimum effort,
  or guild members who whisper a keyword.
- **Login summary:** your effort and what's still open this week (turn it off in the Me tab).
- **Minimap button:** left-click opens the window, right-click opens a menu, drag moves it.

## For officers
Officers are the guild ranks set in guild setup (default 0–1; only the GM changes them).
- **Guild setup** (`/gms setup`, or Options → Guild setup):
  - officer ranks (GM only)
  - effort sources on or off: raids, guild bank, honor, dungeons, each with its points per week
  - features on or off: officer votes, wishlists, crafters, attunements, guild loot
- **Options** (`/gms options`):
  - the four caps (together at most 200 a week)
  - points per dungeon run, guild members needed for a dungeon run
  - gold per guild bank point
  - guild members needed for a guild kill (%)
  - weekly honor for the full honor score
  - loot popup timeout
- **Bank tab:** the wanted list (item, gold value each) and goals.
- **Attunements tab:** remove built-in attunements, add new ones (quest IDs or key item).
- **Corrections:**
  - `/gms adjust`: a player's points this week in one category
  - `/gms bench`, `/gms kill`, `/gms final`
  - `/gms link` and `/gms unlink`
  - removing events in the Log tab
- **Backup:** `/gms export` and `/gms import`. Export now and then: the ledger only exists in
  officers' saved data.

## Where the data lives
- **Ledger:** the real record. It's an event log in every officer's saved data. Officers' clients
  share new events as they happen and swap missing ones when an officer logs in.
- **Snapshots:** officers send the guild a summary of everyone's weekly scores. Every client
  saves the latest one, so raiders can see effort while no officer is online. The effort
  window says how old it is and which officer sent it.
- **Per guild:** saved data is kept separately for each guild, so characters in different
  guilds never mix. A character's first login, or a guild change, can ask for one reload.
- **Backup:** `/gms export` gives the whole ledger as text to save outside the game;
  `/gms import` merges it back in.

No officer or public notes are used.

## Look
Two looks, picked per player in the settings or with `/gms style`: **Modern**, a flat dark
theme in the GMS brand green, and **Classic**, the game's own frames, buttons and font with gold
headings. In Modern, with EllesmereUI installed, its third-party skinning
styles the addon instead, using your EllesmereUI theme, font and accent color. You can turn
that off per addon in EllesmereUI's options.

## Commands
`/gms` and `/guildmanagement` both work. `/gms help` lists everything in game.

| Command | What it does |
|---|---|
| `/gms` | Main window: Effort, Me, Rules, Bank, Wishlist, Crafters and Attunements tabs (officers also get Loot history, Log and Options) |
| `/gms me` | Your own effort: the split per category, what's left this week, the last 4 weeks |
| `/gms rules` | How effort is scored, with the guild's current numbers |
| `/gms main` | Make this character your main |
| `/gms nudge` | Show the login summary again |
| `/gms loot` | Loot window |
| `/gms item <shift-click items>` | Start a loot session by hand (loot authority) |
| `/gms test [shift-click item]` | Try the loot popup and loot window alone (nothing is sent) |
| `/gms trades` | Items you have to trade to a winner, and items coming to you |
| `/gms bank` | Guild bank rules, the wanted list and goals (officers edit) |
| `/gms wish [item]` | Your wishlist, or add an item to it |
| `/gms crafters [item]` | Who in the guild can craft something, or everyone's professions |
| `/gms attune` | Who in the guild is attuned to which raid (officers add or remove attunements) |
| `/gms versions` (or `/gms check`) | Who in your group has the addon and which version, with durability, flasks / elixirs and range |
| `/gms invite` | Raid invites by rank and minimum effort, and invites by whisper keyword |
| `/gms minimap` | Show or hide the minimap button |
| `/gms settings` | This addon's page in the game's settings |
| `/gms welcome` | The short guide to what GMS does |
| `/gms style modern\|classic` | The flat GMS look or the game's own Blizzard style |
| `/gms setup` | Guild setup: officer ranks, effort sources, features (officers edit) |
| `/gms options` / `/gms config` | Effort rules (officers edit, everyone views) / print them |
| `/gms history` | Officers: who won what in the last 4 or 8 weeks, by item or by player |
| `/gms log` | Officers: ledger events (Log tab) |
| `/gms adjust <name> <raid\|bank\|honor\|dungeon> <+/-points> [reason]` | Officers: correct this week's points in a category (0 removes the correction) |
| `/gms bench add\|remove <name>`, `/gms bench list\|clear` | Officers: bench players credited for the kills you record |
| `/gms kill <boss>` | Officers: record a guild kill for your group by hand |
| `/gms final` | Officers: mark (or unmark) the dungeon boss you just killed as its dungeon's final boss |
| `/gms link <alt> <main>`, `/gms unlink <name>` | Officers: link characters by hand |
| `/gms export` / `/gms import` | Officers: back up / restore the ledger |
| `/gms debug` | What the addon can see on this client |
