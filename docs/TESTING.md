# GMS in-game test checklist

One section per module. Each has a **setup** and steps with what should happen. Tick a step
off in `docs/SPEC.md` (build steps) once it works in game.

Before any test: `/reload`, then `/gms selftest` and keep the text. If something goes wrong,
send it with a screenshot and the step number.

**Setups used below**
- **Alone:** one character in the guild.
- **Officer + raider:** two players online, one in an officer rank, one not.
- **Two officers:** two officers online.
- **Group / raid:** a party or raid with guild members.

**Still needs more than one player:** the ledger sync, snapshots, votes, trades, layers, set
pieces in a real session, raid check roles and buffs, offline handling.

---

## 1. Effort, ledger and snapshots
Setup: officer + raider, then two officers.
1. Officer: `/gms adjust <raider> bank 10 test`. The Log tab shows a `cat` event; the raider's
   Effort row goes up by 10 within about 10 seconds.
2. Raider: the Effort tab says "from <officer>, just now". The Me tab shows the 10 bank points.
3. Officer: click that event in the Log tab and confirm. It shows as removed; the raider's
   points drop back.
4. Two officers: officer A logs out, officer B adjusts someone, A logs in. Within a minute
   A's Log tab has B's event (`/gms selftest`: the same event count on both).
5. Officer: `/gms export`, copy; `/gms import`, paste, Import. It says 0 new events.
6. Raider logs in with no officer online: the Effort tab still shows the last snapshot, with
   its age.

## 2. Guild bank
Setup: officer + raider, a guild bank.
1. Officer: add a wanted item in the Bank tab (e.g. Linen Cloth, 1g each) with a goal of 20.
2. Raider: deposit 50g and 5 of the wanted item, close the bank. Me tab: "waiting for an
   officer" until the officer is online, then the bank points show (50g → 1 point at 50g per
   point, items at their value).
3. Officer: open the guild bank. No second deposit is added for the same gold (the larger
   source counts, not both).
4. Raider: withdraw 50g. Bank points go down.
5. Bank tab: the goal shows 5 / 20.

