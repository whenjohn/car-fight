extends CanvasLayer

signal retry_requested()
signal quit_requested()
var _message: Label
var _retry: Button

func _ready() -> void:
	layer = 100
	var background := ColorRect.new()
	background.color = Color("202426")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(center)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 20)
	center.add_child(stack)
	var title := Label.new()
	title.text = "CAR FIGHT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("90d8bd"))
	stack.add_child(title)
	_message = Label.new()
	_message.custom_minimum_size = Vector2(260, 56)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.text = "Joining game..."
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 20)
	stack.add_child(_message)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	_retry = Button.new()
	_retry.text = "Retry"
	_retry.custom_minimum_size = Vector2(88, 40)
	_retry.visible = false
	_retry.pressed.connect(func(): retry_requested.emit())
	actions.add_child(_retry)
	var cancel := Button.new()
	cancel.text = "Quit"
	cancel.custom_minimum_size = Vector2(88, 40)
	cancel.pressed.connect(func(): quit_requested.emit())
	actions.add_child(cancel)

func show_status(ready: bool, failure: String) -> void:
	visible = not ready
	_message.text = "Joining game..." if failure.is_empty() else failure
	_retry.visible = not failure.is_empty()
