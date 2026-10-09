class_name TestRunner
extends RefCounted
## Minimal test harness: every tests/test_*.gd script's test_* methods run in order.
## Used by both the CLI (tests/run_tests.gd) and the Debug Lab.

var passed := 0
var failed := 0
var log: Array[String] = []
var _current := ""
var _current_failed := false

func check(cond: bool, msg: String = "") -> void:
	if not cond:
		_current_failed = true
		log.append("    FAIL %s: %s" % [_current, msg])

func eq(a, b, msg: String = "") -> void:
	if a != b:
		_current_failed = true
		log.append("    FAIL %s: %s (got %s, expected %s)" % [_current, msg, str(a), str(b)])

func run_all() -> bool:
	var dir := DirAccess.open("res://tests")
	var files: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
		f = dir.get_next()
	files.sort()
	for file in files:
		var script = load("res://tests/" + file)
		var inst = script.new()
		inst.t = self
		log.append(file)
		for m in inst.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			_current = name
			_current_failed = false
			if inst.has_method("before_each"):
				inst.before_each()
			inst.call(name)
			if _current_failed:
				failed += 1
			else:
				passed += 1
				log.append("    ok   " + name)
	log.append("")
	log.append("%d passed, %d failed" % [passed, failed])
	return failed == 0