## 3. Raids
Setup: a raid of guild members with an officer (or a raid leader who isn't an officer).
1. Kill a raid boss. Every officer in the raid gets one `kill` event (same id on each).
2. Non-officer leader, no officer online: the kill report waits (`/gms selftest`: "kill
   reports 1"), and is recorded when an officer logs in.
3. Officer: `/gms bench add <name>` before a kill. That player gets credit for it.
4. If the kill isn't recorded (secret values), `/gms kill <boss>` records it by hand.
5. A raid with fewer than 75% guild members: no kill is recorded.

## 4. Honor
Setup: alone, then officer + raider.
1. `/reload`, wait 15 seconds, `/gms debug`: the Honor line shows `honor currency: <id>
   (amount <your honor>)`.
2. Earn honor. `/gms debug` again: "this week" goes up by the honor earned.
3. Spend honor. "this week" doesn't go down.
4. With an officer online, within 5 minutes the honor points show in the Effort tab.

## 5. Mains and alts
Setup: one account with two characters in the guild, an officer online.
1. Log in on the alt. Me tab: "alt of <main>". The Effort tab hides the alt unless "Show alts"
   is ticked.
2. "Make this my main" on the alt. After a minute the officer's Effort tab shows the new main.
3. Officer: `/gms link <alt> <main>` and `/gms unlink <alt>` change it by hand.
4. Points earned on the alt count toward the main.

## 6. Trades (no master loot)
Setup: raid leader, the player holding an item (looted in the last 2 hours), the winner.
1. Leader: `/gms item <shift-click the item>`, award it to the winner.
2. Holder: the Trades window opens with the item, the winner, time left and range.
3. Holder opens a trade with the winner: the item is placed in it. Complete the trade.
4. Leader's loot window shows "delivered".
5. `/reload` on the holder before trading: the pending trade is still there.

## 7. Loot popup, notes and item level
Setup: alone with `/gms test`, then a real session.
1. `/gms test <shift-click an item>`: the popup shows Main spec / Off spec / Pass, your
   equipped item, the item level difference, a note box and a countdown.
2. Answer with a note "BiS". The loot window shows your row with the note and item level.
3. An item your class can't use: the popup says "You can't use this" and the row is red.

## 8. Officer votes
Setup: a raid with the loot authority and another officer.
1. Start a session. Both officers see the loot window with every response.
2. The other officer clicks a row: a vote is added; clicking again takes it back.
3. Only the loot authority's click awards the item.

## 9. Bank goals
See section 2, step 5. Also: change the goal to 0, the goal disappears; add it again, the
progress continues from before.

## 10. Login summary
1. Log in and wait about a minute: the card shows last week, this week, effort, what's open and
   the most-needed bank goal. It fades after 15 seconds unless hovered.
2. Click it: the Me tab opens.
3. Untick it in the Me tab (or the settings): no card at the next login. `/gms nudge` still
   shows it.

## 11. Dungeons
Setup: a party of 3+ guild members, an end-game dungeon.
1. Kill the final boss. Each member reports; an officer records one run for everyone
   (`/gms log`: `run` events, one counted run).
2. A run with only 2 guild members, or a leveling dungeon: no run.
3. New dungeon: an officer kills its final boss and types `/gms final`. It's marked, and that
   run counts.

## 12. Guild tools
- **Guild loot** (turn it on in guild setup): in a guild raid, raiders auto-pass on Rare+, the
  leader auto-needs, and the leader's loot starts sessions.
- **Check group** (`/gms check`): every member's version, durability, flasks / elixirs, range,
  the tank / healer / DPS count and missing class buffs. Officers' Remind button whispers
  outdated players.
- **Wishlist:** add 3 items with `/gms wish <item>`. An officer sees them in the Guild view and
  item tooltips. When one drops, the popup says "On your wishlist (#n)".
- **Crafters:** open a profession window. Another member finds you with `/gms crafters <item>`
  a minute later, and item tooltips show "Crafted by".
- **Attunements:** the grid shows your attunements; an officer adds a custom one and it shows
  for everyone.
- **Minimap button:** left-click, right-click menu, drag. `/gms minimap` hides and shows it.
- **Raid invites** (`/gms invite`): invite by rank and minimum effort; the whisper keyword
  invites a guild member.

## 13. Guild setup and per-guild data
1. A new GM: the setup window comes up the first time. Save it; every member gets it.
2. Switch off a source (e.g. honor): it counts 0 and shows "off". Switch off a feature (e.g.
   layers): its tab disappears.
3. A character in another guild has its own ledger and settings; changing guild asks for one
   reload.

## 14. Looks and help
1. First login with GMS: the welcome guide shows once. `/gms welcome` shows it again.
2. `/gms settings` opens the game's settings at GMS's page; every checkbox works.
3. **Tested:** Classic look and the guild window tab.

## 15. Layers, set pieces, guild awards, window size
1. **Layers** (two players in the same zone): hover an NPC on each. Within a minute the Layers
   tab shows both, by zone and layer. Clicking a name whispers them.
2. **Set pieces:** wear set pieces, `/gms test <a piece of that set>`. Your row shows "n/m set".
3. **Guild bank / Disenchant:** in a session, click Guild bank. The loot history lists the item as
   given to the guild bank, and it doesn't count as anyone's win.
4. **Window size:** `/gms scale 110`. Every GMS window is 10% bigger; it stays after a reload.
5. **Help:** `/gms discord` shows the link, ready to copy.

## 16. Honor currency and update card
1. **Tested:** honor currency by name.
2. Untick "Show a card when a new version is out" in the settings. When a newer version is
   seen, only the chat line shows.

## 17. Offline players
Setup: two officers.
1. Officer A logs in, `/reload`s, and logs out within a minute.
2. Officer B gets no "No player named ... is currently playing" lines.
3. A logs back in: the ledger sync works as usual (section 1, step 4).

## 18. Selftest
1. `/gms selftest` as an officer: 3 lines in chat and a copy window. It shows the version,
   guild, rank, "officer: true", config version, features, ledger events per week, the
   snapshot line, the waiting reports and the `/gms debug` lines.
2. Ctrl+A, Ctrl+C, paste somewhere: every line is there.
3. As a raider: "officer: false", and the snapshot line names an officer.
4. `/gms debug` prints the same lines as before.
5. On a character with no guild: it works and shows "Guild: nil".

## 19. Long-term history
Setup: an officer. Steps 1–6 work now; 7–8 need weeks to leave the ledger (8 weeks after a week
ends) and two officers.
1. `/gms archive`: "Archive: empty ..." (nothing has left the ledger yet).
2. `/gms archive test`: chat says how many weeks, player-weeks, awards and goals were checked,
   then "OK: the archive matches the ledger". A copy window shows the test archive as the web
   export. Nothing is saved: `/gms archive` still says empty.
3. Make some data first if the ledger is thin: `/gms adjust <player> bank 5 test`, a goal on a
   wanted item with a deposit, and an award from `/gms item`. Run `/gms archive test` again:
   still OK, with more player-weeks, awards and goals.
4. `/gms export web`: a copy window with JSON. Paste it into a JSON checker (e.g. jsonlint.com):
   it's valid, has `"format": "gms-web"`, this week with `"source": "ledger"`, your scores and
   the award.
5. Loot history (`/gms history`): the range button steps through 4 weeks, 8 weeks, 3 months,
   All. The count line under the list says "in the last N weeks" or "in all".
6. Loot window (`/gms test <item>`), hover a player who has won something: "Last item: <item>,
   this week". A player who hasn't: no "Last item" line.
7. **Later, when a week leaves the ledger:** the first officer login after that reset archives
   it. `/gms archive` shows 1 week; loot history "All" still lists its awards, marked archived
   (no remove on click); bank goals keep their progress.
8. **Swap:** an officer who was offline logs in. Within about 2 minutes `/gms archive` shows the
   same weeks as the others, and `/gms selftest` shows the same archive line.

## 20. Loot council depth
Setup: an officer alone with `/gms test`, then a raid with the loot authority and a raider.
1. **Guild setup** (`/gms setup`): four new switches (loot priorities, award reasons, tier
   tokens, wins shown to everyone); the window fits them with the Save button below.
2. **Priorities page** (sidebar, officers): shift-click an item, type `Warrior tank > Rogue`
   and a note, Save. It's listed; click it to edit, `x` removes it. Hover the item anywhere:
   officers see "Loot priority: ..." in the tooltip, raiders don't.
3. `/gms test <that item>`: the loot window's header shows "Priority: Warrior tank > Rogue"
   and the note. Warriors (and Rogues) in the list get "prio 1" ("prio 2"); the order of the
   list doesn't change. The Priority button opens the page with the item filled in.
4. **Award reason:** click a player: a dialog with Upgrade / BiS / Off spec / Alt / Other.
   Pick BiS, Award. Chat says "(test) ..."; in a real session the raid announcement ends
   "(Main spec, BiS)". Loot history shows BiS in the Reason column and the tooltip.
5. Switch award reasons off in guild setup: clicking a player gives the old yes/no popup.
6. **Tokens** (need a token, e.g. from a raid): `/gms test <token>`. The header says "Token for:
   <classes>"; your row (after answering) shows "wears N pc" if you wear 2+ pieces of a set,
   and the tooltip names the set ("Wears 4/8 of ...").
7. **Wins for everyone:** switch it on, award something in a real session. A raider sees it under
   "Won this week" in the Effort tab tooltip and the Me tab within a minute. Switched off:
   gone for raiders.
8. **Older officers:** an officer on 3.2.3 saves the effort rules: the priorities and new
   switches are still there afterwards on updated clients.
9. `/gms export web` and `/gms archive test`: still valid and OK, with `"reason"` on awards.

## 21. Guild analytics
Setup: alone in the guild, then as an officer.
1. `/gms analytics` (or the Analytics entry in the sidebar): the Roster view.
   - "Members": the total matches the guild window's member count; online now matches too.
   - A second line with "played in the last 7 / 30 days" (if it's missing, the client doesn't
     give last-online times; tell me).
2. Classes: one bar per class in its class color, biggest first, with count and %. The buttons
   All / Max level / Online change the counts. Hover a bar: the names.
3. Levels: the level cap on its own bar, then 50-59, 40-49 ... Hover: the names.
4. Ranks: one bar per rank with its name.
5. Guild view: Professions (with "N at 300" or the highest skill seen), Attunements ("12 / 30"),
   Effort in bands with the average. As an officer: "This week (officers)" with kills, awards,
   runs, deposits and players. As a raider: no "This week".
6. Both looks (Modern, Classic) and `/gms scale 80` / `130`: nothing overlaps.
7. Guild setup: switch "Guild analytics" off; the tab disappears from the sidebar.

## 22. Recruiter
Setup: an officer, then a second recruiter (a rank that may invite) online at the same time.
1. `/gms debug`: the Recruiter line says "/who API: yes", "guild invite API: yes", "your rank
   may invite: yes". If anything says NO, stop and send me the line.
2. Guild setup: switch "Recruiter" on. The Recruiter entry appears in the sidebar (only for
   ranks that may invite).
3. Templates: click Templates, write one ("Hi {player}, Advent is looking for a {class} ...").
   Save. A second officer sees the same template.
4. Levels 10-14, Guildless ticked, Search: chat says "levels 10-14, N new players found"; the list
   fills; the game's Who window does not open. Search again: the button said "Search 15-19".
5. Hover a player: the whisper as it will be sent, with their name and class filled in.
6. Mode "Whisper", Next: the whisper goes out, the row says "whispered". Clicking Next again
   within 3 seconds says to wait.
7. Mode "Whisper + invite" and "Invite only": the guild invite goes out too.
8. The other recruiter's list shows that player as "contacted" (search the same levels).
9. The player whispers back: it shows under Replies. Invite and Block work; clicking the row
   opens a whisper to them.
10. Shift-click a player: "blacklist"; the other recruiter sees it too.
11. A macro `/gms recruit next` on a key: pressing it contacts the next player.
12. Switch the feature off: the page disappears.

## 23. Members, history, class needs, Wowhead links, wishlist card
1. `/gms debug`: "Guild event log: yes" (or NO: then there's no History view; tell me).
2. Analytics → Members: everyone listed; search "warrior" or a rank name filters; click the
   column headers to sort; alts sit under their main (untick "Alts under their main" to mix
   them). Someone playing an alt shows "on an alt" on their main. Export CSV: paste into a
   spreadsheet, one row per member.
3. Analytics → History (if the log works): joins, leaves, promotions with dates; the Roster view
   says "Last 30 days: N joined, M left".
4. Officer: Analytics → Roster → Needs: set 2 Priest, 1 Rogue and a note, Save. The class bars
   say "need 2"/"need 1", the Members box says "Looking for: 2 Priest, 1 Rogue, <note>". Another
   member sees it too.
5. Recruiter: needed classes show "needed" in the results, and Next contacts them first.
6. Wishlist / Bank / Priorities box: paste `https://www.wowhead.com/classic/item=16866/` or type
   `16866`: it's added like a shift-clicked item. `/gms wish 16866` works too.
7. Put an item on your wishlist, `/gms test <that item>`: besides the popup and sound, a card
   "From your wishlist: ... dropped: #1 on your wishlist".
