extends SceneTree
var failures = 0
var checks = 0

func expect(condition:bool, message:String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void:
	call_deferred("check_interface")

func check_interface() -> void:
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.paused=true
	await process_frame
	for resolution in [Vector2i(1440,900),Vector2i(1920,1080),Vector2i(3440,1440),Vector2i(1280,1024),Vector2i(3840,2160)]:
		root.size=resolution
		await process_frame
		scene.layout_stage()
		await process_frame
		expect((scene.stage.size*scene.stage.scale).is_equal_approx(scene.size),"Stage fills viewport at "+str(resolution))
		expect(scene.stage.position==Vector2.ZERO,"No letterboxing at "+str(resolution))
		expect(scene.town.size==scene.stage.size,"World fills entire stage")
		expect(scene.inspector.position.x+scene.inspector.size.x<=scene.stage.size.x,"Inspector fits")
		expect(scene.fullscreen_button.position.x+scene.fullscreen_button.size.x<scene.inspector.position.x,"Fullscreen control stays visible")
		expect(scene.toolbar.position.y+scene.toolbar.size.y<=scene.stage.size.y,"Toolbar fits")
		scene.business.open("offers")
		await process_frame
		expect(scene.business.body.position.x>=0 and scene.business.body.position.y>=0,"Contracts fit resized display")
		expect(scene.business.body.position.x+scene.business.body.size.x<=scene.stage.size.x,"Contract board fits width")
		expect(scene.business.body.position.y+scene.business.body.size.y<=scene.stage.size.y,"Contract board fits height")
		scene.business.visible=false
		for index in [0,15,68,83,240,255]:
			var x=index%16
			var y=index/16
			expect(scene.town.pick(scene.town.point(x+0.5,y+0.5))==index,"Map input matches rendered plot at "+str(resolution))
	for child in scene.inspector.get_children():
		if child is Label:
			expect(child.position.x+child.size.x<=scene.inspector.size.x,"Property text stays inside panel")
	scene.sim.buy(83)
	scene.sim.demolish(83)
	scene.sim.build(83,"datacenter")
	scene.sim.completed=["bakery","support","studio","robotics"]
	scene.sim.lots[83].level=3
	scene.refresh_inspector()
	await process_frame
	for child in scene.inspector.get_children():
		if child is Label:
			expect(child.position.x+child.size.x<=scene.inspector.size.x,"Maximum-tier inspector text fits")
	var now=scene.town.time
	scene.town.activity_speed=0
	scene.town._process(0.1)
	expect(scene.town.time==now,"Paused world freezes traffic and animation")
	scene.town.activity_speed=3
	scene.town._process(0.05)
	expect(is_equal_approx(scene.town.time-now,0.15),"Activity follows simulation speed")
	var person=scene.town.pedestrians[0]
	person.wait=0
	person.goal=person.pos+Vector2(1,0)
	var before=person.pos
	scene.town._process(0.05)
	expect(person.pos.x>before.x,"Residents walk toward destinations")
	var car=scene.town.vehicles[0]
	car.axis=0
	car.dir=1
	car.at=5.75
	scene.town.time=9
	scene.town.activity_speed=1
	scene.town._process(0.05)
	expect(is_equal_approx(car.at,5.75),"Vehicle stops for red light")
	scene.town.time=1
	scene.town._process(0.05)
	expect(car.at>5.75,"Vehicle proceeds on green light")
	print("INTERFACE AND ACTIVITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
