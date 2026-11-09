extends SceneTree
## Run with a graphical Windows session, not --headless.
## Regression: changing ALWAYS_ON_TOP made a fullscreen-looking window report WINDOWED.
var checks=0
var failures=0
var scene

func expect(condition:bool,message:String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: ",message," | native mode=",DisplayServer.window_get_mode())

func _initialize() -> void:
	call_deferred("probe")

func settle() -> void:
	for i in range(10): await process_frame

func key(code:Key,alt:bool=false) -> void:
	var e=InputEventKey.new()
	e.keycode=code
	e.physical_keycode=code
	e.alt_pressed=alt
	e.pressed=true
	Input.parse_input_event(e)
	e=e.duplicate()
	e.pressed=false
	Input.parse_input_event(e)
	await settle()

func probe() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Fullscreen regression requires the real Windows display server")
		quit(2)
		return
	scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await settle()
	var original_size=DisplayServer.window_get_size()
	var original_position=DisplayServer.window_get_position()
	for i in range(3):
		await key(KEY_F11)
		expect(scene.is_fullscreen(),"F11 enters genuine fullscreen, cycle "+str(i))
		expect(not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP),"Fullscreen has no conflicting topmost flag")
		await key(KEY_F11)
		expect(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED,"Second F11 restores windowed mode")
		expect(DisplayServer.window_get_size()==original_size,"Window dimensions restored")
		expect(DisplayServer.window_get_position()==original_position,"Window position restored")
	# GUI focus and modal guards must not swallow F11.
	scene.business.open("offers")
	await key(KEY_F11)
	expect(scene.is_fullscreen(),"F11 works over customer board")
	await key(KEY_F11)
	expect(not scene.is_fullscreen() and scene.business.visible,"F11 leaves fullscreen without dismissing board")
	scene.business.visible=false
	scene.show_help()
	await settle()
	await key(KEY_F11)
	expect(scene.is_fullscreen(),"F11 works with help visible")
	await key(KEY_F11)
	expect(not scene.is_fullscreen(),"F11 exits with help visible")
	scene.help_dialog.hide()
	scene.ask("Test confirmation","No gameplay changes will be applied.",func():pass)
	await settle()
	# Exercise the child Window input connection used by native popup focus.
	var e=InputEventKey.new()
	e.keycode=KEY_F11
	e.pressed=true
	scene.dialog.window_input.emit(e)
	await settle()
	expect(scene.is_fullscreen(),"Native confirmation forwards fullscreen shortcut")
	scene.dialog.window_input.emit(e)
	await settle()
	expect(not scene.is_fullscreen(),"Native confirmation can exit fullscreen")
	scene.dialog.hide()
	await key(KEY_ENTER,true)
	expect(scene.is_fullscreen(),"Alt+Enter fallback enters fullscreen")
	await key(KEY_ESCAPE)
	expect(not scene.is_fullscreen(),"Escape leaves fullscreen on town view")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	await settle()
	await key(KEY_F11)
	expect(scene.is_fullscreen(),"Can enter fullscreen from maximized window")
	await key(KEY_F11)
	expect(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MAXIMIZED,"Returns to previously maximized window")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await settle()
	# Button clicks use the same controller. Echoes and repeated callbacks during a
	# native transition must not toggle straight back.
	scene.fullscreen_button.pressed.emit()
	scene.fullscreen_button.pressed.emit()
	await settle()
	expect(scene.is_fullscreen(),"Reentrant button callbacks cannot undo transition")
	e.echo=true
	Input.parse_input_event(e)
	await settle()
	expect(scene.is_fullscreen(),"Held F11 repeat is ignored")
	scene.fullscreen_button.pressed.emit()
	await settle()
	expect(not scene.is_fullscreen(),"On-screen button restores window")
	scene.map_tools.open()
	await settle()
	var map_popup=scene.overlay_choice.get_popup()
	e.echo=false
	map_popup.window_input.emit(e)
	await settle()
	expect(scene.is_fullscreen(),"Native map dropdown forwards F11")
	map_popup.window_input.emit(e)
	await settle()
	expect(not scene.is_fullscreen(),"Native map dropdown can leave fullscreen")
	scene.sim.buy(83);scene.sim.demolish(83);scene.sim.build(83,"datacenter")
	scene.business.open("hardware")
	await settle()
	var hardware_popup=scene.business.finance_view.halls[0].option.get_popup()
	hardware_popup.window_input.emit(e)
	await settle()
	expect(scene.is_fullscreen(),"Native hardware dropdown forwards F11")
	hardware_popup.window_input.emit(e)
	await settle()
	expect(not scene.is_fullscreen(),"Hardware dropdown can leave fullscreen")
	scene.business.open("town")
	await settle()
	var council_popup=scene.business.body.find_children("*","OptionButton",true,false)[0].get_popup()
	council_popup.window_input.emit(e);await settle()
	expect(scene.is_fullscreen(),"Native council district picker forwards F11")
	council_popup.window_input.emit(e);await settle()
	expect(not scene.is_fullscreen(),"Council district picker can exit fullscreen")
	scene.business.open("workforce");await settle()
	var staffing_popup=scene.business.body.find_children("*","OptionButton",true,false)[0].get_popup()
	staffing_popup.window_input.emit(e);await settle()
	expect(scene.is_fullscreen(),"Native staffing priority picker enters fullscreen")
	staffing_popup.window_input.emit(e);await settle()
	expect(not scene.is_fullscreen(),"Native staffing priority picker exits fullscreen")
	scene.business.visible=false;scene.show_help();await settle()
	await key(KEY_ESCAPE)
	expect(not scene.help_dialog.visible,"Scrollable help closes with Escape")
	print("WINDOWS FULLSCREEN: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
