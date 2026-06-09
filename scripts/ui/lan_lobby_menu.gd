class_name LanLobbyMenu
extends Control

signal host_requested(port: int, time_of_day_preset: int)
signal join_requested(address: String, port: int)
signal practice_requested(time_of_day_preset: int)
signal disconnect_requested

const MIN_PORT: int = 1024
const MAX_PORT: int = 65535
const TIME_OF_DAY_MORNING: int = 0
const TIME_OF_DAY_AFTERNOON: int = 1
const TIME_OF_DAY_NIGHT: int = 2
const ArenaMenuStyleScript: GDScript = preload("res://scripts/ui/arena_menu_style.gd")
const ArenaMenuMotionScript: GDScript = preload("res://scripts/ui/arena_menu_motion.gd")
const ArenaMenuBackdropScript: GDScript = preload("res://scripts/ui/arena_menu_backdrop.gd")

@onready var status_label: Label = %StatusLabel
@onready var local_addresses_label: Label = %LocalAddressesLabel
@onready var address_edit: LineEdit = %AddressEdit
@onready var port_spin: SpinBox = %PortSpin
@onready var time_of_day_option: OptionButton = %TimeOfDayOption
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var practice_button: Button = %PracticeButton
@onready var disconnect_button: Button = %DisconnectButton

var _menu_motion


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ArenaMenuBackdropScript.apply(self)
	ArenaMenuStyleScript.apply_to_menu(self)
	_menu_motion = ArenaMenuMotionScript.new()
	_menu_motion.bind(self)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	practice_button.pressed.connect(_on_practice_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	_configure_time_of_day_options()
	set_status("Elegí cómo entrar a la arena.")


func _process(delta: float) -> void:
	if _menu_motion != null:
		_menu_motion.update(delta)


func configure(default_address: String, default_port: int, local_addresses: PackedStringArray) -> void:
	address_edit.text = default_address
	port_spin.min_value = MIN_PORT
	port_spin.max_value = MAX_PORT
	port_spin.step = 1
	port_spin.value = clampi(default_port, MIN_PORT, MAX_PORT)
	_select_time_of_day(TIME_OF_DAY_NIGHT)
	set_local_addresses(local_addresses)


func set_status(status: String) -> void:
	if status_label == null:
		return
	status_label.text = status


func set_local_addresses(local_addresses: PackedStringArray) -> void:
	if local_addresses_label == null:
		return
	if local_addresses.is_empty():
		local_addresses_label.text = "IP LOCAL: no disponible"
	else:
		local_addresses_label.text = "IP LOCAL: %s" % ", ".join(local_addresses)


func set_busy(is_busy: bool) -> void:
	host_button.disabled = is_busy
	join_button.disabled = is_busy
	practice_button.disabled = is_busy
	address_edit.editable = not is_busy
	port_spin.editable = not is_busy
	time_of_day_option.disabled = is_busy
	disconnect_button.disabled = not is_busy


func focus_default() -> void:
	if _menu_motion != null:
		_menu_motion.play_open()
	host_button.grab_focus()


func _on_host_pressed() -> void:
	var port: int = int(port_spin.value)
	if not _is_valid_port(port):
		set_status("Puerto inválido.")
		return
	set_busy(true)
	set_status("Abriendo host LAN...")
	host_requested.emit(port, _get_selected_time_of_day())


func _on_join_pressed() -> void:
	var address: String = address_edit.text.strip_edges()
	var port: int = int(port_spin.value)
	if address.is_empty():
		set_status("Ingresá la IP del host.")
		return
	if not _is_valid_port(port):
		set_status("Puerto inválido.")
		return
	set_busy(true)
	set_status("Conectando a %s:%d..." % [address, port])
	join_requested.emit(address, port)


func _on_practice_pressed() -> void:
	set_busy(true)
	set_status("Entrando en práctica...")
	practice_requested.emit(_get_selected_time_of_day())


func _on_disconnect_pressed() -> void:
	set_busy(false)
	set_status("Desconectado.")
	disconnect_requested.emit()


func _is_valid_port(port: int) -> bool:
	return port >= MIN_PORT and port <= MAX_PORT


func _configure_time_of_day_options() -> void:
	if time_of_day_option == null:
		return
	if time_of_day_option.get_item_count() > 0:
		return

	time_of_day_option.add_item("MAÑANA", TIME_OF_DAY_MORNING)
	time_of_day_option.add_item("TARDE", TIME_OF_DAY_AFTERNOON)
	time_of_day_option.add_item("NOCHE", TIME_OF_DAY_NIGHT)
	_select_time_of_day(TIME_OF_DAY_NIGHT)


func _select_time_of_day(preset: int) -> void:
	if time_of_day_option == null:
		return

	for item_index in range(time_of_day_option.get_item_count()):
		if time_of_day_option.get_item_id(item_index) == preset:
			time_of_day_option.select(item_index)
			return


func _get_selected_time_of_day() -> int:
	if time_of_day_option == null:
		return TIME_OF_DAY_NIGHT
	var selected_id: int = time_of_day_option.get_selected_id()
	if selected_id < 0:
		return TIME_OF_DAY_NIGHT
	return selected_id
