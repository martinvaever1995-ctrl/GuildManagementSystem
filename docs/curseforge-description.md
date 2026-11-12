# Guild Management System (GMS)

**Effort tracking, loot council, guild achievements and guild tools for WoW: Forever.**

GMS shows your officers how much each member puts into the guild (raids, guild bank, honor
and end-game dungeons with guildies) right when they hand out loot. Around that it gives the
whole guild achievements, analytics, wishlists, a profession directory, attunements, layers,
raid readiness and raid invites.

The addon never ranks players or decides loot. Your officers do. GMS gives them the
information.

## Set up for your guild
The GM gets a short setup the first time:
- **Officer ranks:** who records effort and runs the loot council.
- **What counts as effort:** raids, guild bank, honor and/or dungeons, with your own points
  per week.
- **Which features are on:** every feature below can be switched on or off for your guild.

Settings reach every member automatically, and officers can change them any time.

## Effort
- Weekly points per category. **Effort** is the sum of the last 4 weeks, so there's no decay
  to manage and old weeks simply drop off at the reset.
- **Raids:** your share of the guild's boss kills (a kill counts when enough of the raid is from
  the guild).
- **Guild bank:** gold and items from the guild's wanted list, minus withdrawals.
- **Honor:** up to a weekly target.
- **Dungeons:** end-game dungeons finished with guildies.
- Mains and alts count as one player.
- **Long-term history:** older weeks are kept as a summary, so loot history goes back months and
  bank goals keep counting.

## Loot council
- **Raiders** answer Main spec / Off spec / Pass in a popup, with the item level difference,
  an optional note, wishlist and "can't use" flags.
- **The loot window** shows every response sorted by effort, with the last 4 weeks, items won,
  each player's last item, set pieces worn, equipped items, notes and wishlist ranks.
- **Loot priorities:** officers set who should get an item first ("Warrior tank > Rogue").
- **Award reasons:** Upgrade, BiS, Off spec, Alt or Other, kept in the loot history.
- **Tier tokens:** which classes a token is for and how many set pieces each player wears.
- **Officer votes,** a **loot history** (4 weeks to all), **Guild bank / Disenchant** buttons and
  **trade tracking** when there's no master loot.
- **Optional:** guild loot (raiders auto-pass on Rare+ in guild raids, the leader needs) and
  showing this week's wins to everyone.

## Guild achievements
- **Guild firsts in PvE:** the first to level 60 (and the first of each class), to 300 in each
  profession, to each attunement, and the guild's first kill of every raid boss and run of every
  end-game dungeon.
- **PvP:** PvP ranks, honorable kills, battleground wins with guildies, and killing blows on
  each enemy race.
- **Race hunt:** officers pick an enemy race and a goal ("500 Gnomes"); the guild hunts together,
  with a leaderboard.
- New firsts pop up for everyone and are announced in guild chat.
- Only members with GMS installed can win them.

## Analytics
- **Roster:** members, online now, classes, levels and ranks. Officers mark which classes the
  guild needs.
- **Members:** everyone in a searchable list, alts under their main, with a CSV export.
- **Guild:** professions, attunements and effort across the guild, and this week's raids and
  deposits for officers.
- **History:** joins, leaves and promotions, kept longer than the game keeps them.

## For the whole guild
- **Wishlists:** rank up to 10 items you want (shift-click or paste a Wowhead link). Only
  officers see them, and a card tells you when one drops.
- **Crafters:** search who can craft what, see everyone's professions, and get "Crafted by"
  on tooltips.
- **Attunements:** a grid of who's attuned to what. Officers add new ones as Forever releases
  them.
- **Layers:** which layer guild members are on, so you know whom to whisper for an invite.
- **Check group:** addon versions, repair, flasks/elixirs, missing buffs, range and a
  tank / healer / DPS count for the whole group.
- **Raid invites:** invite everyone online at chosen ranks and minimum effort, or by
  whisper keyword.
- **Bank goals:** a wanted list with values and targets, with progress for everyone to see.

## Look
- **Modern:** a flat, dark look in the GMS green. It follows your EllesmereUI theme if you use it.
- **Classic:** the game's own Blizzard frames and font.
- Window size from 70 to 130 %, a minimap button, a GMS tab on the guild window and a settings
  page in the game's options.

## Good to know
- Everyone in the guild should install it; officers should update first.
- Data is kept per guild, so characters in different guilds never mix.
- Officers can back up the ledger as text (`/gms export`) and export the guild's history as JSON
  for a website or Discord bot (`/gms export web`).
- Requires an English game client for some detection.
- `/gms` opens the window. `/gms help` lists every command.
- Need help or found a bug? Join our Discord: https://discord.gg/U4UCtfRgmE (`/gms selftest`
  gives a report to paste there).
