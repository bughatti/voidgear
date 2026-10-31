# Changelog

## [1.0.2] — 2026-10-31

### Fixes
- Changing spec while logged in left the Stat Priority dropdown showing the old spec's name.
- Prep: after a spec change the augment rune row could disappear, because its description was still the one for the old spec's main stat ("Increases Intellect" on a Guardian druid).

## [1.0.1] — 2026-10-31

### Fixes
- Prep: right after logging in, a consumable whose description hadn't loaded yet could be skipped, so the weapon oil or rune row was missing or the flask pick was wrong until a /reload. The tab now waits for that text and redraws.
- The login message and the window footer showed an old version number.

## [1.0.0] — 2026-10-30

First public release.

### Top players
- Top tab: what the top Mythic+ players of your spec wear (items, enchants, gems) next to your own gear, from Blizzard's character data. The dropdown switches to any spec.

### Prep
- Enchants and gems you're missing or could improve, from what the top players of your spec use.
- Consumables: flask, combat potion, healing potion, food, weapon oil and augment rune, counting what's already in your bags.
- Best or Budget for the whole list, with a per-item override. Gear on a low upgrade track defaults to Budget.
- Shopping list with a Search AH button. With VoidAH installed, it searches in VoidAH and the AH shopping list gets a "VoidGear suggestions" section that clears itself as you buy and apply.

### Upgrades
- Raid, M+, World and Vault tabs: this season's drops that beat your gear, scored for your spec, with where they drop. Vault picks are shown at the vault's item level.
- Loot is read from the Adventure Guide for this season and your spec (Scan Loot).

### Crests
- Badges on the Character window show which item your crests should go into next, ranked by stat gain per crest. Exact costs are read at the upgrade NPC.
- `/vgear catalyst` lists what in your bags the Catalyst will take.

### Access
- Gear Plan tab on the Character window (a round icon with Chonky Character Sheet), minimap button, `/vgear`.
