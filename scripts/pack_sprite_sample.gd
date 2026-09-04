extends SceneTree
## Reproducible lossless packing of the unmodified CC0 sample frames.
const ANIMATIONS := {"idle": "IDLE", "walk": "WALK", "attack": "ATTACK", "death": "DYING"}
const DIRECTIONS := ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass the extracted archive directory after --")
		quit(1)
		return
	for resolution in [128, 512]:
		for animation in ANIMATIONS:
			for direction in DIRECTIONS:
				_pack(args[0], resolution, animation, direction)
	quit()

func _pack(source: String, resolution: int, animation: String, direction: String) -> void:
	var input := source.path_join(ANIMATIONS[animation]).path_join(direction)
	if resolution == 128:
		input = input.path_join("128")
	var files := DirAccess.get_files_at(input)
	files.sort()
	var output := "res://assets/sprites/ghoul/%d/%s/%s" % [resolution, animation, direction]
	DirAccess.make_dir_recursive_absolute(output)
	var frames: Array = []
	var page := Image.create(2048, 2048, false, Image.FORMAT_RGBA8)
	var page_index := 0
	var x := 2
	var y := 2
	var row_height := 0
	for file in files:
		if not file.ends_with(".png"):
			continue
		var source_image := Image.load_from_file(input.path_join(file))
		assert(source_image != null and source_image.get_width() == resolution)
		source_image.convert(Image.FORMAT_RGBA8)
		var used := source_image.get_used_rect()
		if used.size == Vector2i.ZERO:
			used = Rect2i(0, 0, 1, 1)
		if x + used.size.x + 2 > 2048:
			x = 2
			y += row_height + 4
			row_height = 0
		if y + used.size.y + 2 > 2048:
			assert(page.save_png(output.path_join("%02d.png" % page_index)) == OK)
			page_index += 1
			page.fill(Color.TRANSPARENT)
			x = 2
			y = 2
			row_height = 0
		page.blit_rect(source_image, used, Vector2i(x, y))
		frames.append([page_index, x, y, used.size.x, used.size.y, used.position.x, used.position.y])
		x += used.size.x + 4
		row_height = maxi(row_height, used.size.y)
	var bounds := page.get_used_rect().end + Vector2i(2, 2)
	var cropped := page.get_region(Rect2i(Vector2i.ZERO,
		Vector2i(mini(2048, nearest_po2(bounds.x)), mini(2048, nearest_po2(bounds.y)))))
	assert(cropped.save_png(output.path_join("%02d.png" % page_index)) == OK)
	var manifest := FileAccess.open(output.path_join("frames.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"resolution": resolution, "fps": 12,
		"frames": frames}, "\t") + "\n")
	print("SPRITE_PACK %d %s/%s frames=%d pages=%d" % [resolution, animation, direction, frames.size(), page_index + 1])
