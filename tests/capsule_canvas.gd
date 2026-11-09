extends Control
## Original key-art layout using the game's own sprite atlas and native drawing.
var atlas:Texture2D
var regions:Dictionary
func _ready() -> void:
	atlas=load("res://assets/town_atlas.png")
	regions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/town_atlas.json"))
func sprite(key:String,at:Vector2,scale_factor:float) -> void:
	var r=regions[key]
	draw_texture_rect_region(atlas,Rect2(at-Vector2(128,136)*scale_factor,Vector2(256,256)*scale_factor),Rect2(r[0],r[1],r[2],r[3]))
func title(text:String,y:float,font_size:int,color:Color,x:float=-1) -> void:
	var font=ThemeDB.fallback_font
	var at=Vector2((size.x-font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)/2 if x<0 else x,y)
	draw_string(font,at+Vector2(0,3),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(0,0,0,0.5))
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func _draw() -> void:
	var small=size.y<250
	var vertical=size.y>size.x
	for y in range(0,int(size.y),4):
		var t=float(y)/size.y
		draw_rect(Rect2(0,y,size.x,4),Color("102a31").lerp(Color("39634c"),t))
	var scale_factor=minf(size.x/700.0,size.y/430.0)*0.88
	if small: scale_factor=0.48
	var center=Vector2(size.x*(0.81 if small else 0.5),size.y*(0.74 if vertical else 0.68))
	for a in range(-5,6):
		for b in range(-4,5):
			var at=center+Vector2((a-b)*56,(a+b)*28)*scale_factor
			var tile=PackedVector2Array([at+Vector2(0,-26)*scale_factor,at+Vector2(54,0)*scale_factor,at+Vector2(0,26)*scale_factor,at+Vector2(-54,0)*scale_factor])
			draw_colored_polygon(tile,Color("537351") if (a+b)%2==0 else Color("577956"))
			draw_polyline(tile,Color(0.8,0.83,0.62,0.22),1)
	for obj in [{"key":"tree_0","x":-3,"y":-2},{"key":"tree_1","x":2,"y":-3},{"key":"family_0","x":-3,"y":0},{"key":"family_4","x":2,"y":-2},{"key":"tree_2","x":3,"y":0},{"key":"tree_3","x":-1,"y":3},{"key":"family_2","x":-2,"y":-2},{"key":"datacenter_t3_true","x":0,"y":-1},{"key":"power_t3_true","x":1,"y":-1},{"key":"family_3","x":-2,"y":1},{"key":"datacenter_t2_true","x":0,"y":1},{"key":"cooling_t3_true","x":2,"y":1}]:
		sprite(obj.key,center+Vector2((obj.x-obj.y)*56,(obj.x+obj.y)*28)*scale_factor,scale_factor)
	# A quiet title field; capsules contain only the game title, with no claims/badges.
	var title_height=size.y*(0.40 if vertical else 0.36)
	for y in range(0,int(title_height),2):
		draw_rect(Rect2(0,y,size.x,2),Color(0.035,0.10,0.13,0.98*(1-float(y)/title_height)))
	var margin=size.x*0.045
	draw_line(Vector2(margin,margin),Vector2(size.x-margin,margin),Color("d9bc77"),2)
	if small:
		draw_rect(Rect2(0,0,size.x*0.66,size.y),Color(0.04,0.12,0.15,0.93))
		title("HYPERSCALE",size.y*0.48,35,Color("f5efd9"),18)
		title("DATACENTER TYCOON",size.y*0.64,17,Color("abd8bc"),20)
	else:
		title("HYPERSCALE",size.y*(0.21 if vertical else 0.22),int(size.x*0.097),Color("f5efd9"))
		title("DATACENTER TYCOON",size.y*(0.285 if vertical else 0.315),int(size.x*0.037),Color("abd8bc"))
	draw_line(Vector2(margin,size.y-margin),Vector2(size.x-margin,size.y-margin),Color("d9bc77"),2)
