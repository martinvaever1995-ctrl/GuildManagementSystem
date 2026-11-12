# Guild Management System

## v3.6.1

### Changes
- **Achievements are only for members with GMS installed.** Raid kills, dungeon runs and
  battleground wins credit only the members who run GMS, and the level firsts wait for a member
  with GMS.

## v3.6.0

### PvP
- **Race hunt:** officers pick an enemy race and a goal, e.g. 500 Gnomes (Achievements → Race
  hunt). Every killing blow on that race by a guild member with GMS counts. The Achievements
  tab shows the progress, and hovering it shows the leaderboard. Reaching the goal is a guild
  achievement.
- **PvP kill achievements:** the guild's killing blows on players count toward new guild
  achievements: 100, 500 and 1,000 of each enemy race, 1,000 to 25,000 players in total, and 100
  of every enemy race. Hover "Killing blows on players" for the totals and the top 10.
- Killing blows, not honorable kills, so one kill counts once.

## v3.5.0

### Guild achievements
- **Guild achievements** (`/gms achievements`): guild firsts in PvE and PvP.
  - **PvE:** the first to the level cap (and the first of each class), to 300 in each
    profession, to each attunement; the guild's first kill of every raid boss and first run of
    every end-game dungeon.
  - **PvP:** the first to fill the weekly honor score, to 1,000 / 5,000 / 10,000 / 25,000
    honorable kills, to PvP ranks 6 to 14, and the first battleground wins with 5+ guildies.
  - **Guild:** 50, 100, 200 and 500 members, the first bank goal reached, the first perfect week.
  - New firsts pop up for everyone online and are announced in guild chat.
  - Achievements players already had before GMS are shared by all of them.
  - Officers can switch achievements, or just the guild chat line, off in guild setup.

## v3.4.0

### Analytics
- **New Analytics tab** (`/gms analytics` or `/gms stats`): the guild in numbers.
  - **Roster:** members, online now and at the level cap; classes (all, max level or online),
    levels and ranks. Hover a bar to see who.
  - **Members:** everyone in the guild, searchable and sortable, alts under their main, "on an
    alt" when someone plays an alt, and Export CSV for a spreadsheet.
  - **Guild:** professions and attunements from what GMS collects, effort across the guild, and
    for officers this week's guild kills, awards, dungeon runs and bank deposits.
  - **History:** joins, leaves, kicks and promotions from the game's guild log, kept longer than
    the game keeps them (if the client allows it; `/gms debug` says).
- **Class needs:** officers set which classes the guild is looking for (Analytics → Needs). It
  shows on the class bars and as a "Looking for" line.
- Officers can switch Analytics off in guild setup.

### Smaller things
- **Wowhead links:** paste a Wowhead link or type an item ID in the wishlist, bank and priority
  boxes, and in `/gms wish`.
- **Wishlist card:** a card tells you when an item on your wishlist drops.

## v3.3.0

### Long-term history
- **Weeks are kept:** weeks no longer disappear after 8 weeks. Officers keep a summary of every
  older week: everyone's points per category, every award and the wanted items deposited.
  Officers swap these weeks, so they all have the same ones.
- **Loot history** goes back 3 months or all the way. The loot window shows each player's last
  item and how many weeks ago they got it.
- **Bank goals** keep counting deposits older than 8 weeks, so they no longer go backwards.

### Loot council
- **Loot priorities:** officers set who should get an item first ("Warrior tank > Rogue") on the
  new Priorities page or with the loot window's Priority button. The loot window shows it and
  marks matching players; officers see it in item tooltips.
- **Award reasons:** pick Upgrade, BiS, Off spec, Alt or Other when awarding. It's in the raid
  announcement and the loot history.
- **Tier tokens:** the loot window shows which classes a token is for and how many set pieces
  each player wears.
- **Wins for everyone:** a guild setup option (off by default) shows everyone what was won this
  week.
- All four can be switched off in guild setup.

### For officers
- **`/gms export web`:** the guild's effort and loot history as JSON, for a website or a
  Discord bot. `/gms archive` shows what's kept.
- **`/gms selftest`:** a report to copy and send us when something looks wrong.

### Fixes
- `/gms help` showed "bankonor" and "addemove" instead of "bank|honor" and "add|remove".

### Before you update
- Officers first: an officer on an older version can wipe the loot priorities and the new
  guild setup switches when they save the effort rules.

## v3.2.3

### Fixed
- **"No player named ... is currently playing":** when an officer logged out, the other
  officers could get a row of these in chat. GMS now stops sending to players who go offline
  and hides these lines for its own messages.

## v3.2.2

### Fixed
- **Honor:** honor you earned could go uncounted, because honor is now a currency and GMS was
  looking for the wrong one. GMS now finds it by name. Honor already earned this week may be
  missing; officers can add it with `/gms adjust`.

