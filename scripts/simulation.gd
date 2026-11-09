extends RefCounted
## Pure simulation: no scene nodes, UI, wall clock, or rendering dependencies.

const Geography = preload("res://scripts/town_rules.gd")
const MAP_SIZE = Geography.SIZE
const Economy = preload("res://scripts/economy.gd")
const Operations = preload("res://scripts/operations.gd")
const Civic = preload("res://scripts/civic.gd")
const Research = preload("res://scripts/research.gd")
const Workforce=preload("res://scripts/workforce.gd")
const Scenarios=preload("res://scripts/scenarios.gd")
const Tutorial=preload("res://scripts/tutorial.gd")
const Achievements=preload("res://scripts/achievements.gd")
const SAVE_VERSION = 12
const SAVE_PATH = "user://town.json"
const BUILDINGS = {
	"datacenter": {"name": "Server hall", "cost": 4800, "power": 40, "cooling": 40, "upkeep": 38, "capacity": 100},
	"power": {"name": "Substation", "cost": 2200, "power": 0, "cooling": 0, "upkeep": 8, "capacity": 120},
	"cooling": {"name": "Cooling plant", "cost": 1800, "power": 20, "cooling": 0, "upkeep": 12, "capacity": 120}
}
const TIERS = {
	"datacenter": [
		{"name":"Starter racks","capacity":100,"power":40,"cooling":40,"upkeep":38,"cost":0},
		{"name":"GPU cluster","capacity":220,"power":65,"cooling":70,"upkeep":68,"cost":5200},
		{"name":"Neural supercluster","capacity":420,"power":100,"cooling":110,"upkeep":112,"cost":9500}],
	"power": [
		{"name":"Local substation","capacity":120,"power":0,"cooling":0,"upkeep":8,"cost":0},
		{"name":"Regional substation","capacity":260,"power":0,"cooling":0,"upkeep":16,"cost":3000},
		{"name":"High-voltage hub","capacity":500,"power":0,"cooling":0,"upkeep":28,"cost":6000}],
	"cooling": [
		{"name":"Air cooling","capacity":120,"power":20,"cooling":0,"upkeep":12,"cost":0},
		{"name":"Liquid cooling","capacity":280,"power":35,"cooling":0,"upkeep":23,"cost":2800},
		{"name":"Closed-loop cooling","capacity":550,"power":55,"cooling":0,"upkeep":38,"cost":5200}]
}
const CONTRACTS = [
	{"id":"bakery","type":"project","compute":40,"work":600,"deadline":36,"reward":2200,"rate":0.0,"unlock":0},
	{"id":"support","type":"service","compute":60,"work":1440,"deadline":24,"reward":1400,"rate":2.2,"unlock":0},
	{"id":"studio","type":"project","compute":140,"work":4200,"deadline":48,"reward":6500,"rate":0.0,"unlock":2},
	{"id":"robotics","type":"service","compute":120,"work":4320,"deadline":36,"reward":3000,"rate":2.4,"unlock":2},
	{"id":"research","type":"project","compute":240,"work":9600,"deadline":64,"reward":13000,"rate":0.0,"unlock":4},
	{"id":"council","type":"service","compute":180,"work":8640,"deadline":48,"reward":5000,"rate":2.6,"unlock":4},
	{"id":"atlas","type":"project","compute":480,"work":23040,"deadline":72,"reward":28000,"rate":0.0,"unlock":6},
	{"id":"orbital","type":"service","compute":320,"work":15360,"deadline":48,"reward":9000,"rate":2.8,"unlock":6}
]
var lots: Array = []
var cash: float = 22000.0
var earned: float = 0.0
var hour: int = 8
var approval: int = 75
var bought: bool = false
var cleared: bool = false
var built: bool = false
var won: bool = false
var rescued: bool = false
var last_error: String = ""
var active: Array = []
var completed: Array = []
var history: Array = []
var notices: Array = []
var reputation: int = 0
var next_ticket: int = 0
var community_hour: int = -24
var milestone_claims: Array = []
var campaign_won: bool = false
var company_name="Littlebrook Infrastructure Co."
var scenario_id="littlebrook"
var difficulty="standard"
var play_seconds=0.0
var view_state:Dictionary={}
var save_metadata:Dictionary={}
var finance:Dictionary={}
var ops:Dictionary={}
var civic:Dictionary={}
var research:Dictionary={}
var workforce:Dictionary={}
var scenario_progress:Dictionary={}
var tutorial:Dictionary={}
var achievements:Array=[]
var civic_reports:Dictionary={}
var metrics_generator=0.0

func _init() -> void:
	new_game()

func new_game(company:String="Littlebrook Infrastructure Co.",scenario:String="littlebrook",challenge:String="standard") -> void:
	lots.clear()
	cash = 22000.0
	earned = 0.0
	hour = 8
	approval = 75
	bought = false
	cleared = false
	built = false
	won = false
	rescued = false
	active.clear()
	completed.clear()
	history.clear()
	notices.clear()
	milestone_claims.clear()
	reputation = 0
	next_ticket = 0
	community_hour = -24
	campaign_won = false
	company_name=company.strip_edges().left(48)
	if company_name.is_empty(): company_name="Littlebrook Infrastructure Co."
	scenario_id=scenario if Scenarios.TOWNS.has(scenario) else "littlebrook"
	difficulty=challenge
	play_seconds=0
	view_state.clear()
	save_metadata.clear()
	if challenge=="relaxed": cash=28000
	elif challenge=="challenging": cash=18000
	finance=Economy.new_finance(cash,hour)
	ops=Operations.fresh()
	research=Research.fresh()
	workforce=Workforce.fresh()
	scenario_progress=Scenarios.fresh()
	tutorial=Tutorial.fresh(scenario_id=="littlebrook")
	achievements=[]
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE): lots.append(Geography.authored_lot(x,y,scenario_id))
	civic=Civic.fresh(approval,hour);Civic.refresh(self)

