extends RefCounted
## Clock-driven operations. All random state, phases and consumables are saved.
const Economy=preload("res://scripts/economy.gd")
const KINDS=["heatwave","grid_maintenance","outage"]
const PHASES=["pending","forecast","active","recovery","closed"]
const MAX_MODULES=12
const NAMES={"heatwave":"Heatwave","grid_maintenance":"Grid maintenance","outage":"Surprise grid fault"}

static func quantize(value:float) -> float:
	return roundf(value*1000000)/1000000.0

static func fresh() -> Dictionary:
	return {"rng":7331,"commission":-1,"next_cycle":-1,"next_id":0,"events":[],"results":[],"alerts":[],
		"batteries":0,"charge":0.0,"generators":0,"fuel":0.0,"hub":-1,"warm":false,"warm_ready":-1,"generator_ready":-1,
		"rental_until":0,"rental_site":-1,"crews":false,"total_lost_compute":0.0,"total_backup_mwh":0.0}

static func random_int(state:Dictionary,maximum:int) -> int:
	state.rng=(int(state.rng)*1103515245+12345)%2147483647
	return int(state.rng)%maximum

## Routine alerts (dispatches, reminders) are announced but never auto-pause time.
static func alert(state:Dictionary,message:String,lot:int=-1,routine:bool=false) -> void:
	var row={"message":message,"lot":lot}
	if routine: row.routine=true
	state.alerts.append(row)
	if state.alerts.size()>24: state.alerts.pop_front()

static func add_event(state:Dictionary,kind:String,start:int,duration:int,lead:int,severity:float=1.0) -> void:
	state.events.append({"id":int(state.next_id),"kind":kind,"start":start,"end":start+duration,"lead":lead,"severity":severity,"phase":"pending","lost_compute":0.0,"backup_mwh":0.0,"fuel_used":0.0})
	state.next_id+=1

static func conditions(state:Dictionary) -> Dictionary:
	var grid=1.0;var cooling=1.0;var heat=1.0;var temperature=22
	for event in state.events:
		if event.phase not in ["active","recovery"]: continue
		var recovering=event.phase=="recovery"
		if event.kind=="heatwave":
			cooling=minf(cooling,0.8 if recovering else 0.55/event.severity)
			heat=maxf(heat,1.15 if recovering else 1.4*event.severity)
			temperature=maxi(temperature,29 if recovering else int(38+20*(event.severity-1)))
		elif event.kind=="grid_maintenance": grid=minf(grid,0.8 if recovering else 0.45)
		elif event.kind=="outage": grid=minf(grid,0.75 if recovering else 0.0)
	return {"grid":grid,"cooling":cooling,"heat":heat,"temperature":temperature}

## True while any incident is forecast, active or recovering. Automatic preventive
## service waits for it to clear so crews never take healthy equipment offline mid-event.
static func incident_pending(sim) -> bool:
	return sim.ops.events.any(func(e):return e.phase in ["forecast","active","recovery"])

static func available(lot:Dictionary,hour:int) -> bool:
	return not lot.get("failed",false) and int(lot.get("service_until",0))<=hour

static func condition_factor(lot:Dictionary,hour:int) -> float:
	if not available(lot,hour): return 0.0
	return minf(1,0.5+float(lot.get("condition",100))/100.0)

static func power_plan(sim,base_power:float,power_need:float,override:Dictionary={}) -> Dictionary:
	var state:Dictionary=sim.ops
	var weather=conditions(state) if override.is_empty() else override
	var check_hour=int(weather.get("at_hour",sim.hour))
	var grid=base_power*weather.grid
	var deficit=maxf(0,power_need-grid)
	var hub_online=state.hub>=0 and state.hub<sim.lots.size() and sim.lots[int(state.hub)].kind=="power" and available(sim.lots[int(state.hub)],check_hour)
	# Modules beyond the current substation limit stay idle until another substation exists.
	var limit=module_limit(sim)
	var batteries=mini(int(state.batteries),limit);var generators=mini(int(state.generators),limit)
	var generator=0.0
	# Generators answer real grid incidents only, not a town's permanently weaker grid.
	if hub_online and weather.get("incident_grid",weather.grid)<1 and ((state.warm and state.warm_ready>=0 and check_hour>=state.warm_ready) or (state.generator_ready>=0 and check_hour>=state.generator_ready and not weather.get("startup",false))):
		generator=minf(deficit,minf(generators*180.0,state.fuel*180.0))
	var battery=minf(maxf(0,deficit-generator),minf(state.charge,batteries*120.0)) if hub_online else 0.0
	var recharge=minf(maxf(0,grid-power_need),minf(batteries*60.0,state.batteries*240.0-state.charge)) if hub_online else 0.0
	var standby=generators*0.1 if state.warm and generator==0 and state.fuel>0 else 0.0
	var fuel_used=minf(state.fuel,generator/180.0+standby)
	return {"grid_capacity":grid,"grid_used":minf(grid,power_need)+recharge,"generator":generator,"battery":battery,"recharge":recharge,"fuel_used":fuel_used,"hub_online":hub_online,"supply":grid+generator+battery}

