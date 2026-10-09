# Design decisions

Decisions made without consultation, with the reasoning, so they can be revisited.

## Scope: FF1–FF4 / Dragon Quest, nothing fancier
- **Round-input, speed-ordered turns** (FF1/DQ), not ATB (FF4). Every party member
  picks a command, then all actions resolve by initiative (`Formulas.initiative`).
  Cancel steps back to the previous member, as in FF. Run attempts resolve first,
  then Defend, then everything else by AGI with noise.
- **Side-view** battle layout (enemies left/centre, party status bottom) because it
  reads better with placeholder art; switching to DQ front-view is a layout change
  in `BattleScene` only.
- **Four party members max**, five playable characters so recruiting/party-full
  branches exist. No reserve party.
- **Status ailments**: KO, Poison, Sleep, Silence, Paralyze, Blind, Stone. Poison,
  Silence, Blind, Stone and KO persist after battle; Sleep/Paralyze/buffs clear.
- **Equipment slots**: weapon, shield, head, body, accessory (FF3/FF4 style).
- **No rows, vehicles, or jobs change** (FF1 class change / FF3 jobs). Classes are fixed.

## Technology
- **GDScript, not C#.** The plain `godot` binary runs tests headless with no build step,
  and the pipeline integration is data (JSON/PNG), not code.
- **Content is JSON, not `.tres`.** The asset pipeline is TypeScript; emitting JSON is
  trivial and diffs are readable. Typed loader classes in `src/data/` give the
  engine static types and validate cross-references at load time.
- **Scenes are built in code; one `.tscn` (Boot).** Hand-writing `.tscn` is error
  prone and the layouts are simple. Editor users can still create scenes later.
- **Real art is loaded with `Image.load`/`ImageTexture` at runtime**, not through the
  Godot importer, so files dropped into `assets/` work immediately when running from
  source. (An exported build would need them imported; out of scope.)
- **Placeholder art is generated**: colored blocks with a 3x5 bitmap-font glyph, a
  facing notch for walkers, and eyes for enemies. Readable enough to test with.
- **SFX are synthesized** (square/sine/noise beeps) when no file exists, so every
  interaction has feedback. BGM is silent until files exist.
- **Base resolution 640x360, 32px tiles, 2x window.** Large enough for the default
  font to be legible at 14px; the pipeline can target 32px tiles / 32x32-per-frame
  character sheets.
- **Input via built-in `ui_*` actions plus extra keys registered in code**
  (`Controls.gd`) so Godot's focus navigation works and bindings are one list.

## Architecture
- **`SceneStack`** holds full-screen scenes; only the top processes. Battle pushes over
  the field, menus push over either. Control scenes live in a CanvasLayer so the
  field camera cannot move them.
- **Scenes are freed by `replace_all`, so nothing runs after it in the caller.** Cross-scene
  hand-offs go through state instead (`GameState.pending_event` runs the new-game intro
  when the field loads; battle defeat triggers game over before any fade).
- **`EventRunner`** is a tiny command interpreter (say/choice/if/goto/set_flag/
  give_item/battle/shop/inn/warp/join/...). It is the one place plot progression
  happens; NPC visibility and triggers are conditions on flags. Conditions are
  strings (`met_elder`, `!flag`, `count>=3`, `has_item:id`, `in_party:id`) or
  arrays (all must hold).
- **`BattleLogic` is UI-free** and returns event dictionaries; `BattleScene` animates
  them. The same effect interpreter (`apply_effect`) powers items and spells in the
  field menu, so healing/cure/revive behave identically everywhere.
- **Maps are JSON tile grids** with an entity list (npc, warp, stairs, chest, sign,
  save_point, trigger (rect), region (encounter zone override)). Counters are
  "look-through" tiles so shopkeepers stand behind them.
- **Random encounters** use a per-zone step budget (`steps_per_encounter` ± variance)
  rather than a per-step roll, so fights are evenly spaced. Roads and indoor tiles
  are safe. Terrain filters groups within a zone.
- **Chests and one-shot triggers** store their state as flags
  (`chest:<map>:<x>:<y>`), so they serialize for free.
- **Saves are JSON** in `user://saves/slot_N.json` with a `meta` block for the slot list.

## Numbers (all in `src/core/Formulas.gd`)
- XP to reach level L: `8(L-1)^2 + 2(L-1)`; cap 50.
- Physical damage: `(2*ATK - DEF) * U(0.9,1.1)`, floor `ATK/4`, crit x2, defend x0.5.
- Hit: `80 + hit + AGI/2 - evade`, clamped 10..99; blind -40.
- Magic: `(power + 1.5*INT - 0.5*MDEF) * element * U(0.9,1.1)`; items use flat power.
- Status landing: `chance - SPI/2`, clamped 5..95.
- Run: `50 + 2*(partyAGI - enemyAGI) + 10*attempts`, clamped 10..95; bosses never.
- Growth: per-level stat gain = floor(rate) + Bernoulli(frac(rate)); HP also gains VIT/8.
- Sell price 50%; stack cap 99; inn = base price x party size.

## Testing
- `tests/run_tests.gd` is a SceneTree script so autoloads are available headless.
- `tests/test_story.gd` plays the whole quest through `EventRunner` using the
  `DialogBox.auto_advance` and `EventRunner.scripted_battle_result` hooks.
- `tests/screenshot_tour.gd` drives the real UI with synthetic `InputEventAction`s
  and saves PNGs; it is how layout bugs were found. Not part of `tools/test.sh`
  because it needs a window.
