extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var Strategy=load(get_script().resource_path.get_base_dir().path_join("operating_strategy.gd"))
var checks=0
var failures=0
var reports=[]
func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for route in [
		{"name":"Preservation / engineer","profile":"balanced","branch":"optimize","followup":"predict","style":"preserve","difficulty":"standard"},
		{"name":"Redevelopment / commercial","profile":"balanced","branch":"discover","followup":"outreach","style":"redevelop","difficulty":"standard"},
		{"name":"Premium / visionary","profile":"efficient","branch":"scheduler","followup":"water_loop","style":"preserve","difficulty":"standard"},
		{"name":"Cheap / redundancy","profile":"refurbished","branch":"optimize","followup":"predict","style":"","difficulty":"challenging"},
		{"name":"Relaxed / commercial","profile":"balanced","branch":"discover","followup":"outreach","style":"","difficulty":"relaxed"}]:
		play(route)
	var file=FileAccess.open("C:/Users/Usuario/Development/datacenter/build/balance-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t"));file.close()
	print("BALANCE: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
func play(route:Dictionary) -> void:
	var s=Sim.new();s.new_game(route.name,"littlebrook",route.difficulty)
	s.buy(83);s.demolish(83);s.build(83,"datacenter",route.profile);s.buy(82);s.build(82,"power");s.buy(99);s.build(99,"cooling")
	if route.style=="preserve":
		var count=0
		for i in range(s.lots.size()):
			if s.lots[i].kind in ["park","monument"] and count<3:
				expect(s.council("preserve",s.lots[i].district,i)=="",route.name+" pays for conservation");count+=1
	elif route.style=="redevelop":
		s.borrow(5000);var count=0
		for i in range(s.lots.size()):
			if s.lots[i].kind=="house" and s.lots[i].district=="oldtown" and count<2:
				s.buy(i);s.demolish(i);s.council("housing","oldtown",i);count+=1
	var minimum=s.cash;var max_wait=0;var total_wait=0
	for id in ["bakery","support","studio","robotics","research","council","atlas","orbital"]:
		if id=="studio":
			# Pay for a development interval; research competes with spot income.
			for project in [route.branch,route.followup]:
				s.Research.select(s,project);s.Research.allocate(s,50)
				for i in range(180):
					if s.Research.has(s,project): break
					Strategy.tick(s);minimum=minf(minimum,s.cash)
				expect(s.Research.has(s,project),route.name+" funds "+project)
			s.Research.allocate(s,0)
		if id=="research":
			s.Workforce.set_team(s,"technicians",1);s.Workforce.set_team(s,"engineers",1)
			if route.branch=="discover": s.Workforce.set_team(s,"commercial",1)
		var c=s.contract_definition(id);var waits=0
		while s.metrics().compute<c.compute and waits<1000:
			for site in [83,82,99]:
				var lot:Dictionary=s.lots[site]
				if s.tech_level()>lot.level and s.cash>=s.TIERS[lot.kind][lot.level].cost: s.upgrade(site)
			if s.lots[83].level==3 and s.metrics().compute<c.compute:
				if s.lots[115].kind=="grass" and s.cash>=s.lots[115].price+s.construction_cost(115,"datacenter",route.profile): s.buy(115);s.build(115,"datacenter",route.profile)
				if s.lots[115].kind=="datacenter" and s.lots[115].level<2 and s.cash>=5200: s.upgrade(115)
			if s.metrics().compute>=c.compute: break
			Strategy.tick(s);minimum=minf(minimum,s.cash);waits+=1
		max_wait=maxi(max_wait,waits);total_wait+=waits
		expect(s.accept_contract(id)=="",route.name+" can sign "+id)
		for i in range(120):
			if not s.active.any(func(item):return item.id==id): break
			Strategy.tick(s);minimum=minf(minimum,s.cash)
		expect(id in s.completed,route.name+" delivers "+id)
	if s.finance.debt>0: expect(s.repay(s.finance.debt)=="",route.name+" repays borrowing")
	expect(s.campaign_won and minimum>=0,route.name+" remains solvent through the finale")
	expect(max_wait<180,route.name+" avoids a prolonged capacity dead end")
	expect(absf(s.finance.opening_cash+s.Economy.total(s.finance.totals)-s.cash)<0.02,route.name+" reconciles all wages, research tradeoffs and investments")
	reports.append({"route":route.name,"difficulty":route.difficulty,"minimum_cash":minimum,"ending_cash":s.cash,"debt":s.finance.debt,"hours":s.hour-8,"normal_speed_minutes":(s.hour-8)*4.0/60,"largest_capacity_wait_hours":max_wait,"total_capacity_wait_hours":total_wait,"completed":s.campaign_won,"lost_compute_hours":s.ops.total_lost_compute})
	print("BALANCE ROUTE ",route.name,": min $",minimum,"; hours ",s.hour-8,"; max wait ",max_wait,"; cash $",s.cash)
