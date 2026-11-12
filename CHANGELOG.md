# Changelog

## [1.2.2] — 2026-11-12

- **The gear window (and the WoW Forever gear window) can be dragged** and stays where you put it, even after a restart, also after you resize it.
- **Void hub button:** left-click opens one panel with all your Void addons by name, grouped, each with its own on/off switches (it replaces the ring of icons), with a background slider. The hub's info window now stays where you put it.

## [1.2.1] — 2026-11-10

### Fixed (WoW Forever)
- **Quest upgrades no longer lists far-off quests** while their level is still loading: level 59 Silithus and Mount Hyjal quests showed up for a level 31 character. A quest now waits until the game has sent its level, and the list fills in as levels arrive.
- Quest upgrades also only lists your own faction's quests now (with VoidQuest 0.3.19, which knows each quest's side).

## [1.2.0] — 2026-11-10

### Added (WoW Forever)
- **A gear panel for Forever** (minimap button, Void hub or `/vgear`): **Your gear** scored with your class's weights, **Dungeon upgrades** (drops from dungeons near your level, with drop chances, from VoidDungeon) and **Quest upgrades** (quest rewards you can still get; click for the way to the quest giver, from VoidQuest). Closest to your level first. Midnight's planner no longer opens there.

### Fixed (WoW Forever)
- **Classic "Equip:" stats count:** crit %, hit %, attack power, spell damage, healing, mp5, defense, dodge / parry / block, weapon skill. Caster wands count too. VoidBags' upgrade arrows and VoidQuest's reward advice use this.
- A saved retail preset no longer overrides your class weights on Forever; Spares and the season lookups are off there.

## [1.1.6] — 2026-11-09

- **Fixed: box borders missing a side.** Depending on where a window sat on screen, its left, right or bottom line could vanish. Borders are now exactly one screen pixel and can't round away.

## [1.1.5] — 2026-11-07

### Fixed
- **WoW Forever: attack power counted for nothing.** Gear with "+attack power" (or "+ranged attack power") scored as if that stat weren't there, so a piece like Chasm Walkers looked worse than it is. Attack power now counts for every physical class (about half as much as your main stat; hunters also value ranged attack power). Upgrade arrows in VoidBags and quest reward advice in VoidQuest use these scores too.

## [1.1.4] — 2026-11-03

### Fixed
- **A BoE piece on another character could be listed to disenchant** even though it might still sell: whether it's unbound is only known on the character holding it. Viewed from elsewhere it now shows under **Check** ("if it's still unbound, sell it"), and as **Sell** on its own character.

## [1.1.3] — 2026-11-03

### Fixed
- **Spares judged the same piece differently depending on the character you were on.** Leather, mail and plate pieces (and many trinkets) carry two or three main stats, and the game only reports the one for the class you're logged in as. VoidGear now reads every main stat from the item itself and scores each of your characters with its own, so the Keep / Disenchant list is the same from every character.

## [1.1.2] — 2026-11-03

### Fixed
- **Another character's trinkets could be listed to disenchant.** Seen from a character of another class, VoidGear wrongly decided a trinket with Agility, Intellect and Strength couldn't be used by its owner, so it skipped every keep check. It now reads all three stats, and when it can't tell whether a character can use a piece, or can't compare item levels (an off-hand for someone holding a two-hander), the piece goes to **Check: you decide**, never Disenchant.

## [1.1.1] — 2026-11-03

### Added
- **Spares tab buttons, so you don't have to find each piece in your bags.** On a character with Enchanting, **Disenchant next** disenchants the next piece on its list with each click (hover it to see which; the game needs one click per disenchant), and **Take from bank** moves its pile from its bank and the warband bank into its bags while the bank is open. On your other characters, **Put in warband bank for ...** deposits the pieces your enchanter should disenchant.

### Safer disenchanting
- **Never touched:** every profession item, primary or secondary (anything with a profession stat, a profession named in its tooltip such as Fishing or Cooking, or no combat stats at all), items you protected in VoidBags (middle-click in your bags), items in one of your equipment sets, and anything you **right-click** in the Spares tab ("always keep"; right-click again to undo).
- **Two tests before "disenchant":** a piece has to lose on its stats **and** be below the item level that every character who can wear it already has on. If either test says it's as good, it's kept.
- **The button names the next piece** ("Disenchant: Fiber of Living Agony (3)") and checks it again at the moment you click.

