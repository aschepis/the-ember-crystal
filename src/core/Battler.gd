class_name Battler
extends RefCounted
## Shared combat state for party members and enemies: HP/MP, statuses and derived stats.

var display_name: String = ""
var hp: int = 1
var mp: int = 0
var statuses: Array[String] = []
var defending: bool = false
var is_enemy: bool = false
## Temporary battle buffs: stat key -> additive bonus. Cleared when battle ends.
var buffs: Dictionary = {}

func max_hp() -> int: return 1
func max_mp() -> int: return 0
func stat(_key: String) -> int: return 0
func attack() -> int: return 0
func defense() -> int: return 0
func magic_defense() -> int: return 0
func evade() -> int: return 0
func hit() -> int: return 0
func weapon_element() -> String: return ""
func weapon_inflicts() -> String: return ""
func element_multiplier(_element: String) -> float: return 1.0
func is_status_immune(_status: String) -> bool: return false

func is_alive() -> bool:
	return hp > 0 and not has_status(StatusEffects.KO) and not has_status(StatusEffects.STONE)

func can_act() -> bool:
	if not is_alive():
		return false
	for s in StatusEffects.INCAPACITATING:
		if has_status(s):
			return false
	return true

func can_cast() -> bool:
	return can_act() and not has_status(StatusEffects.SILENCE)

func has_status(s: String) -> bool:
	return s in statuses

func add_status(s: String) -> bool:
	if has_status(s) or is_status_immune(s):
		return false
	statuses.append(s)
	if s == StatusEffects.KO:
		hp = 0
	return true

func remove_status(s: String) -> bool:
	if not has_status(s):
		return false
	statuses.erase(s)
	return true

func clear_battle_statuses() -> void:
	for s in StatusEffects.ALL:
		if not s in StatusEffects.PERSISTENT:
			statuses.erase(s)
	buffs.clear()
	defending = false

## Applies damage, returns actual amount. Waking sleepers on hit is classic FF behaviour.
func take_damage(amount: int) -> int:
	amount = clampi(amount, 0, hp)
	hp -= amount
	if amount > 0:
		remove_status(StatusEffects.SLEEP)
	if hp <= 0:
		hp = 0
		add_status(StatusEffects.KO)
	return amount

func heal(amount: int) -> int:
	if not is_alive():
		return 0
	var before := hp
	hp = mini(max_hp(), hp + amount)
	return hp - before

func restore_mp(amount: int) -> int:
	var before := mp
	mp = mini(max_mp(), mp + amount)
	return mp - before

func revive(fraction: float) -> void:
	remove_status(StatusEffects.KO)
	hp = maxi(1, int(round(max_hp() * fraction)))

func buff(key: String) -> int:
	return int(buffs.get(key, 0))
