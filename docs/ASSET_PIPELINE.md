# Asset pipeline contract

The engine looks for real assets at fixed paths and falls back to generated
placeholders when a file is missing. Files are loaded at runtime with
`Image.load` / `AudioStream*.load_from_file`, so no Godot import step is needed
while running from source. Drop files in, restart the game.

Lookup is in `src/autoload/Placeholder.gd` (`load_real`) and
`src/autoload/AudioManager.gd` (`_load_stream`).

## Sprites

| Path                                       | Size / layout                                  | Used for                          |
| ------------------------------------------ | ---------------------------------------------- | --------------------------------- |
| `assets/sprites/characters/<id>.png`       | 96x128: 3 columns (walk frames), 4 rows (down, left, right, up), 32x32 each | player (`characters.json` id) and NPCs (entity `id`) |
| `assets/sprites/enemies/<id>.png`          | any size; drawn bottom-anchored at the baseline | `enemies.json` id; `size` field only affects placeholders |
| `assets/portraits/<id>.png`                | 48x48 (scaled to 24x24 in menus)               | `characters.json` id              |
| `assets/tiles/tileset.png`                 | 32px tiles in ONE ROW, in `TileDefs.DEFS` order | all maps                          |
| `assets/backgrounds/battle_<zone>.png`     | 640x256                                        | `zone.background` / `group.background` / map `background` (plains, cave, boss, forest) |
| `assets/backgrounds/title.png`, `ending.png` | 640x360                                      | title / ending screens            |

Character sheet frame order (column): 0 = step A, 1 = idle, 2 = step B. The
engine shows frame 1 when standing and cycles 0-1-2-1 while walking.

Tile order (index = column in `tileset.png`), from `src/data/TileDefs.gd`:
```
0 grass 1 forest 2 mountain 3 water 4 sand 5 road 6 floor 7 wall 8 door 9 town
10 cave 11 bridge 12 cave_floor 13 cave_wall 14 stairs 15 counter 16 roof 17 lava
18 crystal 19 void
```
To add a tile type, append to `TileDefs.DEFS` (never reorder) and give it a legend
character in `DEFAULT_LEGEND` or a per-map `legend`.

## Audio

| Path                               | Format                 | Ids used by content                                   |
| ---------------------------------- | ---------------------- | ----------------------------------------------------- |
| `assets/audio/bgm/<id>.ogg|.wav`   | looped                 | `title town overworld dungeon battle boss victory ending` (map `bgm`, `bgm` command) |
| `assets/audio/sfx/<name>.ogg|.wav` | one-shot               | see `AudioManager.SFX_DEFS` keys: cursor confirm cancel error hit crit miss magic heal item encounter victory levelup chest buy door run ko step |

Missing SFX are synthesized; missing BGM is silent.

## Suggested pipeline outputs beyond art

Because content is JSON, the pipeline can also emit:
- `data/dialogs/<set>.json` — any number of files; all keys merge into one table.
- `data/maps/<id>.json` — see `docs/CONTENT_FORMAT.md`; `tools/gen_maps.py` shows the
  ASCII-art authoring path and validates widths.
- New rows in `items.json`, `enemies.json`, `encounters.json`, `shops.json`.

Run `tools/test.sh` after generating content: it fails on dangling ids, warps onto
walls, NPCs on unwalkable tiles, unknown dialog labels and zones with no group for a
terrain present on their maps.
