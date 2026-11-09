extends RefCounted
## Authored geography and spatial rules, shared by simulation and map UI.
const Economy=preload("res://scripts/economy.gd")
const SIZE=16
const DISTRICTS={
	"foundry":{"name":"Foundry Quarter","sensitivity":0.35,"price":0.85},
	"oldtown":{"name":"Old Quarter","sensitivity":1.25,"price":1.0},
	"market":{"name":"Market District","sensitivity":0.8,"price":1.3},
	"riverside":{"name":"Riverside Works","sensitivity":0.55,"price":1.1},
	"gardens":{"name":"Civic Gardens","sensitivity":1.5,"price":1.15}}

static func index(x:int,y:int) -> int:
	return y*SIZE+x

static func district(x:int,y:int) -> String:
	if x>=10 and y>=8: return "gardens"
	if x>=10: return "market"
	if x>=6: return "riverside"
	if y>=7: return "foundry"
	return "oldtown"

static func road(x:int,y:int) -> bool:
	return x in [4,12] or y in [4,12]

static func authored_lot(x:int,y:int,scenario:String="littlebrook") -> Dictionary:
	var area=district(x,y)
	var kind="grass"
	if road(x,y): kind="road"
	elif x in [8,9]: kind="water"
	elif area=="oldtown" and (x*7+y*11)%5<2: kind="house"
	elif area=="market" and (x+y)%3!=0: kind="house"
	elif area=="gardens" and (x+y)%3==0: kind="park"
	elif area=="foundry" and (x+y*2)%9==0: kind="warehouse"
	elif (x+y*3)%11==0: kind="park"
	if Vector2i(x,y)==Vector2i(7,2) or Vector2i(x,y)==Vector2i(11,10): kind="monument"
	if Vector2i(x,y)==Vector2i(3,5): kind="warehouse"
	if Vector2i(x,y) in [Vector2i(2,5),Vector2i(3,6),Vector2i(2,7),Vector2i(3,7)]: kind="grass"
	var price=roundi((700+((x*13+y*7)%5)*100)*DISTRICTS[area].price)
	if kind=="house": price=roundi(1700*DISTRICTS[area].price)
	if kind=="warehouse": price=1200
	if kind=="monument": price=4200
	if kind in ["water","road"]: price=0
	# Preserve the original inexpensive introduction beside the main road.
	if Vector2i(x,y)==Vector2i(2,5): price=800
	if Vector2i(x,y)==Vector2i(3,6): price=800
	if scenario=="sunsprawl":
		if kind=="water": kind="grass"
		if not road(x,y) and x>=10 and y<10: kind="house" if (x+y)%2==0 else "grass"
		if Vector2i(x,y)==Vector2i(7,2): kind="park"
		if kind=="grass": price=roundi(price*0.85) if price>0 else 900
		if kind=="house": price=1800
	elif scenario=="oldbridge":
		if not road(x,y) and kind=="grass" and x not in [8,9] and (x+y)%3!=0: kind="house";price=1700
		if Vector2i(x,y) in [Vector2i(1,1),Vector2i(3,2),Vector2i(6,6),Vector2i(14,9)]: kind="monument";price=4200
		price=roundi(price*1.35)
	# Every opening retains a small usable industrial conversion site.
	if Vector2i(x,y)==Vector2i(3,5): kind="warehouse";price=1200
	if Vector2i(x,y) in [Vector2i(2,5),Vector2i(3,6),Vector2i(2,7),Vector2i(3,7)]: kind="grass";price=800
	return {"town":scenario,"x":x,"y":y,"kind":kind,"owned":false,"price":price,"level":1,"district":area,"protected":kind=="monument" or (area=="gardens" and kind=="park"),"permit":false}

static func distance(a:Dictionary,b:Dictionary) -> int:
	return absi(int(a.x)-int(b.x))+absi(int(a.y)-int(b.y))

static func road_distance(lot:Dictionary) -> int:
	return mini(mini(absi(int(lot.x)-4),absi(int(lot.x)-12)),mini(absi(int(lot.y)-4),absi(int(lot.y)-12)))

static func connection_cost(lot:Dictionary) -> int:
	return maxi(0,road_distance(lot)-1)*350

static func sensitivity(lot:Dictionary) -> float:
	return DISTRICTS[district(int(lot.x),int(lot.y))].sensitivity

static func demolition_impact(lot:Dictionary) -> int:
	if lot.kind=="monument": return 25
	var base={"house":8,"park":5}.get(lot.kind,0)
	return roundi(base*sensitivity(lot))

static func river_access(lot:Dictionary) -> bool:
	return lot.get("town","littlebrook")!="sunsprawl" and int(lot.x) in [7,10]

static func utility_range(level:int) -> int:
	return [4,7,12][clampi(level,1,3)-1]

static func nearest_utility(lots:Array,lot:Dictionary,kind:String,hour:int=-1) -> Dictionary:
	var nearest:Dictionary={}
	var best=999
	for candidate in lots:
		if candidate.kind!=kind or not candidate.owned: continue
		if candidate.get("failed",false) or (hour>=0 and int(candidate.get("service_until",0))>hour): continue
		var d=distance(lot,candidate)
		if d<=utility_range(int(candidate.get("level",1))) and d<best:
			best=d
			nearest=candidate
	return nearest

static func noise(lots:Array,lot:Dictionary) -> float:
	var total=0.0
	for source in lots:
		var intensity={"datacenter":24.0,"cooling":15.0,"power":8.0}.get(source.kind,0.0)
		if intensity==0: continue
		intensity*=Economy.HARDWARE[source.get("hardware","balanced")].noise if source.kind=="datacenter" else 1.0
		intensity*=0.4 if source.get("quiet",false) else 1.0
		var d=distance(lot,source)
		if d<=4: total+=intensity*(1.0-d/5.0)*(1.0+0.15*(int(source.get("level",1))-1))
	return minf(100,total*sensitivity(lot))

static func preview(lots:Array,index_value:int,kind:String,base_cost:int) -> Dictionary:
	var lot:Dictionary=lots[index_value]
	var power=nearest_utility(lots,lot,"power")
	var cooling=nearest_utility(lots,lot,"cooling")
	var clearance={"house":600,"warehouse":250,"park":200,"monument":1400,"datacenter":250,"power":250,"cooling":250}.get(lot.kind,0)
	var surcharge=connection_cost(lot)
	var hearing=4000 if lot.get("protected",false) and not lot.get("permit",false) else 0
	return {"construction":base_cost+surcharge,"access":surcharge,"land":0 if lot.owned else lot.price,"clearance":clearance,
		"total":base_cost+surcharge+clearance+hearing+(0 if lot.owned else lot.price),"hearing":hearing,"power":not power.is_empty(),"cooling":not cooling.is_empty(),
		"power_lot":-1 if power.is_empty() else index(int(power.x),int(power.y)),"cooling_lot":-1 if cooling.is_empty() else index(int(cooling.x),int(cooling.y)),
		"sensitivity":sensitivity(lot),"approval":demolition_impact(lot),"river_bonus":kind=="cooling" and river_access(lot),"protected":lot.get("protected",false) and not lot.get("permit",false)}
