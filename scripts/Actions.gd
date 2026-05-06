class_name Actions
extends RefCounted

# Player-driven action catalog. The data lives in `data/actions.json` and is
# loaded into `CATALOG` at boot by `scripts/CatalogLoader.gd`. Each entry:
#   label_key / progress_label_key: translation keys for the button text
#   duration:        game-minutes the action takes to complete (waits in real
#                    time since 1 real second = 1 game minute by default)
#   effects:         Dictionary of base-stat deltas applied on completion
#   money_reward:    coins added to Family treasury on completion
#   color:           hex string in JSON, parsed to Color by the loader
#   phases:          which life phases gate this action
#   sets_school:     (optional) school id to assign on completion
#   opens_picker:    (optional) marks the action as a UI trigger that opens
#                    a chooser instead of running as a timed wait
#   requires_club:   (optional) only show if pet has at least one club
#   cooldown_minutes (optional) game-minutes after use before reappearing
#
# Actions are NOT instantaneous: `start()` records an `active_action` block
# on the pet (id, started_at_minutes, duration_minutes), and `tick()`
# finishes the action once enough game-minutes have elapsed.

static var CATALOG: Dictionary = {}

static func available_ids(pet: Dictionary, now_minutes: int) -> Array:
	var phase: Dictionary = Stats.current_phase(pet, now_minutes)
	var phase_id: String = String(phase.get("id", ""))
	var has_school: bool = pet.get("school") != null
	var has_any_club: bool = not (pet.get("clubs", []) as Array).is_empty()
	var ids: Array = []
	for id in CATALOG:
		var entry: Dictionary = CATALOG[id]
		# Triggered-only actions are started by special UI flows (e.g. date
		# from BondDetailModal) and never appear in the generic action list.
		if entry.get("triggered_only", false):
			continue
		var allowed: Array = entry.get("phases", [])
		if not allowed.is_empty() and not (phase_id in allowed):
			continue
		# Once a pet has enrolled, the other school options disappear so the
		# action list doesn't keep offering a choice that's already made.
		if entry.has("sets_school") and has_school:
			continue
		# Club activities only show up after the pet has joined at least one.
		if entry.get("requires_club", false) and not has_any_club:
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
	if not _can_afford(pet, action):
		return false
	_deduct_cost(pet, action)
	pet["active_action"] = {
		"id": action_id,
		"started_at_minutes": float(GameClock._total_game_minutes),
		"duration_minutes": int(action.get("duration", 60)),
	}
	PetStore.persist()
	return true

# Up-front money_cost gate. Family pets pull from the shared treasury; NPCs
# live their own lives without touching it (they ignore cost). Returns true
# when the action can be started right now.
static func _can_afford(pet: Dictionary, action: Dictionary) -> bool:
	var cost: int = int(action.get("money_cost", 0))
	if cost <= 0:
		return true
	if String(pet.get("kind", "family")) != "family":
		return true
	return Family.money() >= cost

static func _deduct_cost(pet: Dictionary, action: Dictionary) -> void:
	var cost: int = int(action.get("money_cost", 0))
	if cost <= 0:
		return
	if String(pet.get("kind", "family")) != "family":
		return
	Family.add_money(-cost)

# Two-pet date action — both viewer and partner go busy for the same window
# so neither can start something else while it runs. The catalog entry is
# `triggered_only`, so it never auto-picks; only BondDetailModal calls this.
# The partner's prior auto-picked action (rest/play/etc.) is preempted —
# accepting the date means dropping whatever they were doing. The viewer
# still has to be free, since this is initiated by the player.
static func start_date(viewer: Dictionary, partner: Dictionary) -> bool:
	if is_busy(viewer):
		return false
	if not CATALOG.has("date"):
		return false
	var entry: Dictionary = CATALOG["date"]
	var dur: int = int(entry.get("duration", 1))
	var now: float = float(GameClock._total_game_minutes)
	var viewer_block := {
		"id": "date",
		"started_at_minutes": now,
		"duration_minutes": dur,
		"partner_id": partner.get("id", ""),
	}
	var partner_block := {
		"id": "date",
		"started_at_minutes": now,
		"duration_minutes": dur,
		"partner_id": viewer.get("id", ""),
	}
	viewer["active_action"] = viewer_block
	partner["active_action"] = partner_block
	PetStore.persist()
	return true

