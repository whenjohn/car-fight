#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"

CAR_FIGHT_IMPORT_QUIET=1 "$project_root/scripts/godot_import_check.sh"
"$godot_bin" --headless --path "$project_root" --script res://tests/follow_controller_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/ramming_lab_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/sprite_test_lab_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/sprite_combat_test.gd -- --offline --no-drone
"$godot_bin" --headless --path "$project_root" --script res://tests/scatter_props_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/oil_slick_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/tractor_controller_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/impact_controller_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/correction_classifier_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/authority_probe_delivery_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/asset_smoke_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/boost_afterimage_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/vehicle_animation_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/vehicle_size_respawn_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/vehicle_tuning_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/tire_skid_trails_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/auto_targeting_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/coverage_config_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/area_weapon_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/homing_missile_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/home_world_lighting_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/sense_of_speed_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/always_forward_camera_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/always_forward_camera_ui_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/tree_visual_library_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/city_audition_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/crash_telemetry_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/server_result_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/input_codec_test.gd -- --offline
"$godot_bin" --headless --path "$project_root" --script res://tests/connection_lifecycle_test.gd -- --offline --presentation-test
"$godot_bin" --headless --path "$project_root" --script res://tests/controller_input_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/client_cruise_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/motion_trace_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/local_presentation_test.gd
"$godot_bin" --headless --path "$project_root" --script res://net/state_codec_selftest.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/state_bundle_coalescing_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/remote_position_transport_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/adaptive_presentation_delay_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/window_safety_policy_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/city_ball_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/dots_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/offscreen_indicators_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/troop_delivery_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/web_soak_input_test.gd
"$project_root/scripts/webrtc_turn_harness_lifecycle_test.sh"
"$project_root/scripts/offline_test.sh"
"$project_root/scripts/sprite_network_test.sh"
"$project_root/scripts/network_test.sh"
"$project_root/scripts/network_test_harness_test.sh"
"$project_root/scripts/mixed_transport_test.sh"
"$project_root/scripts/join_transient_test.sh"
"$project_root/scripts/reconnect_test.sh"
"$project_root/scripts/vehicle_size_respawn_test.sh"
"$project_root/scripts/vehicle_mass_collision_test.sh"
"$project_root/scripts/ball_test.sh"
"$project_root/scripts/tractor_test.sh"
"$project_root/scripts/reverse_test.sh"
"$project_root/scripts/combat_test.sh"
"$project_root/scripts/rc_orb_test.sh"
"$project_root/scripts/shield_test.sh"
"$project_root/scripts/det_test.sh"
git -C "$project_root" diff --check
echo "ALL_TESTS PASS"
