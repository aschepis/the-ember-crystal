class_name BattleAction
extends RefCounted
## One queued command for the round: who does what to whom.

var actor: Battler
var kind: String = "attack"      # attack | skill | item | defend | run
var skill: SkillData
var item: ItemData
var targets: Array[Battler] = []
var target_mode: String = "one_enemy"
var initiative: int = 0

static func make(actor_: Battler, kind_: String) -> BattleAction:
	var a := BattleAction.new()
	a.actor = actor_
	a.kind = kind_
	return a

func label() -> String:
	match kind:
		"attack": return "attacks"
		"skill": return "casts " + skill.name
		"item": return "uses " + item.name
		"defend": return "defends"
		"run": return "tries to run"
	return kind
