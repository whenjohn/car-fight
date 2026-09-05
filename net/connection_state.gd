extends RefCounted
## A retained peer object can be connecting or already closed. Identity and
## authority queries are only valid while connected; offline play also qualifies.

static func has_connected_peer(api: MultiplayerAPI) -> bool:
	return api != null and api.multiplayer_peer != null \
		and api.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
