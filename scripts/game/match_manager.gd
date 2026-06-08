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


func _finish_match(winner_id: int) -> void:
	match_running = false
	match_finished.emit(winner_id)
