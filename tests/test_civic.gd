extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Civic=preload("res://scripts/civic.gd")
const Geo=preload("res://scripts/town_rules.gd")
var checks=0
var failures=0
var path="user://civic-test.json"

func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)

func campus():
	var s=Sim.new();s.buy(83);s.demolish(83);s.build(83,"datacenter")
	s.buy(82);s.build(82,"power");s.buy(99);s.build(99,"cooling")
	return s

func sites(s,kind:String,ward:String) -> Array:
	var result=[]
	for i in range(s.lots.size()):
		if s.lots[i].kind==kind and Civic.ward_for(s.lots[i])==ward: result.append(i)
	return result

func displaced_town():
	var s=Sim.new();s.post("grant",20000,"Civic test fixture")
	var homes=sites(s,"house","oldtown")
	for i in range(3): s.buy(homes[i]);s.demolish(homes[i])
	return s

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var s=campus()
	expect(s.civic_reports.oldtown.jobs==8,"Working campus contributes actual local jobs")
	expect(s.civic_reports.oldtown.pressure<18,"Introductory campus does not immediately provoke opposition")
	var base_adoption=Civic.adoption(s);var base_spot=s.metrics().spot_limit
	expect(s.council("education","oldtown")=="","Skills program is a paid action")
	for i in range(12): s.tick()
	expect(Civic.adoption(s)>base_adoption and s.metrics().spot_limit>base_spot,"Education grows adoption and actual open-market demand")
	var before_adoption=Civic.adoption(s);var before_approval=s.approval
	var home=sites(s,"house","oldtown")[0];s.buy(home);s.demolish(home)
	expect(s.approval<before_approval and Civic.adoption(s)==before_adoption,"Demolition reduces support independently of adoption")
	expect(s.civic.wards.oldtown.displaced==1,"Actual home demolition records the displaced family")
	var population=s.civic_reports.oldtown.population
	var vacant=sites(s,"grass","oldtown")[0]
	expect(s.council("housing","oldtown",vacant)=="" and s.lots[vacant].kind=="house","Housing action creates a visible real home at the selected site")
	expect(s.civic.wards.oldtown.displaced==0 and s.civic_reports.oldtown.population==population,"Rehousing restores a home without inventing new residents")
	var next=sites(s,"grass","oldtown")[0];s.council("housing","oldtown",next)
	expect(s.civic_reports.oldtown.population==population+3,"Extra housing welcomes a new worker family")
	var cash=s.cash
	expect(s.council("housing","oldtown",83)!="" and s.cash==cash,"Invalid project cannot overwrite equipment or charge money")
	var noise=s.civic_reports.oldtown.noise
	expect(s.council("quiet","oldtown",83)=="" and s.civic_reports.oldtown.noise<noise,"Acoustic barriers reduce actual residential noise exposure")
	cash=s.cash
	expect(s.council("quiet","oldtown",83)!="" and s.cash==cash,"Repeated acoustic barriers are rejected without a second charge")
	var relocating=campus();relocating.buy(115)
	var old_noise=relocating.civic_reports.oldtown.noise
	expect(relocating.relocate_hall(83,115)=="","Owned vacant industrial site accepts hall relocation")
	expect(relocating.lots[83].kind=="grass" and relocating.lots[115].hardware=="balanced" and relocating.civic_reports.oldtown.noise<old_noise,"Relocation physically moves the hall and reduces noise near the original homes")
	expect(relocating.metrics().compute==0,"Relocated hall has real commissioning downtime")
	relocating.tick();relocating.tick()
	expect(relocating.metrics().compute==100,"Local connections restore relocated hall after exactly two hours")
	var civic=displaced_town();var w:Dictionary=civic.civic.wards.oldtown
	var stages=[]
	for i in range(36):
		civic.tick()
		if not int(w.stage) in stages: stages.append(int(w.stage))
	expect(stages==[0,1,2,3,4],"Real displacement escalates through warning, petition, demonstration and permit pause")
	expect(civic.civic.history.size()>=4 and civic.civic.history[0].message.contains("Rehouse"),"Escalation records a specific cause and remedy")
	var empty=sites(civic,"grass","oldtown")[0];civic.buy(empty)
	cash=civic.cash
	expect(civic.build(empty,"datacenter").contains("permits paused") and civic.cash==cash,"Permit pause prevents new halls without charging construction")
	expect(civic.site_preview(empty).permit_error.contains("Rehouse"),"Construction preview exposes permit cause before spending")
	expect(civic.build(empty,"power")=="","Permit pause leaves remedial utilities available")
	civic.completed=["bakery","support"]
	var hall=sites(civic,"grass","oldtown")[0];civic.buy(hall)
	expect(civic.council("expedite","oldtown")=="" and w.waiver_until==civic.hour+24,"Paid expedited permit has an explicit 24-hour duration")
	expect(w.grievance>=12 and civic.civic.standing<=37,"Aggressive expansion damages local and town-wide trust")
	expect(civic.build(hall,"datacenter")=="" and civic.upgrade(hall)=="","Expedited permit permits real hall construction and tier upgrades")
	for i in range(24): civic.tick()
	civic.completed.append("studio");civic.completed.append("robotics")
	expect(civic.upgrade(hall).contains("permits paused"),"Permit waiver expires and unresolved complaints restrict further expansion")
	var recovery=displaced_town()
	for i in range(36): recovery.tick()
	var wr:Dictionary=recovery.civic.wards.oldtown
	var leading=recovery.civic_reports.oldtown.primary
	expect(recovery.council("negotiate","oldtown")=="" and wr.promise_cause==leading,"Negotiation records the real leading concern and deadline")
	var agreed=wr.promise_value;var stress=wr.stress
	recovery.tick()
	expect(wr.stress==stress,"Negotiation freezes escalation while the agreement is active")
	expect(recovery.council("negotiate","oldtown")!="","Meeting cooldown prevents endless repeated freezes")
	for i in range(3): recovery.council("housing","oldtown",sites(recovery,"grass","oldtown")[0])
	expect(recovery.civic_reports.oldtown.concerns.displacement<=agreed,"Physical rehousing satisfies the negotiated demand")
	recovery.invest_community()
	for i in range(24): recovery.tick()
	expect(recovery.civic.history.any(func(row):return row.message.contains("Promise kept")),"Kept promise is evaluated at its saved deadline")
	expect(wr.stage==0 and wr.stress==0,"Resolving actual concerns de-escalates the protest and lifts permits")
	var broken=displaced_town();broken.council("negotiate","oldtown")
	for i in range(24): broken.tick()
	expect(broken.civic.wards.oldtown.grievance>=10 and broken.civic.history.any(func(row):return row.message.contains("Promise broken")),"Ignoring a promise causes lasting grievance and an explicit result")
	var preserved=Sim.new();var park=sites(preserved,"park","gardens")[0]
	expect(preserved.council("preserve","gardens",park)=="" and preserved.lots[park].preserved,"Conservation action creates a permanent protected covenant")
	preserved.buy(park)
	var conservation_cash=preserved.cash
	expect(preserved.redevelopment_permit(park).contains("Conservation") and preserved.cash==conservation_cash,"Protected covenant rejects a paid heritage hearing before charging money")
	cash=preserved.cash
	expect(preserved.demolish(park).contains("Conservation") and preserved.cash==cash,"Heritage hearing cannot bypass a permanent conservation covenant")
	var restoration=Sim.new();restoration.post("grant",15000,"Restoration fixture")
	var monument=sites(restoration,"monument","riverside")[0]
	restoration.buy(monument);restoration.redevelopment_permit(monument);restoration.demolish(monument)
	expect(restoration.civic.wards.riverside.heritage_loss==1,"Actual landmark removal persists as a heritage concern")
	expect(restoration.council("memorial","riverside",monument)=="" and restoration.civic.wards.riverside.heritage_loss==0 and restoration.lots[monument].protected,"Replacement monument physically repairs lost heritage")
	var strain=campus();strain.post("grant",40000,"Strain fixture")
	strain.lots[83].level=3;strain.lots[82].level=3;strain.lots[99].level=3
	strain.buy(115);strain.build(115,"datacenter");strain.lots[115].level=3
	for i in range(24): strain.tick()
	var water=strain.civic_reports.oldtown.concerns.water
	var power=strain.civic_reports.oldtown.concerns.power
	expect(water>0 and power>0,"Sustained large actual campus load produces water and grid strain")
	strain.council("water","oldtown");strain.council("grid","oldtown")
	expect(strain.civic_reports.oldtown.concerns.water<water and strain.civic_reports.oldtown.concerns.power<power,"Water and grid projects reduce their specific civic pressure")
	var trips=strain.civic_reports.oldtown.concerns.traffic;strain.council("traffic","oldtown")
	expect(strain.civic_reports.oldtown.concerns.traffic<=trips,"Routing eases local traffic instead of altering unrelated concerns")
	var bare=campus();bare.accept_contract("support")
	bare.Operations.add_event(bare.ops,"outage",bare.hour+1,5,0)
	for i in range(5): bare.tick()
	var protected=campus();protected.accept_contract("support");protected.operate("battery");protected.operate("generator");protected.operate("fuel")
	protected.Operations.add_event(protected.ops,"outage",protected.hour+1,5,0)
	for i in range(5): protected.tick()
	expect(bare.civic.wards.market.service_loss>protected.civic.wards.market.service_loss,"Citizens react to lost services; backup that actually serves customers prevents the complaint")
	expect(Civic.thought(bare,"market").length()>10,"Citizen thoughts are derived from the current local condition")
	# Persist a real active agreement, permit waiver, protest and simultaneous operational incident.
	broken=displaced_town()
	broken.buy(83);broken.demolish(83);broken.build(83,"datacenter");broken.buy(82);broken.build(82,"power");broken.buy(99);broken.build(99,"cooling")
	for i in range(36): broken.tick()
	broken.council("negotiate","oldtown");broken.council("expedite","oldtown");broken.Operations.add_event(broken.ops,"heatwave",broken.hour+1,8,0);broken.tick()
	expect(broken.civic.wards.oldtown.ceasefire_until>broken.hour and broken.civic.wards.oldtown.stage==4,"Persistence fixture contains an active agreement, protest and waiver")
	expect(broken.save_game(path),"Civic and operations state can be atomically saved together")
	var loaded=Sim.new()
	var did_load=loaded.load_game(path)

	expect(did_load and loaded.civic==broken.civic and loaded.ops==broken.ops,"Exact civic history, timers and operational random state restore")
	var same=true
	for i in range(80):
		broken.tick();loaded.tick()
		if broken.civic!=loaded.civic or broken.ops!=loaded.ops or broken.lots!=loaded.lots or broken.cash!=loaded.cash: same=false;break
	expect(same,"Saved civic and incident simulation continues exactly for 80 hours")
	var data=JSON.parse_string(FileAccess.get_file_as_string(path));data.civic.wards.oldtown.adoption="bad"
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
	var live=loaded.civic.duplicate(true);cash=loaded.cash
	expect(not loaded.load_game(path) and loaded.civic==live and loaded.cash==cash,"Corrupt civic data is rejected without changing the live town")
	var legacy=displaced_town();legacy.save_game(path)
	data=JSON.parse_string(FileAccess.get_file_as_string(path));data.version=6;data.erase("civic")
	file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
	expect(loaded.load_game(path) and loaded.civic.wards.oldtown.displaced==0 and loaded.approval==legacy.approval,"Legacy save starts civic history from the current town without inventing past displacement")
	var amenity=Sim.new();var amenity_site=sites(amenity,"grass","gardens")[0]
	var benefit=amenity.civic_reports.gardens.benefit
	amenity.council("park","gardens",amenity_site)
	expect(amenity.civic_reports.gardens.benefit>benefit and amenity.lots[amenity_site].protected,"New funded park visibly adds local comfort and gardens protection")
	var specimen=campus();specimen.council("quiet","oldtown",83);specimen.council("education","oldtown")
	specimen.council("preserve","gardens",park);specimen.council("park","gardens",amenity_site)
	expect(specimen.save_game(path) and loaded.load_game(path),"Public projects and conservation can be saved and loaded")
	expect(loaded.lots[83].get("quiet",false) and loaded.lots[park].get("preserved",false) and loaded.lots[amenity_site].get("civic_park",false) and loaded.civic.wards.oldtown.education==1,"Acoustic barriers, conservation, visible public projects and skills persist together")
	data=JSON.parse_string(FileAccess.get_file_as_string(path));data.lots[83].quiet="invalid"
	file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
	cash=loaded.cash
	expect(not loaded.load_game(path) and loaded.cash==cash and loaded.lots[83].quiet,"Malformed site flags cannot replace live state")
	var industry=Sim.new();var residential=Sim.new()
	var industrial_site=sites(industry,"grass","foundry")[0];var residential_site=sites(residential,"grass","oldtown")[0]
	industry.buy(industrial_site);industry.build(industrial_site,"datacenter")
	residential.buy(residential_site);residential.build(residential_site,"datacenter")
	expect(Geo.sensitivity(industry.lots[industrial_site])<Geo.sensitivity(residential.lots[residential_site]) and industry.civic_reports.foundry.noise<residential.civic_reports.oldtown.noise,"The same hall design exposes fewer sensitive homes in the industrial district")
	var thriving=displaced_town();thriving.council("education","oldtown");thriving.council("education","oldtown");thriving.council("education","oldtown")
	for i in range(80): thriving.tick()
	expect(thriving.civic.wards.oldtown.adoption>20 and thriving.civic.wards.oldtown.stage==4 and thriving.approval<50,"AI adoption and an active protest can coexist in the same neighborhood")
	var quiet_move=campus();quiet_move.council("quiet","oldtown",83);quiet_move.buy(115);quiet_move.relocate_hall(83,115)
	expect(quiet_move.lots[83].get("quiet",false) and not quiet_move.lots[115].get("quiet",false),"Relocation keeps purchased barriers at their original physical site")
	# Real UI flows, both pause preferences, world protest objects and low-resolution layout.
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.sim=displaced_town();game.town.sim=game.sim;game.session_started=true;game.menu.visible=false;game.paused=false;game.settings.auto_pause=true
	for i in range(16): game.sim.tick()
	game.handle_operation_alerts();await process_frame
	expect(game.paused and game.business.visible and game.business.tab=="town","Civic alert pauses and opens the relevant council when enabled")
	var ui_snapshot=JSON.stringify(game.sim.civic)
	game.business.town_view.update_live()
	expect(JSON.stringify(game.sim.civic)==ui_snapshot,"Live council action availability is a read-only preview")
	expect(game.business.ward=="oldtown" and game.business.town_view!=null,"Council opens the complaining neighborhood with actionable controls")
	game.business.visible=false;game.paused=false;game.settings.auto_pause=false
	Civic.notify(game.sim,"oldtown","Test update");game.handle_operation_alerts()
	expect(not game.paused and not game.business.visible,"Disabled auto-pause leaves time running and provides a notice")
	for i in range(20): game.sim.tick()
	expect(not game.town.protest_groups().is_empty(),"Demonstrating neighborhoods produce visible map protest groups")
	game.paused=true;game.settings.ui_scale=1.15;root.size=Vector2i(1152,720);game.apply_settings(false,false);game.open_town("oldtown")
	await process_frame;await process_frame
	expect(game.business.body.get_global_rect().end.x<=root.size.x+1 and game.business.body.get_global_rect().end.y<=root.size.y+1,"Council panel fits the minimum display at 115% text scale")
	game.queue_free();await process_frame;await create_timer(0.1).timeout
	DirAccess.remove_absolute(path)
	print("CIVIC: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
