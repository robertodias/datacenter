extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var Strategy=load(get_script().resource_path.get_base_dir().path_join("operating_strategy.gd"))
const Economy=preload("res://scripts/economy.gd")
var checks=0
var failures=0
var path="user://economy-test.json"

func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)

func balanced(profile:String="balanced"):
	var s=Sim.new()
	s.buy(83);s.demolish(83)
	if profile=="training": s.completed=["bakery","support"]
	expect(s.build(83,"datacenter",profile)=="","Build "+profile+" starter hall")
	s.buy(82);s.build(82,"power");s.buy(99);s.build(99,"cooling")
	return s

func reconcile(s,message:String) -> void:
	expect(is_equal_approx(s.cash,Economy.money(s.finance.opening_cash+Economy.total(s.finance.totals))),message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var s=balanced()
	var cheap=balanced("refurbished")
	var efficient=balanced("efficient")
	var training=balanced("training")
	expect(cheap.cash>s.cash and cheap.metrics().compute<s.metrics().compute,"Refurbished hardware trades output for initial savings")
	expect(cheap.metrics().energy>s.metrics().energy and efficient.metrics().energy<s.metrics().energy,"Hardware changes the actual electricity bill")
	expect(efficient.metrics().cooling_need<s.metrics().cooling_need,"Efficient cooling requirements genuinely fall")
	expect(training.metrics().power_need>s.metrics().power_need,"Training accelerators require extra power")
	var probe={"id":"probe","compute":40,"work":400,"deadline":40,"rate":0.0,"reward":1000,"type":"project","workload":"training"}
	expect(training.contract_quote(probe).delivery>s.contract_quote(probe).delivery and cheap.contract_quote(probe).delivery<s.contract_quote(probe).delivery,"Training hardware changes delivered work, not only a cosmetic stat")
	for company in [s,cheap,efficient,training]:
		var m=company.metrics()
		expect(is_equal_approx(m.upkeep,m.maintenance+m.staff+m.energy+m.interest),"All operating cost lines add to displayed upkeep")
		for i in range(24): company.tick()
		reconcile(company,"Ledger reconciles purchases, operation and grants")
		expect(company.finance.history.size()==1,"Daily cash report closes at midnight")
	var earned=s.earned;var cash=s.cash
	expect(s.borrow()=="" and s.cash==cash+5000 and s.earned==earned,"Loan principal is cash but never customer revenue")
	expect(s.finance.debt==5000 and s.metrics().interest==2.5,"Loan interest is charged at the published rate")
	s.tick();reconcile(s,"Interest flows into the same cash ledger")
	expect(s.repay()=="" and s.finance.debt==0 and s.metrics().interest==0,"Repayment removes future interest")
	for i in range(4): expect(s.borrow()=="","Draw credit in clear increments")
	cash=s.cash
	expect(s.borrow()!="" and s.cash==cash,"Credit limit prevents an extra draw")
	expect(s.repay(20000)=="","Earned cash plus loan can repay principal")
	reconcile(s,"Debt draw and repayment reconcile exactly")
	var queue=balanced()
	queue.accept_contract("bakery");queue.accept_contract("support")
	expect(queue.refit(83,"refurbished")=="" and queue.metrics().compute==0,"Refit actually removes hall output")
	expect(queue.refit(83,"efficient")!="","A running refit cannot be replaced")
	queue.tick();queue.tick()
	expect(queue.metrics().compute==90,"Refitted hall returns after exactly two hours")
	var m=queue.metrics()
	expect(m.allocations.bakery==40 and m.allocations.support==50,"First priority receives scarce compute first")
	expect(queue.prioritize("support",-1)=="","Player can change priority")
	m=queue.metrics()
	expect(m.allocations.support==60 and m.allocations.bakery==30,"Priority changes actual allocations")
	expect(m.spot==0 and m.sold<=m.compute,"Reserved units are never also sold on the market")
	var critical=balanced()
	critical.completed=["bakery","support"]
	critical.upgrade(83);critical.upgrade(82)
	expect(critical.accept_contract("robotics")=="","Critical service can be signed with adequate capacity")
	var definition=critical.active[0]
	expect(definition.min_delivery==0.99 and definition.penalty_rate==0.2,"Critical service has stricter explicit terms")
	var recovered=balanced();recovered.completed=["bakery","support"];recovered.upgrade(83);recovered.upgrade(82)
	recovered.accept_contract("robotics")
	recovered.demolish(82);recovered.tick();recovered.build(82,"power")
	for i in range(35): recovered.tick()
	expect("robotics" in recovered.completed,"One lost hour is recovered from spare compute (catch-up up to 125%)")
	critical.demolish(82)
	for i in range(10): critical.tick()
	critical.build(82,"power")
	for i in range(26): critical.tick()
	expect(not "robotics" in critical.completed and critical.history[0].amount==-roundi(definition.reward*0.2),"A long interruption beyond catch-up forfeits the strict bonus and charges the published penalty")
	var experimental=s.contract_definition("studio")
	expect(experimental.workload=="experimental","Experimental customers use a distinct workload")
	s.hour=12;var low=s.contract_quote(experimental)
	s.hour=16;var high=s.contract_quote(experimental)
	expect(high.delivery>low.delivery and high.worst_eta==low.worst_eta,"Burst forecast shows varying output and stable conservative duration")
	# Savings include hardware, priorities, debt, full financial history and refit timing.
	queue.refit(83,"efficient");queue.borrow()
	expect(queue.save_game(path),"Save mid-refit with loans and prioritized work")
	var copy=Sim.new()
	expect(copy.load_game(path),"Load full economic state")
	expect(copy.lots==queue.lots and copy.active==queue.active and copy.finance==queue.finance,"Hardware, reservation order and complete ledger round-trip")
	var saved_data=JSON.parse_string(FileAccess.get_file_as_string(path))
	var altered=saved_data.duplicate(true);altered.cash+=1;write(altered)
	expect(not copy.load_game(path),"Cash that disagrees with its ledger is rejected")
	altered=saved_data.duplicate(true);altered.lots[83].erase("hardware");write(altered)
	expect(not copy.load_game(path),"Missing current-format hardware cannot silently change a saved hall")
	write(saved_data)
	for i in range(30): queue.tick();copy.tick()
	expect(queue.cash==copy.cash and queue.completed==copy.completed and queue.finance==copy.finance,"Continued refit / customer / interest results are exact after reload")
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	data.version=4;data.erase("finance")
	for c in data.active:
		for key in ["workload","min_delivery","penalty_rate","legacy_speed"]: c.erase(key)
	write(data)
	expect(copy.load_game(path) and copy.finance.debt==0,"Version 4 towns import with an opening cash balance")
	expect(copy.active.all(func(c):return c.legacy_speed and c.min_delivery==0.9 and c.penalty_rate==0.1),"Already-signed older contracts keep their original terms")
	reconcile(copy,"Imported ledger begins at the actual imported cash")
	data.version=5;data.finance={"debt":"broken"};write(data)
	cash=copy.cash
	expect(not copy.load_game(path) and copy.cash==cash,"Damaged finance data cannot replace live state")
	DirAccess.remove_absolute(path)
	# Full campaigns with no injected cash, including debt-free and financed strategies.
	for profile in ["balanced","refurbished","efficient","training"]: play_strategy(profile)
	play_strategy("balanced",true)
	root.size=Vector2i(1440,900)
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.sound_enabled=false
	await process_frame
	game.business.open("finance");await process_frame
	expect(game.business.finance_view!=null and game.business.finance_view.rows.size()==Economy.CATEGORIES.size(),"Financial report presents every cash category")
	game.sim=balanced();game.town.sim=game.sim
	game.business.open("offers");game.business.review_contract(game.sim.contract_definition("bakery"))
	expect(game.dialog.visible and game.dialog.dialog_text.contains("Contribution") and game.dialog.dialog_text.contains("Failure"),"Signing opens a concrete margin and risk review")
	game.pending.call();game.dialog.hide()
	expect(game.sim.active.size()==1,"Reviewed contract can actually be signed")
	game.business.open("hardware")
	for i in range(3): await process_frame
	var rig=game.business.finance_view.halls[0]
	expect(game.business.content_scroll.get_global_rect().encloses(rig.option.get_global_rect()),"Hardware shortcut brings the actual profile control into view")
	game.complete_action(game.sim.refit(83,"efficient"),"Refit test")
	for i in range(3): await process_frame
	rig=game.business.finance_view.halls[0]
	expect(game.business.content_scroll.get_global_rect().encloses(rig.option.get_global_rect()) and rig.status.text.contains("REFITTING"),"Refitting preserves the hardware view and shows its actual result")
	expect(game.money_detail(2.5)=="$2.50" and game.money_detail(-52.3)=="-$52.30","Financial amounts preserve cents in cost breakdowns")
	game.pending=Callable()
	game.sound.stop()
	for i in range(3): await process_frame
	game.queue_free();await process_frame;await create_timer(0.1).timeout
	print("COMPUTE ECONOMY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func play_strategy(profile:String,civic_start:bool=false) -> void:
	var s=balanced("balanced" if profile=="training" else profile)
	if profile=="training": s.borrow(10000)
	if civic_start:
		s.borrow(10000)
		var homes=[]
		for i in range(s.lots.size()):
			if s.lots[i].kind=="house" and s.Civic.ward_for(s.lots[i])=="oldtown": homes.append(i)
		for i in range(3): s.buy(homes[i]);s.demolish(homes[i])
		for i in range(36): Strategy.tick(s)
		expect(s.civic.wards.oldtown.stage==4,"Civic campaign reaches a real permit pause from actual demolition")
		expect(s.council("negotiate","oldtown")=="","Civic campaign pays for a measurable negotiation")
		for i in range(3):
			var site=s.Civic.project_site(s,"oldtown",-1)
			expect(s.council("housing","oldtown",site)=="","Civic campaign pays to rehouse a displaced family")
		s.invest_community()
		for i in range(28): Strategy.tick(s)
		expect(s.civic.wards.oldtown.stage==0,"Civic campaign resolves the causes and resumes normal expansion")
	var minimum=s.cash
	for id in ["bakery","support","studio","robotics","research","council","atlas","orbital"]:
		if s.tech_level()>=2 and profile=="training" and s.lots[83].hardware!="training":
			expect(s.refit(83,"training")=="","Financed strategy can refit with earned contract progress")
			for i in range(2): Strategy.tick(s)
		var c=s.contract_definition(id)
		var waits=0
		while s.metrics().compute<c.compute and waits<1500:
			if s.tech_level()>s.lots[83].level and s.cash>=s.TIERS.datacenter[s.lots[83].level].cost: s.upgrade(83)
			if s.tech_level()>s.lots[82].level and s.cash>=s.TIERS.power[s.lots[82].level].cost: s.upgrade(82)
			if s.tech_level()>s.lots[99].level and s.cash>=s.TIERS.cooling[s.lots[99].level].cost: s.upgrade(99)
			if s.lots[83].level==3 and s.metrics().compute<c.compute:
				var other=Sim.cell(3,7)
				if s.lots[other].kind=="grass" and s.cash>=s.lots[other].price+s.construction_cost(other,"datacenter",profile):
					s.buy(other);s.build(other,"datacenter",profile)
				if s.lots[other].kind=="datacenter" and s.lots[other].level<2 and s.cash>=5200: s.upgrade(other)
			if s.metrics().compute>=c.compute: break
			Strategy.tick(s);minimum=minf(minimum,s.cash);waits+=1
		expect(s.accept_contract(id)=="","%s strategy signs %s without injected cash" % [profile,id])
		var elapsed=0
		while s.active.any(func(item):return item.id==id) and elapsed<100:
			Strategy.tick(s);elapsed+=1;minimum=minf(minimum,s.cash)
		expect(id in s.completed,"%s strategy delivers %s" % [profile,id])
	if s.finance.debt>0: expect(s.repay(s.finance.debt)=="","Financed training campaign can repay its loan")
	expect(s.campaign_won and minimum>=0,"%s completes solvent with positive reserves" % profile)
	reconcile(s,"%s complete-campaign cash flow reconciles" % profile)
	print("STRATEGY ",profile+ (" + civic recovery" if civic_start else ""),": min cash $",minimum,"; final $",s.cash,"; debt $",s.finance.debt)

func write(data:Dictionary) -> void:
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
