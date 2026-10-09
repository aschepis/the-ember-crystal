# The Ember Crystal

A short traditional JRPG (early Final Fantasy / Dragon Quest feel) built in
Godot 4.7 with GDScript. The game is a demo; the engine underneath it is the
point: a platform for an AI asset/content pipeline, so every system ships with
placeholder art and JSON content you can replace.

```sh
tools/run.sh          # Debug Lab: launch any subsystem in isolation
tools/run.sh --title  # play the demo from the title screen
tools/test.sh         # headless tests
```

Read `docs/HANDOFF.md` first. Then:

- `docs/DECISIONS.md` — what was decided and why
- `docs/CONTENT_FORMAT.md` — the JSON schemas for items, enemies, maps, dialogs…
- `docs/ASSET_PIPELINE.md` — where to drop real sprites, tiles and audio

## Systems

Overworld / towns / dungeons on tile grids · random encounters by terrain ·
round-based battles with magic, items, statuses, elements, bosses · XP, level ups,
class spell lists · equipment with stat previews · shops and inns · a dialog/event
interpreter with choices, flags and plot gates · three JSON save slots · a Debug
Lab menu to test each piece.
