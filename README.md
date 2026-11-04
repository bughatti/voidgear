# VoidGear

**Know what to wear, what to fix and where your crests go: a gear planner built from what the top Mythic+ players of your spec actually use.**

VoidGear compares your gear with the top Mythic+ players of your spec, then tells you which enchants, gems and consumables you're missing and how to buy them. It finds your upgrades from this season's raid, dungeons, world bosses and Great Vault, and shows which item your crests should go into next. Everything is scored for your spec, from Blizzard's own data.

---

## Features

### Top players
- **Top tab** shows what the top Mythic+ players of your spec wear, slot by slot: items, enchants and gems, next to what you have on
- **Any spec**: the dropdown switches to "Top Subtlety Rogue", "Top Guardian Druid" and so on, so you can plan an off-spec or an alt
- Built from Blizzard's own character data and updated with each release

### Prep: what to fix and buy
- **Enchants and gems** you're missing or could improve, slot by slot, taken from what the top players of your spec use
- **Consumables**: flask, combat potion, healing potion, food, weapon oil and augment rune. It shows what's already in your bags, so you only buy what you're out of
- **Best or Budget**: one switch for the whole list, plus a per-item override. Budget is the same enchant or gem at the lower crafted quality, made for a short-term item. Gear on a low upgrade track (Explorer, Adventurer, Veteran) goes Budget by itself
- **Shopping list** with a **Search AH** button on every row
- **With VoidAH installed**, the Auction House shopping list gets a "VoidGear suggestions" section. Buy it, put it on, and it drops off the list by itself. VoidAH works fine without VoidGear, and VoidGear without VoidAH

### Upgrades
- **Raid, M+ and World tabs** list this season's drops that beat what you wear, scored for your spec, with where each one drops
- **Vault tab** shows the best picks for your Great Vault at the item level the vault gives you
- **Stat priority** for every spec, with a dropdown to pick another, and "Show all items" when you want the full list
- Reads the loot straight from the Adventure Guide (**Scan Loot**, once per season and spec), so it's always this season's loot for your class

### Spares: keep, sell or disenchant
- **Every spare piece of gear** in your characters' bags, their banks and the warband bank (with VoidBags), judged against **all your characters**, not just the one you're on
- **Keep** what's an upgrade, or close to one, for any of them ("+4.2% for Vede (Unholy)"), and pieces whose look you haven't collected
- **Sell** unbound BoE gear that's worth more on the AH than disenchanted (prices from VoidAH)
- **Disenchant** the rest, with which of your enchanters does it and what it gives; **vendor** older-expansion gear
- **No hunting through your bags:** on your enchanter, **Disenchant next** disenchants the next piece on the list with each click, and **Take from bank** pulls the pile out of your bank and the warband bank. On your other characters, **Put in warband bank** deposits what your enchanter should disenchant
- Soulbound gear only counts for its owner; warbound gear and the warband bank's count for everyone

### Crests
- **Where your crests should go next**: a small badge on each upgradeable item on the Character window ranks your next upgrade per crest type by stat gain per crest spent
- It knows when to stop at 4/6 and start another item. Visit the upgrade NPC once and it reads the exact costs, discounts included
- `/vgear catalyst` lists what in your bags the Catalyst will take

### Easy to reach
- **Gear Plan tab** on the Character window (a round icon if you use Chonky Character Sheet), the minimap button, or `/vgear`

---

## Slash Commands

| Command | What it does |
|---|---|
| `/vgear` | Open or close VoidGear |
| `/vgear top` | Open on the Top tab |
| `/vgear prep` | Open on the Prep tab (enchants, gems, consumables) |
| `/vgear vault` | Open on the Vault tab |
| `/vgear scan` | Read this season's raid and M+ loot from the Adventure Guide again |
| `/vgear upgrades` | Where your crests should go next, in chat |
| `/vgear upgrades scan` | Read exact upgrade costs (with the upgrade NPC open) |
| `/vgear upgrades on` / `off` | Show or hide the crest badges on the Character window |
| `/vgear catalyst` | What in your bags the Catalyst will take |
| `/vgear weights` | Show the stat weights in use |

---

## Getting Started

1. Install with the CurseForge app, or copy the `VoidGear` folder into `World of Warcraft/_retail_/Interface/AddOns/`.
2. Restart WoW or `/reload`.
3. Open VoidGear (`/vgear`, the minimap button or the Gear Plan tab) and press **Scan Loot** once. It reads this season's loot from the Adventure Guide for your spec.
4. Start with the **Prep** tab: it lists what to enchant, gem and buy right now.

---

## Good to Know

- **Settings are per character.** Each character keeps its own VoidGear settings, and a new character starts with the settings of the one you played last, so nothing resets when you update. Right-click the Void hub icon by your minimap and pick **Copy settings from...** to take another character's settings for one Void addon or all of them.
- **You still click to enchant and socket.** VoidGear tells you what to use and helps you buy it; the game requires you to apply it yourself.
- **Crest costs are exact after you open the upgrade NPC once.** Before that, VoidGear assumes the same cost for every step and says so in the tooltip.
- **Made for English game clients.** Consumables are recognized by their English tooltips.
- Scores are a guide, not a sim. Trinkets and items with procs are valued from what the top players of your spec choose.

---

## Compatibility

- **WoW 12.1.5** (Midnight Season 2)
- Standalone: nothing else to install
- Works alongside VoidAH (shopping list), VoidBags and Chonky Character Sheet

---

*Part of the Void addon family by Vede · MIT licensed · [Source & bug reports](https://github.com/bughatti/voidgear) · [All Void addons](https://www.curseforge.com/members/bughatti/projects) · free M+ & raid player lookups at [voidscout.io](https://voidscout.io) · more at [tinkerline.io](https://tinkerline.io) · [Discord](https://discord.gg/7ZHmx7zMDh)*