## Three battery and three generator modules per owned substation, up to twelve.
static func module_limit(sim) -> int:
	var substations=sim.lots.filter(func(lot):return lot.kind=="power" and lot.owned).size()
	return clampi(3*substations,3,MAX_MODULES)

static func service_cost(lot:Dictionary) -> int:
	var base={"datacenter":350,"power":200,"cooling":250}.get(lot.kind,0)
	return base*int(lot.get("level",1))*(2 if lot.get("failed",false) else 1)

static func act(sim,action:String,index:int=-1) -> String:
	var state:Dictionary=sim.ops
	var cost=0.0
	var category="resilience"
	if action in ["battery","generator"]:
		var key="batteries" if action=="battery" else "generators"
		if state[key]>=module_limit(sim): return "Each owned substation supports three modules of each type (limit %d)." % module_limit(sim)
		var hub_missing=state.hub<0 or state.hub>=sim.lots.size() or sim.lots[int(state.hub)].kind!="power"
		if hub_missing:
			if index<0 or index>=sim.lots.size() or sim.lots[index].kind!="power":
				for lot in sim.lots:
					if lot.kind=="power" and lot.owned: index=sim.cell(int(lot.x),int(lot.y));break
			if index<0 or index>=sim.lots.size() or sim.lots[index].kind!="power": return "Build a substation before installing backup equipment."
		cost=1800 if action=="battery" else 2600
		if sim.cash<cost: return "Not enough cash for this backup module."
		if hub_missing: state.hub=index
		state[key]+=1
		if action=="battery": state.charge+=240.0
		elif state.generators==1 and conditions(state).grid<1: state.generator_ready=sim.hour+1
	elif action=="fuel":
		if state.generators==0: return "Install a generator before buying fuel."
		var amount=minf(12,36-state.fuel)
		if amount<0.01: return "Fuel storage is full (36 generator-hours)."
		cost=Economy.money(amount*50);category="fuel"
		if sim.cash<cost: return "Not enough cash to buy fuel."
		state.fuel+=amount
	elif action=="rental":
		if state.rental_until>sim.hour+4: return "Rental is still active. Renew during its final four hours."
		if index<0 or index>=sim.lots.size() or not sim.BUILDINGS.has(sim.lots[index].kind):
			for lot in sim.lots:
				if lot.kind=="datacenter" and lot.owned: index=sim.cell(int(lot.x),int(lot.y));break
		if index<0 or index>=sim.lots.size() or not sim.BUILDINGS.has(sim.lots[index].kind): return "Build a campus before hiring mobile cooling."
		cost=750;category="rental"
		if sim.cash<cost: return "Mobile cooling rental costs $750 for 24 hours, plus $12/h operation."
		state.rental_until=maxi(int(state.rental_until),sim.hour)+24;state.rental_site=index
	elif action=="warm":
		if state.generators==0: return "Install a generator first."
		if not state.warm and state.fuel<=0: return "Refuel the generator before enabling warm standby."
		state.warm=not state.warm
		state.warm_ready=sim.hour+1 if state.warm else -1
	elif action=="crews": state.crews=not state.crews
	elif action=="move_hub":
		if index<0 or index>=sim.lots.size() or sim.lots[index].kind!="power" or not sim.lots[index].owned: return "Select another owned substation in the town first."
		if index==state.hub: return "Backup equipment is already at this substation."
		if state.batteries+state.generators==0: return "There is no backup equipment to relocate."
		cost=500
		if sim.cash<cost: return "Moving backup equipment costs $500."
		state.hub=index
	elif action=="service":
		if index<0 or index>=sim.lots.size() or not sim.BUILDINGS.has(sim.lots[index].kind): return "Select an owned hall or utility."
		var lot:Dictionary=sim.lots[index]
		if int(lot.get("service_until",0))>sim.hour or int(lot.get("refit_until",0))>sim.hour: return "This building is already undergoing work."
		if not lot.get("failed",false) and lot.get("condition",100)>=99.9: return "This equipment is already in full condition."
		cost=service_cost(lot);category="repairs"
		if sim.cash<cost: return "Not enough cash for this service visit."
		var hours=sim.Workforce.duration(sim,4 if lot.get("failed",false) else 2)
		lot.service_until=sim.hour+hours
		sim.Workforce.dispatch(sim,"repair" if lot.get("failed",false) else "service",index,hours)
	else: return "Unknown operations action."
	if cost>0: sim.post(category,-cost,"Operations: "+action)
	return ""

