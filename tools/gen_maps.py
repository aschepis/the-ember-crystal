#!/usr/bin/env python3
"""Generates data/maps/*.json from ASCII art. Run: python3 tools/gen_maps.py
Kept as a script so the layouts stay readable and widths are validated."""
import json, os, sys

OUT = os.path.join(os.path.dirname(__file__), "..", "data", "maps")

def rows(text):
    lines = [l for l in text.strip("\n").split("\n")]
    w = max(len(l) for l in lines)
    return [l.ljust(w) for l in lines]

def write(m):
    r = m["rows"]
    w = len(r[0])
    assert all(len(x) == w for x in r), m["id"]
    for e in m.get("entities", []):
        assert 0 <= e["x"] < w and 0 <= e["y"] < len(r), (m["id"], e)
    with open(os.path.join(OUT, m["id"] + ".json"), "w") as f:
        json.dump(m, f, indent=1)
    print("wrote", m["id"], w, "x", len(r))

# ---------------------------------------------------------------- overworld
overworld = rows("""
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~..........fff..MM.......ff.......~~~......~
~...ff.....fff..MM......fff......~~~.......~
~...fff.........MM.......ff.....~~~........~
~....ff.........MM..............~~.........~
~...............MM.............~~..ff......~
~........T......MM.............~~..fff.....~
~........r......MM..ffff.......~~...ff.....~
~........r......MM..ffff.......~~..........~
~........r......MM...ff........~~..........~
~........r......MM.............~~..ff......~
~........rrrrrrrrrr............==..fff.....~
~................MM............~~...ff.....~
~.....ff........MM.............~~..........~
~....ffff.......MM..........ff.~~..........~
~.....ff........MM.........fff.~~.....ss...~
~...............MM..........ff.~~....ssss..~
~...............MM.............~~...ssCss..~
~...ff..........MM.............~~....ssss..~
~..ffff.........MM.............~~.....ss...~
~...ff..........MM....ff.......~~..........~
~...............MM...fff.......~~..ff......~
~...............MM....ff.......~~.fff......~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
""")
write({
    "id": "overworld", "name": "Ember Valley", "kind": "overworld",
    "encounter_zone": "overworld", "bgm": "overworld", "background": "plains",
    "rows": overworld,
    "entities": [
        {"type": "warp", "x": 9, "y": 6, "map": "emberfall", "tx": 11, "ty": 16, "facing": "up"},
        {"type": "warp", "x": 38, "y": 17, "map": "ember_cave_1", "tx": 2, "ty": 17, "facing": "right"},
        {"type": "npc", "id": "pass_guard", "name": "Guard", "x": 17, "y": 11, "glyph": "G", "color": "4060c0",
         "dialog": "pass_guard", "condition": "!met_elder", "facing": "left"},
        {"type": "npc", "id": "pass_guard_open", "name": "Guard", "x": 19, "y": 12, "glyph": "G", "color": "4060c0",
         "dialog": "pass_guard_open", "condition": "met_elder", "facing": "down"},
        {"type": "sign", "x": 10, "y": 12, "text": "West: Emberfall.   East: the mountain pass."},
        {"type": "chest", "x": 22, "y": 8, "item": "potion", "count": 2},
        {"type": "chest", "x": 5, "y": 14, "gold": 60},
        {"type": "chest", "x": 23, "y": 21, "item": "leather_shield"},
        {"type": "region", "x": 32, "y": 0, "w": 12, "h": 24, "encounter_zone": "overworld_east"},
    ],
})

