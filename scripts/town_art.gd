extends RefCounted
## Original, code-drawn isometric scenery. All details share the same projection.
var v
var network: Dictionary = {}

func _init(view) -> void:
	v = view

func p(x: float, y: float, h: float = 0) -> Vector2:
	return v.point(x, y, h)

func poly(points: Array, color: Color) -> void:
	v.polygon(points, color)

func line(a: Vector2, b: Vector2, color: Color, width: float = 1) -> void:
	v.draw_line(a, b, color, maxf(1, width * v.draw_scale), false)

func box(x: float, y: float, w: float, d: float, h: float, color: Color, base: float = 0) -> void:
	v.box(x, y, w, d, h, color, base)

func ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	v.draw_ellipse_at(center, radius * v.draw_scale, color)

func ground(x: float, y: float, w: float, d: float, color: Color) -> void:
	poly([p(x,y),p(x+w,y),p(x+w,y+d),p(x,y+d)], color)

func front(x: float, y: float, w: float, bottom: float, top: float, color: Color) -> void:
	poly([p(x,y,bottom),p(x+w,y,bottom),p(x+w,y,top),p(x,y,top)],color)

func side(x: float, y: float, d: float, bottom: float, top: float, color: Color) -> void:
	poly([p(x,y,bottom),p(x,y+d,bottom),p(x,y+d,top),p(x,y,top)],color)

func window(x: float, y: float, w: float, base: float, height: float, lit: bool = false) -> void:
	front(x-0.015,y,w+0.03,base-2,base+height+2,Color("e0d9b9"))
	front(x,y+0.002,w,base,base+height,Color("f3d77c") if lit else Color("355f70"))
	front(x+0.015,y+0.004,w*0.35,base+height*0.5,base+height-1,Color("f8ecb4") if lit else Color("95bfba"))
	line(p(x+w*0.5,y+0.006,base),p(x+w*0.5,y+0.006,base+height),Color("d6d9c3"))
	line(p(x,y+0.006,base+height*0.45),p(x+w,y+0.006,base+height*0.45),Color("c6ccbb"))
	box(x-0.025,y-0.012,w+0.05,0.045,2,Color("e9dcbc"),base-3)

func bricks(x: float, y: float, w: float, height: float, color: Color) -> void:
	for row in range(2, int(height), 5):
		line(p(x,y,row),p(x+w,y,row),color,0.6)
		for col in range(5):
			var xx = x + (col + (0.5 if row % 2 == 0 else 0.0)) * w / 5.0
			line(p(xx,y,row),p(xx,y,row+4),color,0.6)

func roof(x: float, y: float, w: float, d: float, base: float, rise: float, color: Color) -> void:
	var a = p(x,y,base)
	var b = p(x+w,y,base)
	var c = p(x+w,y+d,base)
	var e = p(x,y+d,base)
	var r1 = p(x,y+d/2,base+rise)
	var r2 = p(x+w,y+d/2,base+rise)
	poly([a,b,r2,r1],color.lightened(0.13))
	poly([r1,r2,c,e],color)
	poly([b,c,r2],color.darkened(0.23))
	# Individual overlapping courses and staggered tile seams.
	for row in range(1,7):
		var t = row/7.0
		line(r1.lerp(e,t),r2.lerp(c,t),color.darkened(0.22),0.8)
		line(a.lerp(r1,t),b.lerp(r2,t),color.lightened(0.25),0.6)
		for col in range(8):
			var u = (col + (0.45 if row%2==0 else 0.0))/8.0
			line(r1.lerp(r2,u).lerp(e.lerp(c,u),t),r1.lerp(r2,u).lerp(e.lerp(c,u),(row+1)/7.0),color.darkened(0.14),0.6)
	line(r1,r2,color.lightened(0.4),2)
	line(e,c,Color("ebe0b7"),2)
	line(b,c,color.darkened(0.35),1)

func fence(x: float,y: float,w: float,d: float,color: Color = Color("e7ddba")) -> void:
	var count = maxi(2, int((w+d)*15))
	for i in range(count+1):
		var t=i/float(count)
		line(p(x+w*t,y+d*t),p(x+w*t,y+d*t,9),color,2)
	line(p(x,y,3),p(x+w,y+d,3),color.darkened(0.13),1.5)
	line(p(x,y,7),p(x+w,y+d,7),color.lightened(0.1),1.5)