static func advance(sim,m:Dictionary) -> void:
	var state:Dictionary=sim.ops
	var h:int=sim.hour
	if state.commission<0 and m.compute>0:
		state.commission=h-1;state.next_cycle=state.commission+144
		add_event(state,"heatwave",state.commission+36,10,12)
		add_event(state,"grid_maintenance",state.commission+72,4,12)
		add_event(state,"outage",state.commission+108+random_int(state,9),3+random_int(state,3),0)
	if state.next_cycle>=0 and h>=state.next_cycle:
		var severity=1.2 if sim.campaign_count()>=4 else 1.0
		if sim.difficulty=="challenging": severity+=0.15
		if sim.difficulty=="relaxed": severity=maxf(1,severity-0.1)
		add_event(state,"heatwave",h+12,12,12,severity)
		add_event(state,"grid_maintenance",h+18,4,12)
		add_event(state,"outage",h+44+random_int(state,13),3+random_int(state,3),0)
		state.next_cycle+=84
	state.charge=quantize(clampf(state.charge+m.battery_recharge-m.battery_output,0,state.batteries*240.0))
	state.fuel=quantize(maxf(0,state.fuel-m.fuel_used))
	state.total_lost_compute=quantize(state.total_lost_compute+maxf(0,m.capacity-m.compute))
	state.total_backup_mwh=quantize(state.total_backup_mwh+m.generator_output+m.battery_output)
	var previous_grid=conditions(state).grid
	for event in state.events:
		if event.phase in ["active","recovery"]:
			event.lost_compute=quantize(event.lost_compute+maxf(0,m.capacity-m.compute))
			event.backup_mwh=quantize(event.backup_mwh+m.generator_output+m.battery_output);event.fuel_used=quantize(event.fuel_used+m.fuel_used)
		var next="pending"
		if h>=event.end+2: next="closed"
		elif h>=event.end: next="recovery"
		elif h>=event.start: next="active"
		elif event.lead>0 and h>=event.start-event.lead: next="forecast"
		if next==event.phase: continue
		event.phase=next
		if next=="forecast": alert(state,"%s forecast: starts in %dh. Open Operations to prepare." % [NAMES[event.kind],event.start-h])
		elif next=="active": alert(state,"%s has begun. Check utility reserves and customer delivery." % NAMES[event.kind])
		elif next=="recovery": alert(state,"%s is recovering; utilities return gradually over 2h." % NAMES[event.kind])
		elif next=="closed":
			state.results.push_front({"name":NAMES[event.kind],"hour":h,"lost_compute":event.lost_compute,"backup_mwh":event.backup_mwh,"fuel_used":event.fuel_used})
			if state.results.size()>12: state.results.resize(12)
			sim.notices.append("%s ended. Campus loss %.0f compute-hours; backup delivered %.0f MW-h." % [NAMES[event.kind],event.lost_compute,event.backup_mwh])
	state.events=state.events.filter(func(e):return e.phase!="closed")
	var grid=conditions(state).grid
	if grid<1 and previous_grid>=1: state.generator_ready=h+1
	elif grid<1 and m.grid_capacity<m.power_need and state.generator_ready<0: state.generator_ready=h
	elif grid>=1: state.generator_ready=-1
	var heat=conditions(state).heat
	var working_count=sim.lots.filter(func(lot):return sim.BUILDINGS.has(lot.kind) and int(lot.get("service_until",0))>h).size()
	for lot in sim.lots:
		if not sim.BUILDINGS.has(lot.kind): continue
		if int(lot.get("service_until",0))>0 and h>=int(lot.service_until):
			lot.service_until=0;lot.condition=100.0;lot.failed=false;lot.wear_warned=false
			sim.notices.append("Service complete at %02d-%02d. Equipment restored." % [lot.x+1,lot.y+1])
		if not available(lot,h):
			if lot.get("failed",false) and int(lot.get("service_until",0))<=h and state.crews and working_count==0:
				if act(sim,"service",sim.cell(int(lot.x),int(lot.y)))=="":
					working_count+=1;alert(state,"Crew dispatched to repair failed equipment.",sim.cell(int(lot.x),int(lot.y)),true)
			continue
		if int(lot.get("refit_until",0))>h: continue
		var wear=0.08*(1+0.25*(int(lot.level)-1))*heat
		if lot.kind=="datacenter": wear*=Economy.HARDWARE[lot.get("hardware","balanced")].wear
		if state.crews: wear*=0.3
		if sim.Research.has(sim,"predict"): wear*=0.65
		lot.condition=quantize(maxf(0,float(lot.get("condition",100))-wear))
		var index=sim.cell(int(lot.x),int(lot.y))
		if lot.condition<(65 if sim.Research.has(sim,"predict") else 55) and not lot.get("wear_warned",false):
			lot.wear_warned=true;alert(state,"Condition warning at %02d-%02d. Plan a service visit before failure." % [lot.x+1,lot.y+1],index)
		if lot.condition<=0 or (lot.condition<30 and random_int(state,100)<10):
			lot.failed=true;alert(state,"Equipment failure at %02d-%02d. Schedule repair in Operations." % [lot.x+1,lot.y+1],index)
		if state.crews and working_count==0 and lot.condition<35 and not lot.get("failed",false) and not incident_pending(sim):
			if act(sim,"service",index)=="": working_count+=1;alert(state,"Maintenance crew started service at %02d-%02d." % [lot.x+1,lot.y+1],index,true)
	if m.fuel_used>0 and state.fuel<3 and state.fuel+m.fuel_used>=3: alert(state,"Generator fuel is low. Refill the tank in Operations.",int(state.hub))
	if state.rental_until==h+4: alert(state,"Mobile cooling expires in 4h. Renew it if the heat is continuing.",-1,true)
	# Warm standby without fuel only costs money; switch it off and say so.
	if state.warm and state.fuel<=0:
		state.warm=false;state.warm_ready=-1
		alert(state,"Warm standby stopped: the generator tank is empty. Refuel in Operations.",int(state.hub))

