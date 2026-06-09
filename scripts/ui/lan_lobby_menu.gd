class_name LanLobbyMenu
extends Control

signal host_requested(port: int)
signal join_requested(address: String, port: int)
signal practice_requested
signal disconnect_requested

const MIN_PORT: int = 1024
const MAX_PORT: int = 65535

@onready var status_label: Label = %StatusLabel
@onready var local_addresses_label: Label = %LocalAddressesLabel
@onready var address_edit: LineEdit = %AddressEdit
@onready var port_spin: SpinBox = %PortSpin
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var practice_button: Button = %PracticeButton
@onready var disconnect_button: Button = %DisconnectButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	practice_button.pressed.connect(_on_practice_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	set_status("Select LAN mode.")


func configure(default_address: String, default_port: int, local_addresses: PackedStringArray) -> void:
	address_edit.text = default_address
	port_spin.min_value = MIN_PORT
	port_spin.max_value = MAX_PORT
	port_spin.step = 1
	port_spin.value = clampi(default_port, MIN_PORT, MAX_PORT)
	set_local_addresses(local_addresses)


func set_status(status: String) -> void:
	if status_label == null:
		return
	status_label.text = status


func set_local_addresses(local_addresses: PackedStringArray) -> void:
	if local_addresses_label == null:
		return
	if local_addresses.is_empty():
		local_addresses_label.text = "HOST IP: unavailable"
	else:
		local_addresses_label.text = "HOST IP: %s" % ", ".join(local_addresses)


func set_busy(is_busy: bool) -> void:
	host_button.disabled = is_busy
	join_button.disabled = is_busy
	practice_button.disabled = is_busy
	address_edit.editable = not is_busy
	port_spin.editable = not is_busy
	disconnect_button.disabled = not is_busy


func focus_default() -> void:
	host_button.grab_focus()


func _on_host_pressed() -> void:
	var port: int = int(port_spin.value)
	if not _is_valid_port(port):
		set_status("Invalid port.")
		return
	set_busy(true)
	set_status("Starting LAN host...")
	host_requested.emit(port)


func _on_join_pressed() -> void:
	var address: String = address_edit.text.strip_edges()
	var port: int = int(port_spin.value)
	if address.is_empty():
		set_status("Enter host IP.")
		return
	if not _is_valid_port(port):
		set_status("Invalid port.")
		return
	set_busy(true)
	set_status("Joining %s:%d..." % [address, port])
	join_requested.emit(address, port)


func _on_practice_pressed() -> void:
	set_busy(true)
	set_status("Starting practice...")
	practice_requested.emit()


func _on_disconnect_pressed() -> void:
	set_busy(false)
	set_status("Disconnected.")
	disconnect_requested.emit()


func _is_valid_port(port: int) -> bool:
	return port >= MIN_PORT and port <= MAX_PORT
