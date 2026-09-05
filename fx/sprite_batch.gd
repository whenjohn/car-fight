extends Node3D
## Opt-in modern-art drawing. Native clocks remain individual; directional
## presentation is managed here. No authoritative state is written here.
const VISUAL := preload("res://fx/directional_sprite.gd")
const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float columns = 14.0;
uniform float frame_pixels = 128.0;
varying vec2 cell;
void vertex() {
    cell = INSTANCE_CUSTOM.xy;
    vec3 centre = MODEL_MATRIX[3].xyz;
    vec3 world = centre
        + INV_VIEW_MATRIX[0].xyz * VERTEX.x * length(MODEL_MATRIX[0].xyz)
        + INV_VIEW_MATRIX[1].xyz * (VERTEX.y + INSTANCE_CUSTOM.z) * length(MODEL_MATRIX[1].xyz);
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}
void fragment() {
    vec2 inset_uv = clamp(UV, vec2(0.5 / frame_pixels), vec2(1.0 - 0.5 / frame_pixels));
    vec4 texel = texture(atlas, (inset_uv + cell) / vec2(columns, 8.0));
    ALBEDO = texel.rgb * COLOR.rgb;
    ALPHA = texel.a * COLOR.a;
}
"""
var enabled := false
var lab
var batches := {}
var character := ""
var drawn := 0
var clocks := {}
var _managed: Array = []

func setup(owner_lab) -> void:
	lab = owner_lab
	process_priority = 100
	enabled = OS.get_environment("CAR_FIGHT_SPRITE_BATCHED") == "1"

func clear() -> void:
	for sprite in _managed:
		if is_instance_valid(sprite):
			sprite.release_batch()
	_managed.clear()
	clocks.clear()
	for node in batches.values():
		node.queue_free()
	batches.clear()
	character = ""
	drawn = 0

func _exit_tree() -> void:
	clear()

func _process(_delta: float) -> void:
	if lab == null:
		return
	var use_batch: bool = enabled and lab.enabled and lab._sample in ["survivor", "thug"]
	if not use_batch:
		if not batches.is_empty():
			clear()
		for target in lab._fixtures:
			if target.visual != null:
				target.visual.visible = true
		return
	if character != lab._sample:
		clear()
		character = lab._sample
	var counts := {}
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	drawn = 0
	for target in lab._fixtures:
		var sprite = target.visual
		if sprite == null:
			continue
		if sprite.sample != character:
			sprite.release_batch()
			sprite.visible = true
			continue
		var action: String = sprite.clip
		if not VISUAL.MODERN_ACTIONS.has(action):
			sprite.release_batch()
			continue
		var node := _batch(action)
		if not sprite.batch_managed and not sprite in _managed:
			_managed.append(sprite)
		sprite.update_batched(clocks[action])
		var index: int = counts.get(action, 0)
		node.multimesh.set_instance_transform(index, instance_transform(sprite))
		node.multimesh.set_instance_custom_data(index, instance_data(sprite, camera))
		node.multimesh.set_instance_color(index, sprite.modulate)
		counts[action] = index + 1
		sprite.visible = false
		drawn += 1
	for action in batches:
		batches[action].multimesh.visible_instance_count = counts.get(action, 0)

static func instance_transform(sprite) -> Transform3D:
	var extent: float = sprite.pixel_size * VISUAL.native_size(sprite.sample)
	return Transform3D(Basis.from_scale(Vector3.ONE * extent), sprite.global_position)

static func instance_data(sprite, camera: Camera3D) -> Color:
	var toward: Vector3 = camera.global_basis.z if camera.projection == Camera3D.PROJECTION_ORTHOGONAL \
		else camera.global_position - sprite.global_position
	var facing: int = sprite.manual_direction if sprite.manual_direction >= 0 \
		else VISUAL.direction_index(sprite.heading, toward)
	return Color(sprite.frame, VISUAL.MODERN_ROWS[facing], sprite.offset.y / VISUAL.native_size(sprite.sample), 0)

func _batch(action: String) -> MultiMeshInstance3D:
	if batches.has(action):
		return batches[action]
	var node := MultiMeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER_CODE.replace("filter_linear_mipmap", "filter_nearest_mipmap") if character == "thug" else SHADER_CODE
	material.shader = shader
	var texture := load(VISUAL.MODERN_ROOT + VISUAL.MODERN_FOLDERS[character] + "/" + VISUAL.MODERN_ACTIONS[action] + ".png") as Texture2D
	material.set_shader_parameter("atlas", texture)
	material.set_shader_parameter("columns", float(texture.get_width()) / VISUAL.native_size(character))
	material.set_shader_parameter("frame_pixels", float(VISUAL.native_size(character)))
	mesh.material = material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = 256
	instances.visible_instance_count = 0
	# The fixed city is small; prototype uses four whole-city action batches.
	# Include billboard extents. Per-area culling can follow if measured needed.
	instances.custom_aabb = AABB(Vector3(-110, -20, -110), Vector3(220, 60, 220))
	node.multimesh = instances
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	batches[action] = node
	# Only four canonical frame sets per character, retained for this batch's
	# lifetime. No weak-cache churn as individuals turn through eight facings.
	clocks[action] = VISUAL._load_modern_clip(character, action, 0)
	return node
