class_name PetStore
extends RefCounted

# Persists a lineage of tamagotchi pets. The first pet created is the
# protagonist; every subsequent pet is linked via `parent_ids` / `spouse_id`.

const SAVE_PATH := "user://pets.json"
const GIVEN_NAMES := [
	"루피", "모모", "콩이", "보리", "초코", "뚱이", "호야", "밤이",
	"삐삐", "달이", "별이", "솜이", "두부", "호떡", "복실", "쫀득",
	"살구", "참외", "메롱", "방울", "포실", "꼬물", "만두", "빵이"
]

static var _pets: Array = []
static var _loaded: bool = false

# --- load/save -----------------------------------------------------------

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(SAVE_PATH):
		var text := FileAccess.get_file_as_string(SAVE_PATH)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Array:
			_pets = parsed
	_migrate_pets()

# Backfill missing fields on pets loaded from older save files.
static func _migrate_pets() -> void:
	var changed := false
	var now_total := int(GameClock._total_game_minutes)
	for pet in _pets:
		if not pet.has("stats"):
			pet["stats"] = Stats.random_base_stats()
			changed = true
		if not pet.has("lifespan_minutes"):
			pet["lifespan_minutes"] = Stats.random_lifespan_minutes()
			changed = true
		if not pet.has("died_at_minutes"):
			pet["died_at_minutes"] = null
			changed = true
		if not pet.has("action_counts"):
			pet["action_counts"] = {}
			changed = true
		if not pet.has("active_action"):
			pet["active_action"] = null
			changed = true
		if not pet.has("gender"):
			pet["gender"] = random_gender()
			changed = true
		if not pet.has("school"):
			pet["school"] = null
			changed = true
		if not pet.has("job"):
			pet["job"] = null
			changed = true
		if not pet.has("clubs"):
			pet["clubs"] = []
			changed = true
		if not pet.has("bonds"):
			pet["bonds"] = {}
			changed = true
		if not pet.has("action_cooldowns"):
			pet["action_cooldowns"] = {}
			changed = true
		if not pet.has("bond_cooldowns"):
			pet["bond_cooldowns"] = {}
			changed = true
		if not pet.has("happiness"):
			pet["happiness"] = Stats.HAPPINESS_START
			pet["happiness_updated_at_minutes"] = now_total
			changed = true
		else:
			# Legacy bond_cooldowns were `{npc_id: until_min}` (hangout-only).
			# New format: `{"{npc_id}::{action}": until_min}` so each
			# interaction (hangout / date / ...) tracks separately.
			var cd: Dictionary = pet["bond_cooldowns"]
			var promoted: Dictionary = {}
			var did_promote := false
			for k in cd.keys():
				var key := String(k)
				if "::" in key:
					promoted[key] = int(cd[k])
				else:
					promoted[key + "::hangout"] = int(cd[k])
					did_promote = true
			if did_promote:
				pet["bond_cooldowns"] = promoted
				changed = true
		if not pet.has("kind"):
			# Inferred from family relations: anyone connected by spouse/parent
			# is "family"; standalone pets from earlier sessions are "npc".
			pet["kind"] = "family"
			changed = true
		# Money is now family-wide (Family.gd). Sweep any leftover per-pet
		# `money` field from older saves into the family pot, then drop it.
		if pet.has("money"):
			var carried: int = int(pet["money"])
			if carried != 0:
				Family.add_money(carried)
			pet.erase("money")
			changed = true
		# Pets generated before the lifespan was bumped keep their too-short
		# rolls and may have already been marked dead. Re-roll to the current
		# range and revive if the new lifespan puts them back in range.
		if int(pet.get("lifespan_minutes", 0)) < Stats.LIFESPAN_MINUTES_MIN:
			pet["lifespan_minutes"] = Stats.random_lifespan_minutes()
			changed = true
			if pet.get("died_at_minutes") != null:
				var age := Stats.age_minutes(pet, now_total)
				if age < int(pet["lifespan_minutes"]):
					pet["died_at_minutes"] = null
	# Promote legacy name-keyed bonds (`{name: count}`) to id-keyed ones,
	# spawning NPC pets to back each previously string-only bond.
	if _migrate_legacy_bonds():
		changed = true
	if changed:
		persist()

