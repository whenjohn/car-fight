extends RefCounted
## Collision ownership for the fixture-only client proxy. Replays must use the
## rollback-restored server body, never the render-time predicted proxy.


static func disabled_states(proxy_enabled: bool, in_rollback: bool,
		presented: bool = true) -> Dictionary:
	return {
		"source": proxy_enabled and not in_rollback,
		"proxy": not proxy_enabled or in_rollback or not presented,
	}
