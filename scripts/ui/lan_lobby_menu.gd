class_name LanLobbyMenu
extends Control

signal host_requested(port: int, map_id: String, time_of_day_preset: int, match_rules: Dictionary)
signal join_requested(address: String, port: int)
signal practice_requested(map_id: String, time_of_day_preset: int, match_rules: Dictionary)
signal disconnect_requested
signal options_requested
signal quit_game_requested
signal browse_requested
signal browse_stopped

enum Screen {
	ENTRY,
	SETUP,
	LAN_CHOICE,
	HOST,
	JOIN,
}

const MIN_PORT: int = 1024
const MAX_PORT: int = 65535
const TIME_OF_DAY_MORNING: int = 0
const TIME_OF_DAY_AFTERNOON: int = 1
const TIME_OF_DAY_NIGHT: int = 2
const ArenaMenuStyleScript: GDScript = preload("res://scripts/ui/arena_menu_style.gd")
const ArenaMenuMotionScript: GDScript = preload("res://scripts/ui/arena_menu_motion.gd")
const ArenaMenuBackdropScript: GDScript = preload("res://scripts/ui/arena_menu_backdrop.gd")

@onready var status_label: Label = %StatusLabel
@onready var entry_screen: VBoxContainer = %EntryScreen
@onready var setup_screen: VBoxContainer = %SetupScreen
@onready var lan_choice_screen: VBoxContainer = %LanChoiceScreen
@onready var host_screen: VBoxContainer = %HostScreen
@onready var join_screen: VBoxContainer = %JoinScreen
@onready var local_addresses_label: Label = %LocalAddressesLabel
@onready var host_info_label: Label = %HostInfoLabel
@onready var address_edit: LineEdit = %AddressEdit
@onready var port_spin: SpinBox = %PortSpin
@onready var join_port_spin: SpinBox = %JoinPortSpin
@onready var map_option: OptionButton = %MapOption
@onready var time_of_day_option: OptionButton = %TimeOfDayOption
@onready var win_mode_option: OptionButton = %WinModeOption
@onready var limit_row: HBoxContainer = %LimitRow
@onready var limit_label: Label = %LimitLabel
@onready var limit_spin: SpinBox = %LimitSpin
@onready var time_row: HBoxContainer = %TimeRow
@onready var time_of_day_row: HBoxContainer = %TimeOfDayRow
@onready var time_spin: SpinBox = %TimeSpin
@onready var session_list: ItemList = %SessionList
@onready var manual_join_toggle: CheckBox = %ManualJoinToggle
@onready var manual_join_panel: VBoxContainer = %ManualJoinPanel
@onready var disconnect_button: Button = %DisconnectButton

var _menu_motion
var _current_screen: int = Screen.ENTRY
var _setup_for_lan_host: bool = false
var _local_addresses: PackedStringArray = []
var _discovered_sessions: Array = []
var _selected_map_id: String = ""
var _pending_map_options: Array = []
var _pending_selected_map_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ArenaMenuBackdropScript.apply(self)
	ArenaMenuStyleScript.apply_to_menu(self)
	_menu_motion = ArenaMenuMotionScript.new()
	_menu_motion.bind(self)
	_connect_buttons()
	_configure_time_of_day_options()
	_configure_win_mode_options()
	if not _pending_map_options.is_empty():
		set_map_options(_pending_map_options, _pending_selected_map_id)
	_update_setup_visibility()
	_show_screen(Screen.ENTRY)
	set_status("Elegí cómo entrar a la arena.")
	if PlayerSettings != null:
		PlayerSettings.settings_changed.connect(_on_settings_changed)


func _process(delta: float) -> void:
	if _menu_motion != null:
		_menu_motion.update(delta)


func configure(default_address: String, default_port: int, local_addresses: PackedStringArray) -> void:
	address_edit.text = default_address
	port_spin.min_value = MIN_PORT
	port_spin.max_value = MAX_PORT
	port_spin.step = 1
	port_spin.value = clampi(default_port, MIN_PORT, MAX_PORT)
	join_port_spin.min_value = MIN_PORT
	join_port_spin.max_value = MAX_PORT
	join_port_spin.step = 1
	join_port_spin.value = clampi(default_port, MIN_PORT, MAX_PORT)
	_local_addresses = local_addresses
	_select_time_of_day(TIME_OF_DAY_NIGHT)
	set_local_addresses(local_addresses)


