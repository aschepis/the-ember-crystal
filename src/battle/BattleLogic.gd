class_name BattleLogic
extends RefCounted
## Rules of a battle without any rendering. Produces event dictionaries the scene animates.
## Events: {type: message|damage|heal|miss|status|cure|ko|revive|buff|mp|escape|levelup|item, ...}

var party: Array[Actor] = []
var enemies: Array[Enemy] = []
var group: EncounterData.Group
var rng: RandomNumberGenerator
var round_number := 0
var run_attempts := 0
var escaped := false
var status_turns: Dictionary = {}   # Battler -> {status: turns_remaining}

func setup(group_id: String, party_: Array[Actor], rng_: RandomNumberGenerator) -> void:
	group = Database.group(group_id)
	assert(group != null, "Unknown encounter group " + group_id)
	party = party_
	rng = rng_
	enemies.clear()
	var ids := group.expand()
	var counts := {}
	for id in ids:
		counts[id] = int(counts.get(id, 0)) + 1
	var seen := {}
	for id in ids:
		var suffix := ""
		if counts[id] > 1:
			suffix = char(65 + int(seen.get(id, 0)))
		seen[id] = int(seen.get(id, 0)) + 1
		enemies.append(Enemy.create(id, suffix))
	for a in party:
		a.defending = false

## A logic instance with no enemies, for applying item/spell effects from the field menu.
static func for_field() -> BattleLogic:
	var l := BattleLogic.new()
	l.party = GameState.party
	l.rng = GameState.rng
	return l

func can_run() -> bool:
	return group != null and group.can_run

func alive_enemies() -> Array[Battler]:
	var out: Array[Battler] = []
	for e in enemies:
		if e.is_alive():
			out.append(e)
	return out

func alive_party() -> Array[Battler]:
	var out: Array[Battler] = []
	for a in party:
		if a.is_alive():
			out.append(a)
	return out

func opponents_of(b: Battler) -> Array[Battler]:
	return alive_party() if b.is_enemy else alive_enemies()

func allies_of(b: Battler) -> Array[Battler]:
	return alive_enemies() if b.is_enemy else alive_party()

func outcome() -> String:
	if escaped:
		return "escape"
	if alive_party().is_empty():
		return "defeat"
	if alive_enemies().is_empty():
		return "victory"
	return ""

## Picks targets for a skill/item/attack from the actor's point of view. `chosen` is the player's pick.
func resolve_targets(actor: Battler, mode: String, chosen: Battler = null) -> Array[Battler]:
	var out: Array[Battler] = []
	match mode:
		"one_enemy":
			if chosen and chosen.is_alive():
				out.append(chosen)
			else:
				var pool := opponents_of(actor)
				if not pool.is_empty():
					out.append(pool[rng.randi_range(0, pool.size() - 1)])
		"all_enemies":
			out = opponents_of(actor)
		"one_ally":
			if chosen:
				out.append(chosen)   # may be KO'd (revive) – callers validate
			else:
				var pool := allies_of(actor)
				if not pool.is_empty():
					out.append(pool[rng.randi_range(0, pool.size() - 1)])
		"all_allies":
			for b in (enemies if actor.is_enemy else party):
				out.append(b)
		"self":
			out.append(actor)
	return out

func enemy_actions() -> Array[BattleAction]:
	var out: Array[BattleAction] = []
	for e in enemies:
		if not e.can_act():
			continue
		var choice := e.choose_action(rng)
		var act := BattleAction.make(e, "attack")
		if choice.get("kind", "attack") == "skill":
			var sk := Database.skill(choice["skill"])
			if sk and (sk.mp_cost == 0 or e.mp >= sk.mp_cost):
				act.kind = "skill"
				act.skill = sk
				act.target_mode = sk.target
				if sk.target == "one_ally":
					# Enemies heal their most wounded friend.
					var best: Battler = e
					for o in alive_enemies():
						if float(o.hp) / o.max_hp() < float(best.hp) / best.max_hp():
							best = o
					act.targets = [best]
				else:
					act.targets = resolve_targets(e, sk.target)
		if act.kind == "attack":
			act.target_mode = "one_enemy"
			act.targets = resolve_targets(e, "one_enemy")
		out.append(act)
	return out

