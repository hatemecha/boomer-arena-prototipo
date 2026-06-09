class_name MatchManager
extends Node

signal score_changed(player_id: int, kills: int, deaths: int)
signal match_started
signal match_finished(winner_id: int)

@export_range(1, 100) var score_limit: int = 10

var match_running: bool = false
var scores: Dictionary = {}


func start_match() -> void:
	match_running = true
	scores.clear()
	match_started.emit()


func ensure_player(player_id: int) -> void:
	if scores.has(player_id):
		return
	scores[player_id] = {"kills": 0, "deaths": 0}
	score_changed.emit(player_id, 0, 0)


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

	if int(killer_score["kills"]) >= score_limit:
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


func format_score_line() -> String:
	var player_ids: Array = scores.keys()
	player_ids.sort()

	var parts: Array[String] = []
	for player_id in player_ids:
		parts.append("P%d %d/%d" % [int(player_id), get_kills(int(player_id)), get_deaths(int(player_id))])
	return "  ".join(parts)


func _finish_match(winner_id: int) -> void:
	match_running = false
	match_finished.emit(winner_id)