static func cell(x:int,y:int) -> int:
	return Geography.index(x,y)

func construction_cost(index:int,kind:String,profile:String="balanced") -> int:
	var base=Economy.HARDWARE[profile].cost if kind=="datacenter" and Economy.HARDWARE.has(profile) else BUILDINGS[kind].cost
	return base+Geography.connection_cost(lots[index])

func site_preview(index:int,kind:String="datacenter",profile:String="balanced") -> Dictionary:
	var base=Economy.HARDWARE[profile].cost if kind=="datacenter" and Economy.HARDWARE.has(profile) else BUILDINGS[kind].cost
	var result=Geography.preview(lots,index,kind,base)
	var power=utility_for(lots[index],"power");var cooling=cooling_for(lots[index])
	result.permit_error=Civic.expand_error(self,lots[index]) if kind=="datacenter" else ""
	result.power=not power.is_empty();result.cooling=not cooling.is_empty()
	result.power_lot=-1 if power.is_empty() else cell(int(power.x),int(power.y))
	result.cooling_lot=-1 if cooling.is_empty() else cell(int(cooling.x),int(cooling.y))
	return result

func redevelopment_permit(index:int) -> String:
	if index<0 or index>=lots.size(): return "Select a property."
	var lot:Dictionary=lots[index]
	if not lot.owned: return "Buy this property first."
	if lot.get("preserved",false): return "Conservation covenant: this site is permanently preserved."
	if not lot.get("protected",false) or lot.get("permit",false): return "This site does not need a hearing."
	if approval<60: return "A heritage hearing requires at least 60 public approval. Preserve or invest in the town first."
	if cash<4000: return "A heritage hearing and relocation plan costs $4,000."
	post("heritage",-4000,"Heritage relocation hearing")
	lot.permit=true
	return ""

func lot_at(x: int, y: int) -> Dictionary:
	if x < 0 or y < 0 or x >= MAP_SIZE or y >= MAP_SIZE: return {}
	return lots[y * MAP_SIZE + x]

func buy(index: int) -> String:
	if index < 0 or index >= lots.size(): return "Select a property first."
	var lot: Dictionary = lots[index]
	if lot.kind in ["road","water"]: return "Public roads and the river are protected. Choose another property."
	if lot.owned: return "You already own this property."
	if cash < lot.price: return "Not enough cash to buy this property."
	post("land",-lot.price,"Property %02d-%02d" % [lot.x+1,lot.y+1])
	lot.owned = true
	bought = true
	return ""

func demolition_cost(kind: String) -> int:
	if kind == "house": return 600
	if kind == "monument": return 1400
	if kind == "park": return 200
	if kind == "grass" or kind == "road": return 0
	return 250

func demolition_impact(kind: String) -> int:
	if kind == "house": return 8
	if kind == "monument": return 25
	if kind == "park": return 5
	return 0

func demolish(index: int) -> String:
	if index < 0 or index >= lots.size(): return "Select a property first."
	var lot: Dictionary = lots[index]
	if not lot.owned: return "Buy the property before demolishing it."
	if lot.get("preserved",false): return "Conservation covenant: this park or landmark is permanently preserved."
	if lot.get("protected",false) and not lot.get("permit",false): return "Protected site: obtain a heritage hearing before redevelopment, or preserve it."
	if lot.kind in ["road", "water", "grass"]: return "There is nothing to demolish here."
	var cost = demolition_cost(lot.kind)
	if cash < cost: return "Not enough cash for demolition."
	post("demolition",-cost,"Clear "+lot.kind)
	Civic.demolished(self,lot)
	workforce.jobs=workforce.jobs.filter(func(job):return job.site!=index)
	lot.kind = "grass"
	lot.level = 1
	for key in ["hardware","refit_until","quiet","civic_home","civic_park"]: lot.erase(key)
	cleared = true
	Civic.refresh(self)
	return ""

func build(index: int, kind: String, profile:String="balanced") -> String:
	if index < 0 or index >= lots.size(): return "Select a property first."
	if not BUILDINGS.has(kind): return "Unknown building."
	if not Economy.HARDWARE.has(profile): return "Unknown hardware profile."
	if kind=="datacenter" and not hardware_unlocked(profile): return "Training accelerators require tier 2 (two customer deliveries)."
	var lot: Dictionary = lots[index]
	if not lot.owned: return "Buy this property first."
	if lot.kind != "grass": return "Demolish the existing building first."
	if kind=="datacenter":
		var error=Civic.expand_error(self,lot)
		if error!="": return error
	if cash < construction_cost(index,kind,profile): return "Not enough cash for this building."
	post("construction",-(Economy.HARDWARE[profile].cost if kind=="datacenter" else BUILDINGS[kind].cost),BUILDINGS[kind].name)
	post("access",-Geography.connection_cost(lot),"Road connection works")
	lot.kind = kind
	lot.level = 1
	lot.condition=100.0;lot.failed=false;lot.service_until=0;lot.wear_warned=false
	if kind == "datacenter":
		built = true
		lot.hardware=profile;lot.refit_until=0
	Workforce.dispatch(self,"construction",index,2)
	Civic.refresh(self)
	return ""

func building_stats(lot: Dictionary) -> Dictionary:
	if not TIERS.has(lot.kind): return {}
	var result:Dictionary=TIERS[lot.kind][clampi(int(lot.get("level",1)),1,3)-1].duplicate()
	if lot.kind=="datacenter": result=Economy.stats(result,lot.get("hardware","balanced"))
	if lot.kind=="cooling" and Geography.river_access(lot): result.capacity*=1.25
	if lot.kind=="datacenter" and Research.has(self,"optimize"):
		result.power*=0.9;result.cooling*=0.9
	if lot.kind=="cooling" and Research.has(self,"water_loop"): result.power*=1.1
	return result