# ---------------------------------------------------------------- town
town = rows("""
########################
#......................#
#..RRRR....RRRR...RRRR.#
#..RRRR....RRRR...RRRR.#
#..#D##....#D##...#D##.#
#......................#
#..rrrrrrrrrrrrrrrrrrr.#
#..r.......r.........r.#
#..r..RRRR.r..RRRR...r.#
#..r..RRRR.r..RRRR...r.#
#..r..#D##.r..#D##...r.#
#..r.......r.........r.#
#..rrrrrrrrrrrrrrrrrrr.#
#..........r...........#
#.....~~...r....ff.....#
#.....~~...r...........#
#..........r...........#
########################
""")
town[17] = town[17][:11] + "r" + town[17][12:]
write({
    "id": "emberfall", "name": "Emberfall", "kind": "town", "bgm": "town",
    "rows": town,
    "entities": [
        {"type": "warp", "x": 11, "y": 17, "map": "overworld", "tx": 9, "ty": 7, "facing": "down"},
        {"type": "warp", "x": 4, "y": 4, "map": "emberfall_inn", "tx": 5, "ty": 8, "facing": "up"},
        {"type": "warp", "x": 12, "y": 4, "map": "emberfall_elder", "tx": 5, "ty": 8, "facing": "up"},
        {"type": "warp", "x": 19, "y": 4, "map": "emberfall_shop_items", "tx": 5, "ty": 8, "facing": "up"},
        {"type": "warp", "x": 7, "y": 10, "map": "emberfall_shop_gear", "tx": 5, "ty": 8, "facing": "up"},
        {"type": "warp", "x": 15, "y": 10, "map": "emberfall_house", "tx": 5, "ty": 8, "facing": "up"},
        {"type": "sign", "x": 3, "y": 5, "text": "The Warm Hearth Inn"},
        {"type": "sign", "x": 11, "y": 5, "text": "Elder's House"},
        {"type": "sign", "x": 18, "y": 5, "text": "Emberfall Sundries"},
        {"type": "sign", "x": 6, "y": 11, "text": "The Whetstone & Hardwear"},
        {"type": "npc", "id": "villager_1", "name": "Villager", "x": 5, "y": 7, "glyph": "V", "color": "c0a080",
         "dialog": "villager_1", "wander": True},
        {"type": "npc", "id": "villager_2", "name": "Child", "x": 16, "y": 14, "glyph": "C", "color": "e0c0a0",
         "dialog": "villager_2", "wander": True},
        {"type": "npc", "id": "villager_3", "name": "Old Woman", "x": 20, "y": 7, "glyph": "O", "color": "b0b0d0",
         "dialog": "villager_3"},
        {"type": "npc", "id": "vex_town", "name": "Vex", "x": 13, "y": 7, "glyph": "V", "color": "7a4ad8",
         "dialog": "vex_recruit", "condition": ["met_elder", "!in_party:vex", "!vex_declined_forever"]},
        {"type": "save_point", "x": 3, "y": 14},
    ],
})

# ---------------------------------------------------------------- interiors
interior = rows("""
###########
#_________#
#_________#
#_________#
#_________#
#_________#
#_________#
#_________#
#_________#
#####D#####
""")
def shop_interior(id_, name, entities, extra_rows=None):
    r = list(extra_rows or interior)
    write({"id": id_, "name": name, "kind": "interior", "bgm": "town", "rows": r,
           "entities": [{"type": "warp", "x": 5, "y": 9, "map": "emberfall", "tx": e_tx, "ty": e_ty, "facing": "down"}] + entities})
    return

inn_rows = rows("""
###########
#_________#
#_c_c_c___#
#_________#
#_________#
#_________#
#_________#
#_________#
#_________#
#####D#####
""")
e_tx, e_ty = 4, 5
shop_interior("emberfall_inn", "The Warm Hearth Inn", [
    {"type": "npc", "id": "innkeeper", "name": "Innkeeper", "x": 2, "y": 1, "glyph": "I", "color": "d0a060", "dialog": "innkeeper", "facing": "down"},
    {"type": "npc", "id": "juno", "name": "Juno", "x": 8, "y": 6, "glyph": "J", "color": "e0a040", "dialog": "juno_recruit", "condition": "!in_party:juno"},
    {"type": "npc", "id": "patron", "name": "Patron", "x": 3, "y": 6, "glyph": "P", "color": "a0a0c0", "dialog": "patron", "wander": True},
], inn_rows)

e_tx, e_ty = 12, 5
shop_interior("emberfall_elder", "Elder's House", [
    {"type": "npc", "id": "elder", "name": "Elder", "x": 5, "y": 2, "glyph": "E", "color": "f0e0c0", "dialog": "elder", "facing": "down"},
    {"type": "chest", "x": 9, "y": 1, "item": "ether"},
])

shop_rows = rows("""
###########
#_________#
#ccccccccc#
#_________#
#_________#
#_________#
#_________#
#_________#
#_________#
#####D#####
""")
e_tx, e_ty = 19, 5
shop_interior("emberfall_shop_items", "Emberfall Sundries", [
    {"type": "npc", "id": "item_keeper", "name": "Shopkeeper", "x": 5, "y": 1, "glyph": "S", "color": "60c060", "dialog": "shop_items", "facing": "down", "interact_through_counter": True},
], shop_rows)

