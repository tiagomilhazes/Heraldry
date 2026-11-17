# CLAUDE.md — Heraldry

All-in-one, modular, immersive UI addon for **World of Warcraft: Forever**. Successor to the author's older addon TimelessUI. Only TimelessUI's **art** is reused; none of its code is.

## Working with Tiago (read first)

- **Language.** Talk to Tiago in **European Portuguese** (PT-PT). Everything in the addon is in **English**: in-game text, code, comments, commit messages and repo docs. There is only an enUS locale.
- **Pace: module by module, in small steps.** Tiago tests each delivery live in game. Don't start the next step until he approves the current one.
- **Tiago decides.** Be critical and assertive, propose options with your reasoning, and say plainly when you disagree.
- **Goal:** "maximum configuration without repeating anything". A setting lives in exactly one place (see the typography rule).
- **Settings panel rule.** Every sub-category of a page is its own **tab**. This applies to every page, current and future, without being asked again. A page with a single sub-category has no tabs.
- **Track testing.** Keep "Por testar" in the project decisions doc up to date: everything delivered but not yet testable in game goes there.
- **Restarts.** A delivery that touches a `.toc`, adds an addon or adds a texture needs a full game restart, because `/reload` is not enough. Flag it as **"Reinício do jogo necessário"**.

## Target client

- **WoW Forever, Midnight-era client. `## Interface: 16001`** in every `.toc`.
- The client looks classic but runs modern APIs: `C_AddOns`, the modern game menu (`AddButton`/`layoutIndex`), `Enum.StatusBarInterpolation`, and **secret values**. In combat, unit life and power can be protected values that Lua code can't do arithmetic on.
- Facts found in testing:
  - There are **no specializations**: `GetSpecialization` returns nothing, so per-spec profiles are hidden.
  - `C_AddOns.GetAddOnEnableState(addon, character)` **always returns 2**. Always read and write the enable state **without** the character argument.
  - The client has action bars 1–8 (MultiBar5–7 included), plus a stance bar and a pet bar with 10 buttons each.
  - The ESC menu is the modern one, even though it looks classic.

## Repository layout

