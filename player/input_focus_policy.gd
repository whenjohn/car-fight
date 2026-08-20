extends RefCounted
## Pure focus policy shared by live input and its headless regression test.

static func live_input_allowed(window_focused: bool) -> bool:
	return window_focused
