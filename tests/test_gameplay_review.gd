extends SceneTree
## Regression checks for the 1.3 gameplay and logic review (docs/REVIEW-1.3-gameplay.md).
## One block per finding, numbered as in the review. Isolated QA saves only.
const Sim=preload("res://scripts/simulation.gd")
const Ops=preload("res://scripts/operations.gd")
const Civic=preload("res://scripts/civic.gd")
const Research=preload("res://scripts/research.gd")
const Work=preload("res://scripts/workforce.gd")
const Tutorial=preload("res://scripts/tutorial.gd")
const SAVE="user://qa_gameplay_review.json"
var checks=0
var failures=0

func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)

func campus(s=null):
	if s==null: s=Sim.new()
	s.post("grant",200000.0-s.cash,"QA funds")
	s.buy(83);s.demolish(83);s.build(83,"datacenter")
	s.buy(82);s.build(82,"power");s.buy(99);s.build(99,"cooling")
	return s

## A buildable plot more than eight plots from every utility.
func far_plots(s,count:int) -> Array:
	var result=[]
	for i in range(s.lots.size()):
		var lot=s.lots[i]
		if lot.kind=="grass" and Sim.Geography.distance(lot,s.lots[82])>8 and Sim.Geography.distance(lot,s.lots[99])>8:
			result.append(i)
			if result.size()==count: break
	return result

func _initialize() -> void: call_deferred("run")

