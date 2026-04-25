class_name Jobs
extends RefCounted

# Job catalogue. Each job earns `income_per_second` for the family while a
# living pet has it assigned. `category` is informational for now; future
# unlocks can gate by stats / education / phase. The protagonist starts with
# `STARTING_JOB` ("clerk", a basic-tier office job) on creation.

const STARTING_JOB := "clerk"

const CATALOG := {
	"clerk":     {"label": "신입 사원",   "category": "office",   "income_per_second": 3},
	"teacher":   {"label": "교사",        "category": "service",  "income_per_second": 5},
	"doctor":    {"label": "의사",        "category": "service",  "income_per_second": 10},
	"merchant":  {"label": "상인",        "category": "commerce", "income_per_second": 4},
	"athlete":   {"label": "운동선수",    "category": "sports",   "income_per_second": 6},
	"artist":    {"label": "예술가",      "category": "creative", "income_per_second": 4},
	"engineer":  {"label": "엔지니어",    "category": "technical","income_per_second": 7},
	"farmer":    {"label": "농부",        "category": "primary",  "income_per_second": 3},
}

static func income_per_second(job_id: String) -> int:
	return int(CATALOG.get(job_id, {}).get("income_per_second", 0))

static func label(job_id: String) -> String:
	return String(CATALOG.get(job_id, {}).get("label", ""))

static func category(job_id: String) -> String:
	return String(CATALOG.get(job_id, {}).get("category", ""))
