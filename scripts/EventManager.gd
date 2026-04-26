extends Node

# Autoload. Watches GameClock and fires life-cycle events for the
# protagonist's family (partner arrival, child birth). UI layers subscribe
# to the signals and respond (show banner, refresh tree).

signal partner_candidate_appeared(partner: Dictionary)
signal child_naming_requested(pending_child: Dictionary)
signal child_born(child: Dictionary)
signal pet_died(pet: Dictionary)

const PARTNER_EVENT_AT_GAME_MINUTES := 30    # 30 game min after start (= 30 real sec)
const CHILD_EVENT_DELAY_GAME_MINUTES := 60   # 60 game min after marriage
const MAX_CHILDREN := 1

var _partner_candidate: Dictionary = {}
var _partner_notified := false
var _pending_child: Dictionary = {}

func _ready() -> void:
	GameClock.time_changed.connect(_tick)

func _tick() -> void:
	var proto := PetStore.protagonist()
	if proto.is_empty():
		return

	_check_deaths()
	_tick_actions()
	_tick_economy()
	# Marriage and child events no longer fire automatically. They must be
	# triggered explicitly (e.g. via a future "결혼하기" / "자녀 갖기" action),
	# which can call `_maybe_fire_partner_event` / `_maybe_fire_child_event`
	# directly or set `_partner_candidate` / `_pending_child` themselves.

func _tick_actions() -> void:
	var proto := PetStore.protagonist()
	var proto_id: String = proto.get("id", "") if not proto.is_empty() else ""
	var now_total := int(GameClock._total_game_minutes)
	for pet in PetStore.all():
		Actions.tick(pet)
		if pet.get("id", "") == proto_id:
			continue
		if not Stats.is_alive(pet, now_total):
			continue
		if Actions.is_busy(pet):
			continue
		_auto_pick_action(pet, now_total)

func _auto_pick_action(pet: Dictionary, now_minutes: int) -> void:
	var ids: Array = Actions.available_ids(pet, now_minutes)
	# Decisions like school enrolment are deliberate player choices, not
	# something the auto-loop should make for non-protagonist pets.
	ids = ids.filter(func(id):
		var entry: Dictionary = Actions.CATALOG[id]
		if entry.has("sets_school") or entry.has("opens_picker"):
			return false
		if Actions.is_on_cooldown(pet, id):
			return false
		return true
	)
	if ids.is_empty():
		return
	var pick: String = ids[randi() % ids.size()]
	Actions.start(pet, pick)

# Per-tick economy: jobs add income, enrolled schools drain cost, graduation
# clears the school field once the pet leaves 아동기. Net delta is applied to
# Family in a single call so we don't write the family file three times per
# tick.
func _tick_economy() -> void:
	var now_total := int(GameClock._total_game_minutes)
	var net_delta: int = 0
	var pets_changed: bool = false
	for pet in PetStore.all():
		if not Stats.is_alive(pet, now_total):
			continue
		var job_id: Variant = pet.get("job")
		if job_id != null:
			net_delta += Jobs.income_per_second(String(job_id))
		var school_id: Variant = pet.get("school")
		if school_id != null:
			var phase_id: String = String(Stats.current_phase(pet, now_total).get("id", ""))
			if phase_id != "child":
				pet["school"] = null
				pets_changed = true
			else:
				net_delta -= Schools.cost_per_second(String(school_id))
	if net_delta != 0:
		Family.add_money(net_delta)
	if pets_changed:
		PetStore.persist()

func _check_deaths() -> void:
	var now_total := int(GameClock._total_game_minutes)
	var changed := false
	for pet in PetStore.all():
		if pet.get("died_at_minutes") != null:
			continue
		if not Stats.is_alive(pet, now_total):
			pet["died_at_minutes"] = now_total
			changed = true
			pet_died.emit(pet)
	if changed:
		PetStore.persist()

func partner_candidate() -> Dictionary:
	return _partner_candidate

func reset() -> void:
	_partner_candidate = {}
	_partner_notified = false
	_pending_child = {}

func accept_partner() -> void:
	if _partner_candidate.is_empty():
		return
	var proto := PetStore.protagonist()
	var at := int(GameClock._total_game_minutes)
	_partner_candidate["born_at_minutes"] = at
	PetStore.add_pet(_partner_candidate)
	PetStore.marry(proto.get("id", ""), _partner_candidate.get("id", ""), at)
	_partner_candidate = {}

func _maybe_fire_partner_event(proto: Dictionary, minutes_since_start: int) -> void:
	if proto.get("spouse_id") != null:
		return
	if not _partner_candidate.is_empty():
		return
	if minutes_since_start < PARTNER_EVENT_AT_GAME_MINUTES:
		return
	_partner_candidate = PetStore.generate_random_pet()
	if not _partner_notified:
		_partner_notified = true
		partner_candidate_appeared.emit(_partner_candidate)

func _maybe_fire_child_event(proto: Dictionary, now_total_minutes: int) -> void:
	if proto.get("spouse_id") == null:
		return
	var children := PetStore.children_of(proto)
	if children.size() >= MAX_CHILDREN:
		return
	var last_ts: int = int(proto.get("married_at_minutes", 0))
	for c in children:
		last_ts = max(last_ts, int(c.get("born_at_minutes", 0)))
	if now_total_minutes - last_ts < CHILD_EVENT_DELAY_GAME_MINUTES:
		return
	if not _pending_child.is_empty():
		return  # waiting for the user to confirm a name
	var spouse := PetStore.spouse_of(proto)
	if spouse.is_empty():
		return
	# Pre-roll the child so the naming modal can show its appearance.
	_pending_child = Genetics.create_child(proto, spouse, PetStore.all(), now_total_minutes)
	child_naming_requested.emit(_pending_child)

func has_pending_child() -> bool:
	return not _pending_child.is_empty()

func pending_child() -> Dictionary:
	return _pending_child

func confirm_child_birth(child_name: String) -> void:
	if _pending_child.is_empty():
		return
	var clean_name := child_name.strip_edges()
	if not clean_name.is_empty():
		_pending_child["given_name"] = clean_name
	PetStore.add_pet(_pending_child)
	var saved := _pending_child
	_pending_child = {}
	child_born.emit(saved)

func suggest_random_name() -> String:
	if PetStore.GIVEN_NAMES.is_empty():
		return ""
	return PetStore.GIVEN_NAMES[randi() % PetStore.GIVEN_NAMES.size()]