# Old saves stored bonds as `{display_name: count}`. Now bonds key by NPC id so
# both sides of a relationship can stay in sync. We detect legacy keys (not a
# 12-hex uid) and substitute a fresh NPC pet for each.
static func _migrate_legacy_bonds() -> bool:
	var changed := false
	for pet in _pets:
		var bonds: Dictionary = pet.get("bonds", {})
		if bonds.is_empty():
			continue
		var rebuilt: Dictionary = {}
		var did_swap := false
		for key in bonds.keys():
			var k := String(key)
			if _is_uid(k):
				rebuilt[k] = int(bonds[key])
				continue
			var npc := _find_or_create_npc_by_name(k)
			var npc_id: String = npc.get("id", "")
			rebuilt[npc_id] = int(bonds[key])
			# Reciprocal — NPC also remembers this pet at the same level.
			var npc_bonds: Dictionary = npc.get("bonds", {})
			npc_bonds[pet.get("id", "")] = max(int(npc_bonds.get(pet.get("id", ""), 0)), int(bonds[key]))
			npc["bonds"] = npc_bonds
			did_swap = true
		if did_swap:
			pet["bonds"] = rebuilt
			changed = true
	return changed

static func _is_uid(s: String) -> bool:
	if s.length() != 12:
		return false
	for c in s:
		if not ("0123456789abcdef".contains(c)):
			return false
	return true

static func _find_or_create_npc_by_name(display_name: String) -> Dictionary:
	for p in _pets:
		if p.get("kind", "") == "npc" and String(p.get("given_name", "")) == display_name:
			return p
	return _create_npc_internal(display_name)

static func create_protagonist(name: String) -> Dictionary:
	var pet := generate_random_pet({"given_name": name})
	# Protagonist starts in early 청년기 with the basic starting job. Age is
	# set to ~37% of lifespan, just inside the 청년기 band (0.36~0.52), so
	# most of young adulthood + middle/mature/elder still lies ahead.
	var lifespan: int = int(pet.get("lifespan_minutes", Stats.DAY_MINUTES))
	var start_age: int = int(0.37 * float(lifespan))
	pet["born_at_minutes"] = int(GameClock._total_game_minutes) - start_age
	pet["job"] = Jobs.STARTING_JOB
	add_pet(pet)
	return pet

static func persist() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_pets))
	# Pet `active_action.started_at_minutes` is a snapshot of GameClock at
	# write time. If the clock isn't saved alongside, a refresh restores old
	# clock + new pet state and active actions appear to restart at 0%.
	GameClock.save()

static func reset() -> void:
	_pets = []
	_loaded = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

# --- queries -------------------------------------------------------------

static func all() -> Array:
	ensure_loaded()
	return _pets

static func protagonist() -> Dictionary:
	var list := all()
	return list[0] if not list.is_empty() else {}

static func find_by_id(id: String) -> Dictionary:
	for p in all():
		if p.get("id", "") == id:
			return p
	return {}

static func family_surname() -> String:
	return protagonist().get("body_id", "")

static func spouse_of(pet: Dictionary) -> Dictionary:
	var sid: String = pet.get("spouse_id", "") if pet.get("spouse_id") != null else ""
	return find_by_id(sid)

static func children_of(parent: Dictionary) -> Array:
	var pid: String = parent.get("id", "")
	return all().filter(func(p): return pid in p.get("parent_ids", []))

# --- mutations -----------------------------------------------------------

static func add_pet(pet: Dictionary) -> void:
	ensure_loaded()
	_pets.append(pet)
	persist()

