extends "res://scripts/research_panel.gd"
const Clients=preload("res://scripts/clients.gd")
func draw(parent:Node) -> void:
	var box=section(parent,"Meet your customers")
	copy(box,"Nine fictional companies, nine very different ideas of what your spare compute is for.")
	if board.client_filter!="":
		action(box,"Show all companies",func():board.client_filter="";board.refresh())
	for company in Clients.COMPANIES:
		if board.client_filter!="" and board.client_filter!=company: continue
		var profile:Dictionary=Clients.COMPANIES[company]
		box=section(parent,company+" / "+profile.specialty)
		copy(box,profile.motto,18,game.GOLD)
		copy(box,profile.background)
		var contract_id=Clients.CAMPAIGN.find_key(company)
		if contract_id!=null:
			var c=game.sim.contract_definition(contract_id)
			copy(box,"Campaign mission: "+profile.mission)
			copy(box,profile.brief)
			var status="Delivered" if contract_id in game.sim.completed else ("Active" if game.sim.active.any(func(a):return a.id==contract_id) else ("Available" if game.sim.campaign_count()>=c.unlock else "Unlocks after %d campaign deliveries" % c.unlock))
			copy(box,"%s / %s / %d compute" % [status,game.sim.Economy.WORKLOADS[c.workload].name,c.compute],14,game.MINT)
		else:
			copy(box,"Research Customer scout to unlock SmilingFace's recurring community inference pilot. It also sponsors the first training commission after eight campaign deliveries.")
		copy(box,"Further training commissions rotate through every company after the eight campaign deliveries.",14,game.MUTED)
		action(box,"Browse contracts",func():board.open("offers"))
func update_live() -> void:
	pass
