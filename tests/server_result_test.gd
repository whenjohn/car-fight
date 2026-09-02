extends SceneTree

const SERVER_RESULT := preload("res://diagnostics/server_result.gd")


func _init() -> void:
	var line := SERVER_RESULT.format_line({
		"players": 2, "minpair": 1.2344, "contact": 1,
		"escapes": 2, "bumps": 3, "ballmax": 4.5,
		"maxy": 5.6, "landed": 1, "grounded": 0,
		"rebound": 6.7, "tilt": 7.8, "maxtilt": 8.9,
		"minx": -9.1, "cloaked": 1, "shields": 2,
		"boosting": 1, "tractorgrabs": 10, "tractorticks": 11,
		"shots": 12, "hits": 13, "ballhits": 14,
		"droneshots": 15, "dets": 16, "impacthits": 17,
		"shieldhits": 18, "impactmax": 19.25, "rcshots": 20,
		"rcdets": 21, "rchits": 22, "coursemaps": 0,
		"courseoff": 0, "gatetransitions": 0,
	})
	var expected := "RESULT players=2 minpair=1.234 contact=1 escapes=2 bumps=3" \
		+ " ballmax=4.500 maxy=5.600 landed=1 grounded=0 rebound=6.700" \
		+ " tilt=7.800 maxtilt=8.900 minx=-9.100 cloaked=1 shields=2" \
		+ " boosting=1 tractorgrabs=10 tractorticks=11 shots=12 hits=13" \
		+ " ballhits=14 droneshots=15 dets=16 impacthits=17 shieldhits=18" \
		+ " impactmax=19.250 rcshots=20 rcdets=21 rchits=22 coursemaps=0" \
		+ " courseoff=0 gatetransitions=0"
	if line != expected:
		push_error("SERVER_RESULT_TEST FAIL\nexpected: %s\nactual:   %s" % [expected, line])
		quit(1)
		return
	print("SERVER_RESULT_TEST PASS")
	quit()
