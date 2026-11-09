extends RefCounted
## Saved neighborhood history. Reports are derived from the actual town, never random complaints.
const Geo=preload("res://scripts/town_rules.gd")
const STAGES=["Calm","Warning","Petition","Demonstration","Permit pause"]
const CAUSES={"displacement":"Rehouse displaced families","noise":"Reduce noise at homes and parks","traffic":"Fund local delivery routing","power":"Reinforce the town electricity network","water":"Add water recycling or use closed-loop cooling","heritage":"Restore lost landmarks and green space","reliability":"Restore reliable local services","trust":"Keep promises and rebuild community trust"}
const COSTS={"negotiate":600,"expedite":2500,"quiet":900,"traffic":1600,"grid":2200,"water":1800,"housing":1800,"park":1000,"memorial":2500,"preserve":700,"education":1000}
const INTEGER_FIELDS=["stage","displaced","green_loss","heritage_loss","education","traffic_projects","last_talk","ceasefire_until","waiver_until"]
const FLOAT_FIELDS=["opinion","adoption","stress","grievance","service_loss","promise_value"]

static func fresh(approval:int=75,hour:int=8,deliveries:int=0) -> Dictionary:
	var state={"standing":float(approval),"grid_projects":0,"water_projects":0,"grid_draw":0.0,"water_use":0.0,"grace_until":hour+12,"wards":{},"alerts":[],"history":[]}
	for id in Geo.DISTRICTS:
		state.wards[id]={"opinion":float(approval),"adoption":minf(90,10+deliveries*5),"stress":0.0,"stage":0,"displaced":0,"green_loss":0,"heritage_loss":0,"education":0,"traffic_projects":0,"grievance":0.0,"service_loss":0.0,"last_talk":-48,"ceasefire_until":0,"waiver_until":0,"promise_cause":"","promise_value":0.0}
	return state

static func adoption(sim) -> float:
	if sim.civic.is_empty(): return 10.0
	var total=0.0
	for ward in sim.civic.wards.values(): total+=ward.adoption
	return total/Geo.DISTRICTS.size()

static func ward_for(lot:Dictionary) -> String:
	return Geo.district(int(lot.x),int(lot.y))

static func shock(sim,amount:float) -> void:
	sim.civic.standing=snappedf(clampf(sim.civic.standing+amount,0,100),0.000001)
	for ward in sim.civic.wards.values(): ward.opinion=snappedf(clampf(ward.opinion+amount,0,100),0.000001)
	sim.approval=clampi(sim.approval+roundi(amount),0,100)

static func demolished(sim,lot:Dictionary) -> void:
	var ward:Dictionary=sim.civic.wards[ward_for(lot)]
	if lot.kind=="house": ward.displaced+=1
	if lot.kind=="park": ward.green_loss+=1
	if lot.kind=="monument": ward.heritage_loss+=2 if sim.scenario_id=="oldbridge" else 1
	shock(sim,-Geo.demolition_impact(lot))

static func local_noise(sim,lot:Dictionary) -> float:
	var value=Geo.noise(sim.lots,lot)
	if sim.ops.hub>=0 and sim.metrics_generator>0:
		var hub:Dictionary=sim.lots[int(sim.ops.hub)]
		var d=Geo.distance(lot,hub)
		if d<=4: value+=18*(1.0-d/5.0)*Geo.sensitivity(lot)*(0.4 if hub.get("quiet",false) else 1.0)
	return minf(100,value)

