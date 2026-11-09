extends RefCounted
const Clients=preload("res://scripts/clients.gd")
## Economic rules and cash reporting. Every cash movement has one category.
const HARDWARE={
	"balanced":{"name":"Balanced racks","cost":4800,"refit":1800,"capacity":1.0,"power":1.0,"cooling":1.0,"upkeep":1.0,"noise":1.0,"wear":1.0,"inference":1.0,"training":1.0,"critical":1.0,"experimental":1.0,"unlock":1,"brief":"Versatile and inexpensive. No workload bonus."},
	"refurbished":{"name":"Refurbished racks","cost":3200,"refit":1000,"capacity":0.9,"power":1.3,"cooling":1.2,"upkeep":1.25,"noise":1.2,"wear":1.6,"inference":1.0,"training":0.8,"critical":1.0,"experimental":0.9,"unlock":1,"brief":"Low purchase price; higher power, maintenance and wear. Training runs slower."},
	"efficient":{"name":"Efficient inference","cost":6400,"refit":2800,"capacity":1.0,"power":0.65,"cooling":0.7,"upkeep":0.85,"noise":0.65,"wear":0.75,"inference":1.12,"training":0.85,"critical":1.0,"experimental":1.0,"unlock":1,"brief":"Lower power, cooling and noise. Inference +12%; training -15%."},
	"training":{"name":"Training accelerators","cost":7600,"refit":3800,"capacity":1.1,"power":1.4,"cooling":1.5,"upkeep":1.25,"noise":1.3,"wear":1.1,"inference":0.95,"training":1.45,"critical":1.0,"experimental":1.05,"unlock":2,"brief":"Training +45% and more physical capacity. Hotter, louder and costlier. Requires tier 2."}}
const WORKLOADS={
	"inference":{"name":"Inference","brief":"Steady, predictable demand. Efficient racks deliver 12% more work per reserved unit."},
	"training":{"name":"Model training","brief":"Batch work benefits from training accelerators. Refurbished and inference racks run it slower."},
	"critical":{"name":"Critical service","brief":"99% delivery required. A missed deadline costs 20% of the bonus. Keep reserves and give it priority."},
	"experimental":{"name":"Experimental AI","brief":"Throughput cycles between 65% (3h) and 115% (9h). Services tolerate 85% delivery. Reserve deadline slack."}}
const CUSTOMER_WORKLOAD={"bakery":"inference","support":"inference","studio":"experimental","robotics":"critical","research":"training","council":"critical","atlas":"training","orbital":"experimental"}
const CATEGORIES={
	"spot_income":"Spot market","service_income":"Recurring customers","project_income":"Project deliveries","bonus_income":"Service bonuses",
	"operations":"Resilience operations","resilience":"Backup equipment","fuel":"Generator fuel","rental":"Mobile cooling hire","repairs":"Repairs / servicing",
	"maintenance":"Equipment upkeep","staff":"Staff / operations","energy":"Electricity","interest":"Loan interest",
	"land":"Land purchases","construction":"Construction","access":"Access works","demolition":"Demolition","upgrade":"Tier upgrades","hardware":"Hardware refits",
	"community":"Community investment","heritage":"Heritage hearings","penalty":"Contract penalties","grant":"Expansion / rescue grants","loan_draw":"Loan principal received","loan_repayment":"Loan principal repaid"}
const SALES=["spot_income","service_income","project_income","bonus_income"]
const OPERATING=["spot_income","service_income","project_income","bonus_income","maintenance","staff","energy","interest","penalty","operations","fuel","rental","repairs"]
const LOAN_LIMIT=20000.0
const INTEREST=0.0005
const ENERGY_PRICE=0.12

static func money(value:float) -> float:
	return roundf(value*100.0)/100.0

static func stats(base:Dictionary,profile:String) -> Dictionary:
	var p:Dictionary=HARDWARE[profile]
	var result=base.duplicate()
	for key in ["capacity","power","cooling","upkeep"]: result[key]=money(base[key]*p[key])
	return result

static func contract(c:Dictionary,legacy:bool=false) -> Dictionary:
	var result=Clients.decorate(c)
	var workload=CUSTOMER_WORKLOAD.get(c.id,"training")
	result.workload=c.get("workload",workload)
	result.min_delivery=c.get("min_delivery",0.9 if legacy else (0.99 if workload=="critical" else (0.85 if workload=="experimental" else 0.9)))
	result.penalty_rate=c.get("penalty_rate",0.1 if legacy or workload!="critical" else 0.2)
	result.legacy_speed=c.get("legacy_speed",legacy)
	return result

static func new_finance(cash:float,hour:int) -> Dictionary:
	return {"opening_cash":cash,"since_hour":hour,"debt":0.0,"totals":{},"current":{},"period_opening":cash,"history":[],"transactions":[]}

static func record(finance:Dictionary,hour:int,category:String,amount:float,note:String) -> void:
	amount=money(amount)
	if is_zero_approx(amount): return
	for totals in [finance.totals,finance.current]: totals[category]=money(totals.get(category,0.0)+amount)
	finance.transactions.push_front({"hour":hour,"category":category,"amount":amount,"note":note})
	if finance.transactions.size()>240: finance.transactions.resize(240)

static func close_day(finance:Dictionary,hour:int,cash:float) -> void:
	if hour%24!=0: return
	finance.history.push_front({"day":int((hour-1)/24)+1,"opening":finance.period_opening,"closing":cash,"totals":finance.current.duplicate()})
	if finance.history.size()>30: finance.history.resize(30)
	finance.current.clear();finance.period_opening=cash

static func total(totals:Dictionary,keys:Array=[]) -> float:
	var sum=0.0
	for key in totals:
		if keys.is_empty() or key in keys: sum+=totals[key]
	return money(sum)

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(value)

static func valid_totals(totals) -> bool:
	if not totals is Dictionary: return false
	for category in totals:
		if not CATEGORIES.has(category) or not number(totals[category]): return false
	return true

static func valid_finance(finance) -> bool:
	if not finance is Dictionary: return false
	for key in ["opening_cash","since_hour","debt","period_opening"]:
		if not number(finance.get(key)): return false
	if finance.debt<0 or finance.debt>LOAN_LIMIT or finance.since_hour<0: return false
	for key in ["totals","current"]:
		if not valid_totals(finance.get(key)): return false
	if not finance.get("history") is Array or finance.history.size()>30: return false
	if not finance.get("transactions") is Array or finance.transactions.size()>240: return false
	for day in finance.history:
		if not day is Dictionary or not valid_totals(day.get("totals")): return false
		for key in ["day","opening","closing"]:
			if not number(day.get(key)): return false
	for transaction in finance.transactions:
		if not transaction is Dictionary: return false
		if not CATEGORIES.has(transaction.get("category")) or not transaction.get("note") is String: return false
		for key in ["amount","hour"]:
			if not number(transaction.get(key)): return false
	return true

static func normalize(finance:Dictionary) -> Dictionary:
	var result=finance.duplicate(true)
	result.since_hour=int(result.since_hour)
	for row in result.transactions: row.hour=int(row.hour)
	for row in result.history: row.day=int(row.day)
	return result
