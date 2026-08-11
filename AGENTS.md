# Car Fight project notes

This is a clean Godot 4.7 experiment. Keep it small and auditable.

- Run with `/Applications/Godot47.app/Contents/MacOS/Godot`.
- Server authority and ENet lifecycle live in `Main.gd`.
- Deterministic FOLLOW math lives in `player/follow_controller.gd`; presentation must not affect it.
- Player input authority belongs to its owning client; body/state authority stays with server peer 1.
- The Jeep and turret are presentation only. The equal-mass sphere is the gameplay collider.
- Do not add weapons, damage, resources, bots, maps, or g2's custom transport/bundle stack without a new explicit scope decision.
- Add a focused regression before changing movement or collision behavior.
- Run `./scripts/test.sh` before committing.
- Use Tailscale (`ssh macai2-ts`) for macai2. This server owns UDP 10080 and launchd label `com.whenjohn.car-fight-server`.

