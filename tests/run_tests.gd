extends SceneTree
## CLI entry: godot --headless --path . --script res://tests/run_tests.gd

func _init() -> void:
	await process_frame
	var runner := TestRunner.new()
	var ok := runner.run_all()
	for line in runner.log:
		print(line)
	var db = root.get_node("Database")
	if not db.load_errors.is_empty():
		print("DATA ERRORS:")
		for e in db.load_errors:
			print("  " + e)
		ok = false
	quit(0 if ok else 1)