func campaign_count() -> int:
	var count = 0
	for c in CONTRACTS:
		if c.id in completed: count += 1
	return count

func tech_level() -> int:
	return 3 if campaign_count() >= 4 else (2 if campaign_count() >= 2 else 1)

func upgrade(index: int) -> String:
	if index < 0 or index >= lots.size(): return "Select a building first."
	var lot: Dictionary = lots[index]
	if not lot.owned or not TIERS.has(lot.kind): return "Select an owned server hall or utility."
	if lot.kind=="datacenter":
		var error=Civic.expand_error(self,lot)
		if error!="": return error
	var level = int(lot.get("level",1))
	if level >= 3: return "This building is fully upgraded."
	if level >= tech_level(): return "Complete %d customer contracts to unlock this upgrade." % (2 if level == 1 else 4)
	var cost = TIERS[lot.kind][level].cost
	if cash < cost: return "Not enough cash for this upgrade."
	post("upgrade",-cost,"Tier %d %s" % [level+1,BUILDINGS[lot.kind].name])
	Workforce.dispatch(self,"upgrade",index,2)
	lot.level = level+1
	lot.condition=maxf(85,float(lot.get("condition",100)))
	Civic.refresh(self)
	return ""

func contract_definition(id: String) -> Dictionary:
	for vision in [false,true]:
		if Research.has(self,"scheduler" if vision else "discover"):
			var offer=Research.offer(self,vision)
			if offer.id==id: return Research.negotiate(self,offer)
	for c in CONTRACTS:
		if c.id == id: return Research.negotiate(self,Economy.contract(c))
	if id == "open_%d" % next_ticket and campaign_count() == CONTRACTS.size():
		return Research.negotiate(self,Economy.contract({"id":id,"type":"project","compute":360+(next_ticket%3)*60,"work":18000,"deadline":72,"reward":20000,"rate":0.0,"unlock":8}))
	return {}

func offers() -> Array:
	var result: Array = []
	for c in CONTRACTS:
		if c.id in completed: continue
		if active.any(func(a): return a.id == c.id): continue
		result.append(contract_definition(c.id))
	for vision in [false,true]:
		if Research.has(self,"scheduler" if vision else "discover"):
			var offer=Research.offer(self,vision)
			if not active.any(func(a):return a.id.begins_with("vision_" if vision else "scout_")): result.append(contract_definition(offer.id))
	if campaign_count() == CONTRACTS.size():
		result.append(contract_definition("open_%d" % next_ticket))
	return result

func accept_contract(id: String) -> String:
	var c = contract_definition(id)
	if c.is_empty(): return "This offer is no longer available."
	if id in completed or active.any(func(a): return a.id == id): return "You already signed this contract."
	for prefix in ["scout_","vision_"]:
		if id.begins_with(prefix) and active.any(func(a):return a.id.begins_with(prefix)): return "Finish the current companion introduction first."
	if active.size() >= 3: return "Your three contract slots are occupied."
	if campaign_count() < c.unlock: return "Complete %d contracts to unlock this customer." % c.unlock
	if metrics().free < c.compute: return "You need %d unreserved online compute to sign this contract." % c.compute
	c.progress = 0.0
	c.remaining = int(c.deadline)
	c.paid = 0.0
	active.append(c)
	if id.begins_with("open_"): next_ticket += 1
	if id.begins_with("scout_"): research.ticket+=1
	if id.begins_with("vision_"): research.vision_ticket+=1
	return ""

func cancel_contract(id: String) -> String:
	for i in range(active.size()):
		if active[i].id == id:
			var c = active[i]
			var penalty = roundi(c.reward*c.get("penalty_rate",0.1))
			post("penalty",-penalty,"Customer: "+c.name)
			reputation = maxi(0,reputation-3)
			receipt(c,"Cancelled",-penalty)
			active.remove_at(i)
			return ""
	return "This contract has already finished."

func receipt(c: Dictionary, outcome: String, amount: float) -> void:
	var item = {"name":c.name,"outcome":outcome,"amount":amount,"hour":hour}
	history.push_front(item)
	if history.size() > 12: history.resize(12)
	notices.append("%s: %s (%s$%d)" % [outcome,c.name,"+" if amount>=0 else "-",absi(roundi(amount))])

func invest_community() -> String:
	if cash < 1000: return "Community investment costs $1,000."
	if hour-community_hour < 24: return "Your next community grant is available in %dh." % (24-(hour-community_hour))
	if approval >= 100: return "Public approval is already at its maximum."
	post("community",-1000,"Community investment")
	Civic.shock(self,10)
	Civic.refresh(self)
	community_hour = hour
	return ""

