# CLAUDE.md — Heraldry

All-in-one, modular, immersive UI addon for **World of Warcraft: Forever**. Successor to the author's older addon TimelessUI. Only TimelessUI's **art** is reused; none of its code is.

`README.md` is the full project documentation: architecture, every feature with its state, file list, decisions, untested list, future work, history, and a list of contradictions found (§10). Read it before making changes. This file holds the standing rules and the context needed to continue exactly where the work stopped (commit `804a2b7`, 2026-11-19, when the project moved from Claude chat to Claude Code), plus the Claude Code work since then: the git clone and local deploy, the bug fixes of 2026-11-19 and the chat copy box.

## Working with Tiago (read first)

- **Language.** Talk to Tiago in **European Portuguese** (PT-PT). Everything in the addon is in **English**: in-game text, code, comments, commit messages and repo docs (README.md and this file). There is only an enUS locale.
- **Pace: module by module, in small steps.** Tiago tests each delivery live in game. Don't start the next step until he approves the current one.
- **Tiago decides.** Be critical and assertive, propose options with your reasoning, and say plainly when you disagree.
- **Prototypes first.** Any new visual is shown first as labelled prototypes (as with S1/S2/S3, R2/R3, D1, Q4, T2, P2) and Tiago picks. Every new hero art set also starts with prototypes.
- **Goal:** "maximum configuration without repeating anything". A setting lives in exactly one place (see the typography rule).
- **Settings panel rule.** Every sub-category of a page is its own **tab**. This applies to every page, current and future, without being asked again. A page with a single sub-category has no tabs.
- **Use what is already on screen before adding a piece.** Tiago rejected extra pieces twice: the block's rails became the cast and swing bars, and the orb gems hold the auras.
- **Track testing.** Keep "Por testar" in the project decisions doc up to date: everything delivered but not yet testable in game goes there.
- **Restarts.** A delivery that touches a `.toc`, adds an addon or adds a texture needs a full game restart, because `/reload` is not enough. Flag it as **"Reinício do jogo necessário"**.
- **Screenshots:** always ignore the **Zygor** addon in them.
- **"feito"** after a Canva step means Tiago downloaded the images to `Imagens Wow/...` on his PC. Find them by modification time: they sometimes land in another subfolder.

## Target client

- **WoW Forever, Midnight-era client. `## Interface: 16001`** in every `.toc`.
- The client looks classic but runs modern APIs:
  - `C_AddOns`
  - the modern game menu (`AddButton` / `layoutIndex`)
  - `Enum.StatusBarInterpolation`
  - **secret values**: in combat, unit life and power can be protected values that Lua code can't do arithmetic on.
- Facts found in testing:
  - There are **no specializations**: `GetSpecialization` returns nothing, so per-spec profiles are hidden. The code and the `/hui spec` commands remain.
  - `C_AddOns.GetAddOnEnableState(addon, character)` **always returns 2**. Always read and write the enable state **without** the character argument.
  - The client has action bars 1–8 (MultiBar5–7 included), plus a stance bar and a pet bar with 10 buttons each.
  - The ESC menu is the modern one, even though it looks classic.
  - **No combat log for addons.** The client has a native swing timer instead: `PLAYER_SWING(duration, type)`, `C_SwingTimer`, `Enum.PlayerSwingType`, `Blizzard_SwingTimer`.
  - Tables cannot be indexed with secret keys. Guard any lookup by possibly secret text with `type(t) == "string" and not issecretvalue(t)`.
  - `UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)` returns a **secret** value even out of combat, and `FontString:SetFormattedText("%d%%", secret)` accepts it (tested 2026-11-19).
  - `Frame:RegisterUnitEvent(event, unit1, unit2)` takes **two units at most**. For more units, register the event plainly and filter in the handler.
  - Aura names and IDs can be secret in combat, so indicators can't match them then.
  - Edit Mode's status-tracking containers call their parent's methods, so **never reparent them**. Use alpha 0, a `SetAlpha` hook and `EnableMouse(false)`.
  - The mail frame calls `parent:Layout()`. Any parent we give it needs `Layout` / `MarkDirty` / `MarkClean`.
  - `FontString:SetText()` before a font is set errors. Apply the font first.
  - `ObjectiveTrackerFrame` is protected. It is hidden with `Hide()` plus an `OnShow` hook, as Questie does.
  - Chat tabs follow `ChatFrame1Tab`, which is anchored to `ChatFrame1`. Shadow and outline belong to the whole chat window.
  - `C_DurationUtil.CreateDurationTextBinding` only writes when it has a formatter (`C_StringUtil.CreateNumericRuleFormatter`).
  - Aura containers: `CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")` after loading `Blizzard_AuraContainer`. Reference: `EllesmereUI/EllesmereUI_AuraKit.lua`.

## Repository layout

