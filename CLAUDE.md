# Vladan Toolkit (WoW Forever addon): project guide

A personal all in one addon for **World of Warcraft: Forever** that grows one feature at a time.
**Every feature must be switchable on/off in the settings panel (`/vt`).**
The repo is **public**: never commit secrets or personal data.

## Writing style
No em dashes and no dashes between words in docs, in game text, code comments or commit messages
(write "auto loot", "per character", "right click"). Hyphens stay only where technically required:
file and repo names, URLs, commands, code identifiers.

## Game facts
- Forever = Interface **16001** (check in game: `/dump select(4, GetBuildInfo())`). If live changes it, update `## Interface:` in the TOC.
- Forever loads as the **Mainline** family, so it has the modern API (Settings, `C_*`, addon compartment) and Midnight style restrictions:
  - Secret values (e.g. `UnitHealth`, unit names): guard with `issecretvalue` before comparing or printing.
  - No `COMBAT_LOG_EVENT_UNFILTERED` / `CombatLogGetCurrentEventInfo`.
  - Some old globals are gone: use `C_Item.GetItemInfo`, `C_Spell.GetSpellInfo`, `C_CVar.GetCVarBool`, etc.
  - Respect `InCombatLockdown()` before touching protected frames.
- No official docs: verify every API in game (`/api`, `/dump`) before relying on it.
- Lua 5.1. No libraries (no Ace3); the native Settings API is enough.

## Layout
```
VladanToolkit.toc     # metadata + file load order
Core.lua              # VT:NewModule, module:On(event, fn), Settings panel, /vt
Modules/<Name>.lua    # one file per feature
```
SavedVariables: `VladanToolkitDB` (account wide, flat: `VladanToolkitDB.<ModuleKey>` is the on/off flag,
`<Key>Pos` a saved frame position) and `VladanToolkitCharDB` (per character, e.g. the auto buy list).

Core helpers: `VT:Print(...)` (command replies), `VT:Notify(...)` (automatic messages, muted by the "Chat messages" setting),
`VT:CreateMovable(key, point, x, y, template)` (draggable frame, position saved, follows "Lock windows", "Window scale"
and "Reset positions"), `VT.commands.<name> = fn(args)` (adds `/vt <name> ...`), `m:IsEnabled()`, `m:Get(optionKey)`,
`VT.format.percent/minutes/seconds/pixels` (slider labels).

**Settings layout:** `/vt` opens the main page (General: lock windows, chat messages, window scale, reset positions).
Each `m.section` becomes its own page in the sidebar. A module's checkbox comes first and its `m:Option(...)`
settings sit indented under it, greyed out while the module is off. Only add an option when a real choice exists.

**UI look:** panels use `"TooltipBackdropTemplate"` (Forever's rounded tooltip panel). Bars use the game's own atlases
(`UI-HUD-ExperienceBar-*`), which Forever skins with its own art. Fonts: `GameFontNormalLarge` titles,
`GameFontDisableSmall` uppercase captions, `Game15Font_Shadow` values.

**Reference source:** Blizzard's Forever UI code is mirrored at `github.com/Gethe/wow-ui-source` (branch `forever`)
and the full API list at `github.com/Ketho/BlizzardInterfaceResources` (branch `forever`, `Resources/GlobalAPI.lua`,
`AtlasInfo.lua` for textures). Check a function exists there before using it. Prefer what Blizzard already built
(e.g. `C_MerchantFrame.SellAllJunkItems`, the mail `OpenAllMail` button).
Chat: only change messages through `ChatFrameUtil.AddMessageEventFilter`; replacing chat functions or `AddMessage`
taints chat and breaks secret value handling.

## Adding a feature
1. Create `Modules/<Name>.lua`:
   ```lua
   local _, VT = ...
   local m = VT:NewModule("<Key>", "<Checkbox title>", "<Tooltip>") -- 4th arg false = off by default
   m.section = "Social" -- settings page: Loot and vendors, Leveling and buffs, Social, Minimap
   m:On("SOME_EVENT", function(...) --[[ runs only while enabled ]] end)
   -- optional extra settings, stored as VladanToolkitDB.<Key><OptionKey>, read with m:Get("<OptionKey>"):
   m:Option({ key = "Delay", title = "Delay", default = 10, min = 3, max = 30, step = 1, format = VT.format.seconds, desc = "..." })
   m:Option({ key = "Sound", title = "Sound", default = true, desc = "..." })
   m:Option({ title = "Session", button = "Reset", onClick = fn, desc = "..." })
   ```
2. Add `Modules\<Name>.lua` to the TOC next to the other modules of its section (a header is added whenever the section changes).
   Secure frames (e.g. click to cast buttons) can't be changed in combat: check `InCombatLockdown()` first;
   `PLAYER_REGEN_DISABLED` still allows a last change just before combat starts.
3. The checkbox appears in `/vt` automatically. Handlers are gated by the toggle, so nothing else is needed.
   A feature that shows UI also sets `m.OnToggle = function(self, enabled) ... end` to show or hide it
   (called at login and whenever the box is ticked).

## Releases (how the game gets updates)
- Every push to `main` that changes `.lua`/`.toc`/`.pkgmeta` runs `.github/workflows/release.yml`: it tags the next
  patch version (`v0.2.0` → `v0.2.1`) and runs itself again on that tag, where BigWigs packager publishes a GitHub release
  (zip + `release.json`, flavor `forever`). The packager refuses to release from a branch push, hence the two runs.
  Pushes that only change docs don't release. For a bigger version jump, push a tag like `v0.3.0` together with the commit.
- `## Version: @project-version@` in the TOC is filled in by the packager.
- WowUp on this PC installs the addon from `https://github.com/vladanp/vladan-toolkit-wow` (Forever / Classic Beta client)
  with Auto Update on. So the loop is: commit → push → wait about a minute for the release → WowUp updates → `/reload`.
- Faster local loop (optional): replace the WowUp folder with a junction to this repo
  (`cmd /c rmdir "<AddOns>\VladanToolkit"` then `New-Item -ItemType Junction -Path "<AddOns>\VladanToolkit" -Target "D:\Projects\vladan-toolkit-wow"`).
  Remove the junction with `cmd /c rmdir` (never `Remove-Item -Recurse`, which deletes the repo files) before WowUp updates again.

## Dev loop
- Addons folder: `C:\Games\World of Warcraft\_classic_beta_\Interface\AddOns\VladanToolkit` (live Forever may use a different folder).
- `/reload` in game picks up changed files. A brand new addon folder or TOC edit may need a full client restart.
- Turn on Lua errors once: `/console scriptErrors 1`.
- SavedVariables are written on `/reload` or logout: `<WoW>\_classic_beta_\WTF\Account\<id>\SavedVariables\VladanToolkit.lua`.
- VS Code: install the recommended `ketho.wow-api` extension (autocomplete + diagnostics).

## Commits
Conventional commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`).
