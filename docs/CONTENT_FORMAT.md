# Content format (data/*.json)

All content is JSON loaded by `src/autoload/Database.gd` into the typed classes in
`src/data/`. Unknown keys are ignored; missing keys take the defaults shown. Ids are
free-form strings and must be unique within their table. `Database` logs every
dangling reference as a warning and `tests/test_data.gd` fails on them.

## config.json
```json
{
  "game_title": "The Ember Crystal",
  "new_game":   {"party": ["ash","mira","dorn"], "gold": 150,
                 "items": [{"id":"potion","count":3}], "map": "emberfall", "x": 11, "y": 15, "facing": "up"},
  "debug_party": {"party": [...], "gold": 5000, "items": [...], "flags": {}},
  "encounter_step_variance": 0.5,
  "poison_field_step_interval": 4
}
```

## classes.json  → `ClassData`
```json
{"id": "fighter", "name": "Fighter", "glyph": "F", "color": "d84a3a", "description": "...",
 "base_stats": {"str":12,"agi":6,"vit":12,"int":3,"spi":4,"luck":5,"max_hp":42,"max_mp":0},
 "growth":     {"str":1.6,"agi":0.6,"vit":1.3,"int":0.2,"spi":0.3,"luck":0.4,"max_hp":4.5,"max_mp":0},
 "spells": [{"level": 4, "skill": "dia"}],
 "weapon_types": ["sword"]}
```
`growth` is the average gain per level (fractional part = probability of +1).

## characters.json → `CharacterData`
```json
{"id": "ash", "name": "Ash", "class": "fighter", "start_level": 1, "glyph": "A", "color": "d84a3a",
 "start_equipment": {"weapon": "bronze_sword", "body": "leather_armor"}, "bio": "..."}
```

## items.json → `ItemData`
```json
{"id": "potion", "name": "Potion", "type": "consumable", "price": 20,
 "usable_field": true, "usable_battle": true, "target": "one_ally",
 "description": "Restores 30 HP.", "effect": {"kind": "heal", "power": 30, "flat": true}}

{"id": "iron_sword", "name": "Iron Sword", "type": "weapon", "price": 420,
 "stats": {"atk": 15}, "classes": ["fighter"], "element": "", "inflicts": ""}

{"id": "ribbon", "type": "accessory", "resist_status": ["poison","sleep",...], "resist_elements": ["fire"]}
```
- `type`: `consumable | weapon | shield | head | body | accessory | key`
- `target`: `one_ally | all_allies | one_enemy | all_enemies | self`
- `stats` keys: `atk def mdef evade hit str agi vit int spi luck max_hp max_mp`
- `classes`: empty/absent = anyone can equip. `sellable` defaults to true except key items.

## skills.json → `SkillData`
```json
{"id": "fire", "name": "Fire", "school": "black", "mp_cost": 4, "target": "one_enemy",
 "usable_field": false, "usable_battle": true, "description": "...",
 "effect": {"kind": "damage", "power": 26, "element": "fire"}}
```
`school`: `white | black | enemy` (enemy skills never appear in menus).

## Effect vocabulary (items and skills share it)
| kind         | fields                                   | notes                                   |
| ------------ | ---------------------------------------- | --------------------------------------- |
| `damage`     | `power`, `element?`, `status?`, `chance?`, `flat?` | magic formula unless `flat`     |
| `physical`   | `multiplier`, `status?`, `chance?`      | attacker's ATK vs DEF (enemy specials)  |
| `heal`       | `power`, `flat?`                         | SPI-scaled unless `flat`                |
| `restore_mp` | `power`                                  |                                         |
| `revive`     | `fraction`                               | targets KO'd allies only                |
| `cure`       | `statuses: ["poison"]` or `["all"]`      | `all` excludes KO                       |
| `status`     | `status`, `chance`                       | resisted by SPI and immunities          |
| `buff`       | `stat`, `amount`                         | battle-only additive bonus              |
| `escape`     |                                          | smoke bomb; fails vs bosses             |
| `full_heal`  |                                          | field only (tent)                       |

Elements used by content: `fire ice lightning earth holy poison`. Statuses:
`ko poison sleep silence paralyze blind stone`.

## enemies.json → `EnemyData`
```json
{"id": "slime", "name": "Slime", "level": 1, "color": "60c0ff", "size": 48, "xp": 4, "gold": 3,
 "stats": {"max_hp":14,"max_mp":0,"str":6,"agi":4,"vit":4,"int":2,"spi":3,"luck":2,"atk":5,"def":1,"mdef":1,"evade":0,"hit":0},
 "weak": ["fire"], "resist": [], "immune": [], "status_immune": [],
 "drops": [{"item": "potion", "chance": 0.2}],
 "actions": [{"kind": "attack", "weight": 3}, {"kind": "skill", "skill": "screech", "weight": 1}],
 "boss": false, "description": "..."}
```
Bosses are immune to KO-style statuses and cannot be run from.