func metrics(extra:Dictionary={},weather_override:Dictionary={}) -> Dictionary:
	var power_supply=0.0;var cooling_supply=0.0
	var power_need=0.0;var cooling_need=0.0
	var compute=0.0;var base_upkeep=0.0
	var halls=0;var connected_compute=0.0
	var disconnected:Array=[];var refitting:Array=[]
	var weights:Dictionary={}
	var failures:Array=[];var servicing:Array=[]
	var equipment=0
	var weather=Operations.conditions(ops) if weather_override.is_empty() else weather_override
	if scenario_id=="sunsprawl":
		weather=weather.duplicate();weather.heat*=1.1;weather.cooling*=0.85;weather.grid*=0.9;weather.temperature=maxi(32,weather.temperature)
	var check_hour=int(weather.get("at_hour",hour))
	for lot in lots:
		var kind:String=lot.kind
		if not BUILDINGS.has(kind): continue
		var b=building_stats(lot)
		equipment+=1
		var condition=Operations.condition_factor(lot,check_hour)
		if lot.get("failed",false): failures.append(cell(int(lot.x),int(lot.y)))
		if int(lot.get("service_until",0))>check_hour: servicing.append(cell(int(lot.x),int(lot.y)))
		power_need+=b.power;cooling_need+=b.cooling;base_upkeep+=b.upkeep
		if kind=="datacenter":
			compute+=b.capacity;halls+=1
			if int(lot.get("refit_until",0))>check_hour: refitting.append(cell(int(lot.x),int(lot.y)));continue
			if not utility_for(lot,"power",check_hour).is_empty() and not cooling_for(lot,check_hour).is_empty():
				connected_compute+=b.capacity*condition
				var profile=lot.get("hardware","balanced")
				weights[profile]=weights.get(profile,0.0)+b.capacity*condition
			else: disconnected.append(cell(int(lot.x),int(lot.y)))
		if kind=="power": power_supply+=b.capacity*condition
		if kind=="cooling" and not utility_for(lot,"power",check_hour).is_empty(): cooling_supply+=b.capacity*condition
	cooling_need*=weather.heat
	if ops.rental_until>check_hour: power_need+=20
	var power_plan=Operations.power_plan(self,power_supply,power_need,weather)
	power_supply=power_plan.supply
	var power_ratio=minf(1,power_supply/power_need) if power_need>0 else 1.0
	var mobile_powered=ops.rental_until>check_hour and ops.rental_site>=0 and not utility_for(lots[int(ops.rental_site)],"power",check_hour).is_empty()
	var available_cooling=(cooling_supply*weather.cooling+(240 if mobile_powered else 0))*power_ratio
	var cooling_ratio=minf(1,available_cooling/cooling_need) if cooling_need>0 else 1.0
	var online=connected_compute*minf(power_ratio,cooling_ratio)
	var efficiency=online/compute if compute>0 else 1.0
	var maintenance=Economy.money(base_upkeep*0.6)
	var staff=Economy.money(base_upkeep-maintenance+Workforce.wages(self))
	var energy=Economy.money(power_plan.grid_used*Economy.ENERGY_PRICE)
	var operations_cost=Economy.money((equipment*3 if ops.crews else 0)+(ops.generators*6 if ops.warm else 0)+(12 if ops.rental_until>check_hour else 0)+(ops.generators*2 if power_plan.generator>0 else 0))
	var interest=Economy.money(finance.debt*Economy.INTEREST)
	var upkeep=Economy.money(maintenance+staff+energy+interest+operations_cost)
	var research_compute=Research.draw(self,online)
	var remaining=online-research_compute;var reserved=0.0;var allocated_total=0.0;var service_revenue=0.0
	var allocations:Dictionary={};var deliveries:Dictionary={};var speeds:Dictionary={}
	var queue=active.duplicate()
	if not extra.is_empty(): queue.append(extra)
	for c in queue:
		var workload:String=c.get("workload","inference")
		var speed_factor=0.0
		for profile in weights: speed_factor+=weights[profile]*Economy.HARDWARE[profile][workload]
		speed_factor=speed_factor/connected_compute if connected_compute>0 else 1.0
		if c.get("legacy_speed",false): speed_factor=1.0
		elif workload=="experimental": speed_factor*=(0.9 if Research.has(self,"scheduler") else 0.65) if hour%12<3 else 1.15
		var allocation=minf(c.compute,remaining)
		if c.type=="service": allocation=minf(allocation,c.compute/maxf(0.001,speed_factor))
		else: allocation=minf(allocation,maxf(0,c.work-c.get("progress",0))/maxf(0.001,speed_factor))
		allocations[c.id]=allocation;speeds[c.id]=speed_factor
		deliveries[c.id]=allocation*speed_factor
		remaining-=allocation;reserved+=c.compute;allocated_total+=allocation
		service_revenue+=deliveries[c.id]*c.rate
	var campaign_wards=[]
	for ward in civic.get("wards",{}):
		if Research.campaign_active(self,ward): campaign_wards.append(ward)
	var spot_limit=300+Civic.adoption(self)*3.0+campaign_wards.size()*15
	var spot=minf(remaining,spot_limit)
	var water_use=0.0;var cooling_weight=0.0;var cooling_units=0.0
	for lot in lots:
		if lot.kind=="cooling" and Operations.available(lot,check_hour):
			var capacity=building_stats(lot).capacity
			cooling_weight+=capacity*[0.9,0.65,0.35][int(lot.level)-1];cooling_units+=capacity
	if mobile_powered: cooling_weight+=240*0.2;cooling_units+=240
	if cooling_units>0: water_use=minf(cooling_need,available_cooling)*cooling_weight/cooling_units
	if Research.has(self,"water_loop"): water_use*=0.65
	var local_shortfalls={}
	for ward in campaign_wards: local_shortfalls[ward]=maxf(0,1.0-remaining/(campaign_wards.size()*15.0))
	for c in queue:
		if c.type!="service" or c.get("workload","") not in ["critical","inference"]: continue
		var ward=Civic.client_ward(c.id)
		local_shortfalls[ward]=local_shortfalls.get(ward,0.0)+maxf(0,1.0-deliveries[c.id]/c.compute)
	var spot_revenue=Economy.money(spot*1.2)
	service_revenue=Economy.money(service_revenue)
	var revenue=spot_revenue+service_revenue
	return {"power":power_supply,"power_need":power_need,"cooling":available_cooling,"cooling_need":cooling_need,
		"compute":online,"capacity":compute,"sold":spot+allocated_total,"efficiency":efficiency,"revenue":revenue,
		"upkeep":upkeep,"profit":Economy.money(revenue-upkeep),"halls":halls,"disconnected":disconnected,"refitting":refitting,
		"spot":spot,"spot_limit":spot_limit,"water_use":water_use,"grid_draw":power_plan.grid_used,"local_shortfalls":local_shortfalls,"reserved":reserved,"research_compute":research_compute,"free":maxf(0,online-reserved-research_compute),"allocations":allocations,"deliveries":deliveries,"speeds":speeds,
		"service_revenue":service_revenue,"spot_revenue":spot_revenue,"maintenance":maintenance,"staff":staff,"energy":energy,"interest":interest,"operations":operations_cost,
		"failures":failures,"servicing":servicing,"weather":weather,"grid_capacity":power_plan.grid_capacity,"generator_output":power_plan.generator,
		"battery_output":power_plan.battery,"battery_recharge":power_plan.recharge,"fuel_used":power_plan.fuel_used,"hub_online":power_plan.hub_online}