func bush(x: float,y: float,r: float = 8) -> void:
	var center=p(x,y,5)
	ellipse(center,Vector2(r,r*0.62),Color("38683a"))
	ellipse(center+Vector2(-2,-2)*v.draw_scale,Vector2(r*0.8,r*0.45),Color("639d40"))

func flowers(x: float,y: float,w: float) -> void:
	ground(x,y,w,0.12,Color("576b39"))
	for i in range(7):
		var pos=p(x+w*i/7.0,y+0.06,3)
		v.draw_rect(Rect2(pos,Vector2(2,2)*v.draw_scale),[Color("edd15f"),Color("d9e4bf"),Color("d4797b")][i%3])

func tree(x: float,y: float,variant: int = 0) -> void:
	var s=v.draw_scale
	var center=p(x,y)
	ellipse(center+Vector2(13,4)*s,Vector2(18,7),Color(0.10,0.24,0.12,0.19))
	line(center,center-Vector2(0,32)*s,Color("66513a"),4)
	line(center-Vector2(0,17)*s,center-Vector2(8,29)*s,Color("806b42"),2)
	if variant%4==3:
		for k in range(3):
			var yy=-14-k*12
			poly([center+Vector2(-14+k*3,yy)*s,center+Vector2(0,yy-24)*s,center+Vector2(14-k*3,yy)*s],Color("3c7151").lightened(k*0.04))
		return
	var leaf=Color("6fa747") if variant%3==0 else (Color("88ad4d") if variant%3==1 else Color("53904d"))
	for k in range(5):
		var c=center+Vector2([-9,9,0,-6,3][k],[-27,-29,-40,-37,-43][k])*s
		var r=[12,13,13,11,10][k]*s
		var points:Array=[]
		for j in range(10):
			var a=j*TAU/10
			var rr=r*(0.88 if j%2==0 else 1.0)
			points.append((c+Vector2(cos(a),sin(a)*0.86)*rr).round())
		poly(points,leaf.darkened(0.22) if k<2 else leaf)
		for j in range(6):
			var a=j*2.4+k
			var at=c+Vector2(cos(a)*r*0.6,sin(a)*r*0.4)
			v.draw_rect(Rect2(at.round(),Vector2(3,2)*s),leaf.lightened(0.15))

func bench(x: float,y: float) -> void:
	box(x,y,0.3,0.10,3,Color("ab7946"),5)
	front(x,y+0.015,0.3,9,14,Color("b78d55"))
	for xx in [x+0.035,x+0.25]:
		line(p(xx,y+0.06),p(xx,y+0.06,8),Color("4d5b53"),2)

func lamp(x: float,y: float) -> void:
	line(p(x,y),p(x,y,39),Color("405a51"),2)
	line(p(x,y,39),p(x+0.07,y,41),Color("405a51"),2)
	box(x+0.02,y-0.03,0.1,0.09,5,Color("f2df9a"),35)
	box(x+0.005,y-0.045,0.13,0.12,2,Color("3d5650"),40)

func shop_sign(x:float,y:float,text:String,color:Color) -> void:
	var center=p(x,y,27)
	var s=v.draw_scale
	var width=maxf(24,text.length()*5.3)*s
	v.draw_rect(Rect2(center-Vector2(width/2,8*s),Vector2(width,13*s)),Color("e4d6ab"))
	v.draw_rect(Rect2(center-Vector2(width/2-1,7*s),Vector2(width-2,11*s)),color)
	v.draw_string(v.font,center+Vector2(-width/2+3*s,2*s),text,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(8,int(9*s)),Color("f9e8bd"))

func draw_building(lot:Dictionary) -> void:
	var x:float=lot.x
	var y:float=lot.y
	var kind:String=lot.kind
	if kind in ["grass","road"]: return
	poly([p(x+0.1,y+0.2),p(x+0.9,y+0.2),p(x+1.12,y+0.8),p(x+0.35,y+1.06)],Color(0.12,0.21,0.13,0.20))
	match kind:
		"house":
			if lot.has("family"): neighborhood_building(x,y,int(lot.family))
			else: house(x,y)
		"warehouse": warehouse(x,y)
		"park": park(x,y)
		"monument": monument(x,y)
		"datacenter":
			if lot.get("level",1)>1: campus_tier(x,y,int(lot.level))
			else: datacenter(x,y)
		"power":
			if lot.get("level",1)>1: utility_tier(x,y,"power",int(lot.level))
			else: power(x,y)
		"cooling":
			if lot.get("level",1)>1: utility_tier(x,y,"cooling",int(lot.level))
			else: cooling(x,y)

