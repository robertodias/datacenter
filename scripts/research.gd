extends RefCounted
## Research consumes physical compute before customers. Completed projects stop drawing.
const Economy=preload("res://scripts/economy.gd")
const Geo=preload("res://scripts/town_rules.gd")
const PROJECTS={
	"optimize":{"name":"Right-sized inference","branch":"Engineer","work":600,"requires":"","brief":"Server halls use 10% less electricity and cooling. Capacity stays the same."},
	"predict":{"name":"Predictive maintenance","branch":"Engineer","work":1600,"requires":"optimize","brief":"Equipment wears 35% slower. Condition warnings arrive below 65%, instead of 55%. Crews and repairs still cost money."},
	"discover":{"name":"Customer scout","branch":"Commercial","work":600,"requires":"","brief":"Discover local inference customers and negotiate 20% lower failure/cancellation fees on newly signed contracts. Existing terms stay fixed."},
	"outreach":{"name":"AI open days","branch":"Commercial","work":1600,"requires":"discover","brief":"Unlock $1,200 district campaigns: 48h of stronger adoption and 15 extra compute of demand. Unserved promises cause reliability complaints."},
	"scheduler":{"name":"Experimental scheduler","branch":"Visionary","work":600,"requires":"","brief":"Experimental throughput bottoms at 90%, up from 65%; its 115% peak stays unchanged. Discover unusual research commissions."},
	"water_loop":{"name":"Water recovery loop","branch":"Visionary","work":1600,"requires":"scheduler","brief":"Cooling uses 35% less water but cooling plants draw 10% more electricity. Useful where water pressure is the constraint."}}

static func fresh() -> Dictionary:
	return {"project":"","allocation":0,"progress":{},"completed":[],"campaigns":{},"ticket":0,"vision_ticket":0,"comments":[],"seen":[],"last_comment":-6}

static func has(sim,id:String) -> bool:
	return id in sim.research.get("completed",[])

static func reason(sim,id:String) -> String:
	if not PROJECTS.has(id): return "Choose a research project."
	if has(sim,id): return "Research already completed."
	var prerequisite:String=PROJECTS[id].requires
	if prerequisite!="" and not has(sim,prerequisite): return "First complete "+PROJECTS[prerequisite].name+"."
	return ""

static func select(sim,id:String) -> String:
	var error=reason(sim,id)
	if error!="": return error
	sim.research.project=id
	return ""

static func allocate(sim,percent:int) -> String:
	if percent not in [0,10,25,50]: return "Choose 0%, 10%, 25% or 50%."
	sim.research.allocation=percent
	return ""

static func draw(sim,online:float) -> float:
	var id:String=sim.research.get("project","")
	if id=="" or has(sim,id): return 0.0
	return minf(online*sim.research.allocation/100.0,maxf(0,PROJECTS[id].work-sim.research.progress.get(id,0.0)))

static func campaign_active(sim,ward:String) -> bool:
	return sim.research.get("campaigns",{}).get(ward,0)>sim.hour

static func campaign(sim,ward:String,preview:bool=false) -> String:
	if not Geo.DISTRICTS.has(ward): return "Choose a district."
	if not has(sim,"outreach"): return "Research AI open days first."
	if campaign_active(sim,ward): return "This district's campaign is already running."
	if sim.cash<1200: return "An AI open day costs $1,200."
	if preview: return ""
	sim.post("community",-1200,"AI open day: "+Geo.DISTRICTS[ward].name)
	sim.research.campaigns[ward]=sim.hour+48
	say(sim,"campaign_"+ward,"I promised "+Geo.DISTRICTS[ward].name+" useful AI. Fifteen compute of new demand, and forty-eight hours to live up to the invitation.")
	return ""

static func offer(sim,vision:bool=false) -> Dictionary:
	var ticket:int=sim.research.vision_ticket if vision else sim.research.ticket
	var id=("vision_" if vision else "scout_")+str(ticket)
	return Economy.contract({"id":id,"type":"project" if vision else "service","compute":120 if vision else 50,"work":3600 if vision else 1200,"deadline":40 if vision else 24,"reward":5200 if vision else 900,"rate":0.0 if vision else 2.1,"unlock":0,"workload":"experimental" if vision else "inference","min_delivery":0.85 if vision else 0.95})

static func say(sim,key:String,message:String) -> void:
	if key in sim.research.seen: return
	sim.research.seen.append(key)
	if sim.research.seen.size()>64: sim.research.seen.pop_front()
	sim.research.comments.push_front({"hour":sim.hour,"message":message})
	if sim.research.comments.size()>12: sim.research.comments.resize(12)
	sim.research.last_comment=sim.hour

