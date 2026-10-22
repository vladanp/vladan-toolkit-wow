# Vladan Toolkit (WoW Forever addon): project guide

A personal all-in-one addon for **World of Warcraft: Forever** that grows one feature at a time.
**Every feature must be switchable on/off in the settings panel (`/vt`).**
The repo is **public**: never commit secrets or personal data.

## Game facts
- Forever = Interface **16001** (check in-game: `/dump select(4, GetBuildInfo())`). If live changes it, update `## Interface:` in the TOC.
- Forever loads as the **Mainline** family, so it has the modern API (Settings, `C_*`, addon compartment) and Midnight-style restrictions:
  - Secret values (e.g. `UnitHealth`, unit names): guard with `issecretvalue` before comparing or printing.
  - No `COMBAT_LOG_EVENT_UNFILTERED` / `CombatLogGetCurrentEventInfo`.
  - Some old globals are gone: use `C_Item.GetItemInfo`, `C_Spell.GetSpellInfo`, `C_CVar.GetCVarBool`, etc.
  - Respect `InCombatLockdown()` before touching protected frames.
- No official docs: verify every API in-game (`/api`, `/dump`) before relying on it.
- Lua 5.1. No libraries (no Ace3); the native Settings API is enough.

## Layout
```
VladanToolkit.toc     # metadata + file load order
Core.lua              # VT:NewModule, module:On(event, fn), Settings panel, /vt
Modules/<Name>.lua    # one file per feature
```
SavedVariables: `VladanToolkitDB` (account-wide, flat: `VladanToolkitDB.<ModuleKey>` is the on/off flag,
`<Key>Pos` a saved frame position) and `VladanToolkitCharDB` (per character, e.g. the auto-buy list).

Core helpers: `VT:Print(...)`, `VT:CreateTextFrame(key, point, x, y)` (draggable text, position saved),
`VT.commands.<name> = fn(args)` (adds `/vt <name> ...`), `m:IsEnabled()`.

**Reference source:** Blizzard's Forever UI code is mirrored at `github.com/Gethe/wow-ui-source` (branch `forever`)
and the full API list at `github.com/Ketho/BlizzardInterfaceResources` (branch `forever`, `Resources/GlobalAPI.lua`).
Check a function exists there before using it. Prefer Blizzard's built-ins (e.g. `C_MerchantFrame.SellAllJunkItems`, the mail `OpenAllMail` button).
Chat: only change messages through `ChatFrameUtil.AddMessageEventFilter`; replacing chat functions or `AddMessage` taints chat and breaks secret-value handling.

## Adding a feature
1. Create `Modules/<Name>.lua`:
   ```lua
   local _, VT = ...
   local m = VT:NewModule("<Key>", "<Checkbox title>", "<Tooltip>") -- 4th arg false = off by default
   m:On("SOME_EVENT", function(...) --[[ runs only while enabled ]] end)
   ```
2. Add `Modules\<Name>.lua` to the TOC.
3. The checkbox appears in `/vt` automatically. Handlers are gated by the toggle, so nothing else is needed.
   A feature that shows UI also sets `m.OnToggle = function(self, enabled) ... end` to show/hide it
   (called at login and whenever the box is ticked).

## Dev loop
- The addon folder is a junction: `C:\Games\World of Warcraft\_classic_beta_\Interface\AddOns\VladanToolkit` → this repo.
  If live Forever uses a different install folder, re-create it:
  `New-Item -ItemType Junction -Path "<WoW>\<folder>\Interface\AddOns\VladanToolkit" -Target "D:\Projects\vladan-toolkit-wow"`
- Edit, then `/reload` in-game. A brand-new addon folder or TOC edit may need a full client restart if `/reload` doesn't pick it up.
- Turn on Lua errors once: `/console scriptErrors 1`.
- SavedVariables are written on `/reload` or logout: `<WoW>\_classic_beta_\WTF\Account\<id>\SavedVariables\VladanToolkit.lua`.
- VS Code: install the recommended `ketho.wow-api` extension (autocomplete + diagnostics).

## Commits
Conventional commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`).