func house(x:float,y:float) -> void:
	var variant=posmod(int(x*7+y*3),5)
	var shop=(int(x)==3 or int(y)==3) and variant<3
	var tall=variant==2 or variant==4
	var h=48 if tall else 33
	var wall=[Color("c99370"),Color("d5c09a"),Color("e5d3aa"),Color("b8c7b0"),Color("b9917a")][variant]
	ground(x+0.1,y+0.1,0.8,0.8,Color("80a853"))
	ground(x+0.45,y+0.7,0.18,0.29,Color("d5c5a0"))
	box(x+0.17,y+0.18,0.65,0.55,4,Color("a49b7c"))
	box(x+0.18,y+0.19,0.63,0.53,h,wall,4)
	bricks(x+0.19,y+0.726,0.61,h,wall.darkened(0.15))
	side(x+0.812,y+0.19,0.53,6,h+3,wall.darkened(0.29))
	for k in range(2):
		side(x+0.815,y+0.28+k*0.25,0.10,14,h-6,Color("426974"))
		line(p(x+0.82,y+0.33+k*0.25,14),p(x+0.82,y+0.33+k*0.25,h-6),Color("b7c5b4"))
	var roof_color=[Color("ac5c3e"),Color("617c86"),Color("855552"),Color("bc7848"),Color("6e777e")][variant]
	roof(x+0.13,y+0.14,0.73,0.64,h+5,19,roof_color)
	box(x+0.66,y+0.25,0.10,0.12,22,Color("a77a5b"),h+8)
	box(x+0.64,y+0.23,0.14,0.16,3,Color("d5b38b"),h+29)
	if tall:
		for xx in [0.27,0.58]: window(x+xx,y+0.734,0.13,30,11,variant==4)
		front(x+0.16,y+0.742,0.67,25,28,Color("e7d9b2"))
	if shop:
		window(x+0.26,y+0.737,0.39,7,13)
		for k in range(6):
			var xx=x+0.2+k*0.1
			poly([p(xx,y+0.73,24),p(xx+0.1,y+0.73,24),p(xx+0.1,y+0.95,20),p(xx,y+0.95,20)],Color("e9dfb5") if k%2==0 else Color("af5c4d"))
			front(xx,y+0.95,0.1,17,20,Color("eee4bb") if k%2==0 else Color("964a3e"))
		shop_sign(x+0.5,y+0.74,["BAKERY","BOOKS","CAFE"][variant],Color("406c59"))
		box(x+0.85,y+0.76,0.08,0.12,12,Color("735943"))
	else:
		for xx in [0.27,0.61]: window(x+xx,y+0.735,0.10,11,12)
		front(x+0.445,y+0.737,0.12,4,23,Color("5b715c"))
		line(p(x+0.53,y+0.741,13),p(x+0.53,y+0.741,15),Color("edcf77"),2)
		box(x+0.425,y+0.75,0.17,0.12,3,Color("c6bda0"))
		flowers(x+0.15,y+0.82,0.25)
		fence(x+0.07,y+0.97,0.33,0)
		fence(x+0.65,y+0.97,0.3,0)
		fence(x+0.95,y+0.15,0,0.82)
		bush(x+0.85,y+0.87,7)
	# Small side garden, shutters, and a mailbox distinguish the residences.
	box(x+0.08,y+0.84,0.035,0.035,10,Color("746246"))
	box(x+0.04,y+0.81,0.12,0.09,5,Color("5f8191"),10)
	if variant==1: tree(x+0.12,y+0.22,1)

