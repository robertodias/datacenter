extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=0
var path="user://release-soak.json"
func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var sim=Sim.new();sim.buy(83);sim.demolish(83);sim.build(83,"datacenter");sim.buy(82);sim.build(82,"power");sim.buy(99);sim.build(99,"cooling")
	for i in range(10): sim.tick()
	expect("FIRST_WATT" in sim.achievements,"Actual earned revenue grants a local achievement")
	var count=sim.achievements.size();sim.Achievements.capture(sim)
	expect(sim.achievements.size()==count,"Achievement capture is idempotent")
	sim.save_game(path);var loaded=Sim.new()
	expect(loaded.load_game(path) and sim.achievements==loaded.achievements,"Local achievements survive reload")
	var data=JSON.parse_string(FileAccess.get_file_as_string(path));data.version=11;data.erase("achievements")
	write(data);expect(loaded.load_game(path) and loaded.achievements.is_empty(),"Schema 11 preview save migrates into final demo")
	loaded.tick();expect("FIRST_WATT" in loaded.achievements,"Migrated company earns supported achievements from actual progress")
	expect(not Sim.Achievements.valid(["FIRST_WATT","FIRST_WATT"]) and not Sim.Achievements.valid(["FAKE"]),"Malformed achievements reject")
	# Dense stress fixture, not an economic strategy: fund and build a sandbox campus.
	sim.new_game("Long-session stress","sandbox");sim.post("grant",10000000,"QA stress fixture capital")
	sim.completed=["bakery","support","studio","robotics"]
	var built=0
	for i in range(sim.lots.size()):
		if sim.lots[i].kind!="grass" or built>=60: continue
		var kind=["power","cooling","datacenter"][built%3]
		sim.buy(i);sim.build(i,kind)
		sim.upgrade(i);sim.upgrade(i);built+=1
	sim.operate("crews");sim.Workforce.set_team(sim,"technicians",3);sim.Workforce.set_team(sim,"engineers",2)
	expect(built==60,"Stress town contains sixty real tier-3 buildings")
	var started=Time.get_ticks_msec()
	for i in range(1000): sim.tick()
	var elapsed=Time.get_ticks_msec()-started
	expect(sim.Operations.valid(sim.ops,sim.lots) and sim.Civic.valid(sim.civic) and sim.Workforce.valid(sim.workforce),"Thousand-hour dense-town state remains valid")
	expect(sim.finance.transactions.size()<=240 and sim.finance.history.size()<=30 and sim.ops.events.size()<=24 and sim.workforce.history.size()<=20,"Long-session histories remain bounded")
	expect(sim.achievements.is_empty(),"Sandbox does not award campaign achievements")
	expect(sim.save_game(path) and loaded.load_game(path),"Dense long-session town saves and loads")
	for i in range(100): sim.tick();loaded.tick()
	expect(sim.cash==loaded.cash and sim.lots==loaded.lots and sim.ops==loaded.ops and sim.civic==loaded.civic and sim.workforce==loaded.workforce,"Dense town continues exactly after reload")
	var report={"buildings":built,"simulation_hours":1100,"timed_ticks":1000,"elapsed_ms":elapsed,"average_tick_ms":elapsed/1000.0,"save_bytes":FileAccess.get_file_as_bytes(path).size(),"renderer":"headless simulation; not a GPU benchmark"}
	var file=FileAccess.open("C:/Users/Usuario/Development/datacenter/build/soak-report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	DirAccess.remove_absolute(path)
	print("RELEASE SOAK: %d checks, %d failures; 1000 ticks %dms" % [checks,failures,elapsed]);quit(1 if failures else 0)
func write(data:Dictionary) -> void:
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
