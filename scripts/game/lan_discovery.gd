class_name LanDiscovery
extends Node

signal session_list_changed(sessions: Array)

const DISCOVERY_PORT: int = 24501
const PROTOCOL_ID: String = "boomer_arena_lan_v1"
const BROADCAST_INTERVAL: float = 1.0
const QUERY_INTERVAL: float = 1.5
const SESSION_TIMEOUT: float = 3.5
const MAX_PACKETS_PER_FRAME: int = 64
const MAX_DRAIN_PACKETS_PER_FRAME: int = 256
const LOOPBACK_POLL_INTERVAL: float = 0.5
const LOOPBACK_SESSION_PATH: String = "user://boomer_arena_lan_sessions.json"

var _listen_udp: PacketPeerUDP
var _send_udp: PacketPeerUDP
var _broadcast_timer: float = 0.0
var _query_timer: float = 0.0
var _loopback_poll_timer: float = 0.0
var _is_hosting: bool = false
var _is_browsing: bool = false
var _host_payload: Dictionary = {}
var _host_session_id: String = ""
var _sessions: Dictionary = {}


func _ready() -> void:
	_listen_udp = PacketPeerUDP.new()
	_send_udp = PacketPeerUDP.new()
	_send_udp.set_broadcast_enabled(true)
	set_process(false)


func _exit_tree() -> void:
	stop_all()


func start_hosting(payload: Dictionary) -> bool:
	set_process(true)
	_is_hosting = true
	_is_browsing = false
	_host_payload = payload.duplicate(true)
	_broadcast_timer = BROADCAST_INTERVAL
	_host_session_id = _get_loopback_session_id(_host_payload)
	_close_listen_socket()
	if not _ensure_listen_bound() or not _ensure_send_bound():
		push_warning("LAN discovery could not open send socket for hosting.")
		_is_hosting = false
		set_process(false)
		return false
	_send_broadcast()
	return true


func update_host_payload(payload: Dictionary) -> bool:
	if not _is_hosting:
		return start_hosting(payload)

	var previous_session_id: String = _host_session_id
	_host_payload = payload.duplicate(true)
	_host_session_id = _get_loopback_session_id(_host_payload)
	if previous_session_id != _host_session_id:
		_remove_loopback_session_by_id(previous_session_id)
	_send_broadcast()
	return true


func start_browsing() -> bool:
	set_process(true)
	if _is_browsing and _listen_udp != null and _listen_udp.is_bound():
		return true

	_is_browsing = true
	if _is_hosting:
		_remove_loopback_session()
	_is_hosting = false
	_host_payload.clear()
	_loopback_poll_timer = LOOPBACK_POLL_INTERVAL
	_query_timer = QUERY_INTERVAL
	_merge_loopback_sessions()

	if not _ensure_listen_bound() or not _ensure_send_bound():
		if _sessions.is_empty():
			push_warning("LAN discovery could not bind port %d for browsing." % DISCOVERY_PORT)
			_is_browsing = false
			set_process(false)
			return false
		# Another local game instance can own the discovery port. Its loopback
		# announcement is still enough to offer that session without manual setup.
		_close_listen_socket(false)
	if _sessions.is_empty():
		session_list_changed.emit([])
	_send_query()
	return true


func refresh_browse() -> void:
	if not _is_browsing:
		return
	_merge_loopback_sessions()
	_expire_sessions()
	_send_query()


func stop_all() -> void:
	if _is_hosting:
		_remove_loopback_session()
	_is_hosting = false
	_is_browsing = false
	set_process(false)
	_host_payload.clear()
	_host_session_id = ""
	_close_listen_socket()
	_close_send_socket()


func is_browsing() -> bool:
	return _is_browsing


func is_hosting() -> bool:
	return _is_hosting


func get_sessions() -> Array:
	var result: Array = []
	for session_id in _sessions.keys():
		var session: Dictionary = _sessions[session_id]
		if _is_session_expired(session):
			continue
		result.append(session)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return result