func warehouse(x:float,y:float) -> void:
	ground(x+0.06,y+0.05,0.9,0.9,Color("aaa388"))
	box(x+0.10,y+0.12,0.78,0.69,38,Color("a98361"))
	bricks(x+0.1,y+0.812,0.78,38,Color("846b52"))
	box(x+0.08,y+0.10,0.82,0.73,5,Color("87999b"),38)
	for k in range(10):
		line(p(x+0.11+k*0.077,y+0.11,44),p(x+0.11+k*0.077,y+0.81,44),Color("b6bcb0"))
	for xx in [0.23,0.58]:
		box(x+xx,y+0.26,0.12,0.23,3,Color("638996"),44)
		front(x+xx,y+0.49,0.12,44,47,Color("a4c5bd"))
	front(x+0.35,y+0.816,0.32,0,26,Color("526866"))
	for h in range(3,26,4): line(p(x+0.35,y+0.82,h),p(x+0.67,y+0.82,h),Color("81918a"))
	window(x+0.17,y+0.817,0.12,16,12)
	shop_sign(x+0.52,y+0.82,"FOR SALE",Color("975a42"))
	for i in range(3): box(x+0.77,y+0.83+i*0.045,0.14,0.04,4,Color("a68956"),i*3)
	box(x+0.10,y+0.86,0.12,0.10,9,Color("6f7d63"))

func park(x:float,y:float) -> void:
	ground(x+0.05,y+0.05,0.9,0.9,Color("7eab50"))
	ground(x+0.4,y+0.03,0.18,0.94,Color("d5c194"))
	ground(x+0.03,y+0.4,0.94,0.18,Color("d5c194"))
	flowers(x+0.1,y+0.72,0.28)
	flowers(x+0.64,y+0.2,0.24)
	bench(x+0.65,y+0.66)
	tree(x+0.22,y+0.26,int(x+y))
	tree(x+0.81,y+0.21,1)
	bush(x+0.8,y+0.87)
	lamp(x+0.1,y+0.9)

func monument(x:float,y:float) -> void:
	ground(x+0.04,y+0.04,0.92,0.92,Color("d2c9ac"))
	for i in range(1,5):
		line(p(x+0.05,y+i*0.2),p(x+0.95,y+i*0.2),Color("b5b09b"))
	box(x+0.2,y+0.2,0.6,0.6,5,Color("b9baac"))
	box(x+0.27,y+0.27,0.46,0.46,5,Color("dce0cb"),5)
	box(x+0.38,y+0.38,0.24,0.24,27,Color("bbbfae"),10)
	box(x+0.34,y+0.34,0.32,0.32,4,Color("e0dec3"),37)
	front(x+0.43,y+0.624,0.14,19,26,Color("8c8767"))
	var c=p(x+0.5,y+0.5,44)
	var s=v.draw_scale
	line(c,c-Vector2(0,16)*s,Color("4d826e"),8)
	line(c-Vector2(0,11)*s,c+Vector2(10,-20)*s,Color("709a7d"),3)
	v.draw_circle(c-Vector2(0,22)*s,4*s,Color("91ab85"))
	bench(x+0.58,y+0.89)
	flowers(x+0.08,y+0.10,0.23)
	lamp(x+0.91,y+0.12)

func datacenter(x:float,y:float) -> void:
	ground(x+0.03,y+0.03,0.94,0.94,Color("b3b5a3"))
	box(x+0.08,y+0.10,0.84,0.75,46,Color("92a5ab"))
	for k in range(9):
		line(p(x+0.12+k*0.09,y+0.855,3),p(x+0.12+k*0.09,y+0.855,44),Color("ced5cf"))
	for h in [8,20,32]: side(x+0.923,y+0.15,0.65,h,h+1,Color("627d83"))
	box(x+0.06,y+0.08,0.88,0.79,4,Color("d3d9ce"),46)
	ground_roof(x+0.12,y+0.14,0.76,0.66,51,Color("617b82"))
	for row in range(2):
		for col in range(3):
			var xx=x+0.18+col*0.23
			var yy=y+0.20+row*0.29
			box(xx,yy,0.17,0.20,8,Color("b8c6c0"),51)
			var at=p(xx+0.085,yy+0.1,60)
			ellipse(at,Vector2(5,3),Color("3e5961"))
			for k in range(3):
				var angle=v.time*3+k*TAU/3
				line(at,at+Vector2(cos(angle)*4,sin(angle)*2)*v.draw_scale,Color("8ea9a8"))
	var led=Color("8ceab1") if network.get("efficiency",0)>0 else Color("e4ab56")
	for k in range(5):
		window(x+0.15+k*0.14,y+0.858,0.09,13,16)
		for j in range(3):
			line(p(x+0.17+k*0.14,y+0.86,16+j*4),p(x+0.19+k*0.14,y+0.86,16+j*4),led)
	front(x+0.12,y+0.861,0.73,36,41,Color("264c5a"))
	line(p(x+0.13,y+0.865,38),p(x+0.84,y+0.865,38),led,1.5)
	shop_sign(x+0.52,y+0.87,"N E X U S",Color("31576b"))
	for xx in [0.08,0.91]: box(x+xx,y+0.91,0.035,0.035,8,Color("d9c16b"))

