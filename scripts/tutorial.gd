extends RefCounted
const STEPS=[
	{"id":"inspect","title":"Meet the town","hint":"Inspect the highlighted warehouse. The property panel explains price, ownership and connections.","action":"inspect"},
	{"id":"buy","title":"Buy your first property","hint":"Buy warehouse 04-06 for $1,200. Purchasing land is separate from clearing and construction.","action":"buy"},
	{"id":"clear","title":"Make room for the campus","hint":"Demolish the owned warehouse for $250. Homes and landmarks have greater civic consequences.","action":"demolish"},
	{"id":"build","title":"Build a working campus","hint":"Build a hall at 04-06, power at 03-06 and cooling at 04-07. Check the resource meters and local links.","action":"datacenter"},
	{"id":"revenue","title":"Earn your first revenue","hint":"Run time until the campus earns $1,200. At 1×, one simulation hour takes four seconds. You can pause whenever you want.","action":"run"},
	{"id":"customer","title":"Make a customer commitment","hint":"Review a contract's capacity, deadline, margin and failure fee. Sign GPN or Synthopic when ready.","action":"contracts"},
	{"id":"upgrade","title":"Improve the campus","hint":"Deliver two customers to unlock tier 2. Select a hall or utility, review the cost, and purchase an upgrade.","action":"upgrade"},
	{"id":"prepare","title":"Prepare for the forecast","hint":"During a forecast, prepare battery/generator reserves or mobile cooling. Operations shows the projected shortfall before impact.","action":"operations"},
	{"id":"dilemma","title":"Consider the neighborhood","hint":"Inspect a home, park or landmark, then open Town council. Compare preservation, relocation and resource remedies before expanding.","action":"council"}]
static func fresh(enabled:bool=true) -> Dictionary:
	return {"enabled":enabled,"done":[]}
static func mark(sim,id:String) -> void:
	if id not in sim.tutorial.done: sim.tutorial.done.append(id)
static func capture(sim) -> void:
	if sim.bought: mark(sim,"buy")
	if sim.cleared: mark(sim,"clear")
	if sim.built and sim.metrics().compute>0: mark(sim,"clear");mark(sim,"build")
	if sim.won: mark(sim,"revenue")
	if not sim.active.is_empty() or not sim.completed.is_empty(): mark(sim,"customer")
	if sim.lots.any(func(lot):return lot.kind in sim.BUILDINGS and lot.level>1): mark(sim,"upgrade")
	for event in sim.ops.events:
		if event.phase!="forecast": continue
		if event.kind=="heatwave":
			if sim.ops.rental_until>event.start or sim.lots.any(func(lot):return lot.kind=="cooling" and lot.level>=2): mark(sim,"prepare")
		elif sim.ops.batteries>0 or (sim.ops.generators>0 and sim.ops.fuel>0): mark(sim,"prepare")
static func current(sim) -> Dictionary:
	for step in STEPS:
		if step.id not in sim.tutorial.done: return step
	return {}
static func valid(data) -> bool:
	if not data is Dictionary or not data.get("enabled") is bool or not data.get("done") is Array or data.done.size()>STEPS.size(): return false
	var ids=STEPS.map(func(s):return s.id);var seen=[]
	for id in data.done:
		if not id is String or id not in ids or id in seen: return false
		seen.append(id)
	return true
