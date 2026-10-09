# Handoff: The Ember Crystal engine

A Godot 4.7 (GDScript) engine for a traditional JRPG in the FF1–FF4 / Dragon Quest
mould, built as a platform for an external asset pipeline. Everything ships with
procedurally generated placeholder art and synthesized sound effects; drop real
assets into `assets/` (see `docs/ASSET_PIPELINE.md`) and they are picked up at
runtime with no editor import step.

## Running it

Requirements: Godot 4.7.x on the PATH as `godot` (Homebrew's `godot` cask works;
`godot_mono` is not needed — the project is pure GDScript).

```sh
tools/run.sh            # opens the Debug Lab (subsystem test menu)
tools/run.sh --title    # opens the title screen instead
tools/test.sh           # headless unit + content tests (exit code 0 on success)
```

The first run performs a one-off headless `--import` to build Godot's script
class cache. If you ever see "Could not find type ItemData", run
`godot --headless --path . --import` once (the test script does this for you).

Opening the project in the Godot editor also works: `godot --editor --path .`
or import the folder from the project manager. Press F5 to run.

## Controls

| Action           | Keys                         |
| ---------------- | ---------------------------- |
| Confirm          | Z, Enter, Space              |
| Cancel / Menu    | X, Esc, Backspace            |
| Move / cursor    | Arrows or WASD               |
| Run (hold)       | Shift                        |
| Page up / down   | Q / E                        |
| Back to Debug Lab| F1 (anywhere)                |
| Force encounter  | F2 (on a map with encounters)|

On a map, Cancel opens the field menu. Save is allowed from the menu on the
overworld, and from save points (cyan `+` tiles) anywhere.

## The Debug Lab

The main scene is the Debug Lab (`src/debug/DebugLab.gd`). Each entry sets up
state and launches one subsystem in isolation:

| Entry                               | What it exercises                                                 |
| ----------------------------------- | ----------------------------------------------------------------- |
| Play: New Game                      | Title → full demo loop (town, quest, pass, cave, boss, ending)     |
| Battle: Random / Pick / Boss / Low  | Round-based battle, targeting, magic, items, run, XP & level ups  |
| Field: Overworld / Town / Dungeon   | Tile movement, encounters by terrain, warps, chests, NPCs, gates  |
| Field: Debug Arena                  | One of every interactable, plus a flag-gated NPC                  |
| Menu: Field Menu                    | Items, Magic, Equip (with stat preview), Status, Order, Save, Quit |
| Shop: Buy / Sell, Inn               | Shop with per-member equip previews and quantities; inn flow      |
| Dialog: Script Runner               | Run any dialog script by id against the live flags                |
| Dialog: Plot Flags Inspector        | Toggle flags; shows which NPCs/branches each flag gates           |
| Save / Load                         | Three JSON slots in `user://saves/`                               |
| Data Browser                        | Every loaded table, raw JSON per entry                            |
| Level-Up Simulator                  | Stat curves 1–50 per class                                        |
| Run Self-Tests                      | The `tests/` suite, in-process                                    |

`user://` on macOS is `~/Library/Application Support/Godot/app_userdata/The Ember Crystal/`.

## Playing the demo quest

1. Talk to the Elder (middle house, north row of Emberfall). Accept.
2. Vex appears in the square (recruit), Juno is in the inn (recruit, party max 4).
3. The Hermit (east house, south row) now gives the Cave Key.
4. Leave town south, walk east along the road; the guard has moved off the pass.
5. Ember Cave is the `C` tile in the eastern dunes. B1: the golem ambush guards the
   southern corridor, the sealed door is top-right. B2: save point, then the boss.
6. Take the crystal, return to the Elder → ending.

## Where things live

```
project.godot            settings, autoload order, 640x360 canvas scaled to 1280x720
scenes/Boot.tscn         the only .tscn; everything else is built in code
src/autoload/            singletons: Controls, Placeholder, Database, GameState,
                         AudioManager, SaveSystem, SceneStack, EventRunner
src/core/                Formulas, StatusEffects, Battler/Actor/Enemy, Inventory
src/data/                typed loaders for each JSON table, TileDefs
src/field/               FieldScene (maps, steps, interaction), FieldEntity/Player/Npc
src/battle/              BattleLogic (rules, no UI), BattleScene (presentation), BattleAction
src/ui/                  UITheme, MenuList, DialogBox, PartyStatusPanel, FieldMenu,
                         ShopScene, SaveMenu, Title/GameOver/Ending
src/debug/               DebugLab and inspectors
data/                    all content as JSON (see docs/CONTENT_FORMAT.md)
data/maps/*.json         generated by tools/gen_maps.py from ASCII art
tests/                   headless test suite, scene smoke test, screenshot tour
docs/                    DECISIONS.md, CONTENT_FORMAT.md, ASSET_PIPELINE.md
```

## Testing

```sh
tools/test.sh                                              # unit + content integrity (50 tests)
godot --headless --path . --script res://tests/smoke_scenes.gd     # instantiate every scene
godot --path . --script res://tests/screenshot_tour.gd -- --out=/tmp/shots   # windowed, saves PNGs
```

The screenshot tour needs a window and keeps it on top while it runs (macOS stops
drawing occluded windows, which would freeze the captures).

## Adding content

- New item/skill/enemy/shop: append to the JSON file. `Database` validates
  cross-references on load and `tests/test_data.gd` fails on dangling ids.
- New map: add a block to `tools/gen_maps.py` (ASCII rows + entities) and run it,
  or write `data/maps/<id>.json` by hand in the same format.
- New dialog: add a key to any `data/dialogs/*.json`. Vocabulary is at the top of
  `src/autoload/EventRunner.gd`.
- New playable character: `data/characters.json` (+ a class in `data/classes.json`).
- Real art/audio: `docs/ASSET_PIPELINE.md`.

## Known limitations / next steps

- No vehicles, rows, ATB, or multi-party juggling (deliberately FF1/DQ scope).
- Enemy AI is weighted-random; no HP-threshold scripting (easy to add in
  `Enemy.choose_action`).
- Shops do not sell spells; spells are learned by class level only.
- Battle animations are flashes and number popups; sprite animation hooks are
  the obvious place for pipeline output.
- Maps are JSON tile grids rendered with a runtime-built TileSet. Replacing
  `assets/tiles/tileset.png` keeps the same tile order as `TileDefs.DEFS`.
