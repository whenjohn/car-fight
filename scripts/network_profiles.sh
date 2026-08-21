#!/bin/zsh

# Shared adverse-network profiles. Values are one-way and apply independently
# in both directions. Keep the names transport-neutral: ENet and WebRTC/TURN
# acceptance use the same conditions even though their shaping mechanisms differ.
car_fight_network_profile() {
	local profile="$1"
	case "$profile" in
		clean)
			CAR_FIGHT_SHAPE_LATENCY_MS=0
			CAR_FIGHT_SHAPE_JITTER_MS=0
			CAR_FIGHT_SHAPE_LOSS_PCT=0
			;;
		latency60)
			CAR_FIGHT_SHAPE_LATENCY_MS=60
			CAR_FIGHT_SHAPE_JITTER_MS=0
			CAR_FIGHT_SHAPE_LOSS_PCT=0
			;;
		latency120)
			CAR_FIGHT_SHAPE_LATENCY_MS=120
			CAR_FIGHT_SHAPE_JITTER_MS=0
			CAR_FIGHT_SHAPE_LOSS_PCT=0
			;;
		jitter)
			CAR_FIGHT_SHAPE_LATENCY_MS=60
			CAR_FIGHT_SHAPE_JITTER_MS=30
			CAR_FIGHT_SHAPE_LOSS_PCT=0
			;;
		loss05)
			CAR_FIGHT_SHAPE_LATENCY_MS=60
			CAR_FIGHT_SHAPE_JITTER_MS=0
			CAR_FIGHT_SHAPE_LOSS_PCT=0.5
			;;
		loss1)
			CAR_FIGHT_SHAPE_LATENCY_MS=60
			CAR_FIGHT_SHAPE_JITTER_MS=0
			CAR_FIGHT_SHAPE_LOSS_PCT=1
			;;
		combined)
			CAR_FIGHT_SHAPE_LATENCY_MS=120
			CAR_FIGHT_SHAPE_JITTER_MS=40
			CAR_FIGHT_SHAPE_LOSS_PCT=1
			;;
		*)
			echo "unknown network profile '$profile'" >&2
			echo "profiles: clean latency60 latency120 jitter loss05 loss1 combined" >&2
			return 2
			;;
	esac
	export CAR_FIGHT_SHAPE_LATENCY_MS CAR_FIGHT_SHAPE_JITTER_MS CAR_FIGHT_SHAPE_LOSS_PCT
}