Each top-level folder is one addon; copy them into `Interface\AddOns\`. **There are no `.xml` files.** Everything is built in Lua with `CreateFrame` and Blizzard templates. Keep it that way unless there's a strong reason not to. There are no bundled libraries and no locale files. Textures are RLE `.tga`.

```
Heraldry/                      core (always loaded)
  Heraldry.toc                 SavedVariables: HeraldryDB; AddonCompartmentFunc
  Core/Init.lua                namespace H (also _G.Heraldry), Print/Error/Debug
  Core/Events.lua              H:RegisterEvent, H:On / H:Fire (internal messages)
  Core/Combat.lua              H:RunOutOfCombat(fn, key)
  Core/Database.lua            HeraldryDB, boot: DB_LOADED -> READY
  Core/Profiles.lua            create/use/copy/reset/rename/delete (+ per-spec profiles, hidden: no specs)
  Core/Options.lua             options page registry, H:OpenOptions / ToggleOptions
  Core/Modules.lua             H:NewModule, module catalog, enable/disable
  Core/Movers.lua              positions per profile, docking
  Core/EditMode.lua            drag/snap/scale UI for movers
  Core/Themes.lua              theme registry + geometry contract + finishes + form themes + variants
  Core/Fonts.lua               global fonts (header/body/outline/scale), LSM aware
  Core/Paper.lua               H.Paper: papers (dark/light/glass), Apply, Crop, Shades, InkOf
  Themes/Standard.lua          neutral theme (colours only, plain wooden rod)
  Themes/Paladin.lua           Paladin theme (TimelessUI art pieces, accent, bronze finish)
  Themes/Priest.lua            PRIEST (Holy Light) and PRIEST_SHADOW themes (Canva kits, see project doc arte-classes-prompts)
  Themes/Druid.lua             DRUID (Ancient Grove) theme + DRUID_BEAR / DRUID_CAT / DRUID_MOONKIN form variants (base = DRUID)
  Themes/Warrior.lua           WARRIOR (Warlord, orcish iron) + WARRIOR_DEFENSIVE / WARRIOR_BERSERKER stance variants (Battle keeps the base)
  Core/GameMenu.lua            "Heraldry" button in the ESC menu
  Core/Commands.lua            /hui, /heraldry (H.commands[cmd] extension point for modules)
  Media/Themes/Paladin/*.tga   ButtonFrame, ButtonFrameSlim, Plate, PlateDouble,
                               Rail, Cap, OrbHealth, OrbPower, Gem, RodCap, RodMid (+ RodCapV, RodMidV)
  Media/Themes/{Priest,PriestShadow,Druid,Warrior}/*.tga   15-file kits: the Paladin set + Minimap, MinimapMask
  Media/Themes/{DruidBear,DruidCat,DruidMoonkin,WarriorDefensive,WarriorBerserker}/  OrbHealth, OrbPower, Cap
  Media/Themes/*/RodCapV*.tga, RodMidV  the same rods standing up (scroll.rodV)
  Media/Themes/Standard/*.tga  RodCap, RodCapR, RodCapV, RodCapVB, RodMid, RodMidV (plain wooden scroll rod)
  Media/Paper/{Light,Dark}.tga parchment shared by Quests, Chat, Tooltips, Raid banners, Data bar
Heraldry_Options/              settings panel, LoadOnDemand
  Style.lua Widgets.lua Panel.lua
  Pages/General|Profiles|Theme|Fonts|Layout|Modules.lua
Heraldry_ActionBars/           ActionBars.lua Art.lua Text.lua RailLight.lua Swing.lua Cast.lua Settings.lua
Heraldry_Orbs/                 Orbs.lua Settings.lua Media/{Liquid1,Liquid2,Glass,Surface}.tga
Heraldry_UnitFrames/           Target.lua Cast.lua Small.lua Indicators.lua Party.lua Raid.lua TargetPlaque.lua Settings.lua Media/Target/{Plaque,LevelRing}.tga
                               Media/Party/{Frame,Banner}.tga, Media/Party/Class/<CLASS>.tga (class-coloured symbols)
                               Media/Class/<CLASS>.tga (plain gold symbols, kept for the target emblems)
Heraldry_Minimap/              Minimap.lua Settings.lua Media/{Frame,Mask}.tga (TimelessUI Paladin frame: fallback when the theme has no minimap.frame)
Heraldry_Quests/               Quests.lua Settings.lua
Heraldry_Chat/                 Chat.lua Text.lua Copy.lua Settings.lua (Copy.lua: /hui copy box and the copy button)
Heraldry_Tooltips/             Tooltips.lua Settings.lua
Heraldry_Auras/                Auras.lua Rows.lua Settings.lua (auras in the orbs' gems; buff/debuff rows)
Heraldry_ClickCast/            ClickCast.lua Settings.lua (click casting on unit frames)
Heraldry_DataBar/              DataBar.lua Settings.lua (top bar: micro menu, XP on the theme rail, gold, bags, durability, FPS/latency, clock, zone, coords, friends, guild)
README.md                      full project documentation
CLAUDE.md                      this file
```

Optional dependencies between modules: `Heraldry_Orbs` lists `## OptionalDeps: Heraldry_ActionBars` (it docks to bar 1). `Heraldry_Auras` lists `## OptionalDeps: Heraldry_Orbs` (it uses the gems). LibSharedMedia-3.0 is used only if another addon provides it.

### `.toc` conventions

- Core load order matters:
  1. Init, Events, Combat
  2. Database, Profiles
  3. Options, Modules
  4. Movers, EditMode
  5. Themes, Fonts, Paper
  6. the theme data (`Themes/*.lua`: Standard, Paladin, Priest, Druid, Warrior)
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
- Bump `## Version` when a delivery changes an addon. Versions on 2026-11-19 (commit `80443ea`):

  | Addon | Version |
  |---|---|
  | core | 0.14.2 |
  | Options | 0.7.11 |
  | ActionBars | 0.11.6 |
  | Orbs | 0.8.0 |
  | UnitFrames | 0.12.3 |
  | Minimap | 0.2.1 |
  | Quests | 0.1.3 |
  | Chat | 0.2.9 |
  | Tooltips | 0.1.1 |
  | Auras | 0.2.7 |
  | ClickCast | 0.1.1 |
  | DataBar | 0.2.0 |

## Namespaces and globals

- **`H`** is the core table. It's `ns.H` inside the core and **`_G.Heraldry`** everywhere else; modules start with `local H = Heraldry`.
- Core sub-tables: `H.Modules` (`.byName`, `.list`), `H.Movers` (`.byKey`), `H.Themes`, `H.Fonts`, `H.Profiles`, `H.Paper`.
- Data shortcuts set at boot:
  - `H.sv`: the whole `HeraldryDB`
  - `H.global`
  - `H.char`: per-character data. It holds the theme, finish and `formThemes`, plus `auraSockets`, `indicators`, `clickcast`, `raidRolled`, `chatHistory` and the per-spec profile fields.
  - `H.profile`: the active profile
- `H.global` also holds `debug`, `editMode` (grid), `options` (panel position, scale, last page) and `minimapGrab`.
- Inside the options addon, `UI` holds the styling and widgets.
- **Global frame names** use the `Heraldry` prefix, for example:
  - `HeraldryActionBar1..8`
  - `HeraldryOrbHealth`, `HeraldryOrbPower`, `HeraldryOrbHealthClick`
  - `HeraldryTargetFrame`, `HeraldryTargetTargetFrame`, `HeraldryFocusFrame`
  - `HeraldrySwingBar`, `HeraldryDataBar`
- **Other globals:**
  - `HeraldryDB` (the SavedVariable)
  - `Heraldry_OnCompartmentClick`
  - `ClickCastFrames[frame] = true` on every clickable unit button, for Clique-style addons.
- Mover keys are `"<Module>.<thing>"`:
  - `ActionBars.bar1..8`, `ActionBars.barstance`, `ActionBars.barpet`, `ActionBars.swing`, `ActionBars.cast`
  - `Orbs.health`, `Orbs.power`
  - `UnitFrames.target`, `UnitFrames.targettarget`, `UnitFrames.focus`, `UnitFrames.party`, `UnitFrames.raid`
  - `Minimap.frame`, `Quests.tracker`, `Chat.frame`, `Tooltips.anchor`
  - `Auras.buffs`, `Auras.debuffs`

  The DataBar has no mover: it anchors to a screen edge from its settings.
- Brand colour is `E8B04B`.

## Core APIs

### Database (`HeraldryDB`)

- Top level: `{ version, global, profiles, overrides, chars }`.
- A profile is `{ modules = {}, layout = {}, preset = "altar", fonts = {} }`.
- Theme and finish are stored **per character**, in `chars[...]`. So is everything that belongs to a class's spells: aura gems, indicators, click-cast bindings.
- `overrides` is reserved for C3 (class overrides) and is unused.

### Modules

- Create one with `H:NewModule(name, { label, defaults, fonts = true })`.
- Hooks: `OnInitialize`; `OnEnable`, which always runs out of combat; and `OnProfileChanged`.
- `mod.db` is a **flat proxy** over the profile. Values equal to the default are not stored, and `mod:ResetSettings()` clears the module's settings. When a module configures several things, its settings carry a prefix: `bar<N>_…`, `party…`, `raid…`, `tot…`, `focus…`, `<block>Place` / `<block>Order`.
- On/off is the game's addon list only (`C_AddOns.EnableAddOn/DisableAddOn(addon)`, without a character), and it takes effect after a reload. A disabled module never loads.

### Events

- `H:RegisterEvent(event, fn)` for game events. It has no unit filter: for unit events of one or two units, use a local frame with `RegisterUnitEvent` so the game filters them.
- `H:On(msg, fn)` and `H:Fire(msg, ...)` for internal messages. Listener lists are copy-on-write and each listener runs in `xpcall`.
- Internal messages: `DB_LOADED`, `READY`, `PROFILE_CHANGED`, `PROFILE_RENAMED`, `THEME_CHANGED`, `FONTS_CHANGED`, `MOVER_ADDED`.
- `H.previews`: list of `{ key, label, desc, get, set }` toggles that modules add (made-up content). Each shows only in its own module's settings, via `page:Preview(key)` at the end of the matching tab.
- `H.commands[cmd] = function(rest)`: modules add `/hui` sub-commands this way (Minimap adds `grab`).

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
- Docking pins one mover to another: `mover.dock = { target, point, relPoint, x, y, movable }`, or `Movers:Dock(key, target, point, relPoint, x, y, movable)` / `Movers:Undock`. A docked frame follows its target.
  - A plain dock gets no box in edit mode.
  - A **movable dock** (the target of target) keeps its box. Dragging it saves an offset from the docked place (`{ "DOCK", dx, dy, scale }` in the layout), so it still follows its target.
- Other functions: `Movers:Apply`, `Movers:Preview` (moves live without saving), `Movers:IsMovable`, `Movers:CenterX(key)` (centre horizontally, height kept), `Movers:Reset(key)`, `Movers:ResetAll()`, `H:RefreshEditMode()`, `H:SetEditMode(on)`, `H:ToggleEditMode()`.
- Edit mode itself:
  - Boxes move with the native `StartMoving`. Snapping happens **only on release**, with gold guide lines while dragging; live snapping caused stutter. Alt places freely.
  - Arrow keys nudge (Shift: 10 px), the mouse wheel scales, right-click resets, middle-click / C / the "Centre" button centres horizontally. The Layout page's Positions tab also has a "Centre" button per frame.
  - Edit mode closes when combat starts.

### Themes: the geometry contract

Each piece type says which numbers a theme must provide, measured in texture pixels.

| Piece type | Fields |
|---|---|
| `button.frame` / `button.frameSlim` | `file, size{w,h}, hole{l,t,r,b}` |
| `bar.plate` / `block.plate` | `file + size`, or `color{r,g,b,a}` |
| `bar.rail` | `file, size, band{top,bottom}` (width must be a power of 2) |
| `bar.cap` | `file, size, join{x,y,h}` |
| `orb.health` / `orb.power` | `file, size, hole{cx,cy,r}, reach`, optional `sockets{{x,y,r}...}` (the ring's gems: top, right, bottom, left) |
| `frame.gem` | `file, size` |
| `scroll.rod` | `cap, capR?, mid, size, capW, midW?, shaft` (cap mirrored when no capR; mid tiled when midW, else stretched) |
| `scroll.rodV` | `cap, capB?, mid, size, capH, midH?, shaft` (standing rod; cap flipped when no capB) |
| `minimap.frame` | `file, size, window, sockets{3}, socketSize, plate, mask, art` (without it the Minimap module uses its own TimelessUI Paladin frame) |

- Optional theme fields:
  - `accent = {r,g,b}`: the metal colour for thin lines.
  - `finish`: one of `none`, `aged`, `bronze`, `iron` (desaturation plus a tint).
  - `class`: the class that "auto" picks this theme for.
- A missing or invalid piece falls back to the Standard theme's piece. Invalid pieces are reported in debug output.
- API:
  - `H:RegisterTheme(key, def)`
  - `Themes:Piece(type)`
  - `Themes:Paint(tex)` applies the finish to theme art
  - `Themes:Accent()` returns the toned accent colour, or nil
  - `Themes:Set(key)`, `Themes:SetFinish(key)`
  - `Themes:ActiveKey()`, `Themes:Field(t, name)`
  - `Themes.MEDIA` is `Interface\AddOns\Heraldry\Media\Themes\`
- The theme is chosen per character, and `"auto"` follows the class.
- **Forms.** A form (shapeshift/stance/Shadowform, by its spell ID) can have its own theme (`H.char.formThemes`). Class defaults are in `Themes.FORM_DEFAULTS`:

  | Class | Form (spell ID) | Theme |
  |---|---|---|
  | Priest | Shadowform (15473) | `PRIEST_SHADOW` |
  | Druid | Bear Form (5487), Dire Bear Form (9634) | `DRUID_BEAR` |
  | Druid | Cat Form (768) | `DRUID_CAT` |
  | Druid | Moonkin Form (24858) | `DRUID_MOONKIN` |
  | Warrior | Defensive Stance (71) | `WARRIOR_DEFENSIVE` |
  | Warrior | Berserker Stance (2458) | `WARRIOR_BERSERKER` |

  Battle Stance keeps `WARRIOR`. UPDATE_SHAPESHIFT_FORM fires THEME_CHANGED when the form changes.
- **Variants.** A theme may set `base = "KEY"`: a variant takes every piece, accent and finish it lacks from its base (`Themes:Field(t, name)`), then Standard. Variants have no `class`, so "auto" keeps picking the main theme. Form variants give only the hero pieces: both orbs and `bar.cap`.

### Fonts: three layers, no duplication

1. **Core (Fonts page):** header font, body font, outline and global scale. Lives in the profile and accepts LibSharedMedia fonts.
2. **Module:** with `fonts = true`, a module can override the font and outline (`db.fontOverride`, `db.font`, `db.fontOutline`). Every module uses the same "Font" tab, `page:FontSection(mod, onChange)`.
3. **Text:** each text's size and position is a setting of its own module.

Always apply fonts with `H.Fonts:Apply(fontString, "header"|"body", size, mod)`. For chat frames (their SetFont returns nothing) use `H.Fonts:Resolve(kind, size, mod)` -> path, size, flags, shadow.

### Paper

Use `H.Paper` for any parchment or glass background:
- `Apply(tex, kind, alpha)`
- `Crop(tex, kind, w, h)`
- `Shades(list, kind, alpha)`
- `InkOf(r, g, b)`
- `IsInk(kind)`

The kinds are `dark`, `light` and `glass`. Light paper recolours text as ink.

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
  - `page:Section`, `page:Text`, `page:Toggle`, `page:Slider`, `page:Dropdown`, `page:Input`, `page:Button`, `page:Color`, `page:FontSection`, `page:Preview(key)`
  - `UI.Confirm` and `UI.OpenMenu`. The menu frame has mouse disabled, and clicks outside it are caught with `GLOBAL_MOUSE_DOWN`.
  - `H.Panel:Rebuild(pageKey)` rebuilds a page. It is used after a picker changes, as in the Data bar block picker.
- One page per module.
  - When a module sets up several separate things (unit frames: target, ToT, focus, party, raid), each thing is a top-level tab with its own row of sub-tabs (`tabs = { { key, label, tabs = { {key,label,build}, ... } } }`). The panel remembers the sub-tab per tab.
  - Module-wide settings (Font) stay a plain top-level tab.
  - Action bars still use a bar picker inside its tabs; the Data bar uses a block picker.
- The sidebar list scrolls, because there are more modules than fit on screen.
- Usual pattern: a `field(name)` helper returns get/set pairs that write to `mod.db` and call `mod:Layout()`. A `colour(name)` helper does the same for `{r,g,b}` settings.

## Secure frames, taint and combat (rules)

- **Never touch protected frames in combat.** Wrap all layout of secure frames (`SetPoint`, `SetSize`, `SetParent`, `Show`/`Hide`, attributes) with `if InCombatLockdown() then H:RunOutOfCombat(fn, key) return end`. Use a unique key per job so repeated calls merge. `Movers:Apply` already defers itself.
- **Hiding Blizzard frames:** reparent them to a local hidden frame (`local hidden = CreateFrame("Frame"); hidden:Hide()`), out of combat. Don't call `Hide()` on them or hook their `Show`. Remember the original parent so the option can be undone.
  - This is how the game's action bar frames, `PlayerFrame`, `TargetFrame`, party and raid frames, cast bar, swing bars, XP/rep bars and bag buttons are hidden.
  - **Deliberate exceptions** (keep them):
    - `ObjectiveTrackerFrame`: `Hide()` + OnShow hook (protected).
    - `BuffFrame` / `DebuffFrame`: Hide + Show hook.
    - Edit Mode status-tracking containers: alpha 0 + SetAlpha hook + no mouse, because they call their parent.
    - Tooltip `NineSlice` and chat art: alpha hooks.
- **Action bars:**
  - They **reuse Blizzard's own action buttons**, reparented into our `SecureHandlerStateTemplate` containers. We never create our own action buttons; this is the approach that worked in TimelessUI.
  - Visibility uses a state driver: `"[petbattle][vehicleui][overridebar] hide; show"`. The pet bar has its own driver.
  - Art that rides on bar 1 (RailLight, swing, cast) undoes bar 1's scale with `SetScale(1/scale)`. **Never `SetIgnoreParentScale`**, which drops the UI scale.
- **Unit frames:**
  - Use `SecureUnitButtonTemplate`, with attributes `unit`, `*type1 = "target"` and `*type2 = "togglemenu"`.
  - Visibility comes from `RegisterUnitWatch` and the visuals are children of the button.
  - Register the button in `ClickCastFrames`.
  - Raid members are the game's `SecureGroupHeaderTemplate` headers; we only dress the buttons. Rolling a raid row up is a secure snippet, so it works in combat.
- **Secret values:**
  - Life and power go straight into `StatusBar:SetMinMaxValues` / `SetValue`; do no arithmetic on them in Lua.
  - Any text that needs maths (percentages) runs in `pcall` and falls back to the plain value.
  - For percentages, prefer `UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)` when it exists.
  - Never use a possibly secret value as a table key or in string matching without an `issecretvalue` guard.
  - Aura time goes through `C_UnitAuras.GetAuraDuration` into a Cooldown, or through a DurationTextBinding with a formatter.
- **Masks:** circular shapes use `Interface\CharacterFrame\TempPortraitAlphaMask` as a mask texture. Minimap frames use their theme's `MinimapMask`.
- Guard APIs that may be missing on this client, for example `UnitIsTapDenied`, `C_ClassColor` and `GetCreatureDifficultyColor`.
- No permanent `OnUpdate`. Run one only while something animates (the swing runs one only while a swing builds). Filter events by unit.

## Visual hierarchy (project rule)

| Level | What | Look |
|---|---|---|
| 1, hero | Action bar block (bars 1+2) and the orbs | Full ornament: double plate, rails, caps, theme rings, button frames |
| 1.5, target | Target frame (Plaque style), minimap (M1 frame), party cartouche | One fixed plaque (lion medallions, two jewels, a slot the bars fill). The target shows only as colour: metal finish on top of the theme finish (theme finish for elite/players, iron hostile, bronze friendly, silver rare, red boss, at the theme finish's brightness) and jewel colour (reaction or class). Shape never changes, so texts never move. Players get their class emblem over the lions (the party symbols, coloured or in the plaque's metal; option) |
| 2, frames | Quest log (and the target's Minimal style) | Dark glass panel, a rim in the theme accent, **one** theme motif (the gem). The quest tracker is parchment by Tiago's choice |
| 3, panels | Chat, damage meter, tooltips, data bar | Flat and dark, with a thin rim (chat/tooltips also offer paper) |

Art is designed **as a whole**, not as loose pieces. The first Paladin art (a pink plate, shield crests and a gold frame on every button) was rejected as random. Paladin uses the bronze finish.

## Implemented

| Step | Content | State |
|---|---|---|
| C1 | Skeleton, DB, profiles, commands, debug | approved |
| C1.5 | Settings panel, ESC menu button | approved |
| C2 | Module system, Modules page (test module since deleted) | approved |
| C4 | Movers, edit mode, Layout page | approved |
| M1 | Action bars 1–8 (layout, size, spacing, fading, mouseover) | approved |
| M1.1 | Stance bar (approved), pet bar | pet bar untested |
| M1.5 | Theme system (Standard + Paladin), the hero block | approved |
| M2 | Orbs: theme rings, docked to bar 1, animated liquid, text, clickable life orb, player frame hidden | approved |
| — | Fonts (core + per-module override), action bar texts | approved |
| — | Tabs in every settings page | approved |
| M4 | Quest tracker as a parchment scroll (Q4): theme rods, light/dark paper, roll up, own tracker | approved |
| M6 | Tooltips on paper (T2): dark/light/glass, metal or quality rim, class names, thin health strip, movable anchor | approved |
| M5 | Chat as a sideways scroll: standing rods, dark/light/glass paper or panel, roll up with glow, tabs and input inside the paper, abbreviations, colours/ink, input history | approved |
| M3 | Unit frames: **target**. Styles Plaque (fixed plaque with the slot cut out and the bars behind it, finish and jewels by target, level in a ring set into the left medallion; per-text size/offset settings) and Minimal (glass panel, theme gem, halo). Secure button, Blizzard target hidden | approved, cast bar in the power row (C4) approved; class emblems approved |
| — | Unit frames: target of target and focus (Small.lua) | approved |
| — | Unit frames: **party** (cartouche / banner / compact) | approved |
| — | Swing bar and player cast bar on the block's rails (RailLight) | approved |
| — | Auras: chosen auras in the power orb's gems, debuff types in the life orb's, time left; buff row by the minimap, serious debuffs over the life orb (row or column), test mode | approved |
| — | Click casting step 1 (bindings, highest rank, enemy/dead alternatives) | approved |
| — | Minimap M1 (theme frame, sockets, addon panel) | approved; panel gathering of LibDBIcon/cluster buttons and `/hui grab` delivered |
| — | Unit frames: **raid** (R3 banners with one rod per row of groups, default 4 per row; R2 tiles) | delivered, untested |
| — | Healer indicators (Indicators.lua) with the editor in the panel | delivered, untested |
| — | Settings sidebar scroll; previews moved into each module's settings | delivered |
| — | Data bar D1 + "maximum configuration" (v0.2.0) | approved (see README §10.10) |
| — | Class themes: Priest Holy Light + Shadow | approved |
| — | Theme by form + variants; Druid Ancient Grove + Bear/Cat/Moonkin | base approved; forms delivered, untested |
| — | Warrior Warlord + Defensive/Berserker stances (commit `804a2b7`) | delivered, untested |
| — | Audit fixes (2026-11-19): party events for every member, missing-buff indicators with secret auras, click-cast alternatives via `@mouseover`, swing-bar scan only when needed, cleanups | approved; party, indicators and raid click-cast need a group to confirm |
| — | Chat copy: `/hui copy` and a note button at the end of the tab row (prototypes K2 box, I1 button) | approved |

Settings tabs per page:

| Page | Tabs |
|---|---|
| General | Character / Panel / Testing |
| Profiles | Active profile / Manage |
| Theme | Theme / Forms / Finish |
| Fonts | Fonts / Scale |
| Layout | Edit mode / Positions |
| Modules | (single page) |
| Action bars | Block / Bars / Look / Visibility / Text / Swing / Cast / Font |
| Orbs | Place / Text / Font / Behaviour |
| Unit frames | Target (Size / Text / Look / Behaviour) / Target of target (Size / Text / Behaviour) / Focus (Size / Text / Behaviour) / Party (Size / Text / Look / Behaviour) / Raid (Size / Text / Look / Behaviour) / Indicators / Font |
| Minimap | Size / Text / Addons / Behaviour / Font |
| Quests | Look / Text / Behaviour / Font |
| Chat | Look / Size / Text / Channels / Input / Behaviour / Font |
| Tooltips | Look / Position / Text / Behaviour / Font |
| Auras | Power orb / Life orb / Buffs / Debuffs / Font |
| Click casting | Bindings / Behaviour |
| Data bar | Bar / Rail / Blocks / Text / Behaviour / Font |

## Untested (needs the situation in game)

The full list is in README §7 and in the project docs ("Por testar"). The most important items:

- **Vehicles:** our bars hide and the game's vehicle bar appears.
- **Pet bar:** on a Hunter or Warlock. It shows only with a pet, clicks and keybinds work, and it moves, resizes and persists.
- **Stance bar with several stances:** buttons per row (including vertical), growing when a new stance is learned, no overlap after switching stances in combat.
- **Pet battles:** our bars hide.
- **Orbs and target in long fights:** text keeps updating with secret values.
- **Target classification:** halo colours on elite, rare and boss, and "??" on bosses.
- **Hidden player frame:** no errors when opening Blizzard's Edit Mode.
- **Raid** in a real raid (rolling up in combat, the dead warning). **Indicators** with secret auras.
- **Form themes:** Shadowform, druid forms and warrior stances, in and out of combat. Gem sockets on every variant orb. The Warrior crest join `{160,128,120}` was set by eye.
- **Data bar:** micro menu in vehicles; hide in combat.
- **Minimap:** cooldown manager icon gathered (else `/hui grab`). The Druid minimap outdoors (it looked black indoors).
- **Party in a real group:** every member's life, mana and debuff gem update live (the 2026-11-19 event fix).
- **Indicators in combat:** missing-buff indicators must not all light up when aura names turn secret.
- **Raid click casting:** enemy/dead alternatives (`@mouseover`) hit the right member after roster changes in combat.
- **Blizzard Edit Mode:** open it with every module on and check for errors. Several Edit Mode frames are reparented (PlayerFrame, TargetFrame, FocusFrame, PartyFrame, MinimapCluster, PlayerCastingBarFrame).
- **Chat copy on the Combat Log tab:** which message the box shows (lines hidden by the game, or none).

## Next steps

1. **Wait for Tiago's in-game result on the Warrior** (delivered at `804a2b7`) and fix what he reports. Then the next class, in the order Tiago picks: Hunter, Mage, Rogue, Shaman and Warlock have no theme yet. Use the Canva recipe (below), with form or stance variants where the class has them. Tiago had about two weeks of Canva from 2026-11-18.
2. **Druid forms:** prototypes approved, the in-game test is pending.
3. **Pending tuning:** default margins of the block, waiting for Tiago's preferred values. (The target percentage report was the `hpPctShow` setting turned off; closed.)
4. **Open option (unanswered):** health orb liquid colour as class / red / custom.
5. **C3 class overrides**, when the first module needs them (`HeraldryDB.overrides` exists, unused).
6. **C7:** installer, presets ("Altar" plus a Healer variant), import/export (planned with `C_EncodingUtil`, existence on Forever not confirmed).
7. **Extras parked by Tiago:**
   - click casting steps 2–3: hovercast keys, bindings in the tooltip, out-of-combat set, copy between characters
   - bespoke per-class target medallions from Canva, worded in Tiago's own prompt
   - the quest log window

Reference notes for the delivered work (implementation details):

- **Target cast bar** (C4): the target's casts take the power row (Cast.lua; gold interruptible, grey not, red interrupted/failed). The game timer is used via SetTimerDuration when available, else GetTime maths in pcall.
- **Class emblems** in the medallions: `UF.EMBLEMS`, `PLAQUE.medallions`, setting `emblem` = colour/metal/off.
- **Target of target and focus** (Small.lua): smaller plaques, same finish/jewel rules, per-frame prefixed settings tot*/focus*, ToT docked right of the target (movable dock).
- **Minimap:**
  - The frame is cut to the art (`FRAME.art`, the file has empty margins) so it reaches the screen's edges.
  - The map is cut to the window by a mask.
  - Sockets: day/night (GameTimeFrame), the addon buttons panel toggle, mail.
  - Zone and clock sit on the plate, with per-text settings.
  - With a theme `minimap.frame`, `MM:Frame()` returns the theme piece, else `MM.FRAME`.
  - The addon panel also gathers MinimapCluster button children, all `LibDBIcon10_*` globals, and names in `H.global.minimapGrab` (`/hui grab`, via GetMouseFoci).