static func advance(sim,m:Dictionary) -> void:
	var state:Dictionary=sim.research
	var id:String=state.project
	if id!="" and m.research_compute>0:
		state.progress[id]=snappedf(minf(PROJECTS[id].work,state.progress.get(id,0.0)+m.research_compute),0.000001)
		if state.progress[id]>=PROJECTS[id].work:
			state.completed.append(id);state.project=""
			sim.notices.append("Research complete: "+PROJECTS[id].name+". Compute returns to customers and the spot market.")
			say(sim,"research_"+id,PROJECTS[id].branch+" insight complete: "+PROJECTS[id].name+". "+PROJECTS[id].brief)
	if sim.hour-state.last_comment<6: return
	for ward in sim.civic.wards:
		if sim.civic.wards[ward].stage>=3:
			var key="protest_"+ward
			if key not in state.seen:
				say(sim,key,Geo.DISTRICTS[ward].name+" is demonstrating. Their demand: "+sim.Civic.CAUSES[sim.civic_reports[ward].primary]+". Apparently more compute is not the answer to everything.");return
	for lot in sim.lots:
		if lot.get("preserved",false):
			var key="preserved_%d_%d" % [lot.x,lot.y]
			if key not in state.seen:
				say(sim,key,"You preserved the "+lot.kind+" in "+Geo.DISTRICTS[lot.district].name+". A useful reminder that some memory belongs to the town.");return
	for c in sim.active:
		if c.id.begins_with("scout_") or c.id.begins_with("vision_"):
			if c.id not in state.seen:
				say(sim,c.id,"You accepted "+c.name+", my introduction. I would allocate the capacity before allocating the congratulations.");return
	if not m.failures.is_empty(): say(sim,"first_failure","Failed equipment is losing capacity. Operations can dispatch a repair; research cannot solder a circuit board.")

static func personality(sim) -> String:
	var counts={"Engineer":0,"Commercial":0,"Visionary":0}
	for id in sim.research.completed: counts[PROJECTS[id].branch]+=1
	var dominant="Curious";var highest=0
	for branch in counts:
		if counts[branch]>highest: highest=counts[branch];dominant=branch
	return dominant

static func valid(state) -> bool:
	if not state is Dictionary: return false
	if not state.get("project") is String or (state.project!="" and not PROJECTS.has(state.project)): return false
	if not Economy.number(state.get("allocation")) or state.allocation!=int(state.allocation) or int(state.allocation) not in [0,10,25,50]: return false
	for key in ["ticket","vision_ticket","last_comment"]:
		if not Economy.number(state.get(key)) or state[key]!=int(state[key]) or state[key]<(-6 if key=="last_comment" else 0): return false
	if not state.get("completed") is Array or state.completed.size()>PROJECTS.size(): return false
	var seen=[]
	for id in state.completed:
		if not id is String or not PROJECTS.has(id) or id in seen: return false
		seen.append(id)
	for id in seen:
		if PROJECTS[id].requires!="" and PROJECTS[id].requires not in seen: return false
	if state.project!="" and (state.project in seen or (PROJECTS[state.project].requires!="" and PROJECTS[state.project].requires not in seen)): return false
	if not state.get("progress") is Dictionary or state.progress.size()>PROJECTS.size(): return false
	for id in state.progress:
		if not PROJECTS.has(id) or not Economy.number(state.progress[id]) or state.progress[id]<0 or state.progress[id]>PROJECTS[id].work: return false
	for id in seen:
		if state.progress.get(id,0)!=PROJECTS[id].work: return false
	if not state.get("campaigns") is Dictionary or state.campaigns.size()>Geo.DISTRICTS.size(): return false
	for ward in state.campaigns:
		if not Geo.DISTRICTS.has(ward) or not Economy.number(state.campaigns[ward]) or state.campaigns[ward]<0 or state.campaigns[ward]!=int(state.campaigns[ward]): return false
	if not state.campaigns.is_empty() and "outreach" not in seen: return false
	if not state.get("comments") is Array or state.comments.size()>12 or not state.get("seen") is Array or state.seen.size()>64: return false
	for entry in state.comments:
		if not entry is Dictionary or not entry.get("message") is String or entry.message.length()>600 or not Economy.number(entry.get("hour")) or entry.hour<0: return false
	for key in state.seen:
		if not key is String or key.length()>100: return false
	return true

static func normalize(state:Dictionary) -> Dictionary:
	var result=state.duplicate(true)
	for key in ["allocation","ticket","vision_ticket","last_comment"]: result[key]=int(result[key])
	for key in result.progress: result.progress[key]=snappedf(float(result.progress[key]),0.000001)
	for key in result.campaigns: result.campaigns[key]=int(result.campaigns[key])
	for entry in result.comments: entry.hour=int(entry.hour)
	return result

static func negotiate(sim,contract:Dictionary) -> Dictionary:
	if has(sim,"discover"): contract.penalty_rate*=0.8
	contract.penalty_rate*=1.0-0.1*sim.workforce.get("commercial",0)
	if contract.type=="project": contract.deadline+=4*sim.workforce.get("commercial",0)
	return contract