## encounters.json → `EncounterData.Group` / `.Zone`
```json
{"groups": [{"id": "slimes", "enemies": [{"enemy": "slime", "count": 2}, "bat"], "can_run": true, "background": ""}],
 "zones":  [{"id": "overworld", "steps_per_encounter": 14, "background": "plains",
             "entries": [{"group": "slimes", "weight": 5, "terrain": ["plains","road"]}]}]}
```
`terrain` filters by the tile's terrain (`TileDefs`); absent = any terrain.

## shops.json → `ShopData`
```json
{"id": "emberfall_items", "name": "...", "kind": "item", "greeting": "...", "items": ["potion", ...]}
{"id": "emberfall_inn", "kind": "inn", "inn_price": 8}
```

## maps/*.json → `MapData`
```json
{"id": "emberfall", "name": "Emberfall", "kind": "town", "bgm": "town",
 "encounter_zone": "", "background": "", "on_enter": "",
 "legend": {"@": "lava"},
 "rows": ["########", "#..r..D#", "########"],
 "entities": [
   {"type": "npc", "id": "elder", "name": "Elder", "x": 5, "y": 2, "dialog": "elder",
    "glyph": "E", "color": "f0e0c0", "wander": false, "facing": "down", "condition": "!done"},
   {"type": "warp",  "x": 5, "y": 9, "map": "overworld", "tx": 9, "ty": 7, "facing": "down"},
   {"type": "stairs","x": 25,"y": 1, "map": "ember_cave_2", "tx": 2, "ty": 2, "condition": "cave_door_open"},
   {"type": "chest", "x": 7, "y": 1, "item": "hi_potion", "count": 1},
   {"type": "chest", "x": 5, "y": 1, "gold": 150},
   {"type": "sign",  "x": 3, "y": 5, "text": "..."},
   {"type": "save_point", "x": 3, "y": 14},
   {"type": "trigger", "x": 13, "y": 12, "w": 15, "h": 4, "dialog": "boss_wyrm", "condition": "!wyrm_defeated", "once": false},
   {"type": "region",  "x": 32, "y": 0, "w": 12, "h": 24, "encounter_zone": "overworld_east"}
 ]}
```
Default legend (see `TileDefs.DEFAULT_LEGEND`):
`. grass  f forest  M mountain  ~ water  s sand  r road  _ floor  # wall  D door
T town  C cave  = bridge  , cave_floor  % cave_wall  S stairs  c counter  R roof
! lava  * crystal  (space) void`. `kind` is `overworld | town | dungeon | interior`;
saving from the menu is only allowed on `overworld` maps.

## dialogs/*.json → command lists
Each file is `{ "<dialog_id>": [command, ...], ... }`. A command is a string (= say)
or one of:
```
{"say": "...", "speaker": "Elder"}     {"message": "..."}
{"choice": [{"text": "Yes", "goto": "l1", "set_flag": "optional"}], "prompt": "...", "speaker": "..."}
{"label": "l1"}  {"goto": "l1"}  {"if": <condition>, "then": "l1", "else": "l2"}  {"end": true}
{"set_flag": "name", "value": true}    {"add_flag": "name", "value": 1}
{"give_item": "id", "count": 1, "silent": false}   {"take_item": "id", "count": 1}
{"give_gold": 100, "silent": false}    {"take_gold": 10}
{"battle": "group_id", "win": "l1", "lose": "l2", "escape": "l3", "background": ""}
{"shop": "shop_id"}  {"inn": "shop_id" | price, "speaker": "Innkeeper"}
{"warp": "map_id", "x": 1, "y": 2, "facing": "down"}
{"join": "character_id", "silent": false}  {"leave": "character_id"}  {"heal_party": true}
{"learn": {"character": "id", "skill": "id"}}
{"sfx": "name"}  {"bgm": "name"}  {"wait": 1.0}  {"game_over": true}  {"ending": true}
```
Text supports `{leader}`, `{gold}` and `{flag:name}`. Losing a `battle` with no
`lose` label goes to Game Over automatically.

### Conditions
A string, or an array of strings that must all hold:
`met_elder`, `!met_elder`, `child_stories>=3` (also `> < <= == !=`),
`has_item:cave_key`, `in_party:vex`, `gold>=100`, `level>=5`, `party_size<4`,
`item:potion>=2`.
