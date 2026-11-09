extends RefCounted
## A paid, repeatable player strategy used by complete campaign tests.
## Never edits cash, suppresses incidents, resets equipment or changes clocks.
static func prepare(s) -> void:
	if s.ops.commission<0: return
	var m=s.metrics()
	var batteries=mini(3,maxi(1,ceili(m.power_need/120)))
	var generators=mini(3,maxi(1,ceili(m.power_need/180)))
	if s.cash<1500 and s.finance.debt<15000: s.borrow()
	if s.ops.batteries<batteries and s.cash>=3300: s.operate("battery")
	if s.ops.generators<generators and s.cash>=4100: s.operate("generator")
	if s.ops.generators>0 and s.ops.fuel<8 and s.cash>=1400: s.operate("fuel")
	if not s.ops.crews: s.operate("crews")
	for event in s.ops.events:
		if event.kind!="heatwave" or event.phase not in ["forecast","active"]: continue
		if event.start-s.hour>4: continue
		var projection=s.forecast_event(event)
		if projection.compute<projection.capacity-0.01 and s.cash>=1600 and s.ops.rental_until<=s.hour+4: s.operate("rental")
	for lot in s.lots:
		if not s.BUILDINGS.has(lot.kind): continue
		if lot.failed and lot.service_until<=s.hour: s.operate("service",s.cell(int(lot.x),int(lot.y)))

static func tick(s) -> void:
	prepare(s)
	s.tick()