## Orders a round: run attempts first, defends next, then by initiative.
func order(actions: Array[BattleAction]) -> Array[BattleAction]:
	for a in actions:
		a.initiative = Formulas.initiative(a.actor.stat("agi"), rng)
		if a.kind == "run":
			a.initiative += 100000
		elif a.kind == "defend":
			a.initiative += 10000
	actions.sort_custom(func(x, y): return x.initiative > y.initiative)
	return actions

func execute(action: BattleAction) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var actor := action.actor
	if not actor.is_alive():
		return ev
	if not actor.can_act():
		if actor.has_status(StatusEffects.SLEEP):
			ev.append({"type": "message", "text": "%s is fast asleep." % actor.display_name})
		elif actor.has_status(StatusEffects.PARALYZE):
			ev.append({"type": "message", "text": "%s can't move!" % actor.display_name})
		return ev
	match action.kind:
		"defend":
			actor.defending = true
			ev.append({"type": "message", "text": "%s defends." % actor.display_name})
		"run":
			_execute_run(action, ev)
		"attack":
			_execute_attack(action, ev)
		"skill":
			_execute_skill(action, ev)
		"item":
			_execute_item(action, ev)
	return ev

func _execute_run(action: BattleAction, ev: Array[Dictionary]) -> void:
	if not can_run():
		ev.append({"type": "message", "text": "Can't escape!"})
		return
	run_attempts += 1
	var pa := 0.0
	for b in alive_party():
		pa += b.stat("agi")
	pa /= maxf(1.0, alive_party().size())
	var ea := 0.0
	for b in alive_enemies():
		ea += b.stat("agi")
	ea /= maxf(1.0, alive_enemies().size())
	var chance := Formulas.run_chance(pa, ea, run_attempts - 1)
	if rng.randi_range(1, 100) <= chance:
		escaped = true
		ev.append({"type": "escape", "success": true, "text": "%s leads the party away!" % action.actor.display_name})
	else:
		ev.append({"type": "escape", "success": false, "text": "Couldn't escape!"})

func _retarget(action: BattleAction) -> Array[Battler]:
	var live: Array[Battler] = []
	for t in action.targets:
		if t.is_alive():
			live.append(t)
	if live.is_empty() and action.target_mode in ["one_enemy", "one_ally"]:
		live = resolve_targets(action.actor, action.target_mode)
	return live

func _execute_attack(action: BattleAction, ev: Array[Dictionary]) -> void:
	var actor := action.actor
	var targets := _retarget(action)
	if targets.is_empty():
		return
	var target := targets[0]
	ev.append({"type": "message", "text": "%s attacks %s!" % [actor.display_name, target.display_name], "actor": actor})
	var chance := Formulas.hit_chance(actor.hit(), actor.stat("agi"), target.evade(), actor.has_status(StatusEffects.BLIND))
	if target.has_status(StatusEffects.SLEEP) or target.has_status(StatusEffects.PARALYZE):
		chance = 100
	if rng.randi_range(1, 100) > chance:
		ev.append({"type": "miss", "target": target, "text": "Miss!"})
		return
	var crit := rng.randi_range(1, 100) <= Formulas.crit_chance(actor.stat("luck"))
	var mult := target.element_multiplier(actor.weapon_element())
	var dmg := Formulas.physical_damage(actor.attack(), target.defense(), rng, crit, target.defending)
	dmg = int(round(dmg * mult))
	_deal_damage(target, dmg, ev, crit)
	var inflict := actor.weapon_inflicts()
	if inflict != "" and target.is_alive() and rng.randi_range(1, 100) <= 30:
		_try_status(target, inflict, 100, ev)

func _execute_skill(action: BattleAction, ev: Array[Dictionary]) -> void:
	var actor := action.actor
	var sk := action.skill
	if actor.has_status(StatusEffects.SILENCE) and sk.school != "enemy":
		ev.append({"type": "message", "text": "%s is silenced and cannot cast!" % actor.display_name})
		return
	if actor.mp < sk.mp_cost:
		ev.append({"type": "message", "text": "%s doesn't have enough MP!" % actor.display_name})
		return
	actor.mp -= sk.mp_cost
	ev.append({"type": "message", "text": "%s casts %s!" % [actor.display_name, sk.name], "actor": actor, "sfx": "magic"})
	var targets := _retarget(action)
	if sk.effect.get("kind") == "revive":
		targets = action.targets  # revive targets the dead on purpose
	for t in targets:
		apply_effect(actor, t, sk.effect, ev, false)

