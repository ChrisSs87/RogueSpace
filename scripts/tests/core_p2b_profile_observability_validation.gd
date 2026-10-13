extends Node

## Telemetry boundary tests only. The companion real-sector fixture proves
## actual instantiation; these deliberately invalid plans do not fabricate it.
var errors: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print("P2B_OBSERVABILITY_CHECK %s %s" % [ok,label])
	if not ok: errors.append(label)

func _ready() -> void:
	var stage = preload("res://scripts/world/Stage6GProceduralPrototype.gd").new()
	var plan := ContentPlacementPlan.new()
	plan.profile_id = &"TEST_TELEMETRY_ONLY"
	plan.generation_error = "fixture invalid plan"
	stage.current_content_plan = plan
	var report: Dictionary = stage.get_sector_profile_metrics()
	check(report.applied.content == "NOT_APPLIED" and report.applied.content_status == "PLAN_REJECTED","invalid plan is not falsely labelled applied")
	plan.generation_error = ""
	report = stage.get_sector_profile_metrics()
	check(report.applied.content == "NOT_APPLIED" and report.applied.content_status == "PLANNED_PENDING_RUNTIME","planning is not runtime consumption")
	stage.current_runtime_content_report = {"error":"fixture rejected runtime input"}
	report = stage.get_sector_profile_metrics()
	check(report.applied.content == "NOT_APPLIED" and report.applied.content_status == "RUNTIME_REJECTED","runtime rejection not falsely applied")
	stage.current_runtime_content_report = {"spawned":[]}
	report = stage.get_sector_profile_metrics()
	check(report.applied.content == String(plan.profile_id) and report.applied.content_status == "CONSUMED" and report.applied.live_enemies == 0,"consumed empty plan not confused with live enemies")
	plan.budget_range = Vector2i(4,6)
	plan.requested_slot_count = 5
	plan.effective_slot_budget = 4
	report = stage.get_sector_profile_metrics()
	check(report.applied.requested_slots == 5 and report.applied.effective_budget == 4 and report.applied.selected_slots == 0 and report.limitations.has("SELECTED_SLOTS_DIFFER_FROM_BUDGET"),"budget stages distinguished, unmet selection visible")
	check(not report.applied.density_applied,"density never claimed applied")
	stage.free()
	print("P2B_OBSERVABILITY_RESULT="+JSON.stringify({"valid":errors.is_empty(),"checks":checks,"errors":errors}))
	get_tree().quit(0 if errors.is_empty() else 1)