static func measure(sim) -> Dictionary:
	sim.metrics_generator=sim.metrics().generator_output
	var result={}
	for id in Geo.DISTRICTS:
		result[id]={"homes":0,"parks":0,"preserved":0,"amenities":0,"jobs":0,"trips":0.0,"noise_sum":0.0,"noise_peak":0.0,"exposure":0,"campuses":0,"sources":[]}
	for i in range(sim.lots.size()):
		var lot:Dictionary=sim.lots[i];var r:Dictionary=result[ward_for(lot)]
		if lot.kind=="house": r.homes+=1
		if lot.kind=="park": r.parks+=1
		if lot.get("preserved",false): r.preserved+=1
		if lot.kind=="park" and lot.get("civic_park",false): r.amenities+=1
		if lot.kind in ["house","park","monument"]:
			var noise=local_noise(sim,lot)
			r.noise_sum+=noise;r.noise_peak=maxf(r.noise_peak,noise);r.exposure+=1
		if lot.kind in sim.BUILDINGS:
			r.jobs+=int(lot.level)*(4 if lot.kind=="datacenter" else 2)
			r.trips+=int(lot.level)*(4 if lot.kind=="datacenter" else 1)
			if lot.kind=="datacenter": r.campuses+=1
			r.sources.append(i)
	for id in result:
		var r:Dictionary=result[id];var w:Dictionary=sim.civic.wards[id]
		var sensitivity:float=Geo.DISTRICTS[id].sensitivity
		r.noise=0.6*r.noise_sum/maxi(1,r.exposure)+0.4*r.noise_peak
		r.trips+=w.adoption/25.0 if r.campuses>0 else 0.0
		r.population=(r.homes+w.displaced)*3
		r.jobs+=w.education*2
		r.benefit=minf(10,r.jobs*0.4)+minf(4,(r.preserved+r.amenities)*2)
		r.concerns={"displacement":w.displaced*12.0,"noise":maxf(0,r.noise-24)*0.8,"traffic":maxf(0,r.trips-12-w.traffic_projects*10)*sensitivity*0.8,"power":maxf(0,sim.civic.grid_draw-220-sim.civic.grid_projects*120)/10.0,"water":maxf(0,sim.civic.water_use-70-sim.civic.water_projects*50)/5.0,"heritage":w.green_loss*8.0+w.heritage_loss*24.0,"reliability":w.service_loss,"trust":maxf(0,65-sim.civic.standing)*0.6+w.grievance}
		r.primary="trust";var highest=0.0;var negative=0.0
		for cause in r.concerns:
			negative+=r.concerns[cause]
			if r.concerns[cause]>highest: highest=r.concerns[cause];r.primary=cause
		r.pressure=maxf(0,negative-r.benefit)
		r.target=clampf(sim.civic.standing+r.benefit-negative,0,100)
		for key in ["noise","pressure","target","trips","benefit"]: r[key]=snappedf(float(r[key]),0.000001)
	return result

static func refresh(sim) -> void:
	sim.civic_reports=measure(sim)

static func notify(sim,id:String,message:String,routine:bool=false) -> void:
	var row={"hour":sim.hour,"ward":id,"message":message}
	if routine: row.routine=true
	sim.civic.alerts.append(row)
	if sim.civic.alerts.size()>30: sim.civic.alerts.pop_front()
	sim.civic.history.push_front(row.duplicate())
	if sim.civic.history.size()>30: sim.civic.history.resize(30)

static func expand_error(sim,lot:Dictionary) -> String:
	var id=ward_for(lot);var ward:Dictionary=sim.civic.wards[id]
	if ward.stage<4 or ward.waiver_until>sim.hour: return ""
	return "%s permits paused: %s. Resolve the cause and reduce pressure below 12; utilities and repairs remain available." % [Geo.DISTRICTS[id].name,CAUSES[sim.civic_reports[id].primary]]

static func client_ward(id:String) -> String:
	return {"bakery":"oldtown","support":"market","studio":"market","robotics":"foundry","research":"riverside","council":"oldtown","atlas":"foundry","orbital":"market"}.get(id,"market")

static func delivered(sim,id:String) -> void:
	var ward:Dictionary=sim.civic.wards[client_ward(id)]
	ward.adoption=minf(100,ward.adoption+8)