func tick() -> void:
	var m = metrics()
	post("spot_income",m.spot_revenue,"Unreserved compute")
	post("service_income",m.service_revenue,"Recurring customer deliveries")
	for category in ["maintenance","staff","energy","interest","operations"]: post(category,-m[category],"Hourly "+Economy.CATEGORIES[category])
	hour += 1
	if bought and built and earned >= 1200 and m.compute > 0:
		won = true
	for i in range(active.size()-1,-1,-1):
		var c: Dictionary = active[i]
		var delivered: float = m.deliveries[c.id]
		c.progress = minf(c.work,c.progress+delivered)
		c.remaining -= 1
		c.paid += delivered*c.rate
		var finished = c.type == "project" and c.progress >= c.work-0.001
		if c.type == "service" and c.remaining <= 0: finished = c.progress/c.work >= c.get("min_delivery",0.9)-0.000001
		if finished:
			post("project_income" if c.type=="project" else "bonus_income",c.reward,c.name)
			completed.append(c.id)
			Civic.delivered(self,c.id)
			reputation = mini(100,reputation+10)
			receipt(c,"Delivered",c.reward)
			active.remove_at(i)
		elif c.remaining <= 0:
			var penalty = roundi(c.reward*c.get("penalty_rate",0.1))
			post("penalty",-penalty,"Customer: "+c.name)
			reputation = maxi(0,reputation-5)
			receipt(c,"Deadline missed",-penalty)
			active.remove_at(i)
	Scenarios.advance(self,m)
	check_milestones()
	Operations.advance(self,m)
	Civic.advance(self,m)
	Research.advance(self,m)
	Workforce.advance(self)
	Tutorial.capture(self)
	Achievements.capture(self)
	Economy.close_day(finance,hour,cash)

func check_milestones() -> void:
	var goals = [
		{"id":"campus","ready":won,"reward":2000,"text":"Campus established"},
		{"id":"gpu","ready":campaign_count()>=2,"reward":3000,"text":"GPU clusters and regional utilities unlocked"},
		{"id":"neural","ready":campaign_count()>=4,"reward":4500,"text":"Neural superclusters and advanced utilities unlocked"},
		{"id":"frontier","ready":campaign_count()>=6,"reward":6000,"text":"Frontier AI customers unlocked"},
		{"id":"v1","ready":Scenarios.ready(self),"reward":10000,"text":Scenarios.info(scenario_id).name.to_upper()+" COMPLETE! new company commissions are now available"}]
	for goal in goals:
		if goal.ready and goal.id not in milestone_claims:
			milestone_claims.append(goal.id)
			post("grant",goal.reward,goal.text)
			notices.append("%s. Expansion grant: $%d" % [goal.text,goal.reward])
	campaign_won = "v1" in milestone_claims
	if campaign_won: Scenarios.finish(self)

func rescue() -> bool:
	if rescued or cash >= 2000: return false
	post("grant",8000,"One-time rescue grant")
	rescued = true
	return true

