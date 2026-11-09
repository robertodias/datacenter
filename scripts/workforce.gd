extends RefCounted
const Economy=preload("res://scripts/economy.gd")
const ROLES={"technicians":{"name":"Technicians","wage":7,"brief":"Each team automatically dispatches one service visit at a time. Normal visit fees still apply; failed equipment and condition below 45% enter the queue."},"engineers":{"name":"Engineers","wage":9,"brief":"Each team removes one hour from new service visits and hardware refits, to a minimum of one hour. Work already underway keeps its agreed duration."},"commercial":{"name":"Commercial staff","wage":6,"brief":"Each team negotiates four extra hours for new project deadlines and 10% lower new failure/cancellation fees. Service durations and existing contracts stay fixed."}}
const PRIORITIES=["Failures first","Utilities first","Halls first"]
static func fresh() -> Dictionary:
	return {"technicians":0,"engineers":0,"commercial":0,"priority":"Failures first","jobs":[],"history":[],"next_id":0}
static func wages(sim) -> float:
	var total=0.0
	for role in ROLES: total+=sim.workforce.get(role,0)*ROLES[role].wage
	return total
static func set_team(sim,role:String,count:int) -> String:
	if not ROLES.has(role) or count<0 or count>3: return "Choose zero to three teams per role."
	sim.workforce[role]=count
	return ""
static func duration(sim,base:int) -> int:
	return maxi(1,base-int(sim.workforce.get("engineers",0)))
static func dispatch(sim,kind:String,site:int,hours:int) -> void:
	if sim.workforce.jobs.size()>=256: return
	sim.workforce.jobs.append({"id":int(sim.workforce.next_id),"kind":kind,"site":site,"start":sim.hour,"end":sim.hour+hours})
	sim.workforce.next_id+=1
static func priority_value(sim,lot:Dictionary) -> int:
	if sim.workforce.priority=="Utilities first": return (0 if lot.kind!="datacenter" else 100)+int(lot.get("condition",100))
	if sim.workforce.priority=="Halls first": return (0 if lot.kind=="datacenter" else 100)+int(lot.get("condition",100))
	return (0 if lot.get("failed",false) else 100)+int(lot.get("condition",100))
static func advance(sim) -> void:
	var state:Dictionary=sim.workforce
	for job in state.jobs:
		if job.end<=sim.hour:
			state.history.push_front(job.duplicate())
			if state.history.size()>20: state.history.resize(20)
	state.jobs=state.jobs.filter(func(job):return job.end>sim.hour)
	if state.technicians<=0: return
	var occupied=sim.lots.filter(func(lot):return sim.BUILDINGS.has(lot.kind) and int(lot.get("service_until",0))>sim.hour).size()
	var capacity=int(state.technicians)+(1 if sim.ops.crews else 0)
	var queue=sim.lots.filter(func(lot):return sim.BUILDINGS.has(lot.kind) and (lot.get("failed",false) or lot.get("condition",100)<45) and int(lot.get("service_until",0))<=sim.hour and int(lot.get("refit_until",0))<=sim.hour)
	queue.sort_custom(func(a,b):
		var left=priority_value(sim,a);var right=priority_value(sim,b)
		return sim.cell(int(a.x),int(a.y))<sim.cell(int(b.x),int(b.y)) if left==right else left<right)
	for lot in queue:
		if occupied>=capacity: break
		var index=sim.cell(int(lot.x),int(lot.y))
		if sim.Operations.act(sim,"service",index)=="":
			occupied+=1;sim.Operations.alert(sim.ops,"Technician team dispatched to %02d-%02d." % [lot.x+1,lot.y+1],index)
static func valid(state) -> bool:
	if not state is Dictionary or not state.get("priority") in PRIORITIES: return false
	for role in ROLES:
		if not Economy.number(state.get(role)) or state[role]!=int(state[role]) or state[role]<0 or state[role]>3: return false
	if not Economy.number(state.get("next_id")) or state.next_id<0 or state.next_id!=int(state.next_id): return false
	if not state.get("jobs") is Array or state.jobs.size()>256 or not state.get("history") is Array or state.history.size()>20: return false
	var ids=[]
	for job in state.jobs+state.history:
		if not job is Dictionary or job.get("kind") not in ["construction","upgrade","refit","service","repair"]: return false
		for key in ["id","site","start","end"]:
			if not Economy.number(job.get(key)) or job[key]!=int(job[key]) or job[key]<0: return false
		if job.site>=256 or job.end<=job.start or job.end-job.start>4 or job.id>=state.next_id or job.id in ids: return false
		ids.append(job.id)
	return true
static func normalize(state:Dictionary) -> Dictionary:
	var result=state.duplicate(true)
	for key in ["technicians","engineers","commercial","next_id"]: result[key]=int(result[key])
	for job in result.jobs+result.history:
		for key in ["id","site","start","end"]: job[key]=int(job[key])
	return result