## v3.2.1

### New
- **Update card setting:** turn off the card that shows when a new version is out, in the settings
  page. The chat message still shows.

## v3.2.0

### New
- **Layers:** a new tab (`/gms layers`) shows which layer online guild members are on, by zone.
  Click someone to whisper them for a group invite. It only shows; it never invites or moves
  anyone. Officers can turn it off in guild setup.
- **Set pieces in the loot window:** see how many pieces of an item's set each player wears.
- **Guild bank and Disenchant buttons:** give an item nobody needs to whoever banks or disenchants
  it. It's recorded in the loot history, but doesn't count as that player winning it.
- **Raid check:** the Check group window now counts tanks, healers and DPS, and shows who is
  missing Fortitude, Arcane Intellect or Mark of the Wild.
- **Window size:** make GMS bigger or smaller in the settings or with `/gms scale 70-130`.
- **Help and bug reports:** a "Help / report a bug" button (or `/gms discord`) with the link to
  our Discord: https://discord.gg/U4UCtfRgmE

### Changes
- The download no longer includes the old AdventForever folder.

## v3.1.1

### New
- **GMS tab on the guild window:** the Guild & Communities window (J) has a GMS tab below its
  side tabs. Click it to open GMS next to the guild window. Turn off "Open GMS next to the guild
  window" in the settings to open it in its usual spot instead.

### Fixes
- **Classic look:** window and card borders, the sidebar highlight and status bars were missing.
  They now show the game's own art.

## v3.1.0

### Classic look
- Pick **Modern** (the flat GMS look) or **Classic (Blizzard)** in the settings (Options →
  AddOns → Guild Management System) or with `/gms style classic` / `/gms style modern`.
- Classic uses the game's own frames, buttons, checkboxes, input boxes, status bars and font,
  with gold headings, like Blizzard's own windows. Every window and feature works the same.
- It's a personal setting: everyone in the guild can choose their own. Changing it reloads
  your interface. With EllesmereUI installed, Modern keeps following EllesmereUI.

## v3.0.1

### New
- **Welcome guide:** the first time you log in with GMS, a short guide explains effort, the loot
  popup and the tabs your guild uses. Open it again with `/gms welcome`.
- **Settings page** in the game's own settings (Options → AddOns → Guild Management System, or
  `/gms settings`): open GMS, guild setup and effort rules (officers), the minimap button and the
  login summary.

### Fixes
- `/gms help` now lists `dungeon` for `/gms adjust` (it already worked).
- The download no longer includes the changelog, and GitHub's "Source code" downloads only
  contain the addon.

## v3.0.0

AdventForever is now **Guild Management System (GMS)**, and any guild can use it.

### For every guild
- **Guild setup:** the GM gets a short setup the first time (`/gms setup`, or Options → Guild setup):
  - officer ranks
  - which effort categories count (raids, guild bank, honor, dungeons) and their points per week
  - which features are on (votes, wishlists, crafters, attunements, guild loot)
  Officers can change it any time, and it reaches every member automatically.
- **Data per guild:** characters in different guilds keep separate ledgers, settings and
  lists. A character's first login, or a guild change, can ask for one reload.
- **Guild loot auto-pass is off by default.** Officers switch it on in guild setup.
- Switched-off categories count 0 and show as "off". Switched-off features disappear from the
  window and the minimap menu.
- The window shows your guild's name. New neutral logo.

### Changed
- The command is now `/gms` (also `/guildmanagement`).
- The Recruit tab and the hidden recruiting channel are gone.

### Coming from AdventForever
- On Wago, AdventForever simply updates to GMS. The download includes AdventForever's last
  version, which does nothing but hand its data to GMS on your first login: your effort
  history, ledger, settings, wishlists, recipes and attunements move over. Guild loot stays
  on for your guild.
- GMS doesn't talk to AdventForever. Switch the whole guild over, officers first.
- Afterwards you can remove AdventForever.

## Earlier versions, as AdventForever

### v2.0.5 (beta)

### Dungeons
- Only **end-game dungeons** count toward the dungeon score now: Blackrock Depths, Lower and
  Upper Blackrock Spire, Dire Maul (East, West, North), Scholomance and Stratholme (both sides).
  Leveling dungeons don't count, and finishing one with guildies says so in chat.
- Leveling-dungeon runs already recorded this week no longer count either.
- New Forever dungeons still count once an officer marks their final boss with `/af final`.

### v2.0.4 (beta)

- AdventForever is now on CurseForge as well. No other changes since 2.0.3.

### v2.0.3 (beta)

### Minimap button
- A minimap button with the Advent logo: **left-click** opens the window, **right-click** opens
  a menu (Effort, Me, Wishlist, Crafters, Attunements, Check group, Raid invites, Loot window,
  Trades, and for officers Loot history and Options), **drag** moves it around the minimap.