func save_game(path: String = SAVE_PATH) -> bool:
	# Keep the original prototype town when upgrading its save format for the first time.
	if FileAccess.file_exists(path) and not FileAccess.file_exists(path+".v0-backup"):
		var parser=JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path))==OK and parser.data is Dictionary and parser.data.get("version")==1:
			if DirAccess.copy_absolute(path,path+".v0-backup")!=OK: return false
	var data = {"version": SAVE_VERSION, "lots": lots, "cash": cash, "earned": earned,
		"hour": hour, "approval": approval, "bought": bought, "cleared": cleared,
		"built": built, "won": won, "rescued": rescued,"active":active,"completed":completed,
		"history":history,"reputation":reputation,"next_ticket":next_ticket,"community_hour":community_hour,
		"milestone_claims":milestone_claims,"campaign_won":campaign_won,
		"company_name":company_name,"scenario_id":scenario_id,"difficulty":difficulty,
		"play_seconds":play_seconds,"view":view_state,"metadata":save_metadata,"finance":finance,"operations":ops,"civic":civic,"research":research,"workforce":workforce,"scenario_progress":scenario_progress,"tutorial":tutorial,"achievements":achievements}
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func load_game(path: String = SAVE_PATH) -> bool:
	last_error = "No saved town yet."
	if not FileAccess.file_exists(path): return false
	last_error = "This save is damaged or from an unsupported version."
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return false
	var data = parser.data
	if not data is Dictionary or not valid_number(data.get("version")): return false
	if data.version!=int(data.version) or int(data.version) not in [1,2,3,4,5,6,7,8,9,10,11,SAVE_VERSION]: return false
	if not data.get("lots") is Array: return false
	var source_size=10 if int(data.version)<=3 and data.lots.size()==100 else MAP_SIZE
	if data.lots.size()!=source_size*source_size: return false
	for key in ["cash", "earned", "hour", "approval"]:
		if not (data.get(key) is float or data.get(key) is int): return false
		if not is_finite(float(data[key])): return false
	for key in ["bought", "cleared", "built", "won", "rescued"]:
		if not data.get(key) is bool: return false
	for i in range(data.lots.size()):
		var lot = data.lots[i]
		if not lot is Dictionary: return false
		if lot.get("x") != i % source_size or lot.get("y") != i / source_size: return false
		if not lot.get("owned") is bool: return false
		if not (lot.get("price") is float or lot.get("price") is int) or lot.price < 0: return false
		if not lot.get("kind") in ["grass", "road", "house", "park", "warehouse", "monument", "datacenter", "power", "cooling", "water"]: return false
		var is_road = int(lot.x) == 4 or int(lot.y) == 4 if source_size==10 else Geography.road(int(lot.x),int(lot.y))
		if is_road != (lot.kind == "road"): return false
		if lot.kind in ["road","water"] and lot.owned: return false
		if BUILDINGS.has(lot.kind) and not lot.owned: return false
		var level = lot.get("level",1)
		if not valid_number(level) or level != int(level) or level < 1 or level > 3: return false
		lot.level = int(level)
		lot.x = int(lot.x)
		lot.y = int(lot.y)
		lot.price = int(lot.price)
		for flag in ["protected","permit","quiet","preserved","civic_home","civic_park"]:
			if lot.has(flag) and not lot[flag] is bool: return false
		var authored=Geography.authored_lot(lot.x,lot.y,data.get("scenario_id","littlebrook"))
		lot.town=authored.town
		lot.district=authored.district
		lot.protected=lot.get("protected",authored.protected and lot.kind in ["monument","park"])
		lot.permit=lot.get("permit",false)
		if not lot.get("hardware","balanced") in Economy.HARDWARE: return false
		if not valid_number(lot.get("refit_until",0)) or lot.get("refit_until",0)<0: return false
		if lot.get("refit_until",0)!=int(lot.get("refit_until",0)): return false
		if data.version>=5 and lot.kind=="datacenter" and (not lot.has("hardware") or not lot.has("refit_until")): return false
		if lot.kind=="datacenter":
			lot.hardware=lot.get("hardware","balanced");lot.refit_until=int(lot.get("refit_until",0))
		if BUILDINGS.has(lot.kind):
			if data.version>=6:
				for key in ["condition","service_until"]:
					if not valid_number(lot.get(key)): return false
				for key in ["failed","wear_warned"]:
					if not lot.get(key) is bool: return false
				if lot.condition<0 or lot.condition>100 or lot.service_until<0 or lot.service_until!=int(lot.service_until): return false
			lot.condition=float(lot.get("condition",100));lot.failed=lot.get("failed",false)
			lot.service_until=int(lot.get("service_until",0));lot.wear_warned=lot.get("wear_warned",false)
	if data.version>=12 and not Achievements.valid(data.get("achievements")): return false
	if data.version>=11 and not Tutorial.valid(data.get("tutorial")): return false
	if data.version>=10 and not Scenarios.valid(data.get("scenario_progress")): return false
	if data.version>=9 and not Workforce.valid(data.get("workforce")): return false
	if data.version>=8 and not Research.valid(data.get("research")): return false
	if data.version>=7 and not Civic.valid(data.get("civic")): return false
	if data.version>=6 and not Operations.valid(data.get("operations"),data.lots): return false
	if data.version>=5 and not Economy.valid_finance(data.get("finance")): return false
	if data.version>=5 and absf(data.finance.opening_cash+Economy.total(data.finance.totals)-data.cash)>0.02: return false
	var loaded_active: Array = []
	var loaded_completed: Array = []
	var loaded_history: Array = []
	var loaded_claims: Array = []
	if data.version >= 2:
		for key in ["active","completed","history","milestone_claims"]:
			if not data.get(key) is Array: return false
		for key in ["reputation","next_ticket","community_hour"]:
			if not valid_number(data.get(key)): return false
		if not data.get("campaign_won") is bool: return false
		if data.active.size()>3 or data.history.size()>12: return false
		var seen: Array = []
		for c in data.active:
			if not c is Dictionary: return false
			for key in ["id","name","client","brief","type"]:
				if not c.get(key) is String: return false
			for key in ["compute","work","deadline","reward","rate","unlock","progress","remaining","paid"]:
				if not valid_number(c.get(key)) or c[key]<0: return false
			if c.compute<=0 or c.work<=0 or c.deadline<=0 or c.remaining<=0 or c.remaining>c.deadline or c.progress>c.work: return false
			if c.type not in ["project","service"] or c.id in seen: return false
			seen.append(c.id)
			c.remaining=int(c.remaining)
			for key in ["compute","work","deadline","reward","unlock"]:
				if c[key]==int(c[key]): c[key]=int(c[key])
			if data.version>=5:
				if not c.get("workload") in Economy.WORKLOADS or not c.get("legacy_speed") is bool: return false
				for key in ["min_delivery","penalty_rate"]:
					if not valid_number(c.get(key)) or c[key]<0 or c[key]>1: return false
		for id in data.completed:
			if not id is String or id in seen: return false
			seen.append(id)
		for claim in data.milestone_claims:
			if not claim is String or claim not in ["campus","gpu","neural","frontier","v1"] or claim in loaded_claims: return false
			loaded_claims.append(claim)
		for entry in data.history:
			if not entry is Dictionary or not entry.get("name") is String or not entry.get("outcome") is String: return false
			if not valid_number(entry.get("amount")) or not valid_number(entry.get("hour")): return false
		loaded_active=data.active
		loaded_completed=data.completed
		loaded_history=data.history
	if data.version>=3:
		for key in ["company_name","scenario_id","difficulty"]:
			if not data.get(key) is String: return false
		if not Scenarios.TOWNS.has(data.scenario_id) or data.difficulty not in ["relaxed","standard","challenging"]: return false
		if not valid_number(data.get("play_seconds")) or data.play_seconds<0: return false
		if not data.get("view") is Dictionary or not data.get("metadata") is Dictionary: return false
		for key in ["zoom","pan_x","pan_y"]:
			if data.view.has(key) and not valid_number(data.view[key]): return false
		if data.view.has("zoom") and (data.view.zoom<0.1 or data.view.zoom>5): return false
		if data.view.has("selected") and (not valid_number(data.view.selected) or data.view.selected!=int(data.view.selected) or data.view.selected< -1 or data.view.selected>=data.lots.size()): return false
		if data.view.has("hardware") and not data.view.hardware in Economy.HARDWARE: return false
		if data.view.has("overlay") and data.view.overlay not in ["Town view","Electricity","Cooling","Noise","Ownership","Opinion"]: return false
		if data.view.has("bookmarks"):
			if not data.view.bookmarks is Array or data.view.bookmarks.size()>3: return false
			for mark in data.view.bookmarks:
				if not mark is Dictionary or not mark.get("name") is String: return false
				for key in ["zoom","pan_x","pan_y","selected"]:
					if not valid_number(mark.get(key)): return false
				if mark.zoom<0.65 or mark.zoom>2.4 or mark.selected<0 or mark.selected>=data.lots.size() or mark.selected!=int(mark.selected): return false
		for key in ["title","saved_at","kind"]:
			if data.metadata.has(key) and not data.metadata[key] is String: return false
	if source_size==10:
		var expanded:Array=[]
		for y in range(MAP_SIZE):
			for x in range(MAP_SIZE):
				expanded.append(data.lots[y*10+x] if x<10 and y<10 else Geography.authored_lot(x,y))
		if data.get("view",{}).has("selected") and data.view.selected>=0:
			var old_index=int(data.view.selected)
			data.view.selected=cell(old_index%10,old_index/10)
		for mark in data.get("view",{}).get("bookmarks",[]):
			var old_index=int(mark.selected)
			mark.selected=cell(old_index%10,old_index/10)
		data.lots=expanded
	lots = data.lots
	cash = float(data.cash)
	earned = maxf(0, data.earned)
	hour = maxi(0, int(data.hour))
	approval = clampi(int(data.approval), 0, 100)
	bought = data.bought
	cleared = data.cleared
	built = data.built
	won = data.won
	rescued = data.rescued
	active=[]
	for c in loaded_active: active.append(Economy.contract(c,data.version<5))
	completed=loaded_completed
	history=loaded_history
	milestone_claims=loaded_claims
	reputation=clampi(int(data.get("reputation",0)),0,100)
	next_ticket=maxi(0,int(data.get("next_ticket",0)))
	community_hour=int(data.get("community_hour",-24))
	campaign_won=campaign_count()>=8
	company_name=data.get("company_name","Littlebrook Infrastructure Co.")
	scenario_id=data.get("scenario_id","littlebrook")
	difficulty=data.get("difficulty","standard")
	play_seconds=float(data.get("play_seconds",0))
	view_state=data.get("view",{}).duplicate(true)
	if view_state.has("selected"): view_state.selected=int(view_state.selected)
	for mark in view_state.get("bookmarks",[]): mark.selected=int(mark.selected)
	save_metadata=data.get("metadata",{}).duplicate(true)
	finance=Economy.normalize(data.finance) if data.version>=5 else Economy.new_finance(cash,hour)
	ops=Operations.normalize(data.operations) if data.version>=6 else Operations.fresh()
	achievements=data.achievements.duplicate() if data.version>=12 else []
	tutorial=data.tutorial.duplicate(true) if data.version>=11 else Tutorial.fresh(false)
	scenario_progress=Scenarios.normalize(data.scenario_progress) if data.version>=10 else Scenarios.fresh()
	workforce=Workforce.normalize(data.workforce) if data.version>=9 else Workforce.fresh()
	research=Research.normalize(data.research) if data.version>=8 else Research.fresh()
	civic=Civic.normalize(data.civic) if data.version>=7 else Civic.fresh(approval,hour,campaign_count())
	Civic.refresh(self)
	notices.clear()
	# Old towns retain their economy and receive their first expansion grant once.
	check_milestones()
	last_error = ""
	return true