### Fixed
- **Spares gave different answers on different characters.** Trinkets are now judged by item level for every character (their effects can only be scored on the character itself), and one below what is worn goes to **Check: you decide**, never Disenchant. So a trinket no longer reads "keep" on its owner and "disenchant" on your other characters. And a character with Enchanting disenchants the pieces it holds itself: a piece in your enchanter's bags no longer says "send it to" whichever enchanter you're on.

## [1.1.0] — 2026-11-03

### Added
- **Spares tab: keep, sell, disenchant or vendor.** Every spare piece of gear in your characters' bags, their banks and the warband bank (with VoidBags), judged against all your characters, not just the one you're on. Keep: an upgrade or within 3% of what one of them wears ("+4.2% for Vede (Unholy)"), or a look you haven't collected. Sell: unbound BoE worth more on the AH than disenchanted (with VoidAH). Disenchant: which of your enchanters does it, and whether to send it there or take it from the warband bank, with what it gives. Vendor: older-expansion gear and soulbound pieces on a character without Enchanting. Catalyst: a piece in your bags the Catalyst would turn into a tier upgrade is kept ("Catalyst it: your tier gloves at 292, you wear 272"). Each character joins the check the first time you log in on it; until then anything that might suit it is listed under "Check after logging in", never Disenchant.

### Fixed
- **Gems for new gear in VoidAH:** right after you put on a new item, its gem could be missing from the VoidGear suggestions in VoidAH until you reopened the Auction House. VoidGear now tells VoidAH when your gear is still loading.

## [1.0.7] — 2026-11-02

### Changed
- **Settings are per character.** Each character keeps its own VoidGear settings, and a new character starts with the settings of the one you played last, so nothing resets when you update. Right-click the Void hub icon by your minimap and pick **Copy settings from...** to take another character's settings for one Void addon or all of them.

## [1.0.6] — 2026-11-02

### Changed
- **Void hub icon:** your Void addons now pop out in rings around the hub icon, fanning away from the minimap, instead of one long column. The pop-up also works while another addon moves or fades the minimap.

## [1.0.5] — 2026-11-01

### Changed
- **Void hub icon:** the list of Void addons is up to date (adds VoidGather and VoidSweep, refreshed descriptions).

## [1.0.4] — 2026-10-31

### Prep tab
- **Easier to read.** Columns are labelled (You have, Get, This item, In bags), and the rows are split into **Must fix**, **Optional upgrades** and **Consumables**. Optional upgrades say they aren't on the shopping list.
- **Shows what you have now:** the enchant on that slot ("Hex of Leeching"), "No diamond", "Empty socket", or for consumables "This one", the other one you carry with its count, or "None".
- Enchant names drop the "Enchant Helm -" part (the row already names the slot), and the shopping list reads "buy 1" / "have 1, buy 1".

## [1.0.3] — 2026-10-31

### Upgrades (Raid, M+, World, Vault)
- Weapons are compared as a whole setup: a two-hander against your main hand and off hand together ("Both Hands"), an off-hand item never against a two-hander, a one-hander against your weaker hand when you dual-wield, and Titan's Grip two-handers against the weaker hand.
- An empty slot shows as "empty slot" instead of hiding the drop or comparing it with your other ring or trinket.
- A unique-equipped ring or trinket is compared with the one it can't be worn beside.
- Drops are only scored at their real item level; one the game hasn't sent yet shows "..." until it does, and the loot list rescans by itself once it loads.
- After a spec change the loot list rescans by itself.
- Items with a passive "Equip:" effect get credit for it, and trinkets with one no longer set the baseline for what a trinket's stats should be worth.
- The trinket baseline is now worked out after login once your gear has loaded (it stayed on a rough default before).

### Great Vault
- Dungeon slots show this season's whole dungeon loot pool, whichever dungeons you ran.
- Raid slots show every boss up to your furthest kill at that slot's difficulty, kept for the season, per raid.
- Abandoned keys no longer set the key level loot is shown at.

### Crests
- Upgrade costs read at the upgrade NPC are only treated as exact while that item's crest discount hasn't changed.
- A socket's gem no longer counts as growing with the item's level.

### Prep
- "Highest secondary stat" consumables are valued at the stat you actually have the most of.

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
