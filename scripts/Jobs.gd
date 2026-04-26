class_name Jobs
extends RefCounted

# Job catalogue. Data lives in `data/jobs.json`, loaded into CATALOG +
# STARTING_JOB at boot by CatalogLoader. Each job earns `income_per_second`
# for the family while a living pet has it assigned. `category` is
# informational for now; future unlocks can gate by stats / education /
# phase. The protagonist starts with STARTING_JOB on creation.

static var CATALOG: Dictionary = {}
static var STARTING_JOB: String = ""

static func income_per_second(job_id: String) -> int:
	return int(CATALOG.get(job_id, {}).get("income_per_second", 0))

static func label(job_id: String) -> String:
	return String(CATALOG.get(job_id, {}).get("label", ""))

static func category(job_id: String) -> String:
	return String(CATALOG.get(job_id, {}).get("category", ""))