func _execute_item(action: BattleAction, ev: Array[Dictionary]) -> void:
	var actor := action.actor
	var it := action.item
	if not GameState.inventory.has(it.id):
		ev.append({"type": "message", "text": "No %s left!" % it.name})
		return
	GameState.inventory.remove(it.id)
	ev.append({"type": "message", "text": "%s uses %s!" % [actor.display_name, it.name], "actor": actor, "sfx": "item"})
	var targets := action.targets if it.effect.get("kind") == "revive" else _retarget(action)
	for t in targets:
		apply_effect(actor, t, it.effect, ev, true)

## Shared effect interpreter for skills and items (see data vocabulary in SkillData/ItemData).
func apply_effect(source: Battler, target: Battler, effect: Dictionary, ev: Array[Dictionary], flat: bool) -> void:
	var kind: String = effect.get("kind", "")
	flat = flat or effect.get("flat", false)
	match kind:
		"damage":
			if not target.is_alive():
				return
			var element: String = effect.get("element", "")
			var mult := target.element_multiplier(element)
			if mult == 0.0:
				ev.append({"type": "miss", "target": target, "text": "%s is immune!" % target.display_name})
				return
			var dmg: int
			if flat:
				dmg = int(round(int(effect.get("power", 0)) * mult * rng.randf_range(0.9, 1.1)))
			else:
				dmg = Formulas.magic_damage(int(effect.get("power", 0)), source.stat("int"), target.magic_defense(), mult, rng)
			var note := ""
			if mult >= 2.0:
				note = "Weak!"
			elif mult < 1.0:
				note = "Resisted."
			_deal_damage(target, dmg, ev, false, note)
			if effect.has("status") and target.is_alive():
				_try_status(target, effect["status"], int(effect.get("chance", 50)), ev)
		"physical":
			if not target.is_alive():
				return
			var dmg := Formulas.physical_damage(int(source.attack() * float(effect.get("multiplier", 1.0))), target.defense(), rng, false, target.defending)
			_deal_damage(target, dmg, ev)
			if effect.has("status") and target.is_alive():
				_try_status(target, effect["status"], int(effect.get("chance", 50)), ev)
		"heal":
			if not target.is_alive():
				ev.append({"type": "message", "text": "It has no effect on %s." % target.display_name})
				return
			var amount: int
			if flat:
				amount = int(effect.get("power", 0))
			else:
				amount = Formulas.heal_amount(int(effect.get("power", 0)), source.stat("spi"), rng)
			var healed := target.heal(amount)
			ev.append({"type": "heal", "target": target, "amount": healed, "text": "%s recovers %d HP." % [target.display_name, healed]})
		"restore_mp":
			var amount := target.restore_mp(int(effect.get("power", 0)))
			ev.append({"type": "mp", "target": target, "amount": amount, "text": "%s recovers %d MP." % [target.display_name, amount]})
		"revive":
			if target.is_alive():
				ev.append({"type": "message", "text": "%s is already standing." % target.display_name})
				return
			target.revive(float(effect.get("fraction", 0.25)))
			ev.append({"type": "revive", "target": target, "text": "%s rises again!" % target.display_name})
		"cure":
			var cured: Array[String] = []
			for s in effect.get("statuses", []):
				if s == "all":
					for st in StatusEffects.ALL:
						if st != StatusEffects.KO and target.remove_status(st):
							cured.append(st)
				elif target.remove_status(String(s)):
					cured.append(String(s))
			if cured.is_empty():
				ev.append({"type": "message", "text": "Nothing to cure."})
			else:
				var names: Array[String] = []
				for c in cured:
					names.append(StatusEffects.display_name(c))
				ev.append({"type": "cure", "target": target, "text": "%s is cured of %s." % [target.display_name, ", ".join(names)]})
		"status":
			if target.is_alive():
				_try_status(target, effect["status"], int(effect.get("chance", 50)), ev)
		"buff":
			var stat: String = effect.get("stat", "def")
			target.buffs[stat] = target.buff(stat) + int(effect.get("amount", 0))
			ev.append({"type": "buff", "target": target, "text": "%s's %s rises." % [target.display_name, stat.to_upper()]})
		"escape":
			if can_run():
				escaped = true
				ev.append({"type": "escape", "success": true, "text": "Smoke fills the air. The party slips away!"})
			else:
				ev.append({"type": "escape", "success": false, "text": "It has no effect here!"})
		"full_heal":
			ev.append({"type": "message", "text": "It can't be used in battle."})

