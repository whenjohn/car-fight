extends RefCounted
## Shared physical dimensions for the authoritative vehicle body.

const COLLISION_RADIUS := 1.55
const CAPSULE_RADIUS := 1.05
const CAPSULE_HEIGHT := 3.40
const CAPSULE_CENTER_Y := CAPSULE_RADIUS - COLLISION_RADIUS
const DEFAULT_CAPSULE_ENABLED := true
const MASS := 2.2
const BOUNCE := 0.18
const CONTACT_FRICTION := 0.0
const ANGULAR_DAMP := 4.5