func ground_roof(x:float,y:float,w:float,d:float,h:float,color:Color) -> void:
	poly([p(x,y,h),p(x+w,y,h),p(x+w,y+d,h),p(x,y+d,h)],color)

func power(x:float,y:float) -> void:
	ground(x+0.06,y+0.06,0.88,0.88,Color("b1ac8d"))
	box(x+0.13,y+0.25,0.42,0.48,27,Color("a2aaa1"))
	for k in range(6):
		front(x+0.16+k*0.06,y+0.734,0.025,5,23,Color("5d7776"))
	for k in range(3):
		box(x+0.21+k*0.11,y+0.36,0.04,0.12,15,Color("576c73"),27)
		for h in range(29,44,4): box(x+0.195+k*0.11,y+0.35,0.07,0.14,1,Color("8da0a0"),h)
	for yy in [0.18,0.81]:
		line(p(x+0.77,y+yy),p(x+0.77,y+yy,57),Color("728883"),3)
		line(p(x+0.57,y+yy,52),p(x+0.95,y+yy,52),Color("c3ccba"),3)
		for xx in [0.64,0.88]: box(x+xx,y+yy,0.03,0.04,6,Color("99a8a4"),53)
	for xx in [0.64,0.88]:
		line(p(x+xx,y+0.18,60),p(x+xx,y+0.5,54),Color("4a5d54"))
		line(p(x+xx,y+0.5,54),p(x+xx,y+0.81,60),Color("4a5d54"))
	fence(x+0.06,y+0.94,0.88,0,Color("89998a"))
	fence(x+0.94,y+0.07,0,0.87,Color("89998a"))
	front(x+0.36,y+0.738,0.12,10,21,Color("ead15b"))
	line(p(x+0.43,y+0.74,19),p(x+0.39,y+0.74,12),Color("515640"),2)

func cooling(x:float,y:float) -> void:
	ground(x+0.05,y+0.05,0.9,0.9,Color("aabcb0"))
	box(x+0.1,y+0.13,0.8,0.72,14,Color("7e9f9d"))
	for xx in [0.31,0.67]:
		box(x+xx-0.14,y+0.25,0.28,0.46,21,Color("b0c7bc"),14)
		for h in range(18,34,3): front(x+xx-0.12,y+0.714,0.24,h,h+1,Color("547e82"))
		var at=p(x+xx,y+0.49,37)
		ellipse(at,Vector2(13,7),Color("d3d9c3"))
		ellipse(at,Vector2(10,5),Color("375864"))
		for k in range(5):
			var a=v.time*3+k*TAU/5
			line(at,at+Vector2(cos(a)*9,sin(a)*4)*v.draw_scale,Color("8cb2ab"),2)
		if network.get("power",0)>0:
			for k in range(4):
				var t=fmod(v.time*0.3+k*0.25,1)
				ellipse(at+Vector2(t*17,-t*34)*v.draw_scale,Vector2(3+t*8,2+t*4),Color(0.89,0.96,0.86,(1-t)*0.32))
	line(p(x+0.13,y+0.86,8),p(x+0.88,y+0.86,8),Color("70b8c2"),4)
	line(p(x+0.13,y+0.86,8),p(x+0.13,y+0.86,19),Color("9acbd0"),4)