static func valid(state,lots:Array) -> bool:
	if not state is Dictionary: return false
	for key in ["rng","commission","next_cycle","next_id","batteries","generators","hub","generator_ready","warm_ready","rental_until","rental_site"]:
		if not Economy.number(state.get(key)) or state[key]!=int(state[key]): return false
	if state.rng<1 or state.rng>=2147483647 or state.batteries<0 or state.batteries>MAX_MODULES or state.generators<0 or state.generators>MAX_MODULES: return false
	if state.commission< -1 or state.next_cycle< -1 or state.next_id<0 or state.rental_until<0 or state.generator_ready< -1 or state.warm_ready< -1: return false
	if state.hub< -1 or state.hub>=lots.size(): return false
	if state.rental_site< -1 or state.rental_site>=lots.size(): return false
	for key in ["charge","fuel","total_lost_compute","total_backup_mwh"]:
		if not Economy.number(state.get(key)) or state[key]<0: return false
	if state.charge>state.batteries*240+0.001 or state.fuel>36.001: return false
	for key in ["warm","crews"]:
		if not state.get(key) is bool: return false
	for key in ["events","results","alerts"]:
		if not state.get(key) is Array: return false
	if state.events.size()>24 or state.results.size()>12 or state.alerts.size()>24: return false
	var seen:Array=[]
	for event in state.events:
		if not event is Dictionary or not event.get("kind") in KINDS or not event.get("phase") in PHASES: return false
		for key in ["id","start","end","lead","severity","lost_compute","backup_mwh","fuel_used"]:
			if not Economy.number(event.get(key)) or event[key]<0: return false
		for key in ["id","start","end","lead"]:
			if event[key]!=int(event[key]): return false
		if event.end<=event.start or event.severity<1 or event.severity>2 or event.id in seen: return false
		seen.append(event.id)
	for result in state.results:
		if not result is Dictionary or not result.get("name") is String: return false
		for key in ["hour","lost_compute","backup_mwh","fuel_used"]:
			if not Economy.number(result.get(key)) or result[key]<0: return false
	for item in state.alerts:
		if not item is Dictionary or not item.get("message") is String or not Economy.number(item.get("lot")): return false
		if item.lot< -1 or item.lot>=lots.size(): return false
	return true

static func normalize(state:Dictionary) -> Dictionary:
	var result=state.duplicate(true)
	for key in ["rng","commission","next_cycle","next_id","batteries","generators","hub","generator_ready","warm_ready","rental_until","rental_site"]: result[key]=int(result[key])
	# Saves from 1.3 could keep a rental with no staging site; end it.
	if result.rental_site<0: result.rental_until=0
	for event in result.events:
		for key in ["id","start","end","lead"]: event[key]=int(event[key])
	for item in result.results: item.hour=int(item.hour)
	for item in result.alerts: item.lot=int(item.lot)
	return result

static func forecast_conditions(state:Dictionary,event:Dictionary,at_hour:int=-1) -> Dictionary:
	var preview=state.duplicate(true)
	if at_hour<0: at_hour=int(event.start)
	for candidate in preview.events:
		if candidate.kind=="outage" and candidate.phase=="pending" and candidate.id!=event.id: continue
		if at_hour>=candidate.end+2: candidate.phase="closed"
		elif at_hour>=candidate.end: candidate.phase="recovery"
		elif at_hour>=candidate.start: candidate.phase="active"
		else: candidate.phase="pending"
	return conditions(preview)
