extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Ops=preload("res://scripts/operations.gd")
var Strategy=load(get_script().resource_path.get_base_dir().path_join("operating_strategy.gd"))
var checks=0
var failures=0
var path="user://operations-test.json"

func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)

func campus():
	var s=Sim.new()
	s.buy(83);s.demolish(83);s.build(83,"datacenter")
	s.buy(82);s.build(82,"power");s.buy(99);s.build(99,"cooling")
	return s

func upgraded():
	var s=campus()
	s.accept_contract("bakery");s.accept_contract("support")
	for i in range(24): s.tick()
	s.upgrade(83);s.upgrade(82);s.upgrade(99)
	return s

func inject(s,kind:String,duration:int=4,lead:int=0) -> void:
	Ops.add_event(s.ops,kind,s.hour+1,duration,lead)
	s.tick()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var s=campus()
	expect(s.operate("battery")=="" and s.ops.charge==240,"Battery installs charged at a real purchase cost")
	expect(s.operate("generator")=="" and s.operate("fuel")=="","Generator and fuel are separate paid purchases")
	var cash=s.cash
	inject(s,"outage")
	var m=s.metrics()
	expect(m.weather.grid==0 and m.generator_output==0 and m.battery_output==60 and m.compute==100,"Batteries bridge the generator's first startup hour")
	s.tick();m=s.metrics()
	expect(s.ops.charge==180 and m.generator_output==60 and m.battery_output==0,"Generator takes over after exactly one hour")
	s.tick()
	expect(s.ops.fuel<12 and s.ops.fuel>11,"Generator consumes fuel according to delivered energy")
	for i in range(5): s.tick()
	expect(s.ops.charge==240 and s.ops.results.size()==1,"Recovery recharges batteries and records a result")
	expect(s.ops.results[0].lost_compute==0 and s.ops.results[0].backup_mwh>=240,"Prepared campus has no lost output during outage")
	expect(is_equal_approx(s.cash,s.Economy.money(s.finance.opening_cash+s.Economy.total(s.finance.totals))),"Backup purchases, energy and running costs reconcile")
	var bare=campus();inject(bare,"outage")
	expect(bare.metrics().compute==0,"Unprepared outage actually stops compute")
	bare.ops.fuel=0
	expect(bare.operate("warm")!="","Cannot enable generator standby without a generator")
	var warm=campus();warm.operate("generator");warm.operate("fuel");warm.operate("warm")
	inject(warm,"outage")
	expect(warm.metrics().compute==100 and warm.metrics().generator_output==60,"Paid warm standby avoids startup downtime")
	var cold=campus();cold.operate("generator");cold.operate("fuel");inject(cold,"outage")
	cold.operate("warm")
	expect(cold.metrics().compute==0,"Switching warm standby on at impact does not skip startup")
	cold.tick()
	expect(cold.metrics().compute==100,"Warm standby becomes ready after its published preparation time")
	var thermal=upgraded();thermal.lots[99].level=1
	inject(thermal,"heatwave",10,12)
	m=thermal.metrics()
	expect(m.compute<220 and m.cooling_need>70 and m.weather.temperature>=38,"Heatwave throttles a campus with thin cooling reserves")
	expect(thermal.operate("rental")=="" and thermal.metrics().compute==220,"Mobile cooling provides practical immediate recovery")
	expect(thermal.metrics().power_need==105 and thermal.metrics().operations==12,"Rental needs power and has a visible operating cost")
	expect(thermal.operate("rental")!="","Rental cannot be stacked or renewed early")
	thermal.lots[99].condition=50.0;thermal.operate("service",99)
	expect(thermal.metrics().compute==220,"Mobile chillers can bridge planned service on the permanent cooling plant")
	# Projection expires temporary gear before a future forecast; it is read-only.
	var future=upgraded();future.lots[99].level=1;future.operate("rental")
	Ops.add_event(future.ops,"heatwave",future.hour+30,10,12)
	var event=future.ops.events[-1]
	var before=JSON.stringify(future.ops)
	expect(future.forecast_event(event).compute<220 and JSON.stringify(future.ops)==before,"Forecast accounts for rental expiry without advancing state")
	var wear=campus()
	wear.lots[83].condition=0.01;wear.tick()
	expect(wear.lots[83].failed and wear.metrics().compute==0,"Neglected equipment can fail independently of the grid")
	expect(wear.operate("service",83)=="" and wear.lots[83].service_until==wear.hour+4,"Breakdown repair has a real four-hour timer")
	for i in range(4): wear.tick()
	expect(not wear.lots[83].failed and wear.metrics().compute==100,"Repairs restore equipment and usable output")
	wear.lots[99].condition=50
	expect(wear.operate("service",99)=="" and wear.metrics().compute==0,"Planned cooling service has downtime that must be covered")
	for i in range(2): wear.tick()
	expect(wear.metrics().compute==100 and wear.lots[99].condition>99,"Planned service completes after two hours")
	var stochastic=campus();stochastic.lots[83].condition=29.0
	for i in range(100):
		stochastic.tick()
		if stochastic.lots[83].failed: break
	expect(stochastic.lots[83].failed and stochastic.lots[83].condition>0,"Poor-condition equipment can fail through the random branch before wearing to zero")
	var hub=campus();hub.operate("battery");hub.operate("generator");hub.operate("fuel")
	hub.lots[82].condition=50.0;hub.operate("service",82)
	inject(hub,"outage")
	expect(not hub.metrics().hub_online and hub.metrics().compute==0,"A serviced backup hub cannot silently power the campus")
	hub.buy(115);hub.build(115,"power")
	expect(hub.operate("move_hub",115)=="" and hub.metrics().hub_online and hub.metrics().compute==100,"Relocating paid backup equipment provides a real recovery route")
	var insured=campus();insured.operate("crews")
	var normal=campus()
	for i in range(10): insured.tick();normal.tick()
	expect(insured.lots[83].condition>normal.lots[83].condition and insured.metrics().operations==9,"Preventive contract reduces actual wear and bills each building")
	insured.lots[83].condition=0;insured.lots[83].failed=true;insured.tick()
	expect(insured.lots[83].service_until>insured.hour,"Preventive crews dispatch to an already failed building")
	var prepared=upgraded();var unprepared=upgraded()
	for company in [prepared,unprepared]: expect(company.accept_contract("robotics")=="","Sign strict customer for the resilience comparison")
	prepared.operate("battery");prepared.operate("generator");prepared.operate("fuel")
	for company in [prepared,unprepared]: inject(company,"outage",10)
	for i in range(35): prepared.tick();unprepared.tick()
	expect("robotics" in prepared.completed and not "robotics" in unprepared.completed,"Resilience changes the strict customer's actual contract outcome")
	# Exact state resumes under a combined outage, heatwave, fuel draw and service.
	var saved=upgraded();saved.operate("battery");saved.operate("generator");saved.operate("fuel");saved.operate("rental")
	inject(saved,"outage",5);Ops.add_event(saved.ops,"heatwave",saved.hour+1,10,0)
	saved.tick();saved.lots[83].condition=25.0;saved.operate("service",83)
	saved.lots[82].condition=29.0
	expect(saved.save_game(path),"Save a combined live incident and scheduled service")
	var copy=Sim.new()
	expect(copy.load_game(path) and copy.ops==saved.ops and copy.lots==saved.lots,"Incident phases, RNG, fuel, charge and timers restore exactly")
	for i in range(160): Strategy.tick(saved);Strategy.tick(copy)
	expect(saved.ops==copy.ops and saved.lots==copy.lots and saved.finance==copy.finance and saved.cash==copy.cash,"Future random failures and subsequent incident schedules stay identical after load")
	expect(saved.ops.results.size()>=4,"Later schedules generate combinations and incident result history")
	var data=JSON.parse_string(FileAccess.get_file_as_string(path));data.operations.rng="broken"
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
	cash=copy.cash
	expect(not copy.load_game(path) and copy.cash==cash,"Corrupt incident data cannot replace the current town")
	DirAccess.remove_absolute(path)
	root.size=Vector2i(1440,900)
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.sound_enabled=false;game.sim=campus();game.town.sim=game.sim
	game.settings.auto_pause=true;game.paused=false
	Ops.alert(game.sim.ops,"Forecast test")
	game.handle_operation_alerts()
	expect(game.paused and game.business.visible and game.business.tab=="operations","Auto-pause opens actionable operations before more time elapses")
	game.business.visible=false;game.paused=false;game.settings.auto_pause=false
	Ops.alert(game.sim.ops,"Non-pausing test");game.handle_operation_alerts()
	expect(not game.paused and not game.business.visible,"Disabling auto-pause preserves running time while still displaying the alert")
	game.paused=true
	for i in range(3): await process_frame
	game.queue_free();await process_frame;await create_timer(0.1).timeout
	print("OPERATIONS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
