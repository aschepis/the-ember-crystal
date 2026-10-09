class_name Enemy
extends Battler
## A runtime enemy in battle. Several enemies of the same kind get letter suffixes (Slime A, B).

var data: EnemyData
var suffix: String = ""

static func create(enemy_id: String, suffix_letter: String = "") -> Enemy:
	var e := Enemy.new()
	e.data = Database.enemy(enemy_id)
	assert(e.data != null, "Unknown enemy " + enemy_id)
	e.is_enemy = true
	e.suffix = suffix_letter
	e.display_name = e.data.name + (" " + suffix_letter if suffix_letter != "" else "")
	e.hp = e.max_hp()
	e.mp = e.max_mp()
	return e

func max_hp() -> int: return int(data.stats.get("max_hp", 10))
func max_mp() -> int: return int(data.stats.get("max_mp", 0))
func stat(key: String) -> int: return int(data.stats.get(key, 0)) + buff(key)
func attack() -> int: return int(data.stats.get("atk", stat("str") / 2)) + buff("atk")
func defense() -> int: return int(data.stats.get("def", stat("vit") / 4)) + buff("def")
func magic_defense() -> int: return int(data.stats.get("mdef", stat("spi") / 4)) + buff("mdef")
func evade() -> int: return int(data.stats.get("evade", stat("agi") / 4)) + buff("evade")
func hit() -> int: return int(data.stats.get("hit", 0)) + buff("hit")
func element_multiplier(element: String) -> float:
	return Formulas.element_multiplier(element, data.weak, data.resist, data.immune)
func is_status_immune(status: String) -> bool:
	return status in data.status_immune or (data.boss and status in [StatusEffects.KO, StatusEffects.STONE, StatusEffects.SLEEP, StatusEffects.PARALYZE])

## Weighted random choice from the data's action list.
func choose_action(rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for a in data.actions:
		total += int(a.get("weight", 1))
	var roll := rng.randi_range(1, maxi(1, total))
	for a in data.actions:
		roll -= int(a.get("weight", 1))
		if roll <= 0:
			return a
	return {"kind": "attack"}