Each top-level folder is one addon; copy them into `Interface\AddOns\`. **There are no `.xml` files.** Everything is built in Lua with `CreateFrame` and Blizzard templates. Keep it that way unless there's a strong reason not to.

```
Heraldry/                      core (always loaded)
  Heraldry.toc                 SavedVariables: HeraldryDB; AddonCompartmentFunc
  Core/Init.lua                namespace H (also _G.Heraldry), Print/Error/Debug
  Core/Events.lua              H:RegisterEvent, H:On / H:Fire (internal messages)
  Core/Combat.lua              H:RunOutOfCombat(fn, key)
  Core/Database.lua            HeraldryDB, boot: DB_LOADED -> READY
  Core/Profiles.lua            create/use/copy/reset/rename/delete
  Core/Options.lua             options page registry, H:OpenOptions / ToggleOptions
  Core/Modules.lua             H:NewModule, module catalog, enable/disable
  Core/Movers.lua              positions per profile, docking
  Core/EditMode.lua            drag/snap/scale UI for movers
  Core/Themes.lua              theme registry + geometry contract + finishes
  Core/Fonts.lua               global fonts (header/body/outline/scale), LSM aware
  Themes/Standard.lua          neutral theme (colours only)
  Themes/Paladin.lua           Paladin theme (art pieces, accent, bronze finish)
  Core/GameMenu.lua            "Heraldry" button in the ESC menu
  Core/Commands.lua            /hui, /heraldry
  Media/Themes/Paladin/*.tga   ButtonFrame, ButtonFrameSlim, Plate, PlateDouble,
                               Rail, Cap, OrbHealth, OrbPower, Gem, RodCap, RodMid
  Media/Themes/*/RodCapV*.tga, RodMidV  the same rods standing up (scroll.rodV)
  Media/Themes/Standard/*.tga  RodCap, RodCapR, RodMid (plain wooden scroll rod)
  Media/Paper/{Light,Dark}.tga parchment shared by Quests and Chat
Heraldry_Options/              settings panel, LoadOnDemand
  Style.lua Widgets.lua Panel.lua
  Pages/General|Profiles|Theme|Fonts|Layout|Modules.lua
Heraldry_ActionBars/           ActionBars.lua Art.lua Text.lua Settings.lua
Heraldry_Orbs/                 Orbs.lua Settings.lua Media/{Liquid1,Liquid2,Glass,Surface}.tga
Heraldry_UnitFrames/           Target.lua Cast.lua Small.lua TargetPlaque.lua Settings.lua Media/Target/{Plaque,LevelRing}.tga
Heraldry_Minimap/              Minimap.lua Settings.lua Media/{Frame,Mask}.tga
Heraldry_Quests/               Quests.lua Settings.lua
Heraldry_Chat/                 Chat.lua Text.lua Settings.lua
Heraldry_Test/                 temporary test module (to be deleted)
```

### `.toc` conventions

- Core load order matters:
  1. Init, Events, Combat
  2. Database, Profiles
  3. Options, Modules
  4. Movers, EditMode
  5. Themes, Fonts
  6. the theme data (`Themes/*.lua`)
  7. GameMenu
  8. Commands, always last
- A module `.toc` needs:
  ```
  ## Interface: 16001
  ## Title: |cffE8B04BHeraldry|r <Name>
  ## Dependencies: Heraldry
  ## X-Heraldry-Module: 1
  ## X-Heraldry-Label: <Label shown on the Modules page>
  ## IconTexture: Interface\Icons\INV_Shield_06
  ```
  List the code file first and `Settings.lua` last. `Settings.lua` registers the module's options page from inside the module addon.
- Bump `## Version` when a delivery changes an addon.

## Namespaces and globals

- **`H`** is the core table. It's `ns.H` inside the core and **`_G.Heraldry`** everywhere else; modules start with `local H = Heraldry`.
- Core sub-tables: `H.Modules` (`.byName`, `.list`), `H.Movers` (`.byKey`), `H.Themes`, `H.Fonts`, `H.Profiles`.
- Data shortcuts set at boot:
  - `H.sv`: the whole `HeraldryDB`
  - `H.global`
  - `H.char`: per-character data (theme and finish)
  - `H.profile`: the active profile
- Inside the options addon, `UI` holds the styling and widgets.
- **Global frame names** use the `Heraldry` prefix, for example:
  - `HeraldryActionBar1..8`
  - `HeraldryOrbHealth`, `HeraldryOrbPower`, `HeraldryOrbHealthClick`
  - `HeraldryTargetFrame`
- **Other globals:**
  - `HeraldryDB` (the SavedVariable)
  - `Heraldry_OnCompartmentClick`
  - `ClickCastFrames[frame] = true` on every clickable unit button, for Clique-style addons.
- Mover keys are `"<Module>.<thing>"`: `ActionBars.bar1`, `Orbs.health`, `UnitFrames.target`, and so on.
- Brand colour is `E8B04B`.

## Core APIs

### Database (`HeraldryDB`)

- Top level: `{ version, global, profiles, overrides, chars }`.
- A profile is `{ modules = {}, layout = {}, preset = "altar", fonts = {} }`.
- Theme and finish are stored **per character**, in `chars[...]`.

### Modules

- Create one with `H:NewModule(name, { label, defaults, fonts = true })`.
- Hooks: `OnInitialize`; `OnEnable`, which always runs out of combat; and `OnProfileChanged`.
- `mod.db` is a **flat proxy** over the profile. Values equal to the default are not stored, and `mod:ResetSettings()` clears the module's settings.
- On/off is the game's addon list only (`C_AddOns.EnableAddOn/DisableAddOn(addon)`, without a character), and it takes effect after a reload. A disabled module never loads.

### Events

- `H:RegisterEvent(event, fn)` for game events.
- `H:On(msg, fn)` and `H:Fire(msg, ...)` for internal messages. Listener lists are copy-on-write and each listener runs in `xpcall`.
- Internal messages: `DB_LOADED`, `READY`, `THEME_CHANGED`, `FONTS_CHANGED`.

### Movers and edit mode

```lua
H:RegisterMover(frame, key, {
  label = "Target",
  default = { point, x, y },
  scalable = true,
  isShown = fn,   -- optional
})
```

- The position is saved as `{point, x, y, scale}`. The anchor point is chosen by which third of the screen the frame is in, so positions survive resolution changes.
- Docking pins one mover to another: `mover.dock = { target, point, relPoint, x, y, movable }`, or `Movers:Dock(key, target, point, relPoint, x, y, movable)` / `Movers:Undock`. A docked frame follows its target. A plain dock gets no box in edit mode; a **movable dock** (the target of target) keeps its box, and dragging it saves an offset from the docked place (`{ "DOCK", dx, dy, scale }` in the layout), so it still follows its target.
- Other functions: `Movers:Apply`, `Movers:Preview` (moves live without saving), `Movers:IsMovable`, `Movers:CenterX(key)` (centre horizontally, height kept), `H:RefreshEditMode()`.
- Edit mode itself:
  - Boxes move with the native `StartMoving`. Snapping happens **only on release**, with gold guide lines while dragging; live snapping caused stutter.
  - Arrow keys nudge, the mouse wheel scales, right-click resets, middle-click / C / the "Centre" button centres horizontally. The Layout page's Positions tab also has a "Centre" button per frame.
  - Edit mode closes when combat starts.

### Themes: the geometry contract

Each piece type says which numbers a theme must provide, measured in texture pixels.

| Piece type | Fields |
|---|---|
| `button.frame` / `button.frameSlim` | `file, size{w,h}, hole{l,t,r,b}` |
| `bar.plate` / `block.plate` | `file + size`, or `color{r,g,b,a}` |
| `bar.rail` | `file, size, band{top,bottom}` (width must be a power of 2) |
| `bar.cap` | `file, size, join{x,y,h}` |
| `orb.health` / `orb.power` | `file, size, hole{cx,cy,r}, reach` |
| `frame.gem` | `file, size` |
| `scroll.rod` | `cap, capR?, mid, size, capW, midW?, shaft` (cap mirrored when no capR; mid tiled when midW, else stretched) |
| `scroll.rodV` | `cap, capB?, mid, size, capH, midH?, shaft` (standing rod; cap flipped when no capB) |

- Optional theme fields:
  - `accent = {r,g,b}`: the metal colour for thin lines.
  - `finish`: one of `none`, `aged`, `bronze`, `iron` (desaturation plus a tint).
- A missing or invalid piece falls back to the Standard theme's piece. Invalid pieces are reported in debug output.
- API:
  - `Themes:Piece(type)`
  - `Themes:Paint(tex)` applies the finish to theme art
  - `Themes:Accent()` returns the toned accent colour, or nil
  - `Themes:Set(key)`, `Themes:SetFinish(key)`
- The theme is chosen per character, and `"auto"` follows the class.

### Fonts: three layers, no duplication

1. **Core (Fonts page):** header font, body font, outline and global scale. Lives in the profile and accepts LibSharedMedia fonts.
2. **Module:** with `fonts = true`, a module can override the font and outline (`db.fontOverride`, `db.font`, `db.fontOutline`). Every module uses the same "Font" tab, `page:FontSection(mod, onChange)`.
3. **Text:** each text's size and position is a setting of its own module.

Always apply fonts with `H.Fonts:Apply(fontString, "header"|"body", size, mod)`. For chat frames (their SetFont returns nothing) use `H.Fonts:Resolve(kind, size, mod)` -> path, size, flags, shadow.

### Options panel

```lua
H:RegisterOptionsPage({
  key, label, desc, group = "modules", order,
  tabs = { { key, label, build = function(page) ... end } },
})
```

- A page takes either `tabs` (the normal case) or a single `build`.
- The last open tab of each page is remembered.
- Widgets:
  - `page:Section`, `page:Text`, `page:Toggle`, `page:Slider`, `page:Dropdown`, `page:Input`, `page:Button`, `page:FontSection`
  - `UI.Confirm` and `UI.OpenMenu`. The menu frame has mouse disabled, and clicks outside it are caught with `GLOBAL_MOUSE_DOWN`.
- One page per module. When a module sets up several separate things (unit frames: target, ToT, focus), each thing is a top-level tab with its own row of sub-tabs (`tabs = { { key, label, tabs = { {key,label,build}, ... } } }`; the panel remembers the sub-tab per tab). Module-wide settings (Font) stay a plain top-level tab. Action bars still use a bar picker inside its tabs.
- Usual pattern: a `field(name)` helper returns get/set pairs that write to `mod.db` and call `mod:Layout()`.

## Secure frames, taint and combat (rules)

- **Never touch protected frames in combat.** Wrap all layout of secure frames (`SetPoint`, `SetSize`, `SetParent`, `Show`/`Hide`, attributes) with `if InCombatLockdown() then H:RunOutOfCombat(fn, key) return end`. Use a unique key per job so repeated calls merge. `Movers:Apply` already defers itself.
- **Hiding Blizzard frames:** reparent them to a local hidden frame (`local hidden = CreateFrame("Frame"); hidden:Hide()`), out of combat. Don't call `Hide()` on them or hook their `Show`. Remember the original parent so the option can be undone. This is how the game's action bar frames, `PlayerFrame` and `TargetFrame` are hidden.
- **Action bars:**
  - They **reuse Blizzard's own action buttons**, reparented into our `SecureHandlerStateTemplate` containers. We never create our own action buttons; this is the approach that worked in TimelessUI.
  - Visibility uses a state driver: `"[petbattle][vehicleui][overridebar] hide; show"`. The pet bar has its own driver.
- **Unit frames:**
  - Use `SecureUnitButtonTemplate`, with attributes `unit`, `*type1 = "target"` and `*type2 = "togglemenu"`.
  - Visibility comes from `RegisterUnitWatch` and the visuals are children of the button.
  - Register the button in `ClickCastFrames`.
- **Secret values:**
  - Life and power go straight into `StatusBar:SetMinMaxValues` / `SetValue`; do no arithmetic on them in Lua.
  - Any text that needs maths (percentages) runs in `pcall` and falls back to the plain value.
  - For percentages, prefer `UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)` when it exists.
- **Masks:** circular shapes use `Interface\CharacterFrame\TempPortraitAlphaMask` as a mask texture.
- Guard APIs that may be missing on this client, for example `UnitIsTapDenied`, `C_ClassColor` and `GetCreatureDifficultyColor`.

## Visual hierarchy (project rule)

| Level | What | Look |
|---|---|---|
| 1, hero | Action bar block (bars 1+2) and the orbs | Full ornament: double plate, rails, caps, theme rings, button frames |
| 1.5, target | Target frame (Plaque style) | One fixed plaque (lion medallions, two jewels, a slot the bars fill). The target shows only as colour: metal finish on top of the theme finish (theme finish for elite/players, iron hostile, bronze friendly, silver rare, red boss, at the theme finish's brightness) and jewel colour (reaction or class). Shape never changes, so texts never move. Class emblems will replace the lions for players (art pending) |
| 2, frames | Quest log (and the target's Minimal style). The minimap moved to 1.5 (M1 frame) | Dark glass panel, a rim in the theme accent, **one** theme motif (the gem) |
| 3, panels | Chat, damage meter, tooltips | Flat and dark, with a thin rim |

Art is designed **as a whole**, not as loose pieces. The first Paladin art (a pink plate, shield crests and a gold frame on every button) was rejected as random. Paladin uses the bronze finish.

## Implemented

| Step | Content | State |
|---|---|---|
| C1 | Skeleton, DB, profiles, commands, debug | approved |
| C1.5 | Settings panel, ESC menu button | approved |
| C2 | Module system, Modules page, test module | approved |
| C4 | Movers, edit mode, Layout page | approved |
| M1 | Action bars 1–8 (layout, size, spacing, fading, mouseover) | approved |
| M1.1 | Stance bar (approved), pet bar | pet bar untested |
| M1.5 | Theme system (Standard + Paladin), the hero block | approved |
| M2 | Orbs: theme rings, docked to bar 1, animated liquid, text, clickable life orb, player frame hidden | approved |
| — | Fonts (core + per-module override), action bar texts | approved |
| — | Tabs in every settings page | approved |
| M4 | Quest tracker as a parchment scroll (Q4): theme rods, light/dark paper, roll up, own tracker | approved |
| M3 | Unit frames: **target**. Styles Plaque (fixed plaque with the slot cut out and the bars behind it, finish and jewels by target, level in a ring set into the left medallion; per-text size/offset settings) and Minimal (glass panel, theme gem, halo). Secure button, Blizzard target hidden | approved, cast bar in the power row (C4) approved; class emblems pending |

Settings tabs per page:

| Page | Tabs |
|---|---|
| General | Character / Panel / Testing |
| Profiles | Active profile / Manage |
| Theme | Theme / Finish |
| Fonts | Fonts / Scale |
| Layout | Edit mode / Positions |
| Modules | (single page) |
| Action bars | Block / Bars / Look / Visibility / Text / Font |
| Orbs | Place / Text / Font / Behaviour |
| Unit frames | Target (Size / Text / Look / Behaviour) / Target of target (Size / Text / Behaviour) / Focus (Size / Text / Behaviour) / Font. Party and raid will be new top-level tabs |
| Minimap | Size / Text / Addons / Behaviour / Font |
| Quests | Look / Text / Behaviour / Font |
| Chat | Look / Size / Text / Channels / Input / Behaviour / Font |

## Untested (needs the situation in game)

- **Vehicles:** our bars hide and the game's vehicle bar appears.
- **Pet bar:** on a Hunter or Warlock. It shows only with a pet, clicks and keybinds work, and it moves, resizes and persists.
- **Stance bar with several stances:** buttons per row (including vertical), growing when a new stance is learned, no overlap after switching stances in combat.
- **Pet battles:** our bars hide.
- **Orbs and target in long fights:** text keeps updating with secret values.
- **Target classification:** halo colours on elite, rare and boss, and "??" on bosses.
- **Hidden player frame:** no errors when opening Blizzard's Edit Mode.

## Next steps

1. ~~Target cast bar~~: approved as C4 — the target's casts take the power row (Cast.lua; gold interruptible, grey not, red interrupted/failed; game timer via SetTimerDuration when available, else GetTime maths in pcall). Pending for the target: class emblems in the medallions (Canva, needs Tiago's prompt wording).
2. Target of target and focus delivered (Small.lua: smaller plaques, same finish/jewel rules, per-frame prefixed settings tot*/focus*, ToT docked right of the target). Party later (vertical cards, prototype P4).
3. **Minimap**: delivered as prototype M1 (TimelessUI Paladin_PlateM frame, level 1.5 like the target): map cut to the window by a mask, sockets = day/night (GameTimeFrame), addon buttons panel toggle, mail; zone + clock on the plate with per-text settings. Approved.
4. **Quest tracker**: delivered as Q4, a parchment scroll (`Heraldry_Quests`): theme rods top and bottom (`scroll.rod`), light (ink) or dark paper, click the top rod to roll up, own tracker reading C_QuestLog with classic fallbacks. The game's tracker is hidden with Hide() + an OnShow hook (Questie's approach on this client; the frame is protected, so it is not reparented). Steps aside when Questie's tracker is on. Only the level carries the difficulty colour; ready/failed shown on the title; rolled up shows a strip with the quest count. Approved. The quest log window itself comes later.
5. **Chat**: delivered as a sideways scroll (`Heraldry_Chat`): standing theme rods (`scroll.rodV`), dark/light/glass paper or a flat panel, rolls up to the fixed side (the mover's anchor), glow on new messages, Enter opens to type. ChatFrame1 kept at its open size and placed in our frame (SetPoint/SetSize hooks); Blizzard art killed by alpha hooks; ink by wrapping AddMessage. Fonts via `H.Fonts:Resolve` (chat frames' SetFont answers nothing). Layout approved. Text.lua: channel names full/short/number/hidden with per-channel short names, "says" dropped, faded timestamps (the game's CVar), fading, input history with plain Up/Down (SetAltArrowKeyMode(false)) saved per character. Text awaiting test.
6. Delete `Heraldry_Test`.
6. Swing bar styling.
7. **C3 class overrides**, when the first module needs them.
8. **C7:** installer, presets ("Altar" plus a Healer variant), import/export.
9. Later: `Heraldry_Auras` (buffs and debuffs attached to the block), then themes for the other classes. These start only once Standard and Paladin are complete.
10. **Pending tuning:** default margins of the block, waiting for Tiago's preferred values.

## Workflow

- **Repo:** `github.com/tiagomilhazes/Heraldry` (private), branch `main`. Commit each delivery with a descriptive message.
- **Game folder:** `D:\World of Warcraft\_forever_\Interface\AddOns\`.
  - Deploy by copying the changed addon folders there and verify them (checksums) before asking for a test.
  - Other bar addons (TimelessUI, EllesmereUI Action Bars) must be disabled while testing the bars.
- **There is no Lua interpreter in the cloud environment.** If you have `luac` or `luacheck` locally, run a syntax check before deploying.
- **Debugging:**
  - `/hui debug` toggles debug output and `/hui status` shows the state.
  - `/hui edit` opens edit mode.
  - `/hui profile ...` manages profiles.
- **Reference docs** in the claude.ai project:
  - `claude/decisoes-projecto.md`: numbered decisions, progress and the untested list, in PT-PT.
  - `claude/arquitetura-core.md`: the core architecture.