- **Quest tracker** (Q4, `Heraldry_Quests`):
  - Theme rods top and bottom (`scroll.rod`), light (ink) or dark paper. Click the top rod to roll up; rolled up shows a strip with the quest count.
  - Own tracker reading C_QuestLog with classic fallbacks.
  - The game's tracker is hidden with Hide() + an OnShow hook (Questie's approach on this client; the frame is protected). Steps aside when Questie's tracker is on.
  - Only the level carries the difficulty colour; ready/failed shown on the title.
- **Chat** (`Heraldry_Chat`):
  - Standing theme rods (`scroll.rodV`), dark/light/glass paper or a flat panel. Rolls up to the fixed side (the mover's anchor), glows on new messages, Enter opens to type.
  - ChatFrame1 is kept at its open size and placed in our frame (SetPoint/SetSize hooks). Blizzard art is killed by alpha hooks; ink comes from wrapping AddMessage.
  - Fonts via `H.Fonts:Resolve`.
  - Text.lua:
    - channel names full/short/number/hidden, with per-channel short names; "says" dropped
    - faded timestamps (the game's CVar); fading
    - input history with plain Up/Down (SetAltArrowKeyMode(false)), saved per character
    - light paper uses an ink palette per chat type (ink_<key> overrides); on other papers the colour pickers write the game's chat colours
    - player names without brackets; message body in plain ink
- **Tooltips** (T2):
  - The game's tooltips on paper with a metal rim, quality rim for items, class-coloured names, a thin health strip.
  - Anchor game/fixed/cursor, defaulting to our mover (`Tooltips.anchor`), growing from the corner nearest the screen edge. Hide units in combat.
  - Background/border only (NineSlice hidden by alpha hook); skinned via TooltipDataProcessor post-calls.
- **Party** (Party.lua):
  - Built on Small.lua (`UF.Small`). Container mover `UnitFrames.party` (SecureHandlerStateTemplate, hidden in raid unless set), grows down/up/right/left.
  - Geometry tables `UF.CARTOUCHE` / `UF.BANNER` in art pixels: `window`, `life`, `power`, `gem`, and `cols` + `stretch`. The art is cut into up to five column pieces; the stretching ones share the extra width; `at(x)` maps art columns into the frame.
  - Height = the bar block's height (301 art rows) in both styles. Class symbols are recessed, class-coloured art (no finish on them; desaturated when dead/offline).
- **Raid** (Raid.lua):
  - `R.rows[r] = { sheet (SecureHandlerBaseTemplate), rod (SecureHandlerClickTemplate whose _onclick toggles the sheet), strip, paper, edge, groups }`.
  - Group headers are parented to their row's sheet. `initialConfigFunction` calls `self:GetParent():CallMethod("Dress", name)`.
  - Settings use the prefix `raid` (`raidGroupsPerRow` = 4, `raidRodSize`, `raidShowEmpty`, `raidWarn`, `raidRange`, `raidDebuff`, `raidDispelOnly`, `raidPaper`, `raidStyle` banner/tiles).
- **Indicators** (Indicators.lua): `UF.Ind`, list per character `H.char.indicators` (class defaults DRUID/PRIEST/PALADIN/SHAMAN).
  - API: `Attach(host, anchor, kind)`, `Layout`, `Update(host, unit)`, `Fake(host, n)`, `LayoutAll`, `UpdateAll`, `Get/Set/Add/Remove/Move/ResetToClass/Spells/SpellIcon`.
  - Plain durations use a ticker with warn colour and pulse; secret durations use a DurationTextBinding.
  - Raid and party hook it with the `indRaid` / `indParty` toggles.
- **Swing bar** (Swing.lua, prototype S1):
  - The theme rail drawn dim, lit as the swing builds: main hand from the left, off hand from the right (in sync when they meet), ranged with a red end window. Data from `PLAYER_SWING(duration, type)`.
  - Plain child of bar 1 (hides with the bars, ignores its scale/alpha).
  - The game's swing bars are reparented away: any top-level frame named *swing*, plus StatusBars labelled "Main Hand"/"Off Hand"/"Ranged" (SwingTimerMainHandFrame etc.), rescanned 3 s after PLAYER_ENTERING_WORLD.
- **Cast on the top rail, swing on the bottom rail** by default (`castPlace = "top"`, `swingPlace = "bottom"`; each has "Where" = top rail / bottom rail / a bar of its own). Nothing is added to the block.
  - RailLight.lua (`AB.RailLight`) draws a lit rail right over one of the block's rails (tiles lined up; the bottom one flipped) or on a separate holder with a mover (`ActionBars.swing`, `ActionBars.cast`).
  - A theme without `bar.rail` (Standard) gets a plain bar in the accent.
  - Cast.lua: UNIT_SPELLCAST_* for the player, channels empty, interrupted/failed flash red, name and time under the block; the game's PlayerCastingBarFrame/CastingBarFrame are reparented away.
- **Auras** (`Heraldry_Auras`, prototype P2):
  - **Gems:** the power orb's gems hold chosen auras per character (`H.char.auraSockets`, names or spell IDs). The icon shows round in the gem, darkening via a Cooldown from `C_UnitAuras.GetAuraDuration`. The life orb's gems light in debuff-type colours (top magic, right curse, bottom poison, left disease), pulsing when removable.
  - **Defaults** apply only when `auraSockets` is nil: `AU.THEME_DEFAULTS[activeThemeKey]`, else `AU.CLASS_DEFAULTS[class]`.

    | Key | Default auras |
    |---|---|
    | PALADIN | seals |
    | PRIEST | Inner Fire, PW:Fortitude, Divine Spirit, Shadow Protection |
    | PRIEST_SHADOW | Shadowform, Vampiric Embrace, Inner Fire, PW:Fortitude |
    | DRUID | Mark of the Wild, Thorns, Omen of Clarity, Rejuvenation |
    | WARRIOR | Battle Shout, Bloodrage, Sweeping Strikes, Enrage |
    | WARRIOR_DEFENSIVE | Battle Shout, Shield Block, Last Stand, Shield Wall |
    | WARRIOR_BERSERKER | Battle Shout, Berserker Rage, Recklessness, Death Wish |

  - **Rows.lua** uses the client's own aura containers:
    - `AddAuraGroup(key, filter, {maxFrameCount, initializeFrame, layout})`, `SetUnit`, flow layout setters.
    - Buttons are styled only in their creation window: `SetIcon`, `SetDurationCooldown`, `SetApplicationCount`, `SetDurationText(fs, {textFormatter})`, `SetCancelAuraButtons("RightButtonUp")`.
    - Buffs (`HELPFUL`) in a row docked left of the minimap (`Auras.buffs`). Serious debuffs (`HARMFUL|CROWD_CONTROL`, optionally `HARMFUL|!CROWD_CONTROL` too) big over the life orb (`Auras.debuffs`), growing right/left (row) or up/down (column, `SetFlowLayoutAxis`), with the time inside the icon.
    - Size = holder scale. The game's BuffFrame/DebuffFrame are hidden (Hide + Show hook, as EllesmereUI does).
    - Test mode with plain look-alike icons (containers only show real auras).
- **Click casting** (`Heraldry_ClickCast`, step 1):
  - Bindings per character (`H.char.clickcast`: mods + button 1-5 + action spell/macro/item/target/menu/focus/assist).
  - Spells by name, so the highest rank is cast (pin with "Name(Rank n)"). A spell may have an enemy and a dead alternative; then the click is a `/cast [@mouseover,dead,help] ..; [@mouseover,harm] ..; [@mouseover] ..` macro. `@mouseover` and not the frame's unit, because raid buttons change unit (also in combat).
  - Applied to every frame in `ClickCastFrames` (a metatable catches frames added later). Attributes we set are tracked per frame and cleared before re-applying; combat defers. Steps aside when Clique is loaded.
  - Capture box in the panel (click with the combination).
- **Data bar** (`Heraldry_DataBar`, prototype D1):
  - Blocks micro/xp/gold/bags/durability/perf/clock/zone/coords/friends/guild, each with `<key>Place` (left/center/right/off), `<key>Order` and its own options. A block picker sits in the Blocks tab.
  - Renderers `TEXT[key](db)`, `DB:RailProgress()`, `DB:Tick()` (every second for perf/clock/coords/zone), `DB:Blizzard()`.
  - Hide in combat is alpha-only, because the micro menu inside must not be hidden in combat.

## Class art pipeline (Canva)

- Since 2026-11-18 **Claude writes the prompts, generates the images in Canva and creates the Canva folders**. Tiago downloads the chosen images to `C:\Users\tiago\Downloads\Imagens Wow\<Class>\`.
- Recipe: project doc `claude/arte-classes-prompts.md` (summary in README §5.4). Rules:
  - Always English, with the fixed opening and closing, the theme material, and the class motif only on hero pieces (orbs, Cap, minimap).
  - Fit rules: round empty hole plus 4 sockets top/right/bottom/left; empty square in button frames; tileable rails and rods.
  - **"No glow, no halo, no light rays"**.
  - **The power orb is always an edit of the approved life orb** (`imageReferences`). Form and stance variants are edits of the base pieces.
  - Never name a real game character in prompts; describe the style instead. Example: "orcish warlord" for Tiago's "High Overlord Saurfang".
- Canva folders, all under the root folder "Heraldry" (`FAHbTQeoXNE`):

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

- Processing (Python with PIL, numpy and scipy; the scripts are **not in the repo**, see README §9.4 to rebuild them):
  1. Cut the black background. Use an automatic threshold from the corners, a morphological close and a hole fill, plus seeds for interior holes.
  2. Measure the pieces:
     - orb hole, reach and sockets; **always verify the sockets with an overlay**
     - button holes
     - rail band 8..120 as a 512×128 crossfaded tile
     - rod cap and mid (mid from the plain shaft only), plus the rotated V versions
     - minimap window, sockets, plate and art, plus a generated MinimapMask
     - plates resized from one 2:1 image
  3. Save TGA with RLE compression.
  4. Add a `Themes/<Class>.lua` with the measured numbers, and add the file to the core `.toc` after the other themes.
  5. Add `FORM_DEFAULTS` entries in `Core/Themes.lua` for forms and stances, and aura defaults in `Heraldry_Auras/Auras.lua`.

## Workflow

- **Repo:** `github.com/tiagomilhazes/Heraldry` (private), branch `main`. The working clone is `D:\Dev\Heraldry` on Tiago's PC, with a local `core.autocrlf=false` so files stay LF, byte-identical to the deployed ones. Edit and commit there.
- **Delivery loop:** change in the clone, commit (one per delivery, descriptive message), deploy, verify, report, wait for Tiago's test. **Push to `main` only after Tiago approves.**
  - On Windows PowerShell 5.1, pass multi-line commit messages through a file (`git commit -F file`): inline messages with quotes get split into pathspecs.
- **Game folder:** `D:\World of Warcraft\_forever_\Interface\AddOns\` is deploy-only. Mirror each changed addon folder:
  ```
  robocopy D:\Dev\Heraldry\<Addon> "D:\World of Warcraft\_forever_\Interface\AddOns\<Addon>" /MIR /XD .claude graphify-out /XF CLAUDE.md README.md
  ```
  `/MIR` also deletes files the repo no longer has (old deploys only copied, so 29 stale files had piled up). The excludes keep the non-addon files in the game's `Heraldry\` folder (`.claude\`, `graphify-out\`, the pointer `CLAUDE.md`). Robocopy exit codes below 8 are success.
  - Verify after every deploy: `cmp` each `git ls-files <Addon>` file against the game copy, and compare the file lists. Report "0 differences" before asking for a test.
  - Other bar addons (TimelessUI, EllesmereUI Action Bars) must be disabled while testing the bars. During tests only Heraldry (plus Zygor) is enabled.
- **Syntax check:** there is no Lua compiler on the PC. Until one is installed, check changed files at least for balanced blocks and brackets, and say the check was partial.
- **Debugging:**
  - `/hui debug` toggles debug output and `/hui status` shows the state.
  - `/hui edit` opens edit mode.
  - `/hui profile ...` manages profiles.
  - `/hui grab` puts the button under the mouse into the minimap's addon panel.
  - `/hui copy` (or the note button at the end of the chat tabs) shows the chat's last lines ready to copy: ask Tiago to paste chat output instead of sending screenshots.
  - BugGrabber + BugSack are recommended for Lua errors.
- **Reporting:** after a delivery, tell Tiago in PT-PT what changed, whether `/reload` is enough or "Reinício do jogo necessário", and what to test. Then update "Por testar".
- **Reference docs** in the claude.ai project (PT-PT):
  - `claude/decisoes-projecto.md`: decisions 1–41, client facts, the process, the older untested list.
  - `claude/decisoes-projecto-2.md`: decisions 42–50 and the newer "Por testar". Continue the numbering there (next is 51).
  - `claude/arte-classes-prompts.md`: the Canva prompt recipe and lessons.
  - `claude/arquitetura-core.md`: the v0 core proposal, **partly superseded** (README §10.2).

## Do not

- Don't create our own action buttons, add `.xml` files, bundle libraries or add locales.
- Don't reparent Edit Mode-managed frames. Don't use `SetIgnoreParentScale`. Don't do arithmetic on or index tables with possibly secret values.
- Don't store theme, finish or class-spell data in the profile. They are per character.
- Don't add a second place for any setting: fonts go only through the three layers, and module settings only in that module's page.
- Don't start the next step before Tiago approves the current one, and don't build a visual without prototypes.
- Known stale comments (README §10) are not instructions. Trust the code and the decisions.
