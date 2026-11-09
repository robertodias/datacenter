extends RefCounted
const TOWNS={
	"littlebrook":{"name":"Littlebrook","brief":"A riverside town with industrial land, homes and a proud local history. Learn to serve customers while keeping the neighborhood livable.","goal":"Deliver eight campaign customers. Expand responsibly, learn resilience, and keep building after the finale.","next":"sunsprawl"},
	"sandbox":{"name":"Littlebrook Sandbox","brief":"The riverside town with a $1,000,000 starting budget. All systems remain active; build your own experiment.","goal":"No required finale. The eight customer milestones remain available as optional goals.","next":""},
	"sunsprawl":{"name":"Sunsprawl","brief":"A dry suburban town. There is no river cooling bonus. Everyday heat raises cooling demand 10%, cooling output is 15% lower, and grid supply is 10% lower.","goal":"Deliver eight customers and sustain at least 400 online compute at 95% uptime, using at most 80 water units, for 24 consecutive hours.","next":"oldbridge"},
	"oldbridge":{"name":"Oldbridge","brief":"A dense historic town with six protected monuments and more expensive redevelopment. Heritage demolition doubles the lasting civic grievance.","goal":"Deliver eight customers, preserve three landmarks or parks, rehouse every displaced family, and reach 65% public approval.","next":""}}
static func info(id:String) -> Dictionary:
	return TOWNS.get(id,TOWNS.littlebrook)
static func fresh() -> Dictionary:
	return {"sustainable_hours":0,"best_sustainable":0,"completed_hour":-1,"distinctions":[]}
static func conserved(sim) -> int:
	return sim.lots.filter(func(lot):return lot.get("preserved",false)).size()
static func displaced(sim) -> int:
	var total=0
	for ward in sim.civic.wards.values(): total+=ward.displaced
	return total
static func advance(sim,m:Dictionary) -> void:
	var p:Dictionary=sim.scenario_progress
	if m.compute>=400 and m.efficiency>=0.95 and m.water_use<=80:
		p.sustainable_hours+=1;p.best_sustainable=maxi(p.best_sustainable,p.sustainable_hours)
	else: p.sustainable_hours=0
static func ready(sim) -> bool:
	if sim.campaign_count()<8: return false
	if sim.scenario_id=="sunsprawl": return sim.scenario_progress.best_sustainable>=24
	if sim.scenario_id=="oldbridge": return conserved(sim)>=3 and displaced(sim)==0 and sim.approval>=65
	return true
static func finish(sim) -> void:
	if sim.scenario_progress.completed_hour>=0: return
	sim.scenario_progress.completed_hour=sim.hour
	if not sim.rescued: sim.scenario_progress.distinctions.append("Self-reliant / no rescue grant")
	if sim.finance.debt==0: sim.scenario_progress.distinctions.append("Debt-free at the finale")
	if displaced(sim)==0 and conserved(sim)>=3: sim.scenario_progress.distinctions.append("Town steward / preservation and rehousing")
	if sim.scenario_progress.best_sustainable>=48: sim.scenario_progress.distinctions.append("Resource guardian / 48 sustainable hours")
static func objectives(sim) -> Array:
	var rows=[{"text":"Establish a campus and earn $1,200","done":sim.won},{"text":"Deliver two customers / unlock tier 2","done":sim.campaign_count()>=2},{"text":"Deliver four customers / unlock tier 3","done":sim.campaign_count()>=4},{"text":"Deliver all eight campaign customers","done":sim.campaign_count()>=8}]
	if sim.scenario_id=="sunsprawl": rows.append({"text":"Sustainable operation: best %d / 24 consecutive hours; current %dh" % [sim.scenario_progress.best_sustainable,sim.scenario_progress.sustainable_hours],"done":sim.scenario_progress.best_sustainable>=24})
	if sim.scenario_id=="oldbridge":
		rows.append({"text":"Preserve three sites: %d / 3" % conserved(sim),"done":conserved(sim)>=3})
		rows.append({"text":"Rehouse displaced families: %d still waiting" % displaced(sim),"done":displaced(sim)==0})
		rows.append({"text":"Public approval: %d%% / 65%%" % sim.approval,"done":sim.approval>=65})
	return rows
static func valid(data) -> bool:
	if not data is Dictionary: return false
	for key in ["sustainable_hours","best_sustainable","completed_hour"]:
		if not (data.get(key) is int or data.get(key) is float) or not is_finite(data[key]) or data[key]!=int(data[key]) or data[key]<(-1 if key=="completed_hour" else 0): return false
	if data.sustainable_hours>data.best_sustainable or not data.get("distinctions") is Array or data.distinctions.size()>4: return false
	for entry in data.distinctions:
		if entry not in ["Self-reliant / no rescue grant","Debt-free at the finale","Town steward / preservation and rehousing","Resource guardian / 48 sustainable hours"]: return false
	return true
static func normalize(data:Dictionary) -> Dictionary:
	var result=data.duplicate(true)
	for key in ["sustainable_hours","best_sustainable","completed_hour"]: result[key]=int(result[key])
	return result
