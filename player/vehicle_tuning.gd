extends RefCounted
## Server-validated per-model vehicle weight tuning.

const MASS_MIN := 1.0
const MASS_MAX := 6.0
const MASS_STEP := 0.1
const MASS_LIGHT := 1.6
const MASS_STANDARD := 2.2
const MASS_HEAVY := 3.2
const MASS_SUPER_HEAVY := 4.5


static func default_mass(vehicle_name: String) -> float:
	if vehicle_name in ["Bus", "Combat Vehicle", "Apocalypse Bus", "Survival Vehicle"]:
		return MASS_SUPER_HEAVY
	if vehicle_name in ["Pickup", "Humvee M242", "Post-Apocalyptic UAZ"] \
			or vehicle_name.begins_with("LP Truck") \
			or vehicle_name.begins_with("LP Tractor"):
		return MASS_HEAVY
	if vehicle_name == "Sedan" or vehicle_name.begins_with("LP Car"):
		return MASS_LIGHT
	return MASS_STANDARD


static func sanitized_mass(value: Variant, fallback := MASS_STANDARD) -> float:
	if value is not float and value is not int:
		return float(fallback)
	var mass := float(value)
	if not is_finite(mass):
		return float(fallback)
	return snappedf(clampf(mass, MASS_MIN, MASS_MAX), MASS_STEP)


static func validated_mass(value: Variant) -> float:
	if value is not float and value is not int:
		return -1.0
	var requested := float(value)
	if not is_finite(requested) or requested < MASS_MIN or requested > MASS_MAX:
		return -1.0
	var snapped := snappedf(requested, MASS_STEP)
	return snapped if is_equal_approx(requested, snapped) else -1.0


static func weight_class(mass: float) -> String:
	if mass < 1.9:
		return "Light"
	if mass < 2.8:
		return "Standard"
	if mass < 4.0:
		return "Heavy"
	return "Super Heavy"
