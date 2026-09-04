extends AnimatedSprite3D
## Camera-relative appearance only. Health and collision live on the target.
const DIRECTIONS := ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
const SAMPLES := ["ghoul", "survivor", "thug"]
const SAMPLE_LABELS := ["Ghoul (original)", "HD survivor (128px)", "Outlined thug (64px)"]
const MODERN_ROOT := "res://assets/local/smallscale-modern/"
const MODERN_FOLDERS := {"survivor": "FREE Character HD Survivor W Bike", "thug": "FREE Character 16-bit Thug Outlined"}
const MODERN_ACTIONS := {"idle": "Idle", "walk": "Walk", "attack": "Attack1", "death": "Die"}
# Source rows run E, SE, S, SW, W, NW, N, NE (visually checked).
const MODERN_ROWS := [2, 3, 4, 5, 6, 7, 0, 1]
static var _clips := {}
var sample := "ghoul"
var heading := Vector3.FORWARD
var resolution := 128
var world_height := 1.8
var clip := "idle"
var manual_direction := -1
var playback_rate := 1.0
var frozen := false
var _key := ""

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	shaded = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no_depth_test = false
	# Source standing figure occupies about 184/512 canvas pixels. The ground
	# registration is at (256, 346), shared across clips and both resolutions.
	pixel_size = world_height / (float(resolution) * 184.0 / 512.0)
	offset = Vector2(0.0, float(resolution) * (346.0 / 512.0 - 0.5))
	if sample != "ghoul" and sample_available(sample):
		var size := native_size(sample)
		pixel_size = world_height / (float(size) * 44.0 / 128.0)
		offset = Vector2(0.0, float(size) * (88.0 / 128.0 - 0.5))
		if sample == "thug":
			texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS

static func native_size(character: String) -> int:
	return 64 if character == "thug" else 128

static func sample_available(character: String) -> bool:
	if character == "ghoul":
		return true
	if not MODERN_FOLDERS.has(character):
		return false
	for action in MODERN_ACTIONS.values():
		if not ResourceLoader.exists(MODERN_ROOT + MODERN_FOLDERS[character] + "/" + action + ".png"):
			return false
	return true

static func direction_index(world_heading: Vector3, toward_camera: Vector3) -> int:
	var facing := Vector2(world_heading.x, world_heading.z)
	var viewer := Vector2(toward_camera.x, toward_camera.z)
	if facing.is_zero_approx() or viewer.is_zero_approx():
		return 0
	return posmod(roundi(-facing.angle_to(viewer) / (PI / 4.0)), 8)

static func load_clip(size: int, action: String, direction: int, character: String = "ghoul") -> SpriteFrames:
	if character != "ghoul" and sample_available(character):
		return _load_modern_clip(character, action, direction)
	var key := "%d/%s/%s" % [size, action, DIRECTIONS[direction]]
	if _clips.has(key):
		var cached: Variant = (_clips[key] as WeakRef).get_ref()
		if cached != null:
			return cached as SpriteFrames
	var base := "res://assets/sprites/ghoul/" + key
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + "/frames.json"))
	if not data is Dictionary:
		return null
	var result := SpriteFrames.new()
	result.set_animation_speed("default", float(data["fps"]))
	result.set_animation_loop("default", action in ["idle", "walk"])
	for values in data["frames"]:
		var texture := AtlasTexture.new()
		texture.atlas = load(base.path_join("%02d.png" % int(values[0]))) as Texture2D
		texture.region = Rect2(values[1], values[2], values[3], values[4])
		texture.margin = Rect2(values[5], values[6], size - values[3], size - values[4])
		texture.filter_clip = true
		result.add_frame("default", texture)
	_clips[key] = weakref(result)
	return result

static func _load_modern_clip(character: String, action: String, direction: int) -> SpriteFrames:
	var key := "%s/%s/%d" % [character, action, direction]
	if _clips.has(key):
		var cached: Variant = (_clips[key] as WeakRef).get_ref()
		if cached != null:
			return cached as SpriteFrames
	var atlas := load(MODERN_ROOT + MODERN_FOLDERS[character] + "/" + MODERN_ACTIONS[action] + ".png") as Texture2D
	var size := native_size(character)
	if atlas == null or atlas.get_height() != size * 8 or atlas.get_width() % size != 0:
		return null
	var result := SpriteFrames.new()
	# Exports supply frame counts, not timing metadata. Adjustable 12 FPS baseline.
	result.set_animation_speed("default", 12.0)
	result.set_animation_loop("default", action in ["idle", "walk"])
	for column in atlas.get_width() / size:
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(column * size, MODERN_ROWS[direction] * size, size, size)
		texture.filter_clip = true
		result.add_frame("default", texture)
	_clips[key] = weakref(result)
	return result

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var toward := camera.global_basis.z if camera.projection == Camera3D.PROJECTION_ORTHOGONAL \
		else camera.global_position - global_position
	var direction := manual_direction if manual_direction >= 0 else direction_index(heading, toward)
	var next := "%d/%s/%d/%s" % [resolution, clip, direction, sample]
	if next != _key:
		var old_clip := _key.split("/")[1] if not _key.is_empty() else ""
		var old_frame := frame
		var old_progress := frame_progress
		var finished := sprite_frames != null and not is_playing() and not frozen
		sprite_frames = load_clip(resolution, clip, direction, sample)
		_key = next
		_ready()
		if sprite_frames != null:
			play("default")
			if old_clip == clip:
				set_frame_and_progress(mini(old_frame, sprite_frames.get_frame_count("default") - 1), old_progress)
				if finished and clip in ["attack", "death"]:
					set_frame_and_progress(sprite_frames.get_frame_count("default") - 1, 1.0)
					pause()
	speed_scale = 0.0 if frozen else playback_rate

func replay() -> void:
	if sprite_frames != null:
		set_frame_and_progress(0, 0.0)
		play("default")
