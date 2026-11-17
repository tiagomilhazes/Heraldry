# Heraldry

All-in-one immersive UI for **World of Warcraft: Forever** (Midnight client, `## Interface: 16001`).
A core addon plus optional modules (`Heraldry_<Module>`), each one a separate addon folder.

## Repository layout

Each top-level folder is one addon. Copy them into `Interface\AddOns\`.

| Folder | What it is |
|---|---|
| `Heraldry` | Core: database, profiles, events, commands, settings registry |
| `Heraldry_Options` | Settings panel, load on demand (opens with `/hui`) |
| `Heraldry_Test` | Test module for the module system (temporary) |
| `Heraldry_ActionBars` | Action bars 1 to 8, stance and pet bars, the block (bars 1+2) |
| `Heraldry_Orbs` | Life and power orbs docked to the block |
| `Heraldry_UnitFrames` | Target frame (focus, target of target, party later) |

## Status

| Step | Content | State |
|---|---|---|
| C1 | Skeleton, database, profiles, profiles per spec, slash commands, debug | done |
| C1.5 | Settings panel (General, Profiles), game menu button | done |
| C2 | Module system, Modules page, test module | done |
| C3 | Settings layers (profile / class) | later, with the first module that needs it |
| C4 | Movers and edit mode | done |
| C5 | Themes (Standard + Paladin) and the art geometry contract | - |
| C6 | Configuration panel | - |
| C7 | Installer, presets, import/export | after 2-3 modules |
| M1 | Action bars: layout, size, spacing, fading, movable | done (vehicle untested) |
| M1.1 | Stance bar and pet bar | done (pet, vehicle untested) |
| M1.5 | Theme system (Standard + Paladin), the block | done |
| M2 | Orbs | done |
| M3 | Unit frames: target | in test |

## Commands

`/hui` or `/heraldry` opens the settings. `/hui help` lists the commands.

## Rules

- English only, in game text and in code.
- Modules only use the core's public API.
- Nothing protected is touched in combat (`H:RunOutOfCombat`).