func campus_tier(x:float,y:float,level:int) -> void:
	ground(x+0.02,y+0.02,0.96,0.96,Color("adb5ad"))
	var led=Color("8ee5c1") if network.get("efficiency",0)>0 else Color("dfa863")
	if level==2:
		# Two linked wings, a recessed loading court and a roof service bridge.
		box(x+0.08,y+0.08,0.36,0.69,54,Color("8eacb6"))
		box(x+0.53,y+0.08,0.39,0.54,39,Color("6b8996"))
		box(x+0.42,y+0.18,0.15,0.22,10,Color("b5d1cd"),26)
		box(x+0.06,y+0.06,0.4,0.73,3,Color("d7dfd2"),54)
		box(x+0.51,y+0.06,0.43,0.58,3,Color("cad5cd"),39)
		for h in [12,25,38]: front(x+0.1,y+0.773,0.32,h,h+5,Color("3f6472"))
		for k in range(5): side(x+0.923,y+0.12+k*0.095,0.06,9,34,Color("a0b9b8"))
		for yy in [0.23,0.49]:
			box(x+0.16,y+yy,0.2,0.18,6,Color("9eaca7"),57)
			ellipse(p(x+0.26,y+yy+0.09,64),Vector2(5,3),Color("32535b"))
		front(x+0.56,y+0.625,0.29,2,25,Color("324c55"))
		for h in range(5,25,4): line(p(x+0.56,y+0.63,h),p(x+0.85,y+0.63,h),Color("789593"))
		line(p(x+0.11,y+0.78,48),p(x+0.42,y+0.78,48),led,2)
	else:
		# Tall compact compute core, low control annex and independent cooling banks.
		box(x+0.12,y+0.1,0.57,0.57,73,Color("7393a5"))
		box(x+0.1,y+0.08,0.61,0.61,4,Color("d6dbce"),73)
		for h in [12,27,42,57]:
			front(x+0.15,y+0.675,0.51,h,h+7,Color("345768"))
			side(x+0.695,y+0.13,0.51,h,h+7,Color("426c7a"))
			line(p(x+0.16,y+0.68,h+1),p(x+0.64,y+0.68,h+1),led)
		for xx in [0.19,0.4]:
			for yy in [0.18,0.42]:
				box(x+xx,y+yy,0.17,0.17,5,Color("9eb2b4"),77)
				ellipse(p(x+xx+0.08,y+yy+0.08,83),Vector2(4,2),Color("314d5d"))
		box(x+0.70,y+0.15,0.22,0.6,25,Color("b0bdae"))
		for yy in [0.25,0.49]:
			box(x+0.74,y+yy,0.14,0.16,9,Color("6e8b8b"),25)
		box(x+0.14,y+0.7,0.53,0.18,21,Color("b4c4bf"))
		for xx in [0.2,0.4]: window(x+xx,y+0.885,0.13,7,11,true)
	# Functional service yards make scale and access legible at normal zoom.
	ground(x+0.52,y+0.8,0.41,0.12,Color("798a84"))
	for xx in [0.57,0.73,0.89]: line(p(x+xx,y+0.81),p(x+xx-0.05,y+0.91),Color("efd68a"),2)
	box(x+0.08,y+0.82,0.13,0.12,8,Color("b58c60"))
	box(x+0.09,y+0.83,0.11,0.1,6,Color("c9a77e"),8)
	for xx in [0.35,0.49]: box(x+xx,y+0.95,0.035,0.035,9,Color("dfbe61"))
	shop_sign(x+0.43,y+0.9,"GPU CAMPUS" if level==2 else "NEURAL CORE",Color("31576b"))