static func advance(sim,m:Dictionary) -> void:
	sim.metrics_generator=m.generator_output
	sim.civic.grid_draw=snappedf(lerpf(sim.civic.grid_draw,float(m.grid_draw),0.2),0.000001)
	sim.civic.water_use=snappedf(lerpf(sim.civic.water_use,float(m.water_use),0.2),0.000001)
	for id in sim.civic.wards:
		var w:Dictionary=sim.civic.wards[id]
		w.service_loss*=0.96
		w.service_loss+=m.local_shortfalls.get(id,0.0)*2.0
		w.grievance=maxf(0,w.grievance-0.04)
	refresh(sim)
	var total=0.0;var weight_total=0.0
	for id in sim.civic.wards:
		var w:Dictionary=sim.civic.wards[id];var r:Dictionary=sim.civic_reports[id]
		var target_adoption=clampf(10+w.education*12+sim.campaign_count()*3+(15 if sim.Research.campaign_active(sim,id) else 0),0,95)
		w.adoption=move_toward(w.adoption,target_adoption,0.5 if sim.Research.campaign_active(sim,id) else 0.15)
		w.opinion=move_toward(w.opinion,r.target,0.6)
		if w.ceasefire_until>0 and sim.hour>=w.ceasefire_until:
			if r.concerns[w.promise_cause]<=w.promise_value:
				w.grievance=maxf(0,w.grievance-6);w.stress=maxf(0,w.stress-10);w.opinion=minf(100,w.opinion+6)
				sim.civic.standing=minf(100,sim.civic.standing+3)
				notify(sim,id,"Promise kept: the agreed concern fell. Trust improved.",true)
			else:
				w.grievance+=10;w.stress=minf(60,w.stress+4)
				notify(sim,id,"Promise broken: the agreed concern is still too high. Trust fell.")
			w.ceasefire_until=0;w.promise_cause="";w.promise_value=0.0
		if sim.hour>=sim.civic.grace_until:
			if r.pressure<12: w.stress=maxf(0,w.stress-2)
			elif r.pressure>=18 and w.ceasefire_until<=sim.hour: w.stress=minf(60,w.stress+(2 if r.pressure>=30 else 1))
		var stage=4 if w.stress>=28 else (3 if w.stress>=18 else (2 if w.stress>=10 else (1 if w.stress>=4 else 0)))
		if stage!=w.stage:
			var easing=stage<w.stage
			w.stage=stage
			notify(sim,id,STAGES[stage]+": "+(CAUSES[r.primary] if stage>0 else "Concerns eased; expansion can continue."),easing)
		for key in FLOAT_FIELDS: w[key]=snappedf(float(w[key]),0.000001)
		var weight=maxi(3,int(r.population));total+=w.opinion*weight;weight_total+=weight
	sim.approval=clampi(roundi(total/maxf(1,weight_total)),0,100)
	refresh(sim)

static func project_site(sim,id:String,index:int,kind:String="grass") -> int:
	if index>=0:
		if index>=sim.lots.size(): return -1
		var lot:Dictionary=sim.lots[index]
		return index if ward_for(lot)==id and lot.kind==kind else -1
	for i in range(sim.lots.size()):
		var lot:Dictionary=sim.lots[i]
		if ward_for(lot)==id and lot.kind==kind and not lot.owned: return i
	return -1

