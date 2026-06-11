class_name MatchManager
extends Node

signal score_changed(player_id: int, kills: int, deaths: int)
signal match_started
signal match_finished(winner_id: int)
signal time_changed(remaining_seconds: float)
signal kill_feed_event(killer_name: String, victim_name: String, killer_id: int, victim_id: int)

enum WinMode {
	KILL_LIMIT,
	TIME_LIMIT,
	PRACTICE,
}

@export var win_mode: WinMode = WinMode.KILL_LIMIT
@export_range(1, 100) var score_limit: int = 10
@export_range(60.0, 1800.0, 1.0) var time_limit_seconds: float = 300.0

var match_running: bool = false
var scores: Dictionary = {}
var time_remaining: float = 0.0

var _player_names: Dictionary = {}


func _process(delta: float) -> void:
	if not match_running or win_mode != WinMode.TIME_LIMIT:
		return

	time_remaining = maxf(time_remaining - delta, 0.0)
	time_changed.emit(time_remaining)
	if time_remaining <= 0.0:
		_finish_time_limit_match()


func configure_rules(mode: WinMode, kill_limit: int, time_seconds: float) -> void:
	win_mode = mode
	score_limit = clampi(kill_limit, 1, 100)
	time_limit_seconds = clampf(time_seconds, 60.0, 1800.0)


func get_rules_snapshot() -> Dictionary:
	return {
		"win_mode": win_mode,
		"score_limit": score_limit,
		"time_limit_seconds": time_limit_seconds,
		"time_remaining": time_remaining,
	}


func apply_rules_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	win_mode = int(snapshot.get("win_mode", win_mode)) as WinMode
	score_limit = int(snapshot.get("score_limit", score_limit))
	time_limit_seconds = float(snapshot.get("time_limit_seconds", time_limit_seconds))
	time_remaining = float(snapshot.get("time_remaining", time_limit_seconds))
	time_changed.emit(time_remaining)


func set_player_name(player_id: int, player_name: String) -> void:
	_player_names[player_id] = player_name


func get_player_name(player_id: int) -> String:
	if _player_names.has(player_id):
		return str(_player_names[player_id])
	return "P%d" % player_id


func start_match() -> void:
	match_running = true
	scores.clear()
	time_remaining = time_limit_seconds
	match_started.emit()
	time_changed.emit(time_remaining)


func ensure_player(player_id: int) -> void:
	if scores.has(player_id):
		return
	scores[player_id] = {"kills": 0, "deaths": 0}
	score_changed.emit(player_id, 0, 0)


func kill_would_end_match(killer_id: int) -> bool:
	if not match_running or win_mode != WinMode.KILL_LIMIT:
		return false
	return get_kills(killer_id) + 1 >= score_limit


func register_kill(killer_id: int, victim_id: int) -> void:
	if not match_running:
		return

	ensure_player(killer_id)
	ensure_player(victim_id)

	var killer_score: Dictionary = scores[killer_id]
	var victim_score: Dictionary = scores[victim_id]
	killer_score["kills"] = int(killer_score.get("kills", 0)) + 1
	victim_score["deaths"] = int(victim_score.get("deaths", 0)) + 1
	score_changed.emit(killer_id, int(killer_score["kills"]), int(killer_score["deaths"]))
	score_changed.emit(victim_id, int(victim_score["kills"]), int(victim_score["deaths"]))

	kill_feed_event.emit(
		get_player_name(killer_id),
		get_player_name(victim_id),
		killer_id,
		victim_id
	)

	if win_mode == WinMode.KILL_LIMIT and int(killer_score["kills"]) >= score_limit:
		_finish_match(killer_id)


func register_death(player_id: int) -> void:
	if not match_running:
		return

	ensure_player(player_id)
	var player_score: Dictionary = scores[player_id]
	player_score["deaths"] = int(player_score.get("deaths", 0)) + 1
	score_changed.emit(player_id, int(player_score["kills"]), int(player_score["deaths"]))


func get_score_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for player_id in scores.keys():
		var player_score: Dictionary = scores[player_id]
		snapshot[int(player_id)] = {
			"kills": int(player_score.get("kills", 0)),
			"deaths": int(player_score.get("deaths", 0)),
		}
	return snapshot


func apply_score_snapshot(snapshot: Dictionary, is_match_running: bool) -> void:
	scores.clear()
	match_running = is_match_running

	for raw_player_id in snapshot.keys():
		var player_id: int = int(raw_player_id)
		var raw_score: Variant = snapshot[raw_player_id]
		if not (raw_score is Dictionary):
			push_warning("Ignoring invalid score snapshot entry for player %d." % player_id)
			continue

		var score: Dictionary = raw_score
		var kills: int = int(score.get("kills", 0))
		var deaths: int = int(score.get("deaths", 0))
		scores[player_id] = {"kills": kills, "deaths": deaths}
		score_changed.emit(player_id, kills, deaths)


func apply_match_finished(winner_id: int) -> void:
	match_running = false
	match_finished.emit(winner_id)


func get_kills(player_id: int) -> int:
	ensure_player(player_id)
	return int(scores[player_id].get("kills", 0))


func get_deaths(player_id: int) -> int:
	ensure_player(player_id)
	return int(scores[player_id].get("deaths", 0))


func get_leading_player_id() -> int:
	var best_id: int = 0
	var best_kills: int = -1
	for player_id in scores.keys():
		var kills: int = get_kills(int(player_id))
		if kills > best_kills:
			best_kills = kills
			best_id = int(player_id)
	return best_id


func format_score_line() -> String:
	var player_ids: Array = scores.keys()
	player_ids.sort()

	var parts: Array[String] = []
	for player_id in player_ids:
		parts.append("P%d %d/%d" % [int(player_id), get_kills(int(player_id)), get_deaths(int(player_id))])
	return "  ".join(parts)


func format_time_remaining() -> String:
	var total_seconds: int = int(ceilf(time_remaining))
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func get_objective_text() -> String:
	match win_mode:
		WinMode.TIME_LIMIT:
			return format_time_remaining()
		WinMode.PRACTICE:
			return "PRÁCTICA"
		_:
			return "PRIMERO A %d" % score_limit


func _finish_match(winner_id: int) -> void:
	match_running = false
	match_finished.emit(winner_id)


func _finish_time_limit_match() -> void:
	var winner_id: int = get_leading_player_id()
	_finish_match(winner_id)
