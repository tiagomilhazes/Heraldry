# Heraldry

An all-in-one, modular, immersive UI addon for **World of Warcraft: Forever**. It is the successor to the author's (Tiago's) older addon **TimelessUI**. From TimelessUI only the **art** is reused, never the code.

This README documents the project as it stood at commit `804a2b7` (2026-11-19), when it moved from Claude chat to Claude Code, updated for the Claude Code work up to commit `80443ea`: the git clone and local deploy (§9.1), the audit fixes and the chat copy box. `CLAUDE.md` holds the standing instructions for an AI agent continuing the work. Where this README and the code disagree, the code wins. Known disagreements are listed in [§10](#10-contradictions-and-stale-information).

Contents:

1. [Architecture](#1-architecture)
2. [Implemented features](#2-implemented-features)
3. [Compatibility](#3-compatibility)
4. [File structure](#4-file-structure)
5. [Development decisions](#5-development-decisions)
6. [Dependencies](#6-dependencies)
7. [Known problems and untested items](#7-known-problems-and-untested-items)
8. [Future work](#8-future-work)
9. [Important details from the history](#9-important-details-from-the-history)
10. [Contradictions and stale information](#10-contradictions-and-stale-information)

---

## 1. Architecture

### 1.1 Core plus module addons

Every top-level folder is one WoW addon. Copy them into `Interface\AddOns\`.

- `Heraldry` is the **core**, which is always loaded. It owns these systems:
  - database, profiles and modules
  - movers and edit mode
  - themes, fonts and paper
  - the settings registry, the game-menu button and slash commands
- `Heraldry_Options` is the **settings panel**. It is load-on-demand and loads the first time the panel opens.
- Every `Heraldry_<Name>` folder is an **optional module** with `## Dependencies: Heraldry` and `## X-Heraldry-Module: 1`.
  - A disabled module never loads, so it costs no memory or CPU.
  - The core works alone: it has the panel, profiles and edit mode, but shows nothing on screen.

Modules talk to the core only through its public API (`_G.Heraldry`, called `H`). A module never touches another module's data. There are two exceptions where one module checks another for docking:
- Orbs dock to bar 1 of ActionBars (`## OptionalDeps: Heraldry_ActionBars`).
- Auras uses the orbs' sockets (`## OptionalDeps: Heraldry_Orbs`).

There are **no `.xml` files**. Everything is built in Lua with `CreateFrame` and Blizzard templates.

### 1.2 Core load order (`Heraldry/Heraldry.toc`)

```
Core\Init.lua  Core\Events.lua  Core\Combat.lua
Core\Database.lua  Core\Profiles.lua
Core\Options.lua  Core\Modules.lua
Core\Movers.lua  Core\EditMode.lua
Core\Themes.lua  Core\Fonts.lua  Core\Paper.lua
Themes\Standard.lua  Themes\Paladin.lua  Themes\Priest.lua  Themes\Druid.lua  Themes\Warrior.lua
Core\GameMenu.lua
Core\Commands.lua          (always last)
```

### 1.3 Namespace and data shortcuts

- `H` is `ns.H` inside the core and `_G.Heraldry` everywhere else. Modules start with `local H = Heraldry`.
- Core sub-tables: `H.Modules` (`.byName`, `.list`), `H.Movers` (`.byKey`), `H.Themes`, `H.Fonts`, `H.Profiles`, `H.Paper`.
- Shortcuts set at boot:

  | Shortcut | Holds |
  |---|---|
  | `H.sv` | the whole `HeraldryDB` |
  | `H.global` | `HeraldryDB.global` |
  | `H.char` | this character's entry |
  | `H.profile` | the active profile |

- `H.commands[cmd] = fn(rest)` is an extension point that lets modules add `/hui` sub-commands. Minimap adds `grab`.
- `H.previews` is a list of `{ key, label, desc, get, set }` toggles for made-up preview content, added by modules.

### 1.4 Boot sequence and messages

- `ADDON_LOADED` fires the `DB_LOADED` message, then `PLAYER_LOGIN` fires the `READY` message (`Core/Database.lua`).
- Internal messages use `H:On(msg, fn)`, `H:Off`, `H:Fire(msg, ...)` (`Core/Events.lua`). Listener lists are copy-on-write and every listener runs in `xpcall`, so an error is reported and the others still run.
- Messages that exist in the code:

  | Message | Fired when |
  |---|---|
  | `DB_LOADED` | the SavedVariable is ready |
  | `READY` | player login, after the DB |
  | `PROFILE_CHANGED` | the active profile changes |
  | `PROFILE_RENAMED` | a profile is renamed |
  | `THEME_CHANGED` | the active theme key changes (theme pick, finish, or a form/stance change) |
  | `FONTS_CHANGED` | the fonts change |
  | `MOVER_ADDED` | a mover is registered |

- Game events go through `H:RegisterEvent(event, fn)` and `H:UnregisterEvent`.

### 1.5 Database (`HeraldryDB`)

```lua
HeraldryDB = {
  version   = 1,
  global    = { debug, editMode = { grid, gridSize }, options = {...panel position/scale/last page...},
                minimapGrab = { [buttonName] = true }, ... },
  profiles  = { ["Default"] = { modules = {}, layout = {}, preset = "altar", fonts = {} } },
  overrides = { },            -- reserved for C3 (class overrides), not used yet
  chars     = { ["Name-Realm"] = { profile, theme, finish, formThemes, useSpecProfiles, specProfiles,
                                   auraSockets, indicators, clickcast, raidRolled, ... } },
}
```

- **Theme and finish live per character**, never in the profile. A profile shared between classes keeps each class's art.
- Other per-character data:
  - `formThemes`: the theme for each form.
  - `auraSockets`: the power-orb gem auras.
  - `indicators`: the healer indicators.
  - `clickcast`: the click-casting bindings.
  - `raidRolled`: which raid rows are rolled up.
  - Chat input history.

  The reason is that spells belong to a class.
- `layout[key] = { point, x, y, scale }`. A movable dock is stored as `{ "DOCK", dx, dy, scale }`.

### 1.6 Modules (`Core/Modules.lua`)

```lua
local M = H:NewModule("Name", { label = "Label", defaults = { ... }, fonts = true })
function M:OnInitialize() end      -- profile ready, no frames yet
function M:OnEnable() end          -- build frames; always runs out of combat
function M:OnProfileChanged() end  -- re-read self.db and re-apply
M.db.key        -- flat proxy over profile.modules[Name]; returns the default when unset
M.db.key = v    -- a value equal to its default is not stored
M:ResetSettings()
```

- Settings are **flat**: strings, numbers, booleans, and some colour tables `{r,g,b}`. When one module configures several things, the key carries a prefix, for example `bar1_size`, `party...`, `raid...`, `tot...`, `focus...` and `<block>Place`.
- `fonts = true` adds `fontOverride`, `font` and `fontOutline`, which form the module font layer.
- On/off comes only from the game's addon list: `C_AddOns.EnableAddOn/DisableAddOn(addon)`, always without the character argument. It takes effect after a reload and applies account-wide.

### 1.7 Movers and edit mode (`Core/Movers.lua`, `Core/EditMode.lua`)

```lua
H:RegisterMover(frame, "Module.thing", { label, default = { point, x, y }, scalable = true, isShown = fn })
H.Movers:Reset(key)  H.Movers:ResetAll()  H.Movers:CenterX(key)  H.Movers:Apply  H.Movers:Preview
H.Movers:Dock(key, targetKey, point, relPoint, x, y, movable)  H.Movers:Undock(key)
H:SetEditMode(on)  H:ToggleEditMode()  H:RefreshEditMode()
```

**Positions**
- The saved anchor point depends on which third of the screen the frame is in, so positions survive resolution and UI-scale changes.
- Positions are applied out of combat only.

**Docking**
- A docked frame follows its target and has no box in edit mode.
- A *movable dock*, such as the target of target, keeps its box. Dragging it saves an offset from the docked place.
- The module decides docking from its own settings; it is not saved by Movers.

**Edit mode**
- Boxes move with the native `StartMoving`.
- Snapping (to screen edges, the centre and other boxes) happens only on release. Gold guide lines show while dragging, and Alt places freely.
- Controls:

  | Input | Action |
  |---|---|
  | Arrow keys | nudge 1 px (Shift: 10 px) |
  | Mouse wheel | scale |
  | Right click | reset to the default place |
  | Middle click, C, or the "Centre" button | centre horizontally |
  | Escape or "Done" | close edit mode |

- Combat closes edit mode.
- Grid settings live in `HeraldryDB.global.editMode`.

**Registered mover keys**

| Module | Keys |
|---|---|
| ActionBars | `ActionBars.bar1` … `bar8`, `ActionBars.barstance`, `ActionBars.barpet`, `ActionBars.swing`, `ActionBars.cast` |
| Orbs | `Orbs.health`, `Orbs.power` |
| UnitFrames | `UnitFrames.target`, `UnitFrames.targettarget`, `UnitFrames.focus` (built from the unit token), `UnitFrames.party`, `UnitFrames.raid` |
| Minimap | `Minimap.frame` |
| Quests | `Quests.tracker` |
| Chat | `Chat.frame` |
| Tooltips | `Tooltips.anchor` |
| Auras | `Auras.buffs`, `Auras.debuffs` |

- The cast and swing holders only matter when "a bar of its own" is chosen.
- The DataBar has **no mover**. It is anchored to the top or bottom edge by its own settings.

### 1.8 Themes (`Core/Themes.lua`, `Themes/*.lua`)

A theme is a set of **pieces**. Each piece has a **type**, and the type defines which numbers the piece must give, measured in texture pixels. This is the **geometry contract**, so any module places any theme's art the same way.

| Piece type | Fields |
|---|---|
| `button.frame` / `button.frameSlim` | `file, size{w,h}, hole{l,t,r,b}`: the art is scaled so the hole matches the button |
| `bar.plate` / `block.plate` | `file + size`, or `color{r,g,b,a}` |
| `bar.rail` | `file, size, band{top,bottom}` (opaque rows; the file width must be a power of 2; tiled sideways) |
| `bar.cap` | `file, size, join{x,y,h}`: (x,y) is the middle of the edge that meets the plate, h is the plate height there; left end, mirrored on the right |
| `orb.health` / `orb.power` | `file, size, hole{cx,cy,r}, reach`, optional `sockets{{x,y,r}×4}` in the order top, right, bottom, left |
| `frame.gem` | `file, size` (the target's level gem; tinted for elite/rare/boss) |
| `scroll.rod` | `cap, capR?, mid, size, capW, midW?, shaft` (cap mirrored when there is no capR; mid tiled when midW is set, else stretched) |
| `scroll.rodV` | `cap, capB?, mid, size, capH, midH?, shaft` (standing rod for the chat; cap flipped when there is no capB) |
| `minimap.frame` | `file, size, window{l,t,r,b}, sockets{{x,y}×3}, socketSize, plate{l,t,r,b}, mask, art{l,t,r,b}` (without it the minimap uses its own Paladin frame) |

**Optional theme fields**
- `accent = {r,g,b}`: the metal colour for thin lines.
- `finish`: one of `none`, `aged`, `bronze`, `iron`. A finish is a desaturation plus a tint, and the player can change it.
- `class`: the class that `"auto"` picks this theme for.
- `base = "KEY"`: this theme is a **variant**. Every piece, accent and finish it lacks comes from the base theme (`Themes:Field(t, name)`), then from Standard. Variants have no `class`.

**Validation and fallback**
- A missing piece, or one that breaks the contract, is dropped with a debug message. The Standard theme's piece is used instead, if Standard has one.

**Active theme**
- The active theme is per character. `"auto"` picks the theme of the character's class, or Standard when the class has none.
- **Form themes** override it. While the player is in a form (shapeshift, stance or Shadowform, identified by spell ID), `H.char.formThemes[spellID]`, or the class default in `Themes.FORM_DEFAULTS`, wins.
- `UPDATE_SHAPESHIFT_FORM(S)` triggers `Themes:CheckForm()`, which fires `THEME_CHANGED` when the key changes.

**API**

| Function | Purpose |
|---|---|
| `H:RegisterTheme(key, def)` | register a theme |
| `Themes:Piece(type)` | the active theme's piece |
| `Themes:Paint(tex)` | apply the finish to a texture showing theme art |
| `Themes:Accent()` | the toned accent colour, or nil |
| `Themes:Set(key)`, `Themes:SetFinish(key)` | choose a theme or finish |
| `Themes:ActiveKey()`, `Themes:Active()` | the active theme |
| `Themes:CurrentForm()`, `Themes:Forms()`, `Themes:FormThemes()`, `Themes:SetFormTheme(id, key)` | form themes |
| `Themes:FinishKey()` | the active finish |

`Themes.MEDIA` is `Interface\AddOns\Heraldry\Media\Themes\`.

### 1.9 Fonts (`Core/Fonts.lua`) — three layers, nothing repeated

1. **Core** (Fonts page): header font, body font, outline and global scale. It is stored in the profile and accepts LibSharedMedia fonts when that library is present.
2. **Module** (`fonts = true`): override of font and outline. Every module shows the same "Font" tab via `page:FontSection(mod, onChange)`.
3. **Text**: each text's size and position is a setting of its own module.

Fonts are always applied with `H.Fonts:Apply(fontString, "header"|"body", size, mod)`. Chat frames are the exception, because their `SetFont` returns nothing: use `H.Fonts:Resolve(kind, size, mod)`, which returns path, size, flags and shadow. Modules listen to `FONTS_CHANGED`.

### 1.10 Paper (`Core/Paper.lua`)

Shared papers for chat, tooltips, quests, raid banners and the data bar: dark parchment, light parchment and dark glass.

| Function | Purpose |
|---|---|
| `H.Paper:Apply(tex, kind, alpha)` | put a paper on a texture |
| `H.Paper:Crop(tex, kind, w, h)` | crop to the area's shape, never stretched |
| `H.Paper:Shades(list, kind, alpha)` | soft dark edges |
| `H.Paper:InkOf(r, g, b)` | any colour as dark ink for light paper |
| `H.Paper:IsInk(kind)` | whether this paper recolours text as ink |

Paper media: `Heraldry/Media/Paper/{Light,Dark}.tga`.

### 1.11 Settings panel (`Core/Options.lua` + `Heraldry_Options`)

```lua
H:RegisterOptionsPage({
  key, label, desc, group = "core" | "modules", order,
  build = function(page) end,                                   -- single page, or
  tabs = { { key, label, build = fn }, ... },                   -- tabs, or nested:
  tabs = { { key, label, tabs = { { key, label, build }, ... } }, ... },
})
H:OpenOptions([key])  H:ToggleOptions()
```

**Widgets** (`Heraldry_Options/Widgets.lua`)

| Widget | Arguments |
|---|---|
| `page:Section(title [, desc])` | |
| `page:Text(textOrFn [, height])` | |
| `page:Toggle` | `{label, desc, get, set}` |
| `page:Slider` | `{label, desc, min, max, step, format, get, set, onRelease}` |
| `page:Dropdown` | `{label, desc, values = fn -> {{value,text}}, get, set, placeholder}` |
| `page:Input` | `{label, desc, placeholder, button, maxLetters, onSubmit, get}` |
| `page:Button` | `{label, desc, text, kind, onClick}` |
| `page:Color` | `{label, desc, get -> r,g,b, set(r,g,b), disabled}` |
| `page:FontSection(mod, onChange)` | the shared Font tab |
| `page:Preview(key)` | the module's preview switch from `H.previews` |

- Every control re-reads its value on `page:Refresh()`.
- Helpers: `UI.Confirm(text, yesLabel, onYes)` and `UI.OpenMenu(anchor, items, current, onPick)`. The menu frame has the mouse disabled; outside clicks are caught with `GLOBAL_MOUSE_DOWN`.
- `H.Panel:Rebuild(pageKey)` rebuilds a page. Pages with a picker use it, for example the DataBar block picker.

**Panel behaviour**
- Sidebar grouped as Heraldry / Modules. The nav list scrolls.
- A header with the title, a row of tabs, scrolling content, and a footer with Reload.
- Drag it by an empty area; Escape closes it.
- Position, scale and the last page are saved in `HeraldryDB.global.options`. The last tab per page, and the sub-tab per tab, are remembered.

**Entry points**
- An "Edit mode" button sits in the panel header.
- The panel also opens from:
  - `/hui`
  - the "Heraldry" button in the ESC menu (`Core/GameMenu.lua`, right under AddOns)
  - the addon compartment (`Heraldry_OnCompartmentClick`)

### 1.12 Secure frames, taint and combat

- Never touch protected frames in combat.
  - Every layout change to a secure frame (`SetPoint`, `SetSize`, `SetParent`, `Show`/`Hide`, attributes) goes through `if InCombatLockdown() then H:RunOutOfCombat(fn, key) return end`.
  - Use a unique key per job, so repeated calls merge.
- **Hiding Blizzard frames:** the general rule is to reparent them, out of combat, to a local hidden frame and remember the original parent so the option can be undone. Exceptions are listed in [§5.3](#53-technical-conventions).
- **Unit frames** use `SecureUnitButtonTemplate` with:
  - attributes `unit`, `*type1 = "target"`, `*type2 = "togglemenu"`
  - visibility from `RegisterUnitWatch`
  - registration in `ClickCastFrames`
- **Secret values:**
  - In combat, unit life and power (and sometimes aura data and cast times) are protected values. Lua must not do arithmetic on them or use them as table keys.
  - They go straight into `StatusBar:SetMinMaxValues/SetValue`.
  - Text that needs maths runs in `pcall` and falls back to the plain value.
  - For percentages, prefer `UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)` when it exists.
  - Guard text lookups with `issecretvalue`.

---

## 2. Implemented features

Status comes from Tiago's in-game tests: **approved** means tested in game and accepted; **delivered** means in the code but not yet confirmed in game.

### 2.1 Core

| Feature | State |
|---|---|
| Skeleton, DB, migrations, profiles (create/use/copy/reset/rename/delete), `/hui` commands, debug (C1) | approved |
| Settings panel, ESC menu button (C1.5) | approved |
| Module system, Modules page (C2) | approved. The test module `Heraldry_Test` was deleted on 2026-11-18. |
| Movers, edit mode, Layout page, docking, movable dock, centring (C4) | approved |
| Theme system with geometry contract, finishes, validation, Standard fallback (M1.5) | approved |
| Fonts (core and module override) | approved |
| Tabs on every settings page; nested tabs (Unit frames) | approved |
| Sidebar scroll in the panel; previews moved into each module's settings | delivered |
| Theme per form (`formThemes`, Theme → Forms tab) | delivered |
| Theme variants (`base`) | delivered |
| Profiles per specialization | in the code (Profiles.lua, `/hui spec`). The panel section is hidden because WoW Forever has no specs. |

**Slash commands** (`/hui` or `/heraldry`)

| Command | Action |
|---|---|
| (none), `config`, `options` | open the settings |
| `help` | list the commands |
| `edit`, `move` | edit mode |
| `status`, `version` | version, character, profile |
| `debug` | toggle debug output |
| `profile list` / `new <name>` / `use <name>` / `copy <name>` / `rename <new name>` / `delete <name>` / `reset` | manage profiles |
| `spec`, `spec on/off`, `spec <n> <profile>` | profiles per spec |
| `grab` | added by Minimap |

### 2.2 Themes (art)

| Key | Label | Class | Notes | State |
|---|---|---|---|---|
| `STANDARD` | Standard | — | neutral: dark plate, no rails or crests, 1px button border, plain wooden scroll rod | approved |
| `PALADIN` | Paladin | PALADIN | TimelessUI art: lion crest, runed gold rail, rose-gold plate; `finish = "bronze"`, gold accent | approved |
| `PRIEST` | Priest: Holy Light (auto for priests) | PRIEST | white marble and pale gold; sun halo and angel on the life orb, tome and candle on the mana orb (no glow) | approved |
| `PRIEST_SHADOW` | Priest: Shadow | PRIEST | obsidian and dark silver; hooded figure and void tendrils, void crystal. Default for Shadowform (15473). | approved as art; the form switch is untested |
| `DRUID` | Druid: Ancient Grove | DRUID | carved oak with bronze oak leaves, stag antlers, World Tree, bear-paw crest, amber gems; accent {0.78,0.58,0.30}, finish none | delivered; Tiago's "Aprovado" covered it (see §10) |
| `DRUID_BEAR` / `DRUID_CAT` / `DRUID_MOONKIN` | Druid: Bear / Cat / Moonkin | variant, base DRUID | own life orb, power orb (animal mirrored on the right) and crest. Defaults: Bear Form 5487 and Dire Bear 9634 → Bear, Cat 768 → Cat, Moonkin 24858 → Moonkin. | delivered, untested |
| `WARRIOR` | Warrior: Warlord | WARRIOR | blackened riveted orcish iron, curved spikes, short bone tusks, crimson strips; axe and horned helm on the orbs, orc skull crest, garnet gem; accent {0.62,0.20,0.16}, finish none. Battle Stance keeps it. | delivered, untested |
| `WARRIOR_DEFENSIVE` / `WARRIOR_BERSERKER` | Warrior: Defensive / Berserker | variant, base WARRIOR | tower shield / horned skull with crossed axes. Defensive Stance 71 and Berserker 2458. | delivered, untested |

- **Full kit for each main theme:** 15 textures in `Heraldry/Media/Themes/<Dir>/`:
  - `ButtonFrame`, `ButtonFrameSlim`, `Cap`, `Gem`, `Minimap`, `MinimapMask`
  - `OrbHealth`, `OrbPower`
  - `Plate`, `PlateDouble`, `Rail`
  - `RodCap`, `RodCapV`, `RodMid`, `RodMidV`

  Paladin has 13: no minimap frame, it uses the Minimap module's own frame.
- **Variants** have 3 textures each: `OrbHealth`, `OrbPower`, `Cap`.
- **Warrior button frames:** the "slim" iron frame is used for both `button.frame` and `button.frameSlim`, because the spiked one would have crossed between neighbouring buttons.

### 2.3 Modules

**Heraldry_ActionBars** (v0.11.6). Page tabs: Block / Bars / Look / Visibility / Text / Swing / Cast / Font.

- **Bars:**
  - Action bars 1–8, plus the stance bar and the pet bar (10 buttons each).
  - The game's own action buttons are reparented into our `SecureHandlerStateTemplate` bars, and the game's bar frames are hidden.
  - Per bar: enabled, buttons, per row, size, spacing, alpha, mouseover fade, fade alpha, show keybinds. Bars 1–4 use 12 per row; MultiBarLeft (bar 5) uses 1 per row; the stance and pet bars default to 32 px.
  - Visibility driver: `"[petbattle][vehicleui][overridebar] hide; show"`. The pet bar has its own driver, `[@pet,exists] show`.
  - **State:** approved (M1, M1.1 stance bar). The pet bar is untested.
- **The block (Art.lua):**
  - Bar 2 docked on top of bar 1 (`join`, `joinGap`), with one double plate around both.
  - Rails along the top and bottom, crests at both ends, a theme frame on each button.
  - Plate margins: `pad`, `padY`. Rail: `railSize`, `railExtend`.
  - **State:** approved (M1.5).
- **Button texts (Text.lua):**
  - Keybind, macro name and count, configured for every bar at once. Size is a share of the button, plus position and offsets.
  - Short keybinds ("s-Z" → "SZ", "Mouse Button 4" → "M4").
  - Per bar, only "show keybinds".
  - **State:** approved.
- **Swing timer (Swing.lua):**
  - Lights a rail of the block.
  - Main hand from the left; off hand from the right (in sync when they meet in the middle); ranged with a red end window.
  - Data comes from the client's `PLAYER_SWING(duration, type)` / `Enum.PlayerSwingType`.
  - The game's swing bars are hidden. They are found by name `*swing*`, or by a "Main Hand / Off Hand / Ranged" label on a StatusBar, rescanned 3 s after `PLAYER_ENTERING_WORLD`.
  - Default `swingPlace = "bottom"`.
  - **State:** approved.
- **Player cast bar (Cast.lua):**
  - Lights the other rail. Channels empty; interrupted or failed flashes red.
  - The spell name and time sit outside the block.
  - The game's `PlayerCastingBarFrame` / `CastingBarFrame` are hidden (option).
  - Default `castPlace = "top"`. "A bar of its own" puts the cast or swing on a separate holder with a mover.
  - Shared engine: `RailLight.lua` (`AB.RailLight`). A theme without `bar.rail` (Standard) gets a plain bar in the accent.
  - **State:** approved.

**Heraldry_Orbs** (v0.8.0). Page tabs: Place / Text / Font / Behaviour. **State:** approved (M2).

- Life and power orbs inside the theme's rings.
- The liquid is a vertical StatusBar cut to a circle, fed with secret values directly. Two liquid layers cross-fade and a bright line rides the surface.
- Docked to the ends of bar 1 by default ("Attach to the action bars").
- The life orb is a secure unit button for `player` (`HeraldryOrbHealthClick`): click targets, right click opens the menu, click casting works on it.
- The player frame is hidden.
- Colours:
  - The life colour follows the class (`LIFE[class]`: priest white, druid orange, warrior brown…).
  - The power colour follows `PowerBarColor` for the power type (rage red, energy yellow, mana blue).

**Heraldry_UnitFrames** (v0.12.3). Page tabs: Target (Size / Text / Look / Behaviour) / Target of target (Size / Text / Behaviour) / Focus (Size / Text / Behaviour) / Party (Size / Text / Look / Behaviour) / Raid (Size / Text / Look / Behaviour) / Indicators / Font.

- **Target (Target.lua + TargetPlaque.lua):** approved (M3).
  - **Plaque style** (default): one fixed plaque from the TimelessUI Paladin kit, with lion medallions and two jewels. The slot is cut out and the bars sit behind it.
    - The kind of target shows only as colour:
      - metal finish on top of the theme finish: theme finish for elite and players, iron hostile, bronze friendly, silver rare, red boss
      - jewel colour: by reaction, or the player's class
    - The level sits in a ring set into the left medallion.
    - Every text has its own size and offset.
    - Class emblems over the lions for players (setting `emblem` = colour / metal / off).
  - **Minimal style:** a glass panel with a rim in the accent, the theme gem holding the level, and a halo for elite / rare / boss.
  - The Blizzard target frame is hidden (option).
- **Target cast bar (Cast.lua):** approved (C4).
  - The power row becomes the cast bar: gold interruptible, grey not interruptible, red interrupted or failed.
  - Timing uses the game's timer via `SetTimerDuration` with `UnitCastingDuration` / `UnitChannelDuration` when available, else `GetTime` maths in `pcall`.
- **Target of target and focus (Small.lua):** approved.
  - Smaller plaques with the same finish and jewel rules.
  - Prefixed settings `tot*` / `focus*`.
  - The ToT is docked right of the target as a movable dock.
- **Party (Party.lua):** approved.
  - Styles:
    - **cartouche** (default): one Canva art piece with a class symbol window, a thick life slot, a thin mana slot, a debuff gem and rope at both ends
    - **banner**: the symbol standing on the bars, for a row
    - **compact**
  - Geometry tables `UF.CARTOUCHE` and `UF.BANNER` in art pixels (`window`, `life`, `power`, `gem`, `cols`, `stretch`, `at(x)`).
  - Class-coloured recessed symbols, desaturated when dead or offline.
  - Dead / ghost / offline, range fade, leader crown, debuff gem (with a "dispellable only" option).
  - Container mover with grow direction; hidden in raid unless set. The Blizzard party frames are hidden.
  - Preview with made-up members.
- **Raid (Raid.lua):** delivered, untested in a real raid.
  - Groups side by side in rows ("Groups per row", default 4, configurable).
  - Style **banner** (R3, default): each row of groups is one parchment sheet hanging from the theme's rod.
    - Clicking the rod rolls the row up. It is a secure snippet, so it works in combat.
    - A rolled row shows a strip such as "Groups 1–4 · 18" and pulses red when a member dies.
    - The rolled state is kept per character (`H.char.raidRolled`).
  - Style **tiles** (R2): a glass panel and theme gem per group.
  - Members come from the game's `SecureGroupHeaderTemplate` headers; the code only dresses the buttons.
  - Shown only in a raid. The game's raid frames are hidden. Preview available.
- **Healer indicators (Indicators.lua):** delivered, untested.
  - A per-character list with class defaults for DRUID, PRIEST, PALADIN and SHAMAN.
  - Each indicator sets:
    - spells: names or IDs, comma separated
    - one of 9 anchor points, plus x/y offset
    - look: icon / square / bar / text
    - size and length, colour
    - time inside / below / above / none, and its size
    - stacks, "only mine", "show when missing", warning seconds (red and pulsing), drain
  - On raid frames, and on party frames (option).
  - The panel has an editor: a member drawn large with live indicators and 9 clickable dots, a list with Add / Remove / Up / Down / "Class defaults", and per-indicator sections.

**Heraldry_Minimap** (v0.2.1). Page tabs: Size / Text / Addons / Behaviour / Font. **State:** approved (M1 prototype).

- The minimap sits in a heraldic frame. It uses the theme's `minimap.frame`, or falls back to its own TimelessUI Paladin frame (`Media/Frame.tga`, `Mask.tga`).
- The map is cut to the window by a mask; the mouse wheel zooms.
- Sockets, top to bottom:
  - day/night and calendar (`GameTimeFrame`)
  - a toggle for the addon-buttons panel
  - mail
- The zone and clock sit on the plate, each with its own text settings.
- The box is cut to the art (`FRAME.art`), so the frame can reach the screen edges.
- The addon panel gathers:
  - minimap children
  - MinimapCluster button children
  - every `LibDBIcon10_*` global
  - names in `H.global.minimapGrab`, added with `/hui grab` (the button under the mouse, found with GetMouseFoci)

  The panel gathering and `/hui grab` are delivered; whether the cooldown manager icon is gathered is untested.

**Heraldry_Quests** (v0.1.3). Page tabs: Look / Text / Behaviour / Font. **State:** approved (Q4).

- The quest tracker is a parchment scroll between the theme's `scroll.rod` rods, on light (ink) or dark paper.
- Clicking the top rod rolls it up into a strip with the quest count.
- Our own tracker reads `C_QuestLog`, with classic API fallbacks.
  - The title opens the quest log; shift-click untracks.
  - Only the level carries the difficulty colour. "· Ready" and "· Failed" show on the title.
- The game's `ObjectiveTrackerFrame` is hidden with `Hide()` plus an `OnShow` hook. It is protected, so it is not reparented.
- It steps aside when Questie's tracker is on.

**Heraldry_Chat** (v0.2.9). Page tabs: Look / Size / Text / Channels / Input / Behaviour / Font. **State:** approved (M5).

- **Look:**
  - The chat is a sideways scroll between standing theme rods (`scroll.rodV`), on dark, light or glass paper, or a flat "panel" style.
  - It rolls up toward the side of the screen it is on, with a glow on new messages. Enter opens it to type.
  - `ChatFrame1` keeps its open size and is placed inside our frame with `SetPoint` / `SetSize` hooks.
  - Blizzard chat art is removed with alpha hooks.
  - Tabs and the input line sit inside the paper.
- **Text.lua:**
  - Channel names full, short (custom per channel), number or hidden; "says" dropped.
  - Faded timestamps, using the game's CVar.
  - Line fading.
  - Plain Up/Down input history (`SetAltArrowKeyMode(false)`), saved per character.
  - Player names without brackets; message body in plain ink.
  - On light paper, an ink palette per chat type (`ink_<key>`). On the other papers, the colour pickers write the game's own chat colours.
- **Copy (Copy.lua):** `/hui copy`, or the note button at the right end of the tab row (prototype I1), opens a dark-parchment box (prototype K2) with the last 200 lines of the visible chat window, already selected for Ctrl+C. Colours, links and icons are stripped; secret lines are skipped and counted ("N hidden by the game"). Approved 2026-11-19.

**Heraldry_Tooltips** (v0.1.1). Page tabs: Look / Position / Text / Behaviour / Font. **State:** approved (T2).

- The game's tooltips on dark (default), light or glass paper, with a metal rim. Only the background and border change; `NineSlice` is hidden by an alpha hook.
- Quality rim for items; class-coloured player names; a thin health strip.
- Anchor: the game's place, our mover (`Tooltips.anchor`, the default; it grows from the corner nearest the screen edge), or the cursor.
- Hide unit tooltips in combat (option).
- Skinned through `TooltipDataProcessor` post-calls.

**Heraldry_Auras** (v0.2.7). Page tabs: Power orb / Life orb / Buffs / Debuffs / Font. **State:** steps 1 and 2 approved.

- **Power-orb gems:** chosen auras per character (`H.char.auraSockets`). The icon shows round in the gem and darkens through a Cooldown driven by `C_UnitAuras.GetAuraDuration`; the time sits in the centre.
  - Defaults apply only when `auraSockets` is nil.
  - Per-theme defaults (`AU.THEME_DEFAULTS`) win over per-class defaults (`AU.CLASS_DEFAULTS`).

  | Key | Default auras |
  |---|---|
  | PALADIN | the four seals |
  | PRIEST | Inner Fire, Power Word: Fortitude, Divine Spirit, Shadow Protection |
  | PRIEST_SHADOW | Shadowform, Vampiric Embrace, Inner Fire, PW:F |
  | DRUID | Mark of the Wild, Thorns, Omen of Clarity, Rejuvenation |
  | WARRIOR | Battle Shout, Bloodrage, Sweeping Strikes, Enrage |
  | WARRIOR_DEFENSIVE | Battle Shout, Shield Block, Last Stand, Shield Wall |
  | WARRIOR_BERSERKER | Battle Shout, Berserker Rage, Recklessness, Death Wish |

  The warrior entries are untested.
- **Life-orb gems:** debuff-type colours (top magic, right curse, bottom poison, left disease), pulsing when the debuff is removable.
- **Rows (Rows.lua):** built on the client's aura containers (`Blizzard_AuraContainer`, `CustomAuraContainerTemplate`).
  - Buffs (`HELPFUL`) in a row docked left of the minimap (`Auras.buffs`); right click cancels, in combat too.
  - Serious debuffs (`HARMFUL|CROWD_CONTROL`, optionally `HARMFUL|!CROWD_CONTROL`) big over the life orb (`Auras.debuffs`). They grow right/left (row) or up/down (column) with the time inside the icon.
  - The game's `BuffFrame` / `DebuffFrame` are hidden with Hide plus a Show hook.
  - Test mode with look-alike icons.

**Heraldry_ClickCast** (v0.1.1). Page tabs: Bindings / Behaviour. **State:** step 1 approved.

- Per-character bindings (`H.char.clickcast`): modifiers + mouse button 1–5 + an action. Actions are spell, macro, item, target, menu, focus or assist.
- Spells are stored by name, so the highest rank is always cast. "Name(Rank n)" pins a rank.
- Optional enemy and dead alternatives build a `/cast [@mouseover,dead,help] ..; [@mouseover,harm] ..; [@mouseover] ..` macro. It uses `@mouseover` (the clicked frame's unit) because raid buttons are made without a unit and change unit with the roster, also in combat (fixed 2026-11-19).
- Applied to every frame in `ClickCastFrames`; a metatable catches frames added later.
- The attributes it sets are tracked and cleared before re-applying. Changes made in combat wait for the end of combat.
- It steps aside when Clique is loaded.
- The panel has a capture box (click with the combination) and a spellbook list.

**Heraldry_DataBar** (v0.2.0). Page tabs: Bar / Rail / Blocks / Text / Behaviour / Font.

- **Bar:** a flat bar along the top (or bottom) edge (prototype D1).
  - Width full or fixed and centred; height; offset; strata.
  - Background flat colour or any paper; opacity; inner and outer rim.
- **Rail:** the theme's rail on the inner or outer edge.
  - Lit by experience, with rested experience in another colour. Reputation shows at the cap, always, or never.
  - Thickness, unlit brightness, colours.
- **Blocks:** each has a place (left / centre / right / hidden), an order, and options of its own.

  | Block | Shows / options |
  |---|---|
  | `micro` | the game's micro menu, scaled |
  | `xp` | percent / numbers / both / what's left, level, rested |
  | `gold` | full / icons / gold only / short |
  | `bags` | free / used / free only, red threshold; click opens the bags |
  | `durability` | red threshold |
  | `perf` | FPS, latency (max / home / world / off) |
  | `clock` | 24 h, server time, seconds; off by default because the minimap shows the time |
  | `zone` | with the subzone |
  | `coords` | decimals |
  | `friends` | friends online |
  | `guild` | guild members online |

- **Text:** size, gap, end padding, separator, labels with their colour, coloured values.
- **Behaviour:** fade on mouse-out, hide in combat (by alpha only, because the micro menu is inside), tooltips, hide the game's XP / reputation / bag bars.
  - The game's status-tracking containers are made invisible (alpha 0, a `SetAlpha` hook, mouse off) rather than reparented, because Edit Mode calls their parent.
  - `MainMenuExpBar`, `ReputationWatchBar`, `BagsBar`, the backpack and bag slots, and `KeyRingButton` are reparented.
- **State:**
  - D1 approved (2026-11-18). The bigger defaults (30 px, 15 pt) followed.
  - The "maximum configuration" release (v0.2.0) was deployed. Tiago's "Aprovado, podes avançar" right after it is read as approval (see §10).

---

## 3. Compatibility

- **Target client:** WoW Forever, a Midnight-era (12.x) client that looks classic. Every `.toc` has `## Interface: 16001`.
- **Modern APIs the client runs:**
  - `C_AddOns`
  - the modern game menu (`InitButtons` / `AddButton` / `layoutIndex`)
  - `Enum.StatusBarInterpolation`
  - secret values (`issecretvalue`)
  - `C_UnitAuras.GetAuraDuration`
  - `C_DurationUtil.CreateDurationTextBinding`, which only writes when given a formatter (`C_StringUtil.CreateNumericRuleFormatter`)
  - the aura containers (`Blizzard_AuraContainer`)
  - `TooltipDataProcessor`
  - `GetMouseFoci`
  - `UnitHealthPercent` with `CurveConstants`
  - `StatusBar:SetTimerDuration` with `UnitCastingDuration` / `UnitChannelDuration`, when present
- **Forever-only API:** the native swing timer (`PLAYER_SWING(duration, type)`, `C_SwingTimer`, `Enum.PlayerSwingType` MainHand / OffHand / Ranged, `Blizzard_SwingTimer`). Without it, the swing bar is never built.
- **Facts found in testing:**
  - There are **no specializations**: `GetSpecialization` returns nothing. Per-spec profiles are hidden in the panel.
  - `C_AddOns.GetAddOnEnableState(addon, character)` **always returns 2**. Always read and write the enable state **without** the character argument.
  - Action bars 1–8 exist (MultiBar5–7 included), plus the stance bar and the pet bar with 10 buttons each.
  - The ESC menu is the modern one.
  - **New files, textures or addons need a full game restart**; `/reload` is not enough.
  - The Blizzard mail frame calls `parent:Layout()`. Any parent we give it needs `Layout` / `MarkDirty` / `MarkClean` methods, even empty ones.
  - The quest tracker is the modern `ObjectiveTrackerFrame` and is protected. Questie hides it with `Hide()` and an `OnShow` hook, deferred in combat.
  - `FontString:SetText()` before a font is set errors ("Font not set"). Always apply the font first.
  - The chat tabs follow `ChatFrame1Tab`, which is anchored to `ChatFrame1`, not to `GeneralDockManager`.
  - Shadow and outline belong to the whole chat window; only the colour can change mid-line.
  - **There is no combat log for addons** (since 12.0).
  - In combat, aura names and IDs can be secret. Indicators then match nothing and say so once in debug output.
  - Edit Mode's status-tracking bar containers call their parent's methods, so they must not be reparented (this caused a `StatusTrackingManager.lua:228` error before the fix).
  - Tables cannot be indexed with secret keys (this caused a `Swing.lua:217` error before the fix).
  - `UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)` is secret even out of combat; `FontString:SetFormattedText("%d%%", secret)` accepts it (tested 2026-11-19).
  - `Frame:RegisterUnitEvent` takes at most two units. The party passed four or five, so some members never updated (fixed 2026-11-19).
- **APIs guarded because they may be missing:** `UnitIsTapDenied`, `C_ClassColor`, `GetCreatureDifficultyColor`, `GetNumSpecializations`, `GetShapeshiftFormInfo`, and others.

---

## 4. File structure

There are no `.xml` files, no bundled libraries and no locale files. Textures are `.tga` (RLE).

### `Heraldry/` (core, v0.14.2)

| File | Purpose |
|---|---|
| `Heraldry.toc` | load order, `SavedVariables: HeraldryDB`, `AddonCompartmentFunc: Heraldry_OnCompartmentClick` |
| `Core/Init.lua` | namespace `H` / `_G.Heraldry`, version, `Print` / `Error` / `Debug` |
| `Core/Events.lua` | game events and internal messages |
| `Core/Combat.lua` | `H:RunOutOfCombat(fn, key)`: a queue keyed by job |
| `Core/Database.lua` | SavedVariable, migrations, character entry, boot (`DB_LOADED` → `READY`) |
| `Core/Profiles.lua` | profile management, profiles per spec |
| `Core/Options.lua` | settings page registry, `H:OpenOptions`, `H:ToggleOptions` |
| `Core/Modules.lua` | `H:NewModule`, flat db proxy, module catalog from the `.toc` tags |
| `Core/Movers.lua` | positions per profile, docking, movable docks, centring |
| `Core/EditMode.lua` | edit mode boxes, snapping on release, guide lines, grid, keys |
| `Core/Themes.lua` | theme registry, geometry contract validators, finishes, form themes, variants |
| `Core/Fonts.lua` | global fonts, LibSharedMedia when present, `Apply` / `Resolve` |
| `Core/Paper.lua` | shared papers and ink helpers |
| `Core/GameMenu.lua` | "Heraldry" button in the ESC menu (modern and classic menus) |
| `Core/Commands.lua` | `/hui`, `/heraldry`, `H.commands` extension point |
| `Themes/Standard.lua` | neutral fallback theme |
| `Themes/Paladin.lua` | Paladin theme (TimelessUI art) |
| `Themes/Priest.lua` | `PRIEST`, `PRIEST_SHADOW` |
| `Themes/Druid.lua` | `DRUID`, plus the variants `DRUID_BEAR` / `DRUID_CAT` / `DRUID_MOONKIN` |
| `Themes/Warrior.lua` | `WARRIOR`, plus the variants `WARRIOR_DEFENSIVE` / `WARRIOR_BERSERKER` |
| `Media/Paper/{Light,Dark}.tga` | parchment for chat, tooltips, quests and the others |
| `Media/Themes/Standard/` | `RodCap`, `RodCapR`, `RodCapV`, `RodCapVB`, `RodMid`, `RodMidV` (plain wooden rod) |
| `Media/Themes/Paladin/` | 13 textures, no minimap |
| `Media/Themes/{Priest,PriestShadow,Druid,Warrior}/` | 15-texture kits |
| `Media/Themes/{DruidBear,DruidCat,DruidMoonkin,WarriorDefensive,WarriorBerserker}/` | `OrbHealth`, `OrbPower`, `Cap` |

### `Heraldry_Options/` (v0.7.11, LoadOnDemand)

| File | Purpose |
|---|---|
| `Style.lua` | colours, font and drawing helpers for the panel |
| `Widgets.lua` | page builder and widgets, `UI.Confirm`, `UI.OpenMenu`, `page:Preview` |
| `Panel.lua` | the window: sidebar (scrolls), header, tabs and nested tabs, content, footer |
| `Pages/General.lua` | Character / Panel / Testing |
| `Pages/Profiles.lua` | Active profile / Manage, plus the spec section only on clients with specs |
| `Pages/Theme.lua` | Theme / Forms / Finish |
| `Pages/Fonts.lua` | Fonts / Scale |
| `Pages/Layout.lua` | Edit mode / Positions, with a "Centre" button per frame |
| `Pages/Modules.lua` | turns module addons on or off (single page) |

### Module folders

| Folder (version) | Files | Media |
|---|---|---|
| `Heraldry_ActionBars` (0.11.6) | `ActionBars.lua` (bars), `Art.lua` (theme art), `Text.lua` (button texts), `RailLight.lua` (lit rail engine), `Swing.lua`, `Cast.lua`, `Settings.lua` | — |
| `Heraldry_Orbs` (0.8.0, OptionalDeps ActionBars) | `Orbs.lua`, `Settings.lua` | `Media/{Liquid1,Liquid2,Glass,Surface}.tga` |
| `Heraldry_UnitFrames` (0.12.3) | `Target.lua` (module, target), `Cast.lua` (target casts), `Small.lua` (ToT, focus; base for party), `Indicators.lua`, `Party.lua`, `Raid.lua`, `TargetPlaque.lua` (plaque geometry, finishes, jewels, emblems), `Settings.lua` | `Media/Target/{Plaque,LevelRing}.tga`, `Media/Party/{Frame,Banner}.tga`, `Media/Party/Class/<CLASS>.tga` (class-coloured symbols, 9 classes), `Media/Class/<CLASS>.tga` (plain gold symbols, 9 classes) |
| `Heraldry_Minimap` (0.2.1) | `Minimap.lua`, `Settings.lua` | `Media/{Frame,Mask}.tga` (TimelessUI Paladin frame) |
| `Heraldry_Quests` (0.1.3) | `Quests.lua`, `Settings.lua` | — |
| `Heraldry_Chat` (0.2.9) | `Chat.lua`, `Text.lua`, `Copy.lua` (copy box and button), `Settings.lua` | — |
| `Heraldry_Tooltips` (0.1.1) | `Tooltips.lua`, `Settings.lua` | — |
| `Heraldry_Auras` (0.2.7, OptionalDeps Orbs) | `Auras.lua` (gems), `Rows.lua` (buff and debuff rows), `Settings.lua` | — |
| `Heraldry_ClickCast` (0.1.1) | `ClickCast.lua`, `Settings.lua` | — |
| `Heraldry_DataBar` (0.2.0) | `DataBar.lua`, `Settings.lua` | — |

### Root files

| File | Purpose |
|---|---|
| `README.md` | this documentation |
| `CLAUDE.md` | instructions for Claude Code |

### Outside the repository

- **Project docs in the claude.ai project "UI Addon World of Warcraft Forever"**, in PT-PT:
  - `claude/decisoes-projecto.md`: decisions 1–41, client facts, the delivery process, the old "Por testar" list
  - `claude/decisoes-projecto-2.md`: decisions 42–50 and the new "Por testar"
  - `claude/arte-classes-prompts.md`: the Canva prompt recipe
  - `claude/arquitetura-core.md`: the v0 core proposal, partly superseded (see §10)
- **Canva folders**, all inside the root folder "Heraldry" (`FAHbTQeoXNE`):

  | Folder | ID |
  |---|---|
  | Priest - Holy Light | `FAHbTaxEe_g` |
  | Priest - Shadow | `FAHbTW3gv0I` |
  | Druid - Ancient Grove | `FAHbToVyb8U` |
  | Druid - Bear | `FAHbTqO6AaE` |
  | Druid - Cat | `FAHbTk613_Y` |
  | Druid - Moonkin | `FAHbToBPcmM` |
  | Warrior - Prototypes | `FAHbT6IHfI4` |
  | Warrior - Warlord | `FAHbUGm0-no` |

- **Downloaded Canva sources** on Tiago's PC: `C:\Users\tiago\Downloads\Imagens Wow\<Class>\` (`Druid/`, `Warrior/`, `Priest/`, plus older loose files).
- **Art pipeline scripts** (`cut.py`, `orbsX.py`, `kitX.py`, Python with PIL, numpy and scipy) lived in the cloud session's `/tmp/pr`. They are not in the repository; see §9.4.
- **Working clone:** `D:\Dev\Heraldry` on Tiago's PC (see §9.1). The game folder only receives deploys.

---

## 5. Development decisions

The decisions are numbered as in the project docs. Superseded ones are marked.

### 5.1 Product and process

1. New, clean addon. From TimelessUI only the art is imported, and only when needed.
2. Core plus modules as separate addon folders (the EllesmereUI model).
3. Default layout "Altar", plus a Healer variant. Presets and the installer are not built yet (C7).
4. Three layers: theme (per character, follows the class) / profile / class overrides. The class-override layer (C3) is postponed until a module needs it. The spec layer was dropped because there are no specs; per-class things are stored per character.
5. Name "Heraldry"; commands `/hui` and `/heraldry`; modules named `Heraldry_<Module>`.
6. **English only**, in game and in code. Only an enUS locale exists. Conversation with Tiago is in **European Portuguese**.
7. Git: `github.com/tiagomilhazes/Heraldry`, private, branch `main`, one folder per addon. Each delivery gets its own commit.
8. Turning modules on or off applies to all characters.
9. **Pace:** module by module, in small steps. Tiago tests each delivery live and decides. Proposals are critical, with options and reasoning.
10. **Goal:** "maximum configuration without repeating anything". A setting lives in exactly one place.
11. **Settings panel rule:** every sub-category of a page is its own tab, on every page. A page with one sub-category has no tabs. A module that configures several separate things uses nested tabs.
12. **Prototypes before visuals:** every new visual is first shown as prototypes (labelled options such as S1/S2/S3, R2/R3, D1, Q4, T2, P2) and Tiago picks.
13. Art is designed **as a whole**, never as loose pieces. The first Paladin art (pink plate, shield crests, a gold frame on every button) was rejected as random.
14. **Before adding a piece to the screen, use one that already exists.** Tiago rejected extra pieces twice: the rails became the cast and swing bars, and the orb gems hold the auras.

### 5.2 Visual hierarchy (project rule)

| Level | What | Look |
|---|---|---|
| 1, hero | Action bar block (bars 1+2) and the orbs | full ornament: double plate, rails, caps, theme rings, button frames |
| 1.5 | Target (Plaque), minimap (M1 frame), party (cartouche) | a fixed plaque or frame; the target is identified only by colour |
| 2, frames | Quest tracker, the target's Minimal style | dark glass panel, a rim in the theme accent, **one** theme motif (the gem). Exception chosen by Tiago: the quest tracker is parchment, with a light option. |
| 3, panels | Chat, tooltips, data bar, (damage meter) | flat and dark, with a thin rim (chat and tooltips also offer paper) |

### 5.3 Technical conventions

- Load order in the core `.toc`, as in §1.2. In module `.toc` files the code file comes first and `Settings.lua` last. Bump `## Version` on every delivery that changes an addon.
- Module `.toc` template:
  ```
  ## Interface: 16001
  ## Title: |cffE8B04BHeraldry|r <Name>
  ## Dependencies: Heraldry
  ## X-Heraldry-Module: 1
  ## X-Heraldry-Label: <Label>
  ## IconTexture: Interface\Icons\...
  ```
- Global frame names use the `Heraldry` prefix: `HeraldryActionBar1..8`, `HeraldryOrbHealth`, `HeraldryOrbPower`, `HeraldryOrbHealthClick`, `HeraldryTargetFrame`, `HeraldryDataBar`, and so on. Other globals: `HeraldryDB`, `Heraldry_OnCompartmentClick`, `ClickCastFrames`.
- Mover keys are `"<Module>.<thing>"`. The brand colour is `E8B04B`.
- **Action bars reuse Blizzard's own buttons** inside our secure containers; we never create action buttons. This approach worked in TimelessUI; EllesmereUI creates its own buttons.
- **Hiding Blizzard frames:**
  - The rule is to reparent them to a local hidden frame, out of combat, and never to call `Hide()` on them or hook their `Show`.
  - Exceptions with a reason:

    | Frame | Method | Reason |
    |---|---|---|
    | `ObjectiveTrackerFrame` | `Hide()` + `OnShow` hook | protected; Questie's approach |
    | `BuffFrame` / `DebuffFrame` | Hide + Show hook | EllesmereUI's approach |
    | Edit Mode status-tracking containers | alpha 0 + `SetAlpha` hook + mouse off | they call their parent |
    | Tooltip `NineSlice`, chat art | alpha hooks | only the art must go |

- **Masks:** circular shapes use `Interface\CharacterFrame\TempPortraitAlphaMask`. The minimap uses the theme's `MinimapMask`.
- **Bar 1's scale** is undone on child art with `SetScale(1/scale)`, never with `SetIgnoreParentScale(true)`, which also drops the UI scale.
- The **edit mode** snaps only on release. Live snapping and code-driven movement stuttered.
- **No permanent `OnUpdate`.** Swing runs one only while a swing builds; events are filtered by unit.
- **Typography** follows the three layers in §1.9. Fonts are applied only through `H.Fonts`.
- **Settings code pattern:** a `field(name)` helper returns get/set pairs that write to `mod.db` and call `mod:Layout()`.
- Unit frames are one module (`Heraldry_UnitFrames`) so focus, ToT, party and raid reuse code. The first glass target design became the "Minimal" style.
- The "Heraldic" target style (decision 26: TargetArc and Scroll rods with rails) was abandoned for the Plaque style, because mixed art families never aligned texts and bars. Principle: **the frame never changes shape, only colour.**
- Decision 16 (buffs and debuffs fixed beside the block) is **superseded** by decision 40 (auras in the orb gems, plus discreet rows).

### 5.4 Class art via Canva

- From 2026-11-18 Claude writes the prompts, generates the images, and creates Canva folders. Tiago downloads the chosen images to `Imagens Wow/<Class>/`. Tiago has about two weeks of Canva left, counted from 2026-11-18.
- **Prompt recipe** (`claude/arte-classes-prompts.md`), always in English:
  1. Fixed opening: `Game interface asset for a World of Warcraft UI: <piece>, front view, centred, isolated on a plain pure black background.`
  2. The theme's material, the same for every piece.
  3. The class motif, on hero pieces only (orbs, Cap, minimap). On the life orb it sits outside the upper left; on the power orb, outside the upper right.
  4. Fit rules: orbs get `The centre of the ring is a perfectly round empty hole, pure black, nothing inside. Four small round empty gem sockets ... exactly at the top, right, bottom and left.`; button frames get an empty square inside; rails and rods are horizontally tileable.
  5. `No glow, no halo, no light rays, crisp solid edges and a perfectly clean pure black background.`
  6. Fixed closing: `Hand-painted fantasy style like World of Warcraft Classic interface art, high detail, crisp edges, no text.`
- **The power orb is always an edit of the approved life orb** (`imageReferences` with its media id: "keep exactly the same ring…"). Generated from scratch, the Priest mana orb came out with a thinner ring and a bigger hole.
- Form and stance variants are edits of the base pieces: the life orb with a new motif, the power orb as an edit of that life orb with the motif mirrored on the right, the crest with a new centre relief.
- **Warrior history:**
  - Rejected: A (forged iron), C (fortress), B (blood and leather; Tiago disliked the buckles), and a Spartan revision of B.
  - Tiago then chose "High Overlord Saurfang" as the style. The prompts describe an orcish warlord and never name the character.
  - The first ring was too thin and things hung below it, so it was fixed: a thick ring, short tusks, nothing hanging.
- Approved Canva media ids: Druid health orb `MAHbTvntRC4`, Druid crest `MAHbTn1PZYk`, Warrior base life orb `MAHbUO5zNT0`, Warrior crest `MAHbUCFja2c`.

---

## 6. Dependencies

- **Required:** none outside this repository. Each module depends on the core (`## Dependencies: Heraldry`).
- **Internal optional dependencies:** `Heraldry_Orbs` → `Heraldry_ActionBars` (docking); `Heraldry_Auras` → `Heraldry_Orbs` (gems).
- **Libraries:** none bundled. `LibSharedMedia-3.0` is used **if another addon provides it** (through `LibStub("LibSharedMedia-3.0", true)`) to offer more fonts.
- **Blizzard load-on-demand addons used:** `Blizzard_AuraContainer` (Rows.lua loads it). `Blizzard_SwingTimer` is hidden, not used.
- **Third-party addons the code reacts to:**

  | Addon | Reaction |
  |---|---|
  | Questie | the quest scroll steps aside when Questie's tracker is on |
  | Clique | click casting steps aside |
  | LibDBIcon buttons | gathered into the minimap panel |
  | EllesmereUI / ERB | names skipped when scanning for swing bars |
  | Zygor | ignored; Tiago's screenshots show it and it must always be ignored |

- **Testing setup:** only Heraldry is enabled, plus Zygor. Other bar addons (TimelessUI, EllesmereUI Action Bars) must be off while testing the bars. BugGrabber with BugSack is recommended for catching Lua errors.
- **Reference code:** `EllesmereUI/EllesmereUI_AuraKit.lua`, for the aura-container API.

---

## 7. Known problems and untested items

**Untested in game (needs the situation):**

- Vehicles: our bars hide and the game's vehicle bar appears, including the cast and swing bars.
- Pet bar (Hunter or Warlock): shows only with a pet; clicks, keybinds, move, resize, persistence.
- Stance bar with several stances: buttons per row (including vertical); it grows when a stance is learned; no overlap after switching in combat.
- Pet battles: the bars hide.
- Orbs and target in long fights: text keeps updating with secret values; finish and jewels change when switching targets in combat.
- Target classification: plaque and ring metal on elite, rare and boss; "??" on bosses. Emblems of enemy-faction and other classes; switching between player and NPC in combat.
- Target cast bar in combat: time left with secret values, channels, the not-interruptible and interrupted colours.
- Focus: the Blizzard focus frame hidden; the focus in combat.
- Quests: a failed quest; the game's tracker not coming back after an instance or vehicle; rolling up in combat; Questie on.
- Chat:
  - placement: chat on the right or centre of the screen; Blizzard Edit Mode moving it
  - messages: secret messages; item links mid-message with plain ink
  - windows: new and undocked windows; the oldest line overlapping the tabs; tabs back after the overflow fix
- Tooltips: combat and instance unit tooltips; epic and rare rims; light paper; windows opened for the first time; font scaling not leaking elsewhere.
- Party: a real group (joining, leaving, order, the player); debuff gem with secret auras; range fade; offline and ghost; hidden in raid; Blizzard frames hidden without errors; clicks in combat.
- Swing and cast: dual wield; ranged or wand; cast pushback; mob interrupts; real channels; the game's "Main Hand" bar staying hidden (a fix was confirmed); the game's cast bar hidden without Edit Mode errors.
- Auras:
  - gems: time format in combat; real debuffs of each type and the pulse; the Standard theme (four points around the orb)
  - rows: cancelling with right click in combat; a real stun or fear; row and column layouts; the time inside debuff icons after `/reload`
- Click casting: self (life orb) and party; "when dead" and "on enemies"; a change made in combat applies after combat; mouse buttons 4 and 5.
- Hidden player frame: no errors when opening Blizzard's Edit Mode.
- Raid (42): a real raid; rolling a row in combat; the dead warning on a rolled row; empty groups hidden.
- Indicators (43): secret auras in combat (time through the duration binding, no errors).
- Data bar (47): micro menu in vehicles; hide in combat with the micro menu inside; light paper background; reputation at the cap.
- Form themes (46): Shadowform (ID 15473); bear, dire bear, cat and moonkin swapping orbs and crest, in combat too.
- Minimap addon panel (48): the cooldown manager icon gathered automatically (otherwise use `/hui grab`).
- Warrior (50): stance switching in and out of combat; gem sockets on the orbs of all three stances (Berserker's power-orb sockets were measured by hand); the minimap with its sockets inside the ring (a smaller map window); the crest joining the block (the join `{160,128,120}` was set by eye).
- Druid minimap outdoors: in one screenshot, taken inside an inn, it was black.
- Audit fixes of 2026-11-19, approved without a group: party frames updating every member in a real group; missing-buff indicators staying down when aura names turn secret in combat; raid click-cast alternatives (`@mouseover`) after roster changes in combat.
- Chat copy on the Combat Log tab: which message the box shows.

**Open questions and pending tuning:**

- Block default margins (side margins, top and bottom margin, "Plate and rails past the bar"): waiting for Tiago's preferred values.
- Target health percentage: closed. The setting `hpPctShow` was off (checked in game 2026-11-19).
- Health orb liquid colour: offering a choice (class / red / custom) was proposed; Tiago did not answer.

**Known limitations (by design or caused by the client):**

- Chat: messages the game marks secret get no abbreviations or ink; changes only apply to new lines.
- Aura row buttons can only be styled when created, so time and text-size options need `/reload`.
- Indicators cannot match auras whose names and IDs are secret.
- Quest log window: not built (only the tracker).
- The Warrior spiked button frame is not used (the slim frame is used for both).

---

## 8. Future work

Planned or discussed, **not implemented**:

1. **Class art for the remaining classes**: Hunter, Mage, Rogue, Shaman, Warlock (Tiago picks the order), using the Canva recipe, with form or stance variants where a class has them. This uses Tiago's remaining Canva budget (about two weeks from 2026-11-18).
2. **C3 class overrides**, when the first module needs them. The `overrides` table exists in the DB but is unused. The original plan was a small `overridable` list per module and a Profile / Class selector next to those options.
3. **C7**: installer (first login or `/hui install`), presets ("Altar" plus a Healer variant, written into `layout`), and import/export. The plan was `C_EncodingUtil` (CBOR + compression + Base64) with no libraries; whether it exists on Forever is not confirmed.
4. **Click casting steps 2–3** (Tiago parked these as extras): hovercast keys over frames, bindings in the tooltip, an out-of-combat set, copying between characters.
5. **Bespoke per-class target medallions** from Canva, in the lion medallion's style, as an alternative to the party symbols. Each one must be prompted in Tiago's own words. A first try matched the style but drew a whole hammer instead of a medallion.
6. **The quest log window** (only the tracker exists).
7. A damage meter panel is mentioned in the visual hierarchy (level 3); no work has been done on it.
8. Options discussed but not decided: health orb liquid colour (class / red / custom); redoing the Warrior spiked button frame with the spikes turned inward if Tiago wants it.
9. The original core proposal also listed optional pixel-perfect scaling and keeping the UI in a central 16:9 area on ultrawide screens. These were never confirmed or built.

---

## 9. Important details from the history

### 9.1 Delivery process (what Tiago expects)

Since 2026-11-19 the work happens in a git clone on Tiago's PC, `D:\Dev\Heraldry`, with a local `core.autocrlf=false` so files stay LF and byte-identical to the deployed copies.

1. Syntax-check every changed Lua file. There is no Lua compiler on the PC yet (the cloud sessions had `texluac`); until one is installed, at least check balanced blocks and brackets and say the check was partial.
2. Commit in the clone with a descriptive message. On Windows PowerShell 5.1 pass multi-line messages through a file (`git commit -F file`).
3. Mirror each changed addon folder into `D:\World of Warcraft\_forever_\Interface\AddOns\` and **verify byte for byte** (`cmp` against `git ls-files`, and the file lists) before asking for a test:
   ```
   robocopy D:\Dev\Heraldry\<Addon> "D:\World of Warcraft\_forever_\Interface\AddOns\<Addon>" /MIR /XD .claude graphify-out /XF CLAUDE.md README.md
   ```
   - `/MIR` deletes files the repo no longer has: the old copy-only deploys had left 29 stale files (removed 2026-11-19).
   - The excludes keep the non-addon files in the game's `Heraldry\` folder (`.claude\` with the graphify skill, `graphify-out\`, a pointer `CLAUDE.md`).
   - Robocopy exit codes below 8 mean success.
4. Say whether a `/reload` is enough or a **game restart** is needed ("Reinício do jogo necessário"), which applies to any new texture, file or addon, or a `.toc` file-list change.
5. Update "Por testar" in the project decisions doc.
6. Report to Tiago in PT-PT, short, and wait for approval before the next step.
7. **Push to `main` only after Tiago approves.**

### 9.2 Behaviour notes

- Tiago tests with screenshots; **always ignore the Zygor addon** in them.
- When Tiago only says "feito" after a Canva step, it means he downloaded the images to `Imagens Wow/...`. Files sometimes land in the wrong subfolder, so find them by modification time.
- Profiles: Tiago asked whether positions and sizes can be copied from another profile. They can, with Profiles → Manage → "Copy settings from" (it copies the whole profile).

### 9.3 Lessons learnt (code)

- `SetIgnoreParentScale` drops the UI scale.
- Never index a table with a value that may be secret (guard with `issecretvalue`).
- Never reparent Edit Mode-managed containers.
- Apply the font before `SetText`.
- The mail frame calls `parent:Layout()`.
- Chat window fonts go through `Fonts:Resolve`.
- Chat clipping: turning clipping off, so the last line's letters with descenders weren't cut, let old messages show above the paper. Clipping went back on, and the line area drops 30% of the font size below the window.

### 9.4 Art pipeline (Python, PIL, numpy, scipy)

- **Background cut (`cut.py`):** pure black is removed.
  - The threshold is automatic from the image corners: max(5, p99 of the corners + 4).
  - Dark components touching the border become background. Then a morphological close and a hole fill follow.
  - Seeds can be given for interior dark areas.
  - Soft alpha on edges.
- **Orbs (`orbsX.py`, env `ORBS=`):**
  - Crop to a square of 512.
  - Measure the hole `(cx, cy, r)` from the transparent centre component.
  - Measure `reach` and find socket candidates (dark opaque blobs in the ring).
  - **Always check the sockets visually with an overlay.** Detection misses some; on the Warrior orbs the sockets sit about 146 px from the centre (150 on the Defensive power orb).
- **Kit (`kitX.py`, env `KIT=` letter):**
  - Button frames: hole measurement.
  - Rail: band rows 8..120 as a 512×128 crossfaded tile.
  - Rod: cap and mid, plus versions rotated for `scroll.rodV`. The mid must come only from the plain shaft; on the Warrior rod it was re-cut by hand from x≈440 over 900 px and stretched to 512.
  - Plates: both resized from one 2:1 image.
  - Minimap: window, sockets, plate and art box, plus a generated `MinimapMask`.
  - Gem, Cap.
- **Output:** TGA with `compression='tga_rle'`. Contact sheets on a dark-red background were used to check cuts.
- **Fixes along the way:**
  - Dark art needs a low threshold with close and fill.
  - Very dark plates need brightening by about ×1.45 (Priest Shadow).
  - Glow blobs on rods had their alpha zeroed outside the shaft core.
- **The scripts are not in the repository.** They lived in the old session's `/tmp/pr`, and copies were left in that session's outputs (`art-pipeline/`). Rebuild them from this description if those copies are gone.

---

## 10. Contradictions and stale information

These were found while writing this document. None of them has been changed in code.

1. **Old README** (before this rewrite) listed `Heraldry_Test`, which was deleted, a "C5/C6" status, and the target as "in test". It is replaced by this file.
2. **`claude/arquitetura-core.md`** is the v0 *proposal* ("nothing is implemented before Tiago approves"). Several parts differ from what was built:

   | Proposal | What was built |
   |---|---|
   | `Libs/` folder | no bundled libraries |
   | `Layers.lua` with an `overridable` list | C3 not built |
   | `Layout.lua`, `Share.lua`, `Config/` | not built |
   | `Locales/` with ptBR | enUS only |
   | BLP textures | TGA |
   | `H.Theme:DefinePieceType`, `H.Config:RegisterPage`, `OnThemeChanged` | `H:RegisterTheme` with validators in `Themes.lua`, `H:RegisterOptionsPage`, the `THEME_CHANGED` message |
   | module on/off "per character" | account-wide (decision 12, and the `GetAddOnEnableState` fact) |

3. **Swing/cast rail defaults:** the header of `RailLight.lua` says the swing uses the top rail and the cast the bottom one. The code (`castPlace = "top"`, `swingPlace = "bottom"`), decision 39 and CLAUDE.md say cast top, swing bottom. Tiago swapped them; the comment is stale. **Fixed 2026-11-19** (commit `80443ea`).
4. **`Party.lua` header** lists only the "cartouche" and "compact" styles. The code and settings also have **"banner"**, which Tiago approved. **Fixed 2026-11-19** (commit `80443ea`).
5. **Raid settings text** (`Settings.lua`, raid style description) says "each group a parchment banner under the theme's rod". The code and decision 42 give **one rod per row of groups** (default 4 groups per row). **Fixed 2026-11-19** (commit `80443ea`).
6. **`Heraldry_Options/Style.lua` header** says "until the theme system exists (C5)". The theme system exists; the comment is stale. **Fixed 2026-11-19** (commit `80443ea`).
7. **`Core/Database.lua` header** lists only some character fields. The code also stores `finish`, `formThemes`, `auraSockets`, `indicators`, `clickcast`, `raidRolled`, chat history, and `global.minimapGrab`. **Fixed 2026-11-19** (commit `80443ea`).
8. **The previous `CLAUDE.md`** had duplicated numbers in "Next steps" (two items 8 and two items 9), and its "Implemented" table missed raid, indicators, the data bar and the class themes. Both are corrected in the new `CLAUDE.md`.
9. **Decision 9** ("other classes only once Standard + Paladin are complete and everything works") versus the class art done on 2026-11-18/19 for Priest, Druid and Warrior. That art was Tiago's explicit decision, driven by his remaining Canva time.
10. **Approval wording:** "Aprovado, podes avançar" (2026-11-18) came after the data bar "maximum configuration" delivery, while the Druid base theme was also waiting for approval. Both are treated as approved. For the Druid forms Tiago approved the prototypes ("Estão muito bons") but has not reported an in-game test.
11. **Per-spec profiles** exist in code and in `/hui help`, although the client has no specs. The panel hides the section; the commands remain.
12. **The rule "hide Blizzard frames by reparenting, never `Hide()`"** has the deliberate exceptions listed in §5.3.
