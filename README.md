# Vladan Toolkit

A personal all in one addon for **World of Warcraft: Forever**. Every feature is a small module you can switch on or off.

Type **`/vt`** in game (or use the addon compartment on the minimap) to open the settings.

## Features
| Feature | What it does |
|---|---|
| Faster auto loot | Grabs all loot instantly when auto loot is on. |
| Sell junk | Sells all grey items when you open a vendor. |
| Auto repair | Repairs all gear at vendors that can repair. |
| Auto buy reagents | Tops up a list for each character at vendors: `/vt buy <shift click item> <count>` (0 removes, `/vt buy` lists). |
| XP tracker | A card with Forever's own XP bar art, XP per hour, projected level up time, and kills and quests to level. Hover for details, drag to move, right click to reset. |
| Auto open all mail | Presses the mailbox's Open All button for you (skips COD and GM mail). |
| Missing buff reminder | Out of combat, pulsing icons for your missing class buffs. Click an icon to cast it on yourself, drag the title to move. |
| Copyable chat links | Web links in chat become clickable; click, then Ctrl+C. |
| LFG chat scanner | `/vt lfg` opens a window of LFG and LFM posts from chat channels, grouped by dungeon, with roles and class colors. Filter by dungeon or word (a sound plays for new matches), click to whisper, Shift click to invite. |
| Square minimap | A clean square minimap with a thin border. |
| Auto zoom out | Zooms the minimap back out 10 seconds after you zoom in. |
| Minimap buttons on hover | Hides the clock, tracking and addon buttons until your mouse is over the minimap. |
| Low supplies warning | A small card when gear durability or items on your auto buy list run low, with a sound. Right click dismisses it until something new runs low. |
| Error spam filter | Hides red error spam (not enough rage/energy/mana, not ready yet, range and facing) using the game's own switches. Other errors still show. |
| Tooltip extras | Item level (when not already shown), stack size, and item, spell and NPC IDs. |

## Settings
`/vt` opens the main page with general settings: lock windows, chat messages, window scale and a button to reset window positions.
Each group has its own page in the sidebar (Loot and vendors, Leveling and buffs, Social, Minimap, Interface). Extra options
sit under the feature they belong to and grey out while it is off:

- **XP tracker:** XP per hour window (5 to 60 min), details line, floating XP gains, reset session.
- **Missing buff reminder:** icon size, spell names, pulsing border.
- **LFG chat scanner:** how long posts stay, sound and chat line for new matches.
- **Auto zoom out:** delay (3 to 30 sec).
- **Low supplies warning:** durability threshold, supplies threshold, sound.
- **Error spam filter:** resource errors, cooldown errors, range and facing errors, only during combat.
- **Tooltip extras:** item level, stack size, IDs.

## Install
**WowUp** (updates automatically): Get Addons → Install from URL → `https://github.com/vladanp/vladan-toolkit-wow`.
Every change pushed to `main` publishes a new release automatically.

Manual: download the zip ending in `forever.zip` from [Releases](https://github.com/vladanp/vladan-toolkit-wow/releases)
and extract it into `World of Warcraft\<Forever folder>\Interface\AddOns`.

See [CLAUDE.md](CLAUDE.md) for how to add a feature.