func _deal_damage(target: Battler, dmg: int, ev: Array[Dictionary], crit: bool = false, note: String = "") -> void:
	var dealt := target.take_damage(dmg)
	var text := "%s takes %d damage." % [target.display_name, dealt]
	if crit:
		text = "Critical hit! " + text
	if note != "":
		text = note + " " + text
	ev.append({"type": "damage", "target": target, "amount": dealt, "crit": crit, "text": text})
	if not target.is_alive():
		ev.append({"type": "ko", "target": target, "text": "%s is defeated!" % target.display_name if target.is_enemy else "%s falls!" % target.display_name})

func _try_status(target: Battler, status: String, chance: int, ev: Array[Dictionary]) -> void:
	if target.is_status_immune(status) or target.has_status(status):
		if not target.has_status(status):
			ev.append({"type": "miss", "target": target, "text": "%s resists %s." % [target.display_name, StatusEffects.display_name(status)]})
		return
	if rng.randi_range(1, 100) > Formulas.status_chance(chance, target.stat("spi")):
		ev.append({"type": "miss", "target": target, "text": "%s shrugs it off." % target.display_name})
		return
	target.add_status(status)
	if not status_turns.has(target):
		status_turns[target] = {}
	status_turns[target][status] = 3 if status == StatusEffects.PARALYZE else 99
	ev.append({"type": "status", "target": target, "status": status, "text": "%s is %s!" % [target.display_name, _status_verb(status)]})

func _status_verb(status: String) -> String:
	match status:
		StatusEffects.POISON: return "poisoned"
		StatusEffects.SLEEP: return "put to sleep"
		StatusEffects.SILENCE: return "silenced"
		StatusEffects.PARALYZE: return "paralyzed"
		StatusEffects.BLIND: return "blinded"
		StatusEffects.STONE: return "turned to stone"
	return status

## Poison ticks, sleepers may wake, paralysis wears off.
func end_of_round() -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var everyone: Array[Battler] = []
	everyone.append_array(alive_party())
	everyone.append_array(alive_enemies())
	for b in everyone:
		b.defending = false
		if b.has_status(StatusEffects.POISON):
			var dmg := maxi(1, int(b.max_hp() * Formulas.POISON_TICK_RATIO))
			_deal_damage(b, dmg, ev, false, "Poison:")
		if b.has_status(StatusEffects.SLEEP) and rng.randf() < 0.35:
			b.remove_status(StatusEffects.SLEEP)
			ev.append({"type": "cure", "target": b, "text": "%s wakes up." % b.display_name})
		if b.has_status(StatusEffects.PARALYZE):
			var turns: int = status_turns.get(b, {}).get(StatusEffects.PARALYZE, 1) - 1
			if turns <= 0:
				b.remove_status(StatusEffects.PARALYZE)
				ev.append({"type": "cure", "target": b, "text": "%s can move again." % b.display_name})
			else:
				status_turns[b][StatusEffects.PARALYZE] = turns
	return ev

func rewards() -> Dictionary:
	var xp := 0
	var gold := 0
	var drops: Array[String] = []
	for e in enemies:
		xp += e.data.xp
		gold += e.data.gold
		for d in e.data.drops:
			if rng.randf() < float(d.get("chance", 0.0)):
				drops.append(d["item"])
	return {"xp": xp, "gold": gold, "drops": drops}

## Grants rewards to the party. XP is split among survivors (FF1 style). Returns events.
func apply_rewards(r: Dictionary) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var survivors := alive_party()
	var share := int(r["xp"] / maxi(1, survivors.size()))
	ev.append({"type": "message", "text": "Gained %d XP (%d each) and %d gold." % [r["xp"], share, r["gold"]], "sfx": "victory"})
	GameState.add_gold(r["gold"])
	for item_id in r["drops"]:
		GameState.inventory.add(item_id)
		ev.append({"type": "item", "text": "Found %s!" % Database.item(item_id).name, "sfx": "chest"})
	for b in survivors:
		var a := b as Actor
		var report := a.gain_xp(share, rng)
		if report["levels"] > 0:
			ev.append({"type": "levelup", "target": a, "text": "%s reached level %d!" % [a.display_name, a.level], "sfx": "levelup"})
			for sid in report["new_skills"]:
				ev.append({"type": "message", "text": "%s learned %s!" % [a.display_name, Database.skill(sid).name]})
	return ev

func cleanup() -> void:
	for a in party:
		a.clear_battle_statuses()