func valid_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func post(category:String,amount:float,note:String) -> void:
	amount=Economy.money(amount)
	cash=Economy.money(cash+amount)
	if category in Economy.SALES: earned=Economy.money(earned+amount)
	Economy.record(finance,hour,category,amount,note)

func borrow(amount:float=5000) -> String:
	amount=Economy.money(amount)
	if amount<=0 or not is_finite(amount) or finance.debt+amount>Economy.LOAN_LIMIT: return "The credit limit is $20,000."
	finance.debt+=amount
	post("loan_draw",amount,"Working capital loan")
	return ""

func repay(amount:float=5000) -> String:
	if not is_finite(amount) or amount<=0: return "Choose a positive repayment amount."
	amount=Economy.money(minf(amount,finance.debt))
	if amount<=0: return "There is no loan to repay."
	if cash<amount: return "Not enough cash to repay this principal."
	finance.debt-=amount
	post("loan_repayment",-amount,"Loan principal repayment")
	return ""

func hardware_unlocked(profile:String) -> bool:
	return Economy.HARDWARE.has(profile) and tech_level()>=Economy.HARDWARE[profile].unlock

func refit(index:int,profile:String) -> String:
	if index<0 or index>=lots.size() or lots[index].kind!="datacenter": return "Select a server hall."
	var lot:Dictionary=lots[index]
	if not hardware_unlocked(profile): return "Training accelerators require tier 2 (two deliveries)."
	if lot.get("hardware","balanced")==profile: return "This hall already uses that hardware."
	if not Operations.available(lot,hour): return "Repair or finish servicing this hall before refitting it."
	if int(lot.get("refit_until",0))>hour: return "Wait for the current refit to finish."
	var cost=Economy.HARDWARE[profile].refit
	if cash<cost: return "Not enough cash for this hardware refit."
	post("hardware",-cost,Economy.HARDWARE[profile].name)
	lot.hardware=profile;lot.refit_until=hour+Workforce.duration(self,2);lot.condition=100.0
	Workforce.dispatch(self,"refit",index,Workforce.duration(self,2))
	Civic.refresh(self)
	return ""