func utility_tier(x:float,y:float,kind:String,level:int) -> void:
	ground(x+0.04,y+0.04,0.92,0.92,Color("a8b4a8"))
	if kind=="power":
		for xx in [0.1,0.4,0.7]:
			box(x+xx,y+0.35,0.22,0.39,30,Color("819797"))
			for k in range(4): front(x+xx+0.025+k*0.045,y+0.745,0.018,4,27,Color("455f61"))
			for yy in [0.43,0.61]: box(x+xx+0.07,y+yy,0.07,0.06,12,Color("c2c6af"),30)
		for yy in [0.17,0.83]:
			for xx in [0.12,0.87]: line(p(x+xx,y+yy),p(x+xx,y+yy,62 if level==2 else 75),Color("718985"),3)
			line(p(x+0.12,y+yy,59 if level==2 else 72),p(x+0.87,y+yy,59 if level==2 else 72),Color("d2d4bc"),4)
		if level==3:
			box(x+0.06,y+0.05,0.35,0.22,49,Color("7b9eaa"))
			front(x+0.09,y+0.28,0.29,29,40,Color("335867"))
			box(x+0.05,y+0.04,0.37,0.24,4,Color("c9d7c7"),49)
		fence(x+0.05,y+0.97,0.9,0,Color("7d8f84"))
	else:
		for xx in [0.12,0.55]:
			box(x+xx,y+0.13,0.32,0.64,22 if level==2 else 43,Color("769e9f"))
			var height=24 if level==2 else 45
			for h in range(5,height-1,4): front(x+xx+0.02,y+0.775,0.28,h,h+1,Color("385f6a"))
			for yy in [0.29,0.59]:
				ellipse(p(x+xx+0.16,y+yy,height),Vector2(13,7),Color("c9d7c8"))
				ellipse(p(x+xx+0.16,y+yy,height+1),Vector2(9,5),Color("355867"))
		if level==3:
			box(x+0.45,y+0.12,0.08,0.68,12,Color("d1dad1"))
			line(p(x+0.48,y+0.82,13),p(x+0.92,y+0.82,13),Color("89cbd0"),5)
			box(x+0.08,y+0.8,0.22,0.12,19,Color("9bbab5"))
		else: line(p(x+0.15,y+0.84,9),p(x+0.85,y+0.84,9),Color("83c6c4"),5)

func neighborhood_building(x:float,y:float,family:int) -> void:
	ground(x+0.05,y+0.05,0.9,0.9,Color("91a969"))
	var walls=[Color("ddc99b"),Color("b99078"),Color("ccad91"),Color("b5bda2"),Color("a2b6b9"),Color("d4c7ac")]
	if family==0:
		box(x+0.17,y+0.24,0.62,0.47,24,walls[0]);roof(x+0.12,y+0.2,0.72,0.55,24,15,Color("bd7952"))
		box(x+0.67,y+0.3,0.1,0.12,22,Color("ae8966"),27)
		for xx in [0.25,0.58]: window(x+xx,y+0.715,0.13,8,10)
		front(x+0.44,y+0.72,0.1,0,18,Color("527f78"));flowers(x+0.15,y+0.84,0.25);tree(x+0.85,y+0.18,1)
	elif family==1:
		for xx in [0.08,0.51]:
			box(x+xx,y+0.18,0.37,0.55,32,walls[1]);roof(x+xx-0.02,y+0.15,0.41,0.61,32,16,Color("657d87"))
			window(x+xx+0.05,y+0.735,0.1,15,11);front(x+xx+0.23,y+0.74,0.09,0,21,Color("4b6c5b"))
			fence(x+xx,y+0.94,0.35,0);flowers(x+xx+0.03,y+0.83,0.15)
	else:
		var h=[0,0,57,39,65,43][family]
		box(x+0.1,y+0.13,0.79,0.65,h,walls[family])
		box(x+0.08,y+0.11,0.83,0.69,4,Color("d9d5ba"),h)
		if family==2: roof(x+0.07,y+0.1,0.85,0.73,h+4,13,Color("6f727f"))
		for floor in range(10,h-5,17):
			for xx in [0.2,0.44,0.68]: window(x+xx,y+0.785,0.12,floor,11)
			for yy in [0.23,0.48]: side(x+0.895,y+yy,0.12,floor,floor+11,Color("466d79"))
		if family==3:
			for k in range(7): box(x+0.12+k*0.11,y+0.79,0.11,0.15,3,Color("ead3a1") if k%2 else Color("5c9185"),20)
			shop_sign(x+0.5,y+0.81,"MARKET",Color("55776a"));box(x+0.08,y+0.89,0.16,0.1,8,Color("bb8d5d"))
		elif family==4:
			box(x+0.2,y+0.23,0.4,0.3,8,Color("607f89"),h+4)
			line(p(x+0.13,y+0.79,4),p(x+0.85,y+0.79,4),Color("9cc8c5"),3)
		elif family==5:
			for xx in [0.16,0.35,0.56,0.76]: box(x+xx,y+0.8,0.06,0.06,25,Color("e3d8ba"))
			box(x+0.1,y+0.76,0.78,0.17,4,Color("d4c7a6"),25)
			shop_sign(x+0.49,y+0.84,"LIBRARY",Color("5a766e"))
		front(x+0.46,y+0.79,0.1,0,19,Color("42665f"));bench(x+0.65,y+0.92)
	lamp(x+0.08,y+0.91)