- Hide it from its menu; `/af minimap` brings it back.

### Raid invites
- `/af invite` (or the minimap menu): tick the guild ranks to invite and, if you like, a
  minimum effort. One click invites everyone online who matches. Hover the count to see who.
- From solo it invites 4, turns the party into a raid as soon as someone joins, then invites
  the rest.
- **Whisper invites:** switch it on and guild members who whisper you the keyword (default
  "inv") get an invite. It stays off until you switch it on, every session.

### Can't use
- The loot window marks **can't use** in red when a player answers Main spec or Off spec on an
  item their class can't use (armor type, weapon type, shields, librams / idols / totems, and
  class-restricted items like tier pieces). Hover them for the reason.
- The loot popup tells you too: **You can't use this**.

### v2.0.2 (beta)

### Versions and raid readiness
- `/af versions` (or `/af check`) opens a window listing everyone in your group:
  - their **addon version**: green when current, orange when outdated, red when not installed
  - their **repair** percentage (the tooltip shows the lowest item)
  - whether they have a **flask or elixirs** up (the tooltip names them)
  - whether they're **in range**
- Officers get a **Remind** button that whispers every guild member in the group who is
  outdated or hasn't got the addon.
- When a newer version is out, a small **update card** tells you once per session, instead of
  a chat line that's easy to miss.
- Players on 2.0.1 or older still show their version, but not their repair or buffs.

### Wishlists
- The new **Wishlist** tab: rank up to 10 items you want, most wanted first. Shift-click an
  item into the box, or use `/af wish <shift-click item>`. Move items up and down, or remove them.