func _process(delta: float) -> void:
	_poll_packets()
	_expire_sessions()
	if _is_browsing:
		_query_timer += delta
		if _query_timer >= QUERY_INTERVAL:
			_query_timer = 0.0
			_send_query()
		_loopback_poll_timer += delta
		if _loopback_poll_timer >= LOOPBACK_POLL_INTERVAL:
			_loopback_poll_timer = 0.0
			_merge_loopback_sessions()

	if not _is_hosting:
		return

	_broadcast_timer += delta
	if _broadcast_timer < BROADCAST_INTERVAL:
		return
	_broadcast_timer = 0.0
	_send_broadcast()


func _ensure_listen_bound() -> bool:
	if _listen_udp == null:
		return false
	if _listen_udp.is_bound():
		return true
	return _listen_udp.bind(DISCOVERY_PORT, "*", true) == OK


func _ensure_send_bound() -> bool:
	if _send_udp == null:
		return false
	if _send_udp.is_bound():
		return true
	return _send_udp.bind(0, "*", true) == OK


func _close_listen_socket(clear_sessions: bool = true) -> void:
	if _listen_udp != null and _listen_udp.is_bound():
		_listen_udp.close()
	if clear_sessions:
		_sessions.clear()


func _close_send_socket() -> void:
	if _send_udp != null and _send_udp.is_bound():
		_send_udp.close()


func _send_broadcast() -> void:
	if _send_udp == null or _host_payload.is_empty():
		return
	if not _send_udp.is_bound() and not _ensure_send_bound():
		return

	var payload: Dictionary = _host_payload.duplicate(true)
	payload["protocol"] = PROTOCOL_ID
	payload["type"] = "announce"
	payload["timestamp"] = Time.get_unix_time_from_system()
	_publish_loopback_session(payload)
	_send_to_discovery_targets(payload)


func _send_query() -> void:
	if not _is_browsing:
		return
	_send_to_discovery_targets({
		"protocol": PROTOCOL_ID,
		"type": "query",
	})


func _send_to_discovery_targets(payload: Dictionary) -> void:
	if _send_udp == null:
		return
	if not _send_udp.is_bound() and not _ensure_send_bound():
		return
	var packet: PackedByteArray = JSON.stringify(payload).to_utf8_buffer()
	for target in _get_broadcast_targets():
		_send_udp.set_dest_address(target, DISCOVERY_PORT)
		_send_udp.put_packet(packet)


func _get_broadcast_targets() -> PackedStringArray:
	var targets: PackedStringArray = PackedStringArray(["255.255.255.255"])
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		var octets: PackedStringArray = address.split(".")
		if octets.size() != 4:
			continue
		var subnet_broadcast: String = "%s.%s.%s.255" % [octets[0], octets[1], octets[2]]
		if not targets.has(subnet_broadcast):
			targets.append(subnet_broadcast)
	return targets


func _poll_packets() -> void:
	if not (_is_browsing or _is_hosting) or _listen_udp == null or not _listen_udp.is_bound():
		return

	var available_count: int = _listen_udp.get_available_packet_count()
	var packets_to_handle: int = mini(available_count, MAX_PACKETS_PER_FRAME)
	for packet_index in range(packets_to_handle):
		var packet: PackedByteArray = _listen_udp.get_packet()
		var sender_ip: String = _listen_udp.get_packet_ip()
		_handle_packet(packet, sender_ip)

	var packets_to_drain: int = mini(available_count - packets_to_handle, MAX_DRAIN_PACKETS_PER_FRAME)
	for packet_index in range(packets_to_drain):
		_listen_udp.get_packet()


func _handle_packet(packet: PackedByteArray, sender_ip: String) -> void:
	var json := JSON.new()
	if json.parse(packet.get_string_from_utf8()) != OK:
		return
	if not (json.data is Dictionary):
		return

	var data: Dictionary = json.data
	if str(data.get("protocol", "")) == PROTOCOL_ID and str(data.get("type", "")) == "query":
		if _is_hosting:
			_send_announcement_to(sender_ip)
		return
	if not _is_browsing:
		return
	if _store_session(data, sender_ip):
		session_list_changed.emit(get_sessions())


