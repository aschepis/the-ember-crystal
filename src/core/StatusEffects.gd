class_name StatusEffects
## Status ailment vocabulary (early-FF scope). Battle-only statuses clear when combat ends.

const KO := "ko"
const POISON := "poison"
const SLEEP := "sleep"
const SILENCE := "silence"
const PARALYZE := "paralyze"
const BLIND := "blind"
const STONE := "stone"

const ALL := [KO, POISON, SLEEP, SILENCE, PARALYZE, BLIND, STONE]
## Persist outside battle (need an item/spell/inn to cure).
const PERSISTENT := [KO, POISON, SILENCE, BLIND, STONE]
## Lose your turn.
const INCAPACITATING := [KO, SLEEP, PARALYZE, STONE]

const NAMES := {
	KO: "KO", POISON: "Poison", SLEEP: "Sleep", SILENCE: "Silence",
	PARALYZE: "Paralyze", BLIND: "Blind", STONE: "Stone",
}

const SHORT := {
	KO: "KO", POISON: "PSN", SLEEP: "SLP", SILENCE: "SIL",
	PARALYZE: "PAR", BLIND: "BLD", STONE: "STN",
}

static func display_name(id: String) -> String:
	return NAMES.get(id, id.capitalize())