func set_status(status: String) -> void:
	if status_label == null:
		return
	status_label.text = status


func set_local_addresses(local_addresses: PackedStringArray) -> void:
	_local_addresses = local_addresses
	if local_addresses_label == null:
		return
	if local_addresses.is_empty():
		local_addresses_label.text = "IP LOCAL: no disponible"
	else:
		local_addresses_label.text = "IP: %s  ·  PUERTO: %d" % [", ".join(local_addresses), int(port_spin.value)]


func set_busy(is_busy: bool) -> void:
	disconnect_button.disabled = not is_busy
	disconnect_button.visible = is_busy
	_set_screen_interactive(not is_busy)


func set_discovered_sessions(sessions: Array) -> void:
	_discovered_sessions = sessions
	if session_list == null:
		return
	session_list.clear()
	for session in sessions:
		if not (session is Dictionary):
			continue
		var entry: Dictionary = session
		var mode_text: String = "TIEMPO" if str(entry.get("mode", "kills")) == "time" else "BAJAS"
		var label: String = "%s  ·  %s  ·  %s %d  ·  %d/%d" % [
			entry.get("name", "Partida"),
			entry.get("map", "MAPA"),
			mode_text,
			int(entry.get("limit", 10)),
			int(entry.get("players", 1)),
			int(entry.get("max_players", 2)),
		]
		session_list.add_item(label)


func set_map_options(map_options: Array, selected_map_id: String = "") -> void:
	if map_option == null:
		_pending_map_options = map_options.duplicate(true)
		_pending_selected_map_id = selected_map_id
		return

	_pending_map_options.clear()
	_pending_selected_map_id = ""
	map_option.clear()
	var selected_index: int = 0
	for index in range(map_options.size()):
		if not (map_options[index] is Dictionary):
			continue
		var option: Dictionary = map_options[index]
		var map_id: String = str(option.get("id", ""))
		var label: String = str(option.get("label", map_id)).to_upper()
		if map_id.is_empty():
			continue
		map_option.add_item(label, index)
		map_option.set_item_metadata(map_option.get_item_count() - 1, map_id)
		if map_id == selected_map_id:
			selected_index = map_option.get_item_count() - 1

	if map_option.get_item_count() <= 0:
		map_option.add_item("TEST ARENA", 0)
		map_option.set_item_metadata(0, "test_arena")
	if selected_index >= 0 and selected_index < map_option.get_item_count():
		map_option.select(selected_index)
	_selected_map_id = _get_selected_map_id()


func focus_default() -> void:
	if _menu_motion != null:
		_menu_motion.play_open()
	_focus_current_screen()


func get_match_rules() -> Dictionary:
	var win_mode: int = MatchManager.WinMode.KILL_LIMIT
	if win_mode_option.get_selected_id() == MatchManager.WinMode.TIME_LIMIT:
		win_mode = MatchManager.WinMode.TIME_LIMIT
	return {
		"win_mode": win_mode,
		"score_limit": int(limit_spin.value),
		"time_limit_seconds": float(time_spin.value) * 60.0,
	}


