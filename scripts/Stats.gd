class_name Stats
extends RefCounted

# Pet attribute system. Six base stats are stored on each pet at birth and
# stay constant; the displayed value is `base * age_factor(age, lifespan)`,
# producing a rise/peak/decline curve over the pet's life.

const KEYS := ["strength", "intelligence", "charisma", "stamina", "agility", "luck"]
const LABELS := {
	"strength": "근력",
	"intelligence": "지능",
	"charisma": "매력",
	"stamina": "체력",
	"agility": "민첩",
	"luck": "운",
}
const STAT_MIN := 1
const STAT_MAX := 10

# Day length in game minutes (mirrors GameClock).
const DAY_MINUTES := 24 * 60

# Development-tier lifespan: 1~3 game days. Tune this single source later.
const LIFESPAN_MINUTES_MIN := 1 * DAY_MINUTES
const LIFESPAN_MINUTES_MAX := 3 * DAY_MINUTES

# --- factories ----------------------------------------------------------

static func random_base_stats() -> Dictionary:
	var s := {}
	for k in KEYS:
		s[k] = randi_range(4, 8)
	return s

static func random_lifespan_minutes() -> int:
	return randi_range(LIFESPAN_MINUTES_MIN, LIFESPAN_MINUTES_MAX)

static func inherit_stats(parent_a_stats: Dictionary, parent_b_stats: Dictionary) -> Dictionary:
	var s := {}
	for k in KEYS:
		var av: float = float(parent_a_stats.get(k, 5))
		var bv: float = float(parent_b_stats.get(k, 5))
		var avg: float = (av + bv) * 0.5
		var jitter: float = randf_range(-2.0, 2.0)
		s[k] = clampi(int(round(avg + jitter)), STAT_MIN, STAT_MAX)
	return s

# --- age curve ----------------------------------------------------------

static func age_minutes(pet: Dictionary, now_minutes: int) -> int:
	return max(0, now_minutes - int(pet.get("born_at_minutes", 0)))

static func age_factor(age_min: int, lifespan_min: int) -> float:
	if lifespan_min <= 0:
		return 1.0
	var p: float = float(age_min) / float(lifespan_min)
	if p >= 1.0:
		return 0.0
	if p <= 0.2:
		return lerp(0.3, 0.7, p / 0.2)
	if p <= 0.6:
		return lerp(0.7, 1.0, (p - 0.2) / 0.4)
	return lerp(1.0, 0.3, (p - 0.6) / 0.4)

static func life_phase(age_min: int, lifespan_min: int) -> String:
	if lifespan_min <= 0:
		return "—"
	var p: float = float(age_min) / float(lifespan_min)
	if p >= 1.0:
		return "사망"
	if p <= 0.2:
		return "유년기"
	if p <= 0.6:
		return "청년기"
	return "노년기"

# --- queries ------------------------------------------------------------

static func current_stats(pet: Dictionary, now_minutes: int) -> Dictionary:
	var base: Dictionary = pet.get("stats", {})
	var lifespan_min: int = int(pet.get("lifespan_minutes", DAY_MINUTES))
	var age_min := age_minutes(pet, now_minutes)
	var f := age_factor(age_min, lifespan_min)
	var out := {}
	for k in KEYS:
		var v: int = int(round(float(base.get(k, 5)) * f))
		out[k] = clampi(v, 0, STAT_MAX)
	return out

static func is_alive(pet: Dictionary, now_minutes: int) -> bool:
	if pet.get("died_at_minutes") != null:
		return false
	var lifespan_min: int = int(pet.get("lifespan_minutes", DAY_MINUTES))
	return age_minutes(pet, now_minutes) < lifespan_min
