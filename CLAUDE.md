# The Ember Crystal — notes for agents

Godot 4.7 GDScript JRPG engine. No C#. Content is JSON under `data/`, art is
generated placeholders unless a file exists under `assets/`.

- Run: `tools/run.sh` (Debug Lab) / `tools/run.sh --title`.
- Test: `tools/test.sh` (headless; refreshes the class cache first). Keep it green.
- Scene smoke test: `godot --headless --path . --script res://tests/smoke_scenes.gd`.
- Visual check: `godot --path . --script res://tests/screenshot_tour.gd -- --out=DIR`
  (opens a window; keep it unobscured).
- New `class_name` scripts need `godot --headless --path . --import` once before
  headless runs can see them (`tools/test.sh` does this).
- Full-screen UI scenes are `Control`s pushed through `SceneStack`; they must size
  themselves with `UITheme.fullscreen(self)`.
- Maps come from `tools/gen_maps.py`; edit the ASCII there and regenerate rather
  than editing `data/maps/*.json` by hand.
- Docs to keep current: `docs/HANDOFF.md`, `docs/DECISIONS.md`, `docs/CONTENT_FORMAT.md`.
