extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
var checks = 0
var failures = 0

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _init() -> void:
	var sim = Sim.new()
	expect(sim.lots.size() == 256, "Town has 256 plots")
	expect(sim.buy(68) != "", "Public roads cannot be purchased")
	expect(sim.build(83, "datacenter") != "", "Cannot build on unowned land")
	expect(sim.demolish(83) != "", "Cannot demolish unowned property")
	expect(sim.buy(83) == "", "Buy the starter warehouse")
	expect(sim.cash == 20800, "Purchase charges the correct price")
	expect(sim.buy(83) != "" and sim.cash == 20800, "Repeated purchase cannot charge twice")
	expect(sim.build(83, "datacenter") != "", "Occupied land blocks construction")
	expect(sim.demolish(83) == "" and sim.cash == 20550, "Demolition clears and charges")
	expect(sim.lots[83].kind == "grass" and sim.lots[83].owned, "Demolition retains ownership")
	expect(sim.build(83, "datacenter") == "", "Build first server hall")
	expect(sim.metrics().compute == 0, "No power means no compute")
	var before = sim.cash
	sim.tick()
	expect(sim.cash == before - 38 and sim.earned == 0, "Offline hall costs upkeep without revenue")
	sim.buy(82)
	sim.build(82, "power")
	expect(sim.metrics().compute == 0, "Power alone cannot bypass cooling")
	sim.buy(99)
	sim.build(99, "cooling")
	var m = sim.metrics()
	expect(m.power_need == 60 and m.power == 120, "Utility power demand included")
	expect(m.cooling_need == 40 and m.cooling == 120, "Cooling supplies full capacity")
	expect(m.compute == 100 and is_equal_approx(m.profit,54.8), "Campus pays $7.20/h for 60 MW before net profit")
	for i in range(10): sim.tick()
	expect(sim.earned == 1200 and sim.won, "First playable objective completes from real revenue")
	var path = "user://simulation-test.json"
	expect(sim.save_game(path), "Atomic save succeeds")
	var other = Sim.new()
	expect(other.load_game(path), "Save loads")
	expect(other.cash == sim.cash and other.earned == sim.earned and other.won, "Economy and progression survive reload")
	expect(other.metrics() == sim.metrics(), "Network state survives reload")
	expect(other.lots == sim.lots, "All lot state survives reload")
	for i in range(3):
		var idx = 80 + i * 16
		if sim.lots[idx].kind == "road": continue
		sim.cash = 100000
		sim.buy(idx)
		if sim.lots[idx].kind != "grass": sim.demolish(idx)
		sim.build(idx, "datacenter")
	m = sim.metrics()
	expect(m.efficiency < 1 and m.compute < m.capacity, "Overbuilding throttles capacity")
	expect(m.sold <= 300, "Demand caps revenue")
	for lot in sim.lots:
		if lot.kind == "power": sim.demolish(int(lot.y) * 16 + int(lot.x))
	expect(sim.metrics().compute == 0, "Removing electricity stops revenue")
	var poor = Sim.new()
	poor.cash = 10
	expect(poor.buy(83) != "" and poor.cash == 10, "Insufficient funds cannot purchase land")
	expect(poor.rescue() and poor.cash == 8010, "Recovery grant works")
	poor.cash = 0
	expect(not poor.rescue(), "Recovery grant is one-time")
	var civic = Sim.new()
	civic.buy(39)
	civic.redevelopment_permit(39)
	civic.demolish(39)
	expect(civic.approval == 50, "Monument demolition costs 25 approval")
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var old_cash = other.cash
	expect(not other.load_game(path) and other.cash == old_cash, "Malformed save does not overwrite current town")
	DirAccess.remove_absolute(path)
	print("SIMULATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
