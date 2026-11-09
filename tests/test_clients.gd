extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Clients=preload("res://scripts/clients.gd")
var checks=0
var failures=0
var path="user://clients-test.json"
func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var sim=Sim.new()
	var roster=["FreeAGI","Synthopic","Groove","Noodle","Amazing","Megahard","SmilingFace","BlueWhale","GPN"]
	var reached=[]
	for c in sim.offers():
		expect(c.client in roster and c.name.begins_with(c.client+":"),"Campaign offer names its fictional sponsor")
		reached.append(c.client)
	var scout=sim.Research.offer(sim)
	expect(scout.client=="SmilingFace" and scout.workload=="inference","Community hub sponsors the research-unlocked inference pilot")
	reached.append(scout.client)
	expect(roster.all(func(c):return c in reached),"All nine requested companies have playable contracts")
	for c in Sim.CONTRACTS: sim.completed.append(c.id)
	sim.check_milestones()
	for i in range(18):
		sim.next_ticket=i
		var offer=sim.contract_definition("open_%d" % i)
		expect(offer.client==roster[roster.find(Clients.COMMISSIONS[i%9])] and offer.workload=="training" and offer.work==18000,"Repeat commissions preserve training economics and rotate sponsors")
	sim.new_game();sim.buy(83);sim.demolish(83);sim.build(83,"datacenter");sim.buy(82);sim.build(82,"power");sim.buy(99);sim.build(99,"cooling")
	expect(sim.accept_contract("bakery")=="" and sim.accept_contract("support")=="","Existing first-campus capacity serves GPN and Synthopic")
	for i in range(4): sim.tick()
	sim.save_game(path)
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	data.version=11;data.erase("achievements")
	for c in data.active: c.name="Old mission";c.client="Old sponsor";c.brief="Old copy"
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
	var loaded=Sim.new()
	expect(loaded.load_game(path),"Preview save migrates with in-flight contracts")
	expect(sim.active==loaded.active,"Migration refreshes narrative without resetting deadlines, negotiated fees, delivery or payments")
	for i in range(25): sim.tick();loaded.tick()
	expect(sim.cash==loaded.cash and sim.completed==loaded.completed and sim.history==loaded.history,"Migrated contracts deliver identically and record fictional names")
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true;game.menu.visible=false
	game.settings.ui_scale=1.15;game.apply_settings(false,false);root.size=Vector2i(1152,720)
	await process_frame;game.layout_stage()
	game.business.open("clients")
	for i in range(3): await process_frame
	expect(game.business.content_scroll.get_v_scroll_bar().max_value>game.business.content_scroll.size.y,"Nine biographies scroll at minimum resolution with enlarged text")
	for company in roster:
		game.business.client_filter=company;game.business.refresh()
		for i in range(2): await process_frame
		var text=labels(game.business.body)
		expect(text.contains(Clients.COMPANIES[company].background) and text.contains(Clients.COMPANIES[company].motto),"Company profile displays complete lore for "+company)
	game.business.open("offers")
	for i in range(3): await process_frame
	var cards=game.business.content_scroll.get_child(0).get_children()
	expect(game.business.bindings.all(func(b):return not b.quote.text.contains("9999") and not b.quote.text.contains("worst slack")),"Unavailable contracts explain capacity instead of displaying placeholder delivery times")
	for card in cards:
		var box=card.get_child(0)
		var previous_bottom=0.0
		var fits=true
		for child in box.get_children():
			fits=fits and child.position.y>=previous_bottom and child.position.y+child.size.y<=box.size.y
			previous_bottom=child.position.y+child.size.y
		expect(fits,"Contract copy and actions flow without overlap at enlarged text")
	game.queue_free();await process_frame;await create_timer(0.1).timeout
	DirAccess.remove_absolute(path)
	print("FICTIONAL CLIENTS: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
func labels(node:Node) -> String:
	var text=node.text+"\n" if node is Label else ""
	for child in node.get_children(): text+=labels(child)
	return text
