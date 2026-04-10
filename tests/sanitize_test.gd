extends SceneTree

func _init():
	var global_script = load("res://scripts/global.gd").new()

	var test_cases = [
		{"input": "normal_id_123", "expected": "normal_id_123"},
		{"input": "ID-with-hyphens_and_underscores", "expected": "ID-with-hyphens_and_underscores"},
		{"input": "../traversal", "expected": "traversal"},
		{"input": "..\\windows_traversal", "expected": "windows_traversal"},
		{"input": "/absolute/path", "expected": "absolutepath"},
		{"input": "id; rm -rf /", "expected": "idrmrf"},
		{"input": "account$id", "expected": "accountid"},
		{"input": "id with spaces", "expected": "idwithspaces"},
		{"input": "!!!specialChars!!!", "expected": "specialChars"}
	]

	var all_passed = true
	for test in test_cases:
		var result = global_script.sanitize_filename(test["input"])
		if result == test["expected"]:
			print("PASS: '%s' -> '%s'" % [test["input"], result])
		else:
			print("FAIL: '%s' -> expected '%s', got '%s'" % [test["input"], test["expected"], result])
			all_passed = false

	if all_passed:
		print("\nAll sanitization tests passed!")
		quit(0)
	else:
		print("\nSome sanitization tests failed.")
		quit(1)
