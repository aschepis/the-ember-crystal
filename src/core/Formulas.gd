class_name Formulas
## Every tunable number in one place. Numbers are FF1-ish: simple, readable, generous.

const MAX_LEVEL := 50
const SELL_RATIO := 0.5
const MAX_ITEM_STACK := 99
const MAX_PARTY := 4
const RUN_BASE_CHANCE := 50
const CRIT_MULTIPLIER := 2.0
const DEFEND_MULTIPLIER := 0.5
const POISON_TICK_RATIO := 0.08  # fraction of max HP lost per turn / per 4 steps

## Total XP required to *reach* a level. Quadratic curve: lvl 2 = 10, lvl 10 ~ 630, lvl 30 ~ 7300.
static func xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	return int(floor(8.0 * pow(level - 1, 2.0) + 2 * (level - 1)))

static func level_for_xp(xp: int) -> int:
	var lvl := 1
	while lvl < MAX_LEVEL and xp >= xp_for_level(lvl + 1):
		lvl += 1
	return lvl

## Physical damage: attacker.attack vs defender.defense, with variance and a crit roll.
static func physical_damage(attack: int, defense: int, rng: RandomNumberGenerator, crit: bool = false, defending: bool = false) -> int:
	var base := float(attack * 2 - defense)
	base = maxf(base, float(attack) * 0.25)   # armor never fully negates a hit
	var dmg := base * rng.randf_range(0.9, 1.1)
	if crit:
		dmg *= CRIT_MULTIPLIER
	if defending:
		dmg *= DEFEND_MULTIPLIER
	return maxi(1, int(round(dmg)))

static func hit_chance(attacker_hit: int, attacker_agi: int, defender_evade: int, attacker_blind: bool) -> int:
	var chance := 80 + attacker_hit + attacker_agi / 2 - defender_evade
	if attacker_blind:
		chance -= 40
	return clampi(chance, 10, 99)

static func crit_chance(luck: int, weapon_crit: int = 0) -> int:
	return clampi(3 + luck / 4 + weapon_crit, 1, 50)

## Magic damage scales with power (from the skill) and the caster's INT, resisted by MDEF.
static func magic_damage(power: int, intelligence: int, mdef: int, multiplier: float, rng: RandomNumberGenerator) -> int:
	if multiplier == 0.0:
		return 0
	var base := float(power) + float(intelligence) * 1.5 - float(mdef) * 0.5
	base = maxf(base, float(power) * 0.25)
	return maxi(1, int(round(base * multiplier * rng.randf_range(0.9, 1.1))))

static func heal_amount(power: int, spirit: int, rng: RandomNumberGenerator) -> int:
	return maxi(1, int(round((float(power) + float(spirit) * 1.5) * rng.randf_range(0.9, 1.1))))

## Chance a status lands, after immunity checks. Resist stat is the target's SPI.
static func status_chance(base_chance: int, target_spirit: int) -> int:
	return clampi(base_chance - target_spirit / 2, 5, 95)

static func run_chance(party_agi_avg: float, enemy_agi_avg: float, attempts: int) -> int:
	var chance := RUN_BASE_CHANCE + int((party_agi_avg - enemy_agi_avg) * 2.0) + attempts * 10
	return clampi(chance, 10, 95)

## Turn order initiative: speed plus noise so equal-AGI combatants vary round to round.
static func initiative(agi: int, rng: RandomNumberGenerator) -> int:
	return agi * 2 + rng.randi_range(0, agi + 4)

static func element_multiplier(element: String, weak: Array, resist: Array, immune: Array) -> float:
	if element == "":
		return 1.0
	if element in immune:
		return 0.0
	if element in weak:
		return 2.0
	if element in resist:
		return 0.5
	return 1.0

static func inn_cost(base: int, party_size: int) -> int:
	return base * maxi(1, party_size)
