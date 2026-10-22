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
SavedVariables: `VladanToolkitDB`, a flat table. `VladanToolkitDB.<ModuleKey>` is the on/off flag.

## Adding a feature
1. Create `Modules/<Name>.lua`:
   ```lua
   local _, VT = ...
   local m = VT:NewModule("<Key>", "<Checkbox title>", "<Tooltip>") -- 4th arg false = off by default
   m:On("SOME_EVENT", function(...) --[[ runs only while enabled ]] end)
   ```
2. Add `Modules\<Name>.lua` to the TOC.
3. The checkbox appears in `/vt` automatically. Handlers are gated by the toggle, so nothing else is needed.
   A feature that creates UI must also hide it when disabled (no hook for that yet: add `OnToggle` to Core when the first UI module needs it).

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