func prioritize(id:String,direction:int) -> String:
	for i in range(active.size()):
		if active[i].id!=id: continue
		var target=clampi(i+direction,0,active.size()-1)
		if target==i: return "Already at the end of the priority list."
		var c=active.pop_at(i);active.insert(target,c)
		return ""
	return "That contract has already finished."

func contract_quote(c:Dictionary) -> Dictionary:
	var candidate=c.duplicate(true)
	candidate.progress=0.0
	var before=metrics();var after=metrics(candidate)
	var delivery:float=after.deliveries.get(c.id,0.0)
	var eta=ceili(c.work/delivery) if delivery>0 else 9999
	var lost_spot=before.spot_revenue-after.spot_revenue
	var contribution=delivery*c.rate-lost_spot if c.type=="service" else c.reward/float(maxi(1,eta))-lost_spot
	var trough=0.9 if Research.has(self,"scheduler") else 0.65
	var variance=trough if hour%12<3 else 1.15
	var worst_eta=ceili(c.work/maxf(0.001,delivery/variance*trough)) if c.get("workload","")=="experimental" else eta
	var warning=""
	for event in ops.events:
		if event.phase in ["forecast","active","recovery"] and event.start<=hour+c.deadline:
			warning="Known incident overlaps this term. Check Operations projections and backup reserves."
	return {"delivery":delivery,"eta":eta,"worst_eta":worst_eta,"slack":int(c.deadline)-worst_eta,
		"margin":Economy.money(contribution),"cash_profit":after.profit,"reserved":c.compute,"free_after":maxf(0,before.free-c.compute),
		"penalty":roundi(c.reward*c.get("penalty_rate",0.1)),"min_delivery":c.get("min_delivery",0.9),"power":after.power_need,"cooling":after.cooling_need,"warning":warning}

func utility_for(lot:Dictionary,kind:String,at_hour:int=-1) -> Dictionary:
	return Geography.nearest_utility(lots,lot,kind,hour if at_hour<0 else at_hour)

func operate(action:String,index:int=-1) -> String:
	return Operations.act(self,action,index)

func cooling_for(lot:Dictionary,at_hour:int=-1) -> Dictionary:
	var result=utility_for(lot,"cooling",at_hour)
	var when=hour if at_hour<0 else at_hour
	if not result.is_empty() or ops.rental_until<=when or ops.rental_site<0: return result
	var site:Dictionary=lots[int(ops.rental_site)]
	if Geography.distance(lot,site)<=4 and not utility_for(site,"power",when).is_empty(): return site
	return {}

func take_operation_alerts() -> Array:
	var result=ops.alerts.duplicate(true)
	ops.alerts.clear()
	return result

func operations_status() -> String:
	var m=metrics()
	if not m.failures.is_empty(): return "%d equipment failures · Open Operations" % m.failures.size()
	for phase in ["active","recovery"]:
		for kind in ["outage","grid_maintenance","heatwave"]:
			for event in ops.events:
				if event.phase==phase and event.kind==kind: return "%s %s · Check reserves" % [Operations.NAMES[event.kind],phase]
	for event in ops.events:
		if event.phase=="forecast": return "%s in %dh · Prepare" % [Operations.NAMES[event.kind],event.start-hour]
	if not m.servicing.is_empty(): return "%d service visits in progress" % m.servicing.size()
	return ""

func forecast_event(event:Dictionary) -> Dictionary:
	var forecast=Operations.forecast_conditions(ops,event,maxi(hour,int(event.start)))
	forecast.at_hour=maxi(hour,int(event.start))
	forecast.startup=event.phase=="forecast"
	return metrics({},forecast)

func council(action:String,ward:String,index:int=-1) -> String:
	return Civic.act(self,action,ward,index)

func relocate_hall(source:int,target:int,preview:bool=false) -> String:
	if source<0 or source>=lots.size() or target<0 or target>=lots.size(): return "Select source hall and destination."
	var a:Dictionary=lots[source];var b:Dictionary=lots[target]
	if a.kind!="datacenter" or not a.owned: return "Choose an owned server hall."
	if not b.owned or b.kind!="grass": return "Buy and clear the destination first."
	if not Operations.available(a,hour) or int(a.get("refit_until",0))>hour: return "Finish repairs, service or refitting before moving."
	var error=Civic.expand_error(self,b)
	if error!="": return error
	var cost=1500+Geography.connection_cost(b)
	if cash<cost: return "Relocation costs $%d including access works." % cost
	if preview: return ""
	post("construction",-1500,"Relocate server hall")
	post("access",-Geography.connection_cost(b),"Relocation access works")
	for key in ["level","hardware","condition","failed","service_until","wear_warned"]: b[key]=a.get(key)
	b.kind="datacenter";b.refit_until=hour+2
	a.kind="grass";a.level=1
	for key in ["hardware","condition","failed","service_until","wear_warned","refit_until"]: a.erase(key)
	Civic.refresh(self)
	return ""

func take_civic_alerts() -> Array:
	var result=civic.alerts.duplicate(true)
	civic.alerts.clear()
	return result