static func marry(a_id: String, b_id: String, at_game_minutes: int) -> void:
	var a := find_by_id(a_id)
	var b := find_by_id(b_id)
	if a.is_empty() or b.is_empty():
		return
	a["spouse_id"] = b_id
	b["spouse_id"] = a_id
	a["married_at_minutes"] = at_game_minutes
	b["married_at_minutes"] = at_game_minutes
	persist()

# --- factories -----------------------------------------------------------

static func generate_random_pet(overrides: Dictionary = {}) -> Dictionary:
	var all_chars := Characters.all()
	var body: Dictionary = all_chars[randi() % all_chars.size()]
	var eyes: Dictionary = all_chars[randi() % all_chars.size()]
	var pet := {
		"id": make_uid(),
		"kind": "family",
		"given_name": GIVEN_NAMES[randi() % GIVEN_NAMES.size()],
		"body_id": body.get("id", ""),
		"eyes_id": eyes.get("id", ""),
		"color": body.get("color", "#ffffff"),
		"parent_ids": [],
		"spouse_id": null,
		"born_at_minutes": 0,
		"married_at_minutes": null,
		"stats": Stats.random_base_stats(),
		"lifespan_minutes": Stats.random_lifespan_minutes(),
		"died_at_minutes": null,
		"action_counts": {},
		"active_action": null,
		"gender": random_gender(),
		"school": null,
		"job": null,
		"clubs": [],
		"bonds": {},
		"action_cooldowns": {},
		"bond_cooldowns": {},
		"happiness": Stats.HAPPINESS_START,
		"happiness_updated_at_minutes": int(GameClock._total_game_minutes),
	}
	for k in overrides:
		pet[k] = overrides[k]
	return pet

# NPCs are full pets — same shape as the protagonist, just not user-controlled.
# They're born young-adult so they're already working-age, and assigned a
# random job so the world feels populated. EventManager auto-ticks them along
# with everyone else.
static func create_npc(name: String) -> Dictionary:
	ensure_loaded()
	var npc := _create_npc_internal(name)
	persist()
	return npc

# Internal version used during migration that does NOT call persist (caller
# batches the write).
static func _create_npc_internal(name: String) -> Dictionary:
	var pet := generate_random_pet({"given_name": name, "kind": "npc"})
	var lifespan: int = int(pet.get("lifespan_minutes", Stats.DAY_MINUTES))
	# Place NPCs randomly within the 청년기/중년기 band (0.25 ~ 0.65 of life)
	# so bond candidates feel like a mix of fresh adults and seasoned ones.
	var p: float = randf_range(0.25, 0.65)
	var start_age: int = int(p * float(lifespan))
	pet["born_at_minutes"] = int(GameClock._total_game_minutes) - start_age
	var job_ids: Array = Jobs.CATALOG.keys()
	if not job_ids.is_empty():
		pet["job"] = String(job_ids[randi() % job_ids.size()])
	_pets.append(pet)
	return pet

static func find_or_create_npc_by_name(name: String) -> Dictionary:
	ensure_loaded()
	for p in _pets:
		if p.get("kind", "") == "npc" and String(p.get("given_name", "")) == name:
			return p
	var npc := _create_npc_internal(name)
	persist()
	return npc

# Mutual bond bump — both sides remember each other at +amount.
static func add_bond(a_id: String, b_id: String, amount: int) -> void:
	if amount == 0 or a_id == "" or b_id == "" or a_id == b_id:
		return
	var a := find_by_id(a_id)
	var b := find_by_id(b_id)
	if a.is_empty() or b.is_empty():
		return
	var ab: Dictionary = a.get("bonds", {})
	ab[b_id] = int(ab.get(b_id, 0)) + amount
	a["bonds"] = ab
	var bb: Dictionary = b.get("bonds", {})
	bb[a_id] = int(bb.get(a_id, 0)) + amount
	b["bonds"] = bb
	persist()

static func make_uid() -> String:
	var s := ""
	for i in 12:
		s += "%x" % (randi() % 16)
	return s

static func random_gender() -> String:
	return "male" if randi() % 2 == 0 else "female"