func run() -> void:
	# 1. Clearing the campus ends the rental, and the save still loads.
	var s=campus()
	expect(s.operate("rental",83)=="","1: rental staged")
	s.tick()
	s.demolish(83);s.demolish(82);s.demolish(99)
	expect(s.ops.rental_site==-1 and s.ops.rental_until==0,"1: rental ends when no building remains")
	var m=s.metrics()
	expect(m.power_need==0 and m.operations==0,"1: no rental demand or fee without buildings")
	expect(s.save_game(SAVE),"1: save written")
	var loaded=Sim.new()
	expect(loaded.load_game(SAVE),"1: save with a returned rental loads")
	var broken=Ops.fresh();broken.rental_until=40;broken.rental_site=-1
	expect(Ops.valid(broken,s.lots) and Ops.normalize(broken).rental_until==0,"1: older saves with an orphaned rental load and end it")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# 2. Disconnected halls and unpowered plants take no power or cooling.
	s=campus()
	var before=s.metrics()
	for i in far_plots(s,3): s.buy(i);s.build(i,"datacenter")
	var after=s.metrics()
	expect(after.disconnected.size()==3,"2: three far halls are disconnected")
	expect(is_equal_approx(after.power_need,before.power_need) and is_equal_approx(after.cooling_need,before.cooling_need),"2: disconnected halls add no demand")
	expect(is_equal_approx(after.compute,before.compute),"2: connected compute is unaffected")
	var plant=far_plots(s,1)[0]
	s.buy(plant);s.build(plant,"cooling")
	expect(is_equal_approx(s.metrics().power_need,before.power_need),"2: an unpowered cooling plant draws nothing")

	# 3. Sunsprawl's weaker grid does not run generators; a real incident does.
	s=Sim.new();s.new_game("QA","sunsprawl","standard");campus(s)
	s.buy(114);s.build(114,"datacenter");s.buy(115);s.build(115,"cooling")
	s.operate("generator",82);s.operate("fuel");s.operate("warm")
	for i in range(3): s.tick()
	m=s.metrics()
	expect(Ops.conditions(s.ops).grid==1.0 and m.power<m.power_need,"3: Sunsprawl campus is short of power with no incident")
	expect(m.generator_output==0,"3: generators stay on standby without an incident")
	var outage=s.metrics({},{"grid":0.0,"cooling":1.0,"heat":1.0,"temperature":22})
	expect(outage.generator_output>0,"3: generators still answer a real grid incident in Sunsprawl")

	# 4. A promise needs a real improvement.
	s=Sim.new();s.cash=100000
	var park=-1
	for i in range(s.lots.size()):
		if s.lots[i].kind=="park" and not s.lots[i].protected and s.lots[i].district!="gardens": park=i;break
	var ward=s.lots[park].district
	s.buy(park);s.demolish(park)
	var concern=s.civic_reports[ward].concerns[s.civic_reports[ward].primary]
	expect(s.council("negotiate",ward)=="","4: negotiation opens on the heritage concern")
	expect(s.civic.wards[ward].promise_value<=concern-2.0,"4: the promised level is below today's value")
	var standing=s.civic.standing
	for i in range(25): s.tick()
	expect(s.civic.standing<=standing,"4: doing nothing does not keep the promise")
	expect(is_equal_approx(Civic.promise_target("noise",30),19.5) and is_equal_approx(Civic.promise_target("heritage",8),5.2),"4: promise targets are a 35% cut")

	# 5. The rental moves with a relocated hall.
	s=campus()
	s.operate("rental",83);s.buy(114)
	expect(s.relocate_hall(83,114)=="","5: hall relocated")
	expect(s.ops.rental_site==114,"5: rental follows the hall")

	# 6. Modules above the substation limit stay idle.
	s=campus()
	var subs=[98,114,115]
	for i in subs:
		s.buy(i)
		if s.lots[i].kind!="grass": s.demolish(i)
		s.build(i,"power")
	for k in range(12): s.operate("battery",82)
	expect(s.ops.batteries==12,"6: twelve batteries with four substations")
	for i in subs: s.demolish(i)
	var plan=Ops.power_plan(s,0.0,2000.0,{"grid":0.0,"cooling":1.0,"heat":1.0,"temperature":22})
	expect(plan.battery<=Ops.module_limit(s)*120.0+0.001,"6: battery output is capped at the current limit")

	# 7. Commercial terms leave with the staff who negotiated them.
	s=campus();s.tick()
	var base=s.contract_definition("bakery")
	Work.set_team(s,"commercial",3)
	expect(s.accept_contract("bakery")=="","7: contract signed with commercial staff")
	var signed=s.active[0]
	expect(signed.deadline==base.deadline+12 and signed.commercial==3,"7: three teams add twelve hours")
	Work.set_team(s,"commercial",0)
	expect(signed.deadline==base.deadline and is_equal_approx(signed.penalty_rate,base.penalty_rate),"7: dismissing them restores the base terms")
	expect(signed.remaining<=signed.deadline,"7: remaining time stays within the deadline")

	# 8. Continuing to the next town keeps achievements.
	s=Sim.new()
	s.new_game("QA","sunsprawl","standard",["LITTLEBROOK","FIRST_WATT","NOT_AN_ACHIEVEMENT"])
	expect(s.achievements==["LITTLEBROOK","FIRST_WATT"],"8: earned achievements carry to the next town")
	s.new_game("QA","littlebrook","standard")
	expect(s.achievements.is_empty(),"8: a new company starts with none")

	# 9. A rebuilt substation reconnects backup equipment.
	s=campus()
	s.operate("battery",82)
	s.demolish(82)
	expect(s.ops.hub==-1,"9: hub cleared with the last substation")
	s.buy(98);if s.lots[98].kind!="grass": s.demolish(98)
	s.build(98,"power")
	expect(s.ops.hub==98,"9: new substation hosts the backup equipment")

	# 10. Upgrades re-arm the wear warning.
	s=campus();s.completed=["bakery","support"]
	s.lots[83].condition=40.0;s.lots[83].wear_warned=true
	expect(s.upgrade(83)=="","10: hall upgraded")
	expect(not s.lots[83].wear_warned,"10: wear warning re-armed")

	# 11 and 16. Scout services pay near the market and need 90% delivery.
	s=campus()
	var scout=Research.offer(s,false)
	var per_unit=(scout.work*scout.rate+scout.reward)/scout.work
	expect(per_unit<=1.6,"11: scout services pay about $1.50 per unit (got %.2f)" % per_unit)
	expect(is_equal_approx(scout.min_delivery,0.9),"16: scout services need 90% delivery")

	# 12. A refit keeps condition and never undercuts building the hardware.
	s=campus();s.buy(98);if s.lots[98].kind!="grass": s.demolish(98)
	s.build(98,"datacenter","refurbished")
	s.lots[98].condition=60.0
	var cash=s.cash
	expect(s.refit(98,"efficient")=="","12: refit started")
	expect(cash-s.cash>=Sim.Economy.HARDWARE.efficient.cost-Sim.Economy.HARDWARE.refurbished.cost,"12: refit costs at least the build-price difference")
	expect(s.lots[98].condition==60.0,"12: condition carries through a refit")
	expect(s.refit_cost({"hardware":"balanced"},"efficient")==Sim.Economy.HARDWARE.efficient.refit,"12: ordinary refits keep their listed price")

	# 13. Building on vacant plots completes the clearing step.
	s=Sim.new();s.cash=100000
	s.buy(82);s.buy(99);s.buy(114)
	s.build(82,"datacenter");s.build(99,"power");s.build(114,"cooling")
	for i in range(3): s.tick()
	expect("clear" in s.tutorial.done and Tutorial.current(s).get("id","")!="clear","13: tutorial does not ask for a needless demolition")

	# 14. Repeat commissions wait for the town's charter.
	s=Sim.new();s.new_game("QA","sunsprawl","standard")
	for c in Sim.CONTRACTS: s.completed.append(c.id)
	s.check_milestones()
	expect(not s.offers().any(func(c):return c.id.begins_with("open_")),"14: no commissions before the Sunsprawl charter")
	s.scenario_progress.best_sustainable=24;s.check_milestones()
	expect(s.offers().any(func(c):return c.id.begins_with("open_")),"14: commissions open with the charter")

	# 15. Demolition clears a heritage permit.
	s=Sim.new();s.cash=100000
	var site=-1
	for i in range(s.lots.size()):
		if s.lots[i].get("protected",false) and not s.lots[i].get("preserved",false): site=i;break
	s.buy(site);s.lots[site].permit=true
	expect(s.demolish(site)=="","15: permitted site demolished")
	expect(not s.lots[site].get("permit",false),"15: the permit does not outlive the building")

	# 17. Idle halls make less traffic.
	s=campus()
	ward=Civic.ward_for(s.lots[83])
	var busy=s.civic_reports[ward].trips
	s.lots[83].failed=true;Civic.refresh(s)
	expect(s.civic_reports[ward].trips<busy,"17: a failed hall makes fewer delivery trips")

	print("GAMEPLAY REVIEW: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
