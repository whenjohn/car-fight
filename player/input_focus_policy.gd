extends RefCounted
## Pure focus policy shared by live input and its headless regression test.

static func live_input_allowed(game_window_focused: bool,
		tool_window_focused: bool = false) -> bool:
	return game_window_focused and not tool_window_focused