func _connect_buttons() -> void:
	%PracticeButton.pressed.connect(_on_practice_entry_pressed)
	%LanButton.pressed.connect(_on_lan_entry_pressed)
	%OptionsButton.pressed.connect(_on_options_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	%StartSetupButton.pressed.connect(_on_start_setup_pressed)
	%BackFromSetupButton.pressed.connect(_on_back_from_setup_pressed)
	%HostLanButton.pressed.connect(_on_host_lan_choice_pressed)
	%BrowseLanButton.pressed.connect(_on_browse_lan_pressed)
	%BackFromLanChoiceButton.pressed.connect(_on_back_from_lan_choice_pressed)
	%CopyInfoButton.pressed.connect(_on_copy_info_pressed)
	%CreateHostButton.pressed.connect(_on_create_host_pressed)
	%BackFromHostButton.pressed.connect(_on_back_from_host_pressed)
	%RefreshSessionsButton.pressed.connect(_on_refresh_sessions_pressed)
	session_list.item_activated.connect(_on_session_activated)
	manual_join_toggle.toggled.connect(_on_manual_join_toggled)
	%JoinManualButton.pressed.connect(_on_join_manual_pressed)
	%BackFromJoinButton.pressed.connect(_on_back_from_join_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	win_mode_option.item_selected.connect(_on_win_mode_selected)


func _on_settings_changed() -> void:
	ArenaMenuStyleScript.apply_to_menu(self)


func _on_practice_entry_pressed() -> void:
	_setup_for_lan_host = false
	_show_screen(Screen.SETUP)
	_update_setup_visibility()
	set_status("Elegí mapa y horario.")


func _on_lan_entry_pressed() -> void:
	_setup_for_lan_host = true
	_show_screen(Screen.LAN_CHOICE)
	set_status("Elegí hostear o buscar partidas.")


func _on_options_pressed() -> void:
	options_requested.emit()


func _on_quit_pressed() -> void:
	quit_game_requested.emit()


func _on_start_setup_pressed() -> void:
	if _setup_for_lan_host:
		_show_screen(Screen.HOST)
		set_local_addresses(_local_addresses)
		set_status("Compartí la IP y el puerto con tus amigos.")
		return
	set_busy(true)
	set_status("Entrando en práctica...")
	practice_requested.emit(_get_selected_map_id(), _get_selected_time_of_day(), {})


func _on_back_from_setup_pressed() -> void:
	if _setup_for_lan_host:
		_show_screen(Screen.LAN_CHOICE)
	else:
		_show_screen(Screen.ENTRY)


func _on_host_lan_choice_pressed() -> void:
	_setup_for_lan_host = true
	_show_screen(Screen.SETUP)
	_update_setup_visibility()
	set_status("Configurá las reglas de la partida LAN.")


func _on_browse_lan_pressed() -> void:
	_show_screen(Screen.JOIN)
	set_status("Buscando partidas en la red local...")
	browse_requested.emit()


func _on_back_from_lan_choice_pressed() -> void:
	_show_screen(Screen.ENTRY)


func _on_copy_info_pressed() -> void:
	var ip_text: String = ", ".join(_local_addresses) if not _local_addresses.is_empty() else "127.0.0.1"
	var copy_text: String = "%s:%d" % [ip_text.split(",")[0].strip_edges(), int(port_spin.value)]
	DisplayServer.clipboard_set(copy_text)
	set_status("Copiado: %s" % copy_text)


func _on_create_host_pressed() -> void:
	var port: int = int(port_spin.value)
	if not _is_valid_port(port):
		set_status("Puerto inválido.")
		return
	set_busy(true)
	set_status("Abriendo host LAN...")
	host_requested.emit(port, _get_selected_map_id(), _get_selected_time_of_day(), get_match_rules())


func _on_back_from_host_pressed() -> void:
	_show_screen(Screen.SETUP)


func _on_refresh_sessions_pressed() -> void:
	set_status("Actualizando lista de partidas...")
	browse_requested.emit()


func _on_session_activated(index: int) -> void:
	if index < 0 or index >= _discovered_sessions.size():
		return
	var session: Dictionary = _discovered_sessions[index]
	var address: String = str(session.get("address", ""))
	var port: int = int(session.get("port", 0))
	if address.is_empty() or not _is_valid_port(port):
		set_status("Partida inválida.")
		return
	set_busy(true)
	set_status("Conectando a %s:%d..." % [address, port])
	join_requested.emit(address, port)


func _on_manual_join_toggled(enabled: bool) -> void:
	manual_join_panel.visible = enabled


func _on_join_manual_pressed() -> void:
	var address: String = address_edit.text.strip_edges()
	var port: int = int(join_port_spin.value)
	if address.is_empty():
		set_status("Ingresá la IP del host.")
		return
	if not _is_valid_port(port):
		set_status("Puerto inválido.")
		return
	set_busy(true)
	set_status("Conectando a %s:%d..." % [address, port])
	join_requested.emit(address, port)


func _on_back_from_join_pressed() -> void:
	browse_stopped.emit()
	_show_screen(Screen.LAN_CHOICE)


func _on_disconnect_pressed() -> void:
	set_busy(false)
	set_status("Desconectado.")
	disconnect_requested.emit()
	_show_screen(Screen.ENTRY)


func _on_win_mode_selected(_index: int) -> void:
	_update_win_mode_ui()


func _show_screen(screen: int) -> void:
	_current_screen = screen
	entry_screen.visible = screen == Screen.ENTRY
	setup_screen.visible = screen == Screen.SETUP
	lan_choice_screen.visible = screen == Screen.LAN_CHOICE
	host_screen.visible = screen == Screen.HOST
	join_screen.visible = screen == Screen.JOIN
	_focus_current_screen()


func _focus_current_screen() -> void:
	match _current_screen:
		Screen.ENTRY:
			%PracticeButton.grab_focus()
		Screen.SETUP:
			if map_option != null:
				map_option.grab_focus()
			elif _setup_for_lan_host:
				%StartSetupButton.grab_focus()
			elif time_of_day_option != null:
				time_of_day_option.grab_focus()
			else:
				%StartSetupButton.grab_focus()
		Screen.LAN_CHOICE:
			%HostLanButton.grab_focus()
		Screen.HOST:
			%CreateHostButton.grab_focus()
		Screen.JOIN:
			if session_list.get_item_count() > 0:
				session_list.grab_focus()
			else:
				%RefreshSessionsButton.grab_focus()


func _set_screen_interactive(enabled: bool) -> void:
	for button in find_children("*", "Button", true, false):
		if button == disconnect_button:
			continue
		(button as Button).disabled = not enabled
	for spin in [port_spin, join_port_spin, limit_spin, time_spin]:
		if spin != null:
			spin.editable = enabled
	if address_edit != null:
		address_edit.editable = enabled
	if time_of_day_option != null:
		time_of_day_option.disabled = not enabled
	if map_option != null:
		map_option.disabled = not enabled
	if win_mode_option != null:
		win_mode_option.disabled = not enabled
	if session_list != null:
		session_list.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _is_valid_port(port: int) -> bool:
	return port >= MIN_PORT and port <= MAX_PORT


func _configure_time_of_day_options() -> void:
	if time_of_day_option == null or time_of_day_option.get_item_count() > 0:
		return
	time_of_day_option.add_item("MAÑANA", TIME_OF_DAY_MORNING)
	time_of_day_option.add_item("TARDE", TIME_OF_DAY_AFTERNOON)
	time_of_day_option.add_item("NOCHE", TIME_OF_DAY_NIGHT)
	_select_time_of_day(TIME_OF_DAY_NIGHT)


func _configure_win_mode_options() -> void:
	if win_mode_option == null or win_mode_option.get_item_count() > 0:
		return
	win_mode_option.add_item("POR BAJAS", MatchManager.WinMode.KILL_LIMIT)
	win_mode_option.add_item("POR TIEMPO", MatchManager.WinMode.TIME_LIMIT)
	_update_win_mode_ui()


func _update_setup_visibility() -> void:
	var show_match_rules: bool = _setup_for_lan_host
	var mode_row: Node = win_mode_option.get_parent() if win_mode_option != null else null
	if mode_row != null:
		mode_row.visible = show_match_rules
	if time_of_day_row != null:
		time_of_day_row.visible = true
	if show_match_rules:
		_update_win_mode_ui()
	else:
		if limit_row != null:
			limit_row.visible = false
		if time_row != null:
			time_row.visible = false


func _update_win_mode_ui() -> void:
	var is_time_mode: bool = win_mode_option.get_selected_id() == MatchManager.WinMode.TIME_LIMIT
	if limit_row != null:
		limit_row.visible = not is_time_mode
	if limit_label != null:
		limit_label.text = "BAJAS"
	if time_row != null:
		time_row.visible = is_time_mode


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


func _get_selected_map_id() -> String:
	if map_option == null or map_option.get_item_count() <= 0:
		return "test_arena"
	var selected_index: int = map_option.selected
	if selected_index < 0:
		selected_index = 0
	var metadata: Variant = map_option.get_item_metadata(selected_index)
	var map_id: String = str(metadata).strip_edges()
	if map_id.is_empty():
		return "test_arena"
	_selected_map_id = map_id
	return map_id