e_tx, e_ty = 7, 11
shop_interior("emberfall_shop_gear", "The Whetstone & Hardwear", [
    {"type": "npc", "id": "weapon_keeper", "name": "Smith", "x": 3, "y": 1, "glyph": "W", "color": "c0c0c0", "dialog": "shop_weapons", "facing": "down", "interact_through_counter": True},
    {"type": "npc", "id": "armor_keeper", "name": "Armorer", "x": 7, "y": 1, "glyph": "A", "color": "c08040", "dialog": "shop_armor", "facing": "down", "interact_through_counter": True},
], shop_rows)

e_tx, e_ty = 15, 11
shop_interior("emberfall_house", "Quiet House", [
    {"type": "npc", "id": "hermit", "name": "Hermit", "x": 5, "y": 3, "glyph": "H", "color": "9090a0", "dialog": "hermit", "facing": "down"},
    {"type": "chest", "x": 1, "y": 1, "gold": 120},
    {"type": "chest", "x": 9, "y": 1, "item": "bomb_fragment", "count": 2},
])

# ---------------------------------------------------------------- cave floor 1
cave1 = rows("""
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%,,,,,%%%%%%%%%%%%,,,,,,%%%%%%%%%%%%
%%%%,,,,,,,%%%%%%%%%%,,,,,,,,%%%%%%%%%%%
%%%,,,%%%,,,%%%%%%%%%,,%%%,,,,%%%%%%%%%%
%%%,,%%%%%,,,%%%%%%%,,,%%%%,,,%%%%%%%%%%
%%%,,%%%%%%,,,%%%%%%,,%%%%%%,,,%%%%%%%%%
%%%,,,%%%%%%,,,%%%%,,,%%%%%%%,,,%%%%%%%%
%%%%,,,%%%%%%,,,,,,,,,%%%%%%%%,,,%%%%%%%
%%%%%,,,%%%%%%,,,,,,,%%%%%%%%%,,,,%%%%%%
%%%%%%,,,%%%%%%%,,,%%%%%%%%%%%%,,,,%%%%%
%%%%%%%,,,%%%%%%,,,%%%%%%%%%%%%%,,,,%%%%
%%%%%%%%,,,%%%%%,,,%%%%%%%%%%%%%%,,,,%%%
%%%%%%%%%,,,%%%%,,,%%%%%%%%%%%%%%%,,,,%%
%%%%%%%%%%,,,%%%,,,%%%%%%%%%%%%%%%%,,,,%
%%%%%%%%%%%,,,,,,,,,%%%%%%%%%%%%%%%%,,,%
%%%%%%%%%%%%,,,,,,,,,,%%%%%%%%%%%%%,,,,%
%%%%%%%%%%%%%,,,,,,,,,,,%%%%%%%%%%,,,,%%
%,,,,,,,,,,,,,,,,%%%%,,,,,,,,,,,,,,,,%%%
%,,,,,,,,,,,,,,,%%%%%%,,,,,,,,,,,,,,%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
""")
write({
    "id": "ember_cave_1", "name": "Ember Cave B1", "kind": "dungeon",
    "encounter_zone": "cave", "bgm": "dungeon", "background": "cave",
    "rows": cave1,
    "entities": [
        {"type": "warp", "x": 1, "y": 17, "map": "overworld", "tx": 37, "ty": 17, "facing": "left"},
        {"type": "warp", "x": 1, "y": 18, "map": "overworld", "tx": 37, "ty": 17, "facing": "left"},
        {"type": "trigger", "x": 25, "y": 1, "dialog": "cave_sealed_door", "condition": "!cave_door_open"},
        {"type": "stairs", "x": 25, "y": 1, "map": "ember_cave_2", "tx": 2, "ty": 2, "facing": "down", "condition": "cave_door_open"},
        {"type": "chest", "x": 7, "y": 1, "item": "hi_potion"},
        {"type": "chest", "x": 5, "y": 1, "gold": 150},
        {"type": "chest", "x": 38, "y": 14, "item": "ether"},
        {"type": "chest", "x": 20, "y": 7, "item": "phoenix_down"},
        {"type": "chest", "x": 12, "y": 15, "item": "gi"},
        {"type": "sign", "x": 3, "y": 17, "text": "Turn back. The deep is no place for the warm-blooded."},
        {"type": "save_point", "x": 17, "y": 15},
        {"type": "trigger", "x": 13, "y": 16, "w": 4, "h": 1, "dialog": "golem_ambush", "condition": "!golem_defeated"},
    ],
})

