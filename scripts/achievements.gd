extends RefCounted
const ITEMS={
	"FIRST_WATT":{"name":"First watt","detail":"Establish a working campus and earn $1,200."},
	"TRUSTED_PROVIDER":{"name":"Trusted provider","detail":"Deliver two campaign customers."},
	"NEURAL_SCALE":{"name":"Neural scale","detail":"Unlock tier 3 through four customer deliveries."},
	"FEED_THE_AI":{"name":"Feed the AI","detail":"Complete a compute-funded research project."},
	"HUMAN_TOUCH":{"name":"The human touch","detail":"Finish a repair or service visit with a technician team employed."},
	"TOWN_STEWARD":{"name":"Town steward","detail":"Permanently preserve three parks or landmarks."},
	"LIGHTS_ON":{"name":"Keep the lights on","detail":"Finish an incident with backup power used and no lost compute."},
	"LITTLEBROOK":{"name":"Littlebrook's future","detail":"Complete Littlebrook's charter."},
	"SUNSPRAWL":{"name":"Beat the heat","detail":"Complete Sunsprawl's sustainable-operation charter."},
	"OLDBRIDGE":{"name":"History and capacity","detail":"Complete Oldbridge's preservation charter."}}
static func capture(sim) -> void:
	if sim.scenario_id=="sandbox": return
	var conditions={"FIRST_WATT":sim.won,"TRUSTED_PROVIDER":sim.campaign_count()>=2,"NEURAL_SCALE":sim.campaign_count()>=4,"FEED_THE_AI":not sim.research.completed.is_empty(),"HUMAN_TOUCH":sim.workforce.technicians>0 and sim.workforce.history.any(func(j):return j.kind in ["service","repair"]),"TOWN_STEWARD":sim.Scenarios.conserved(sim)>=3,"LIGHTS_ON":sim.ops.results.any(func(r):return r.lost_compute<0.001 and r.backup_mwh>0),"LITTLEBROOK":sim.scenario_id=="littlebrook" and sim.campaign_won,"SUNSPRAWL":sim.scenario_id=="sunsprawl" and sim.campaign_won,"OLDBRIDGE":sim.scenario_id=="oldbridge" and sim.campaign_won}
	for id in conditions:
		if conditions[id] and id not in sim.achievements:
			sim.achievements.append(id);sim.notices.append("Achievement: "+ITEMS[id].name)
static func valid(data) -> bool:
	if not data is Array or data.size()>ITEMS.size(): return false
	var seen=[]
	for id in data:
		if not id is String or not ITEMS.has(id) or id in seen: return false
		seen.append(id)
	return true
