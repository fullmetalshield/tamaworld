class_name Actions
extends RefCounted

# Player-driven action catalog. Each entry on `CATALOG`:
#   label_key:    translation key for the button text
#   duration:     game-minutes the action takes to complete (waits in real time
#                 since 1 real second = 1 game minute by default)
#   effects:      Dictionary of base-stat deltas applied on completion
#   money_reward: coins added to pet["money"] on completion
#
# Actions are NOT instantaneous: `start()` records an `active_action` block on
# the pet (id, started_at_minutes, duration_minutes), and `tick()` finishes
# the action once enough game-minutes have elapsed. While an action is
# running, pet["active_action"] is the source of truth; UI reads `progress()`
# to render the donut, and `tick()` flushes rewards exactly once.

const CATALOG := {
	"play": {
		"label_key": "ACTION_PLAY",
		"progress_label_key": "ACTION_PLAY_PROGRESS",
		"duration": 120,
		"effects": {"charisma": 1, "luck": 1},
		"money_reward": 5,
		"color": Color(1.00, 0.78, 0.84, 1),
		"phases": ["toddler", "child", "teen", "young_adult", "middle_aged", "mature"],
	},
	"study": {
		"label_key": "ACTION_STUDY",
		"progress_label_key": "ACTION_STUDY_PROGRESS",
		"duration": 180,
		"effects": {"intelligence": 1},
		"money_reward": 10,
		"color": Color(0.78, 0.85, 1.00, 1),
		"phases": ["child", "teen", "young_adult", "middle_aged"],
	},
	"rest": {
		"label_key": "ACTION_REST",
		"progress_label_key": "ACTION_REST_PROGRESS",
		"duration": 60,
		"effects": {"stamina": 1},
		"money_reward": 0,
		"color": Color(0.72, 0.93, 0.83, 1),
		"phases": ["infant", "toddler", "child", "teen", "young_adult", "middle_aged", "mature", "elder"],
	},
	"school_public": {
		"label_key": "ACTION_SCHOOL_PUBLIC",
		"progress_label_key": "ACTION_SCHOOL_ENROLL_PROGRESS",
		"duration": 1,
		"effects": {},
		"money_reward": 0,
		"color": Color(0.82, 0.93, 0.78, 1),
		"phases": ["child"],
		"sets_school": "public",
	},
	"school_private": {
		"label_key": "ACTION_SCHOOL_PRIVATE",
		"progress_label_key": "ACTION_SCHOOL_ENROLL_PROGRESS",
		"duration": 1,
		"effects": {},
		"money_reward": 0,
		"color": Color(0.82, 0.88, 1.00, 1),
		"phases": ["child"],
		"sets_school": "private",
	},
	"school_elite": {
		"label_key": "ACTION_SCHOOL_ELITE",
		"progress_label_key": "ACTION_SCHOOL_ENROLL_PROGRESS",
		"duration": 1,
		"effects": {},
		"money_reward": 0,
		"color": Color(0.97, 0.88, 0.65, 1),
		"phases": ["child"],
		"sets_school": "elite",
	},
}

static func available_ids(pet: Dictionary, now_minutes: int) -> Array:
	var phase: Dictionary = Stats.current_phase(pet, now_minutes)
	var phase_id: String = String(phase.get("id", ""))
	var has_school: bool = pet.get("school") != null
	var ids: Array = []
	for id in CATALOG:
		var entry: Dictionary = CATALOG[id]
		var allowed: Array = entry.get("phases", [])
		if not allowed.is_empty() and not (phase_id in allowed):
			continue
		# Once a pet has enrolled, the other school options disappear so the
		# action list doesn't keep offering a choice that's already made.
		if entry.has("sets_school") and has_school:
			continue
		ids.append(id)
	return ids

static func is_busy(pet: Dictionary) -> bool:
	return pet.get("active_action") is Dictionary

static func active_id(pet: Dictionary) -> String:
	var a: Variant = pet.get("active_action")
	if a is Dictionary:
		return String(a.get("id", ""))
	return ""

static func progress(pet: Dictionary) -> float:
	var a: Variant = pet.get("active_action")
	if not (a is Dictionary):
		return 0.0
	var dur: float = float(a.get("duration_minutes", 1))
	if dur <= 0.0:
		return 1.0
	var now_min: float = GameClock._total_game_minutes
	var started: float = float(a.get("started_at_minutes", now_min))
	return clampf((now_min - started) / dur, 0.0, 1.0)

static func remaining_minutes(pet: Dictionary) -> int:
	var a: Variant = pet.get("active_action")
	if not (a is Dictionary):
		return 0
	var dur: int = int(a.get("duration_minutes", 0))
	var now_min: float = GameClock._total_game_minutes
	var started: float = float(a.get("started_at_minutes", now_min))
	return max(0, dur - int(now_min - started))

static func start(pet: Dictionary, action_id: String) -> bool:
	if is_busy(pet):
		return false
	if not CATALOG.has(action_id):
		return false
	var action: Dictionary = CATALOG[action_id]
	pet["active_action"] = {
		"id": action_id,
		"started_at_minutes": float(GameClock._total_game_minutes),
		"duration_minutes": int(action.get("duration", 60)),
	}
	PetStore.persist()
	return true

# Returns the rewards dict if the action just completed; empty dict otherwise.
static func tick(pet: Dictionary) -> Dictionary:
	if not is_busy(pet):
		return {}
	if progress(pet) < 1.0:
		return {}
	return _complete(pet)

static func _complete(pet: Dictionary) -> Dictionary:
	var a: Dictionary = pet.get("active_action", {})
	var action_id: String = String(a.get("id", ""))
	pet["active_action"] = null
	if not CATALOG.has(action_id):
		PetStore.persist()
		return {}
	var action: Dictionary = CATALOG[action_id]
	var stats: Dictionary = pet.get("stats", {})
	var effects: Dictionary = action.get("effects", {})
	for k in effects:
		var delta: int = int(effects[k])
		stats[k] = clampi(int(stats.get(k, 5)) + delta, Stats.STAT_MIN, Stats.STAT_MAX)
	pet["stats"] = stats
	var money_reward: int = int(action.get("money_reward", 0))
	if money_reward != 0:
		Family.add_money(money_reward)
	if action.has("sets_school"):
		pet["school"] = String(action["sets_school"])
	var counts: Dictionary = pet.get("action_counts", {})
	counts[action_id] = int(counts.get(action_id, 0)) + 1
	pet["action_counts"] = counts
	PetStore.persist()
	return {
		"action_id": action_id,
		"effects": effects,
		"money": money_reward,
	}