- Only officers see your list. It reaches them when you change it and when you or they log in.
- When an item on your wishlist drops, the loot popup says **On your wishlist (#2)** and plays
  a sound.
- In the loot window, officers see each player's wishlist rank for the item next to their
  note (**wish #2**).
- Officers get a **Guild** view in the Wishlist tab: every wished-for item, how many players
  want it and who (with their rank and effort).
- Item tooltips show officers who has the item on their wishlist. Raiders see their own rank.

### Crafters
- The new **Crafters** tab (`/af crafters`) is the guild's profession directory:
  - **Search** for an item or enchant (or shift-click one) to see who in the guild can make it.
    Online crafters are shown in green, and clicking a result whispers the first one online.
  - With no search, it lists everyone's **professions** with their skill level and number of
    recipes, gathering professions included.
- Your recipes are read when you open a profession window, and your skill levels when you log
  in. Recipes are only ever added, so a filtered window can't lose any.
- Item tooltips show **Crafted by:** with up to 4 guild members, online ones first.
- The directory is shared quietly in the background. Large data waits behind everything else,
  so it never delays loot, votes or effort updates.

### Attunements
- The new **Attunements** tab (`/af attune`) shows who in the guild is attuned to what, as a grid:
  a filled square means attuned, and **?** means not known yet. Players with the most
  attunements are listed first.
- Hover a column to see what it takes and how many are attuned, or a player to see all of
  theirs.
- Built in: Upper Blackrock Spire, Molten Core, Onyxia's Lair, Blackwing Lair and Naxxramas.
  An attunement counts when its quest is done or its key item is in your bags, bank or key ring.
- Officers can **remove** an attunement the guild doesn't need (click its column) and **add**
  new ones as WoW: Forever releases them: a name, a short label, and the quest IDs that
  finish it or its key item. "Restore classic ones" brings back removed built-in ones.
- Your client checks your attunements after login, after you turn in a quest and when your
  bags change, and shares them with the guild.

### v2.0.1 (beta)

### Guild loot in raids
- In a guild raid (a raid instance with at least 75% guild members), raiders **automatically
  pass** on Rare and better items, and the **raid leader automatically needs**. The raid leader
  gets every good item and hands it out with the loot window, so nobody can need on it first.
- Items the raid leader receives start loot sessions by themselves.
- Officers get a warning in chat if anyone else rolls on, or wins, such an item. Players without
  the addon can't be made to pass, but the warning shows it.
- `/af debug` shows whether this client allows rolling by addon.

### v2.0.0

First release. AdventForever tracks each player's **effort** (raids, guild bank, honor and
dungeons with guildies) and shows it to officers when they hand out loot. The addon never
decides who gets an item: officers do.

### Effort
- Each raid week you can score up to 120 points: **Raids** (up to 50), **Guild bank** (up to
  30), **Honor** (up to 20) and **Dungeons** (up to 20).
- Your effort is the sum of the last 4 weeks (max 480). The oldest week drops off at the
  weekly reset, so there's no decay.
- Officers can set the caps, the gold rate, the honor target and the guild kill rule in
  Options.

### Raids
- A boss kill counts as a **guild kill** when at least 75% of the raid are guild members.
- Your raid score is your share of the guild's kills that week.
- Kills record themselves. If the game hides the result, an officer can enter it with
  `/af kill <boss>`.
- Officers can put players on the bench (`/af bench add <name>`), and bench players get credit
  for kills.

### Guild bank
- Gold deposits count toward your score, and so do items on the officers' **wanted list**,
  at their listed value. Withdrawals count against it.
- Your own client reports your deposits when you close the bank. Officers' clients also read
  the bank log, so deposits from players without the addon count too, and no deposit is
  counted twice.
- The new **Bank** tab shows the rules and the wanted list. Officers can add and remove items.
- **Goals:** officers can set a target for a wanted item (e.g. "200 Arcanite Bars"). The Bank tab
  shows the guild's progress with a bar, and items still needed are listed first.

### Honor
- Your client counts the honor you earn while the addon is running and reports it to the
  officers.
- The full honor score is reached at a weekly honor target the officers set.

### Dungeons with guildies
- Finishing a dungeon (its last boss) with at least 3 guild members in the group earns 2.5
  points, up to 20 a week.
- Your own client reports the run, and a run counts once however many of you report it.
- Final bosses of the classic dungeons are built in. Officers mark the final boss of new
  dungeons with `/af final` after killing it.

### Mains and alts
- Effort counts per player: your main and all your alts together, with the caps applying to
  you as a whole.
- Characters on the same WoW account link themselves. Pick your main with "Make this my
  main" in the Me tab, or `/af main`.
- Officers can link and unlink characters by hand (`/af link`, `/af unlink`), for example
  for players on two accounts.

### Loot
- **Loot popup:** Main spec / Off spec / Pass, your equipped item for that slot, the
  **item level difference** (+8 ilvl), a countdown, and an optional **note** (e.g. "BiS").
- **Loot window** for the master looter or raid leader:
  - responses grouped by type and sorted by effort, as a guide only
  - each player's effort, the last 4 weeks, items won this week, equipped items with the item
    level difference, and their note
  - click anyone to award
- **Officer votes:** every officer in the raid gets the loot window with all responses and can
  vote for a candidate. Votes are shown as a count, with the voters' names in the tooltip, and
  only go to the officers. Whoever hands out the loot still makes the call.
- Without master loot, the raid leader starts a session with `/af item <shift-click>`.
- **Trades:** when an item is awarded by trade, the player holding it gets a Trades window
  (`/af trades`) showing:
  - who to trade it to
  - the time left of the 2-hour trade window
  - whether the winner is in range

  Opening the trade puts the item in for you. Delivery is tracked, and the officers see it in
  the loot window.
- **Loot history** (officers, Loot tab): who won what over the last 4 or 8 weeks, by item or
  by player.

### Windows
- A flat, modern look: sidebar navigation with the Advent logo and icons, content on cards
  with crisp black outlines, gradient bars, and the Inter font. With EllesmereUI installed,
  it follows your EllesmereUI theme, font and accent color.
- Officer pages (Loot history, Log, Recruit, Options) only show for officers.
- The main window (`/af`) has these tabs:
  - **Effort:** everyone's effort, sortable
  - **Me:** your own effort per category and what's left this week
  - **Rules:** how scoring works, with the guild's current numbers
  - **Loot:** loot history
  - **Log:** every recorded event; officers can click one to remove a mistake
  - **Bank:** the bank rules and wanted list
  - **Options:** the rules settings
  - **Recruit:** guildless players with the addon
- Windows remember where you left them.

### Login summary
- About a minute after you log in, a small card shows:
  - your effort last week and this week
  - what's still open this week (raids, bank, honor)
  - what the guild needs most from the bank goals
  - any items you have to trade
- Click it to open the Me tab. Turn it off with the checkbox in the Me tab; `/af nudge` shows it
  again.

### Recruiting
- Guildless players who run the addon show up in the **Recruit** tab for guild ranks that can
  invite, with an **Invite** button.

### For officers
- All effort is kept in a shared **ledger** that syncs between officers when they log in.
  Raiders get a summary from whichever officer is online.
- `/af export` and `/af import` back up and restore the ledger as text. Export now and then.
- `/af adjust <name> <raid|bank|honor> <+/-points>` corrects a player's points for this week.
- `/af test` runs a practice loot session with made-up raiders. Nothing is sent or recorded.
- `/af debug` shows what the addon sees: your rank, the roster, and which game features work
  on this client.

### Notes
- Made for WoW: Forever (interface 16001).
- Everyone in the guild should install it. Officers are guild ranks 0–1 by default; the GM
  can change this in Options.
- Type `/af help` for all commands.
