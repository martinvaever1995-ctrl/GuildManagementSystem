# GMS web export (format version 1)

`/gms export web` (officers) gives the guild's effort and loot history as one JSON object, for a
website, a spreadsheet or a Discord bot. Copy it from the window (Ctrl+A, Ctrl+C).

It holds every archived week (weeks older than the 8-week ledger) and every week still in the
officer's ledger, up to the current one. It's read-only data: nothing reads it back into the game.
For a backup that can be imported again, use `/gms export` (the full ledger).

## Example

```json
{
  "format": "gms-web",
  "version": 1,
  "addonVersion": "3.3.0",
  "guild": "Advent",
  "realm": "CAMWOW EU5 Realm 4 PvP",
  "exported": 1794150000,
  "exportedBy": "Spnkn Morwick",
  "currentWeek": 2966,
  "categories": ["raid", "bank", "honor", "dungeon"],
  "config": {
    "caps": { "raid": 50, "bank": 30, "honor": 20, "dungeon": 20 },
    "goldPerPoint": 50,
    "honorTarget": 5000,
    "guildKillShare": 75,
    "dungeonPerRun": 2.5,
    "features": { "raid": true, "bank": true, "honor": true, "dungeon": true, "votes": true,
                  "wishlist": true, "crafters": true, "attune": true, "layers": true, "guildLoot": false }
  },
  "players": [
    { "name": "Spnkn Morwick", "class": "WARRIOR", "alts": ["Other Character"] }
  ],
  "weeks": [
    {
      "week": 2966,
      "start": 1793689200,
      "end": 1794294000,
      "source": "ledger",
      "caps": { "raid": 50, "bank": 30, "honor": 20, "dungeon": 20 },
      "scores": [
        { "player": "Spnkn Morwick", "raid": 50, "bank": 12, "honor": 2, "dungeon": 5, "total": 69 }
      ],
      "loot": [
        { "player": "Spnkn Morwick", "itemId": 16866, "item": "Helm of Might",
          "itemString": "item:16866::::::::60:::::", "response": "Main spec", "reason": "BiS", "forGuild": false,
          "time": 1793900000, "awardedBy": "Other Officer" }
      ]
    }
  ]
}
```

## Fields

**Top level**

| Field | Type | Meaning |
|---|---|---|
| `format` | string | Always `"gms-web"`. |
| `version` | number | Format version. Fields are only ever added within a version; a breaking change gets a new number. |
| `addonVersion` | string | GMS version that made the export. |
| `guild`, `realm` | string | The guild and realm. |
| `exported` | number | Unix time (seconds, server time) of the export. |
| `exportedBy` | string | The officer who exported it. |
| `currentWeek` | number | The raid week at export time (see Weeks). |
| `categories` | array | The effort categories, in the order used everywhere. |
| `config` | object | The guild's rules **now**: caps per category, gold per bank point, weekly honor target, guild kill share (%), points per dungeon run, and features on/off. |
| `players` | array | Every main that appears in the export, sorted by name. |
| `weeks` | array | Oldest first. |

**Players**

| Field | Type | Meaning |
|---|---|---|
| `name` | string | The main's name, as GMS shows it (no realm for the home realm). |
| `class` | string or null | Class token (`WARRIOR`, `MAGE`, ...) if they're in the guild roster now. |
| `alts` | array | Characters linked to this main. |

Scores are per main (alts included). Loot is per character: map a loot `player` to its main with
the `alts` lists.

**Weeks**

| Field | Type | Meaning |
|---|---|---|
| `week` | number | Raid week number: weeks are numbered by the weekly reset that ends them, so the number goes up by one every reset. |
| `start`, `end` | number | Unix times of the reset that starts and ends the week. |
| `source` | string | `"ledger"` (worked out from the events now) or `"archive"` (stored when the week left the ledger). |
| `caps` | object | The caps that applied: for archived weeks, the caps when it was archived; for ledger weeks, the caps now. |
| `scores` | array | One entry per player with anything that week: points per category and `total` (capped at the sum of the caps). |
| `loot` | array | Every award that week, oldest first. |

**Loot**

| Field | Type | Meaning |
|---|---|---|
| `player` | string | The character that got it. |
| `itemId` | number or null | Item ID. |
| `item` | string or null | Item name as it was linked. |
| `itemString` | string or null | The game's item string (item ID, enchant, suffix ...). |
| `response` | string or null | `"Main spec"`, `"Off spec"`, `"Pass"`, or for items given to the guild `"Guild bank"` / `"Disenchant"`. |
| `reason` | string or null | The officer's award reason: `"Upgrade"`, `"BiS"`, `"Off spec"`, `"Alt"`, `"Other"`, or null. |
| `forGuild` | boolean | `true` for Guild bank and Disenchant: the item isn't the player's win. |
| `time` | number | Unix time of the award. |
| `awardedBy` | string or null | The officer who recorded it. |

## Notes
- Archived weeks keep the scores they had when they were archived. If officers change the caps
  later, those weeks don't change; ledger weeks always use the current caps.
- Removed (voided) events are never in the export.
- Names with spaces are normal on WoW: Forever ("First Surname").
- Strings are JSON-escaped; there are no game color codes in the text.