# Club-specific variant of `start`. The `club_id` is stored on the active
# action so `_complete` knows which club's bond pool to draw from when the
# wait finishes. The underlying action id stays "club_activity" so all the
# generic timing/effects/money logic still applies.
static func start_club_activity(pet: Dictionary, club_id: String) -> bool:
	if is_busy(pet):
		return false
	if not CATALOG.has("club_activity"):
		return false
	var action: Dictionary = CATALOG["club_activity"]
	if not _can_afford(pet, action):
		return false
	_deduct_cost(pet, action)
	pet["active_action"] = {
		"id": "club_activity",
		"club_id": club_id,
		"started_at_minutes": float(GameClock._total_game_minutes),
		"duration_minutes": int(action.get("duration", 90)),
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

static func is_on_cooldown(pet: Dictionary, action_id: String) -> bool:
	return cooldown_remaining_minutes(pet, action_id) > 0

static func cooldown_remaining_minutes(pet: Dictionary, action_id: String) -> int:
	var cooldowns: Dictionary = pet.get("action_cooldowns", {})
	var until: int = int(cooldowns.get(action_id, 0))
	return max(0, until - int(GameClock._total_game_minutes))

# Stamps the action's cooldown_until timestamp on the pet so the same action
# can't be re-triggered until enough game-minutes have elapsed. No-op for
# actions without `cooldown_minutes` defined.
static func set_cooldown(pet: Dictionary, action_id: String) -> void:
	var entry: Dictionary = CATALOG.get(action_id, {})
	var cd_min: int = int(entry.get("cooldown_minutes", 0))
	if cd_min <= 0:
		return
	var cooldowns: Dictionary = pet.get("action_cooldowns", {})
	cooldowns[action_id] = int(GameClock._total_game_minutes) + cd_min
	pet["action_cooldowns"] = cooldowns
	PetStore.persist()

static func _form_club_bond(pet: Dictionary, club_id: String) -> void:
	var clubs: Array = pet.get("clubs", [])
	# Fall back to a random joined club if the caller didn't specify one
	# (e.g. a save from before per-club tracking was added).
	if not (club_id in clubs):
		if clubs.is_empty():
			return
		club_id = String(clubs[randi() % clubs.size()])
	# Promote the club mate to a full NPC pet (same shape as the protagonist,
	# just not user-controlled). Reuse by name so repeat encounters compound
	# the same relationship instead of spawning a fresh person each time.
	var npc: Dictionary = PetStore.find_or_create_npc_by_name(Clubs.random_member_name())
	PetStore.add_bond(pet.get("id", ""), npc.get("id", ""), 1)

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
	var happiness_delta: int = int(action.get("happiness_delta", 0))
	if happiness_delta != 0:
		Stats.apply_happiness_delta(pet, int(GameClock._total_game_minutes), happiness_delta)
	var money_reward: int = int(action.get("money_reward", 0))
	# Only family members fund the family pot. NPCs run actions of their own
	# but their rewards stay off the player's books.
	if money_reward != 0 and String(pet.get("kind", "family")) == "family":
		Family.add_money(money_reward)
	if action.has("sets_school"):
		pet["school"] = String(action["sets_school"])
	if action_id == "club_activity":
		_form_club_bond(pet, String(a.get("club_id", "")))
	var counts: Dictionary = pet.get("action_counts", {})
	counts[action_id] = int(counts.get(action_id, 0)) + 1
	pet["action_counts"] = counts
	PetStore.persist()
	return {
		"action_id": action_id,
		"effects": effects,
		"money": money_reward,
	}
