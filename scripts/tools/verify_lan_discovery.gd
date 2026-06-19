extends SceneTree

const LanDiscoveryScript: GDScript = preload("res://scripts/game/lan_discovery.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host: Node = LanDiscoveryScript.new()
	var browser: Node = LanDiscoveryScript.new()
	get_root().add_child(host)
	get_root().add_child(browser)

	var payload: Dictionary = {
		"name": "LAN VERIFY",
		"port": 24500,
		"map": "Test Arena",
		"mode": "kills",
		"limit": 10,
		"players": 1,
		"max_players": 2,
	}
	_expect(host.start_hosting(payload), "host opens its announcement socket")
	_expect(browser.start_browsing(), "browser binds the discovery port")
	var listen_udp: PacketPeerUDP = browser.get("_listen_udp") as PacketPeerUDP
	_expect(listen_udp != null and listen_udp.is_bound(), "browser remains bound when a loopback session exists")

	payload["players"] = 2
	_expect(host.update_host_payload(payload), "host updates an active announcement")
	_expect(int(host.get("_host_payload").get("players", 0)) == 2, "updated player count is stored")

	host.stop_all()
	browser.stop_all()
	host.queue_free()
	browser.queue_free()
	if _failed:
		quit(1)
		return
	print("VERIFY LAN discovery OK")
	quit()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("LAN discovery verification failed: %s" % message)