# ---------------------------------------------------------------- cave floor 2 (boss)
cave2 = rows("""
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%,,,,%%%%%%%%%%%%%%%%%%%%%%%%%
%,S,,,,,,%%%%%%!!!%%%%%%%%%%%%
%,,,,%%,,,%%%%!!!!!%%%%%%%%%%%
%%%%%%%%,,,%%%!!!!!%%%,,,,,,%%
%%%%%%%%%,,,%%%!!!%%%,,,,,,,,%
%%%%%%%%%%,,,%%%%%%%,,,,%%,,,%
%%%%%%%%%%%,,,,,,,,,,,,,%%,,,%
%%%%%%%%%%%%,,,,,,,,,,,%%%,,,%
%%%%%%%%%%%%%%%%,,,,%%%%%%,,,%
%%%%%%%%%%%%%%%%,,,,%%%%%,,,,%
%%%%%%%%%%%%%%%,,,,,,%%%%,,,%%
%%%%%%%%%%%%%%,,,,,,,,%%,,,,%%
%%%%%%%%%%%%%,,,,*,,,,,,,,,%%%
%%%%%%%%%%%%%,,,,,,,,,,,,,%%%%
%%%%%%%%%%%%%%,,,,,,,,%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
""")
write({
    "id": "ember_cave_2", "name": "Ember Cave B2", "kind": "dungeon",
    "encounter_zone": "cave_deep", "bgm": "dungeon", "background": "cave",
    "rows": cave2,
    "entities": [
        {"type": "stairs", "x": 2, "y": 2, "map": "ember_cave_1", "tx": 25, "ty": 2, "facing": "down"},
        {"type": "chest", "x": 27, "y": 4, "item": "silk_robe"},
        {"type": "chest", "x": 19, "y": 9, "item": "iron_sword"},
        {"type": "chest", "x": 1, "y": 3, "item": "remedy"},
        {"type": "save_point", "x": 17, "y": 10},
        {"type": "trigger", "x": 13, "y": 12, "w": 15, "h": 4, "dialog": "boss_wyrm", "condition": "!wyrm_defeated"},
        {"type": "trigger", "x": 17, "y": 13, "dialog": "crystal_pickup", "condition": ["wyrm_defeated", "!has_crystal"]},
    ],
})

# ---------------------------------------------------------------- debug arena (tiny map for field tests)
arena = rows("""
####################
#__________________#
#__________________#
#_____________~~___#
#_____________~~___#
#__________________#
#__________________#
#__________________#
#__________________#
#__________________#
#__________________#
####################
""")
arena[11] = arena[11][:10] + "D" + arena[11][11:]
write({
    "id": "debug_arena", "name": "Debug Arena", "kind": "interior", "bgm": "",
    "encounter_zone": "", "rows": arena,
    "entities": [
        {"type": "npc", "id": "dbg_talker", "name": "Tester", "x": 4, "y": 3, "glyph": "T", "color": "ffffff", "dialog": "debug_dialog", "facing": "down"},
        {"type": "npc", "id": "dbg_shop", "name": "Debug Shop", "x": 8, "y": 3, "glyph": "S", "color": "60c060", "dialog": "shop_debug", "facing": "down"},
        {"type": "npc", "id": "dbg_inn", "name": "Debug Inn", "x": 12, "y": 3, "glyph": "I", "color": "d0a060", "dialog": "innkeeper", "facing": "down"},
        {"type": "npc", "id": "dbg_fight", "name": "Fight Me", "x": 16, "y": 3, "glyph": "F", "color": "d84a3a", "dialog": "debug_fight", "facing": "down"},
        {"type": "npc", "id": "dbg_wander", "name": "Wanderer", "x": 10, "y": 8, "glyph": "W", "color": "c0a080", "dialog": "villager_2", "wander": True},
        {"type": "npc", "id": "dbg_locked", "name": "Unlockable", "x": 4, "y": 8, "glyph": "U", "color": "ffe060", "dialog": "debug_unlocked", "condition": "debug_unlock"},
        {"type": "chest", "x": 2, "y": 10, "item": "potion", "count": 3},
        {"type": "chest", "x": 17, "y": 10, "gold": 999},
        {"type": "sign", "x": 1, "y": 1, "text": "Debug Arena. Talk to everyone. Open the chests. Flip the flag."},
        {"type": "save_point", "x": 18, "y": 1},
        {"type": "warp", "x": 10, "y": 11, "map": "emberfall", "tx": 11, "ty": 15, "facing": "up"},
    ],
})
