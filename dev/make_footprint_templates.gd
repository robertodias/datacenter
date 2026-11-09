extends SceneTree
## Draws the Grid 2.0 footprint templates for the art brief (docs/ART-BRIEF-MULTISIZE.md):
## one PNG per footprint with the mint ground diamond, cell grid lines, the anchor dot and
## the height guides. Output: assets/art/_templates/footprint-<w>x<h>.png
##   godot --headless --path . --script res://dev/make_footprint_templates.gd
## A cell is half a current plot: its diamond is 84 x 42 px at native scale.
const FOOTPRINTS=[[1,1],[1,2],[2,1],[2,2],[3,2],[2,3],[3,3]]

func corner(anchor:Vector2,i:float,j:float) -> Vector2:
	return anchor+Vector2(42*(i-j),21*(i+j))

func inside(p:Vector2,poly:Array) -> bool:
	return Geometry2D.is_point_in_polygon(p,PackedVector2Array(poly))

func line(img:Image,a:Vector2,b:Vector2,color:Color) -> void:
	var steps=int(maxf(absf(b.x-a.x),absf(b.y-a.y)))+1
	for k in range(steps+1):
		var p=a.lerp(b,float(k)/steps)
		if p.x>=0 and p.y>=0 and p.x<img.get_width() and p.y<img.get_height(): img.set_pixelv(Vector2i(p),color)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/art/_templates")
	for f in FOOTPRINTS:
		var w:int=f[0];var h:int=f[1]
		var big=w>2 or h>2
		var size=384 if big else 256
		var anchor=Vector2(192,216) if big else Vector2(128,136)
		var img=Image.create(size,size,false,Image.FORMAT_RGBA8)
		img.fill(Color(0.2,0.22,0.24,1))
		var poly=[corner(anchor,0,0),corner(anchor,w,0),corner(anchor,w,h),corner(anchor,0,h)]
		for y in range(size):
			for x in range(size):
				if inside(Vector2(x,y)+Vector2(0.5,0.5),poly): img.set_pixel(x,y,Color("62c4a0"))
		for i in range(1,w): line(img,corner(anchor,i,0),corner(anchor,i,h),Color("2f7d66"))
		for j in range(1,h): line(img,corner(anchor,0,j),corner(anchor,w,j),Color("2f7d66"))
		for k in range(4): line(img,poly[k],poly[(k+1)%4],Color("e9f5dc"))
		# Height guides above the top corner: 1 storey = 28 px. Coral line = tallest allowed.
		var tallest=anchor.y-(200 if big else 128)
		for storey in range(1,8):
			var y=anchor.y-storey*28
			if y<tallest: break
			line(img,Vector2(0,y),Vector2(size-1,y),Color(1,1,1,0.12))
		line(img,Vector2(0,tallest),Vector2(size-1,tallest),Color("ef8a6f"))
		for dx in range(-2,3):
			for dy in range(-2,3): img.set_pixelv(Vector2i(anchor)+Vector2i(dx,dy),Color("ffd166"))
		img.save_png("res://assets/art/_templates/footprint-%dx%d.png" % [w,h])
		print("TEMPLATE %dx%d canvas %d anchor %s right %s bottom %s left %s" % [w,h,size,anchor,poly[1],poly[2],poly[3]])
	quit()
