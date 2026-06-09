class_name NetworkManager
extends Node

signal host_started(port: int)
signal join_started(address: String, port: int)
signal joined_server
signal connection_failed(message: String)
signal server_disconnected
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal network_status_changed(status: String)

const DEFAULT_PORT: int = 24500
const DEFAULT_MAX_CLIENTS: int = 1

enum Mode {
	OFFLINE,
	HOST,
	CLIENT,
}

@export_range(1024, 65535) var port: int = DEFAULT_PORT
@export var default_join_address: String = "127.0.0.1"
@export_range(1, 16) var max_clients: int = DEFAULT_MAX_CLIENTS

var mode: int = Mode.OFFLINE

var _peer: ENetMultiplayerPeer


func _ready() -> void:
	_connect_multiplayer_signals()


func configure(next_port: int, next_default_join_address: String, next_max_clients: int) -> void:
	if _is_valid_port(next_port):
		port = next_port
	else:
		push_warning("Invalid LAN port %d. Keeping %d." % [next_port, port])

	if not next_default_join_address.strip_edges().is_empty():
		default_join_address = next_default_join_address.strip_edges()

	max_clients = maxi(next_max_clients, 1)


func apply_startup_args() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var wants_host: bool = false
	var join_address: String = ""
	var parsed_port: int = port

	var index: int = 0
	while index < args.size():
		var arg: String = args[index].strip_edges()
		match arg:
			"--lan-host", "--host":
				wants_host = true
			"--lan-join", "--join":
				if index + 1 < args.size():
					index += 1
					join_address = args[index].strip_edges()
			"--lan-address", "--address", "--ip":
				if index + 1 < args.size():
					index += 1
					join_address = args[index].strip_edges()
			"--lan-port", "--port":
				if index + 1 < args.size():
					index += 1
					parsed_port = _parse_port(args[index], parsed_port)
			_:
				if arg.begins_with("--lan-join=") or arg.begins_with("--join="):
					join_address = arg.get_slice("=", 1).strip_edges()
				elif arg.begins_with("--lan-address=") or arg.begins_with("--address=") or arg.begins_with("--ip="):
					join_address = arg.get_slice("=", 1).strip_edges()
				elif arg.begins_with("--lan-port=") or arg.begins_with("--port="):
					parsed_port = _parse_port(arg.get_slice("=", 1), parsed_port)
		index += 1

	port = parsed_port
	if wants_host:
		return host_game(port)
	if not join_address.is_empty():
		return join_game(join_address, port)
	return false


func host_game(next_port: int = port) -> bool:
	if not _is_valid_port(next_port):
		_fail("Cannot host LAN game because port %d is invalid." % next_port)
		return false

	disconnect_network(false)
	_peer = ENetMultiplayerPeer.new()
	var error: Error = _peer.create_server(next_port, max_clients)
	if error != OK:
		_peer = null
		_fail("Cannot host LAN game on port %d. Error: %s." % [next_port, error_string(error)])
		return false

	port = next_port
	mode = Mode.HOST
	multiplayer.multiplayer_peer = _peer
	host_started.emit(port)
	network_status_changed.emit("LAN HOST :%d" % port)
	return true


func join_game(address: String = default_join_address, next_port: int = port) -> bool:
	var clean_address: String = address.strip_edges()
	if clean_address.is_empty():
		_fail("Cannot join LAN game because the address is empty.")
		return false
	if not _is_valid_port(next_port):
		_fail("Cannot join LAN game because port %d is invalid." % next_port)
		return false

	disconnect_network(false)
	_peer = ENetMultiplayerPeer.new()
	var error: Error = _peer.create_client(clean_address, next_port)
	if error != OK:
		_peer = null
		_fail("Cannot join LAN game at %s:%d. Error: %s." % [clean_address, next_port, error_string(error)])
		return false

	default_join_address = clean_address
	port = next_port
	mode = Mode.CLIENT
	multiplayer.multiplayer_peer = _peer
	join_started.emit(default_join_address, port)
	network_status_changed.emit("JOINING %s:%d" % [default_join_address, port])
	return true


func disconnect_network(emit_status: bool = true) -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	_peer = null
	mode = Mode.OFFLINE
	if emit_status:
		network_status_changed.emit("OFFLINE")


func is_networked() -> bool:
	return multiplayer.multiplayer_peer != null and mode != Mode.OFFLINE


func is_host() -> bool:
	return is_networked() and mode == Mode.HOST and multiplayer.is_server()


func is_client() -> bool:
	return is_networked() and mode == Mode.CLIENT


func get_local_peer_id() -> int:
	if not is_networked():
		return 1
	return multiplayer.get_unique_id()


func get_status_text() -> String:
	match mode:
		Mode.HOST:
			return "LAN HOST :%d" % port
		Mode.CLIENT:
			return "LAN CLIENT %s:%d" % [default_join_address, port]
		_:
			return "OFFLINE"


func _connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _parse_port(raw_value: String, fallback: int) -> int:
	if not raw_value.is_valid_int():
		push_warning("Invalid LAN port value: %s." % raw_value)
		return fallback

	var parsed_port: int = int(raw_value)
	if not _is_valid_port(parsed_port):
		push_warning("LAN port out of range: %d." % parsed_port)
		return fallback
	return parsed_port


func _is_valid_port(value: int) -> bool:
	return value >= 1024 and value <= 65535


func _fail(message: String) -> void:
	push_error(message)
	connection_failed.emit(message)
	network_status_changed.emit("LAN ERROR")


func _on_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)
	network_status_changed.emit(get_status_text())


func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)
	network_status_changed.emit(get_status_text())


func _on_connected_to_server() -> void:
	joined_server.emit()
	network_status_changed.emit(get_status_text())


func _on_connection_failed() -> void:
	var message := "LAN connection failed."
	disconnect_network(false)
	connection_failed.emit(message)
	network_status_changed.emit(message)


func _on_server_disconnected() -> void:
	disconnect_network(false)
	server_disconnected.emit()
	network_status_changed.emit("SERVER DISCONNECTED")