static func act(sim,action:String,id:String,index:int=-1,preview:bool=false) -> String:
	if not COSTS.has(action) or not Geo.DISTRICTS.has(id): return "Choose a council action and district."
	var w:Dictionary=sim.civic.wards[id];var r:Dictionary=sim.civic_reports[id]
	if sim.cash<COSTS[action]: return "Not enough cash for this council action."
	var site=-1
	if action=="negotiate":
		if sim.hour-w.last_talk<48: return "The council will meet again in %dh." % (48-(sim.hour-w.last_talk))
		if r.concerns[r.primary]<8: return "There is no substantial concern to negotiate."
	elif action=="expedite" and w.waiver_until>sim.hour: return "An expedited permit is already active."
	elif action=="expedite" and w.stage<4: return "Expedited permits only apply while hall permits are paused here."
	elif action=="quiet":
		if index<0 or index>=sim.lots.size() or not sim.lots[index].kind in sim.BUILDINGS: return "Choose an owned hall or utility."
		if sim.lots[index].get("quiet",false): return "This site already has acoustic barriers."
	elif action in ["housing","park","memorial","preserve"]:
		site=project_site(sim,id,index,"grass" if action!="preserve" else (sim.lots[index].kind if index>=0 and index<sim.lots.size() else "park"))
		if site<0: return "No suitable site in this district; select a vacant parcel."
		if action=="preserve" and (not sim.lots[site].kind in ["park","monument"] or sim.lots[site].get("preserved",false)): return "Choose a park or landmark without an existing conservation covenant."
	elif action=="education" and w.education>=3: return "This district already has three skills programs."
	if preview: return ""
	sim.post("community",-COSTS[action],Geo.DISTRICTS[id].name+" / "+action)
	match action:
		"negotiate":
			w.last_talk=sim.hour;w.ceasefire_until=sim.hour+24;w.promise_cause=r.primary;w.promise_value=maxf(8,r.concerns[r.primary]*0.65)
		"expedite":
			w.waiver_until=sim.hour+24;w.grievance+=12;w.stress=minf(60,w.stress+4);shock(sim,-8)
		"quiet": sim.lots[index].quiet=true
		"traffic": w.traffic_projects+=1
		"grid": sim.civic.grid_projects+=1
		"water": sim.civic.water_projects+=1
		"education": w.education+=1
		"housing":
			sim.lots[site].kind="house";sim.lots[site].civic_home=true;sim.lots[site].price=roundi(1700*Geo.DISTRICTS[id].price)
			w.displaced=maxi(0,w.displaced-1)
		"park":
			sim.lots[site].kind="park";sim.lots[site].civic_park=true;w.green_loss=maxi(0,w.green_loss-1)
			sim.lots[site].protected=id=="gardens"
		"memorial":
			sim.lots[site].kind="monument";sim.lots[site].protected=true;w.heritage_loss=maxi(0,w.heritage_loss-1)
		"preserve":
			sim.lots[site].preserved=true;sim.lots[site].protected=true;sim.lots[site].permit=false
			shock(sim,2)
	for key in FLOAT_FIELDS: w[key]=snappedf(float(w[key]),0.000001)
	refresh(sim)
	return ""

static func thought(sim,id:String) -> String:
	var r:Dictionary=sim.civic_reports[id];var w:Dictionary=sim.civic.wards[id]
	if r.pressure>=12: return CAUSES[r.primary]+("!" if w.stage>=3 else ".")
	if w.adoption>=35: return "AI helps at work. Keep our neighborhood livable."
	if r.jobs>0: return "Local jobs are welcome. So is a quiet street."
	return "Enjoying our parks and familiar streets."

static func valid(value) -> bool:
	if not value is Dictionary: return false
	for key in ["standing","grid_projects","water_projects","grid_draw","water_use","grace_until"]:
		if not number(value.get(key)) or value[key]<0: return false
	if value.standing>100 or value.grid_draw>100000 or value.water_use>100000: return false
	for key in ["grid_projects","water_projects","grace_until"]:
		if value[key]!=int(value[key]): return false
	if not value.get("wards") is Dictionary or value.wards.size()!=Geo.DISTRICTS.size(): return false
	for id in Geo.DISTRICTS:
		if not value.wards.get(id) is Dictionary: return false
		var w:Dictionary=value.wards[id]
		for key in INTEGER_FIELDS+FLOAT_FIELDS:
			if not number(w.get(key)) or (key!="last_talk" and w[key]<0): return false
		for key in INTEGER_FIELDS:
			if w[key]!=int(w[key]): return false
		if w.stage>4 or w.opinion>100 or w.adoption>100 or w.stress>64 or w.education>3: return false
		if not w.get("promise_cause") is String or (w.promise_cause!="" and not CAUSES.has(w.promise_cause)): return false
		if w.ceasefire_until>0 and w.promise_cause=="": return false
	for key in ["alerts","history"]:
		if not value.get(key) is Array or value[key].size()>30: return false
		for row in value[key]:
			if not row is Dictionary or not Geo.DISTRICTS.has(row.get("ward")) or not row.get("message") is String or not number(row.get("hour")): return false
	return true

static func number(value) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func normalize(value:Dictionary) -> Dictionary:
	var result=value.duplicate(true)
	for key in ["grid_projects","water_projects","grace_until"]: result[key]=int(result[key])
	for key in ["standing","grid_draw","water_use"]: result[key]=snappedf(float(result[key]),0.000001)
	for w in result.wards.values():
		for key in FLOAT_FIELDS: w[key]=snappedf(float(w[key]),0.000001)
		for key in INTEGER_FIELDS: w[key]=int(w[key])
	for key in ["alerts","history"]:
		for row in result[key]: row.hour=int(row.hour)
	return result