func _send_announcement_to(address: String) -> void:
	if address.is_empty() or _host_payload.is_empty():
		return
	var payload: Dictionary = _host_payload.duplicate(true)
	payload["protocol"] = PROTOCOL_ID
	payload["type"] = "announce"
	payload["timestamp"] = Time.get_unix_time_from_system()
	_send_udp.set_dest_address(address, DISCOVERY_PORT)
	_send_udp.put_packet(JSON.stringify(payload).to_utf8_buffer())


func _store_session(data: Dictionary, sender_ip: String) -> bool:
	var game_port: int = int(data.get("port", 0))
	if game_port <= 0:
		return false

	var address: String = sender_ip
	if address.is_empty() or address == "0.0.0.0":
		address = "127.0.0.1"

	var session_id: String = "%s:%d" % [address, game_port]
	var session: Dictionary = {
		"id": session_id,
		"name": str(data.get("name", "Partida LAN")),
		"address": address,
		"port": game_port,
		"map": str(data.get("map", "TestArena")),
		"mode": str(data.get("mode", "kills")),
		"limit": int(data.get("limit", 10)),
		"players": int(data.get("players", 1)),
		"max_players": int(data.get("max_players", 2)),
		"last_seen": Time.get_ticks_msec() / 1000.0,
	}
	_sessions[session_id] = session
	return true


func _expire_sessions() -> void:
	if not _is_browsing:
		return

	var removed: bool = false
	for session_id in _sessions.keys():
		var session: Dictionary = _sessions[session_id]
		if _is_session_expired(session):
			_sessions.erase(session_id)
			removed = true
	if removed:
		session_list_changed.emit(get_sessions())


func _is_session_expired(session: Dictionary) -> bool:
	var last_seen: float = float(session.get("last_seen", 0.0))
	var now: float = Time.get_ticks_msec() / 1000.0
	return now - last_seen > SESSION_TIMEOUT


func _get_loopback_session_id(payload: Dictionary) -> String:
	var game_port: int = int(payload.get("port", 0))
	if game_port <= 0:
		return ""
	return "127.0.0.1:%d" % game_port


func _publish_loopback_session(payload: Dictionary) -> void:
	var session_id: String = _get_loopback_session_id(payload)
	if session_id.is_empty():
		return

	_host_session_id = session_id
	var sessions: Dictionary = _read_loopback_session_file()
	var entry: Dictionary = payload.duplicate(true)
	entry["address"] = "127.0.0.1"
	entry["last_seen_unix"] = Time.get_unix_time_from_system()
	sessions[session_id] = entry
	_write_loopback_session_file(sessions)


func _remove_loopback_session() -> void:
	_remove_loopback_session_by_id(_host_session_id)


func _remove_loopback_session_by_id(session_id: String) -> void:
	if session_id.is_empty():
		return
	var sessions: Dictionary = _read_loopback_session_file()
	if not sessions.has(session_id):
		return
	sessions.erase(session_id)
	_write_loopback_session_file(sessions)


func _merge_loopback_sessions() -> void:
	if not _is_browsing:
		return

	var sessions: Dictionary = _read_loopback_session_file()
	if sessions.is_empty():
		return

	var now_unix: float = Time.get_unix_time_from_system()
	var changed: bool = false
	var file_changed: bool = false
	for session_id in sessions.keys():
		var raw_entry: Variant = sessions[session_id]
		if not (raw_entry is Dictionary):
			sessions.erase(session_id)
			file_changed = true
			continue

		var entry: Dictionary = raw_entry
		var last_seen_unix: float = float(entry.get("last_seen_unix", 0.0))
		if now_unix - last_seen_unix > SESSION_TIMEOUT:
			sessions.erase(session_id)
			file_changed = true
			continue

		if _store_session(entry, "127.0.0.1"):
			changed = true

	if file_changed:
		_write_loopback_session_file(sessions)
	if changed:
		session_list_changed.emit(get_sessions())


func _read_loopback_session_file() -> Dictionary:
	if not FileAccess.file_exists(LOOPBACK_SESSION_PATH):
		return {}

	var file := FileAccess.open(LOOPBACK_SESSION_PATH, FileAccess.READ)
	if file == null:
		return {}

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	if not (json.data is Dictionary):
		return {}
	return json.data


func _write_loopback_session_file(sessions: Dictionary) -> void:
	var file := FileAccess.open(LOOPBACK_SESSION_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(sessions))
