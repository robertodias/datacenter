extends RefCounted
const Economy=preload("res://scripts/economy.gd")
var board
var game
var rows:Array=[]
var halls:Array=[]
var loan_label:Label
var balance_label:Label
var borrow_button:Button
var repay_button:Button
var live_label:Label
var hardware_heading:Control

func _init(owner_board) -> void:
	board=owner_board;game=board.game

func draw(parent:Node) -> void:
	rows.clear();halls.clear()
	var sim=game.sim
	var p=board.card(parent,225)
	game.label(p,"Cash flow / operating costs",Rect2(20,10,720,30),22)
	game.button(p,"Jump to hardware",Rect2(780,11,185,34),func():board.show_hardware())
	live_label=game.paragraph(p,"",Rect2(20,49,930,100),15,game.INK)
	balance_label=game.paragraph(p,"",Rect2(20,160,930,54),14)
	p=board.card(parent,153)
	game.label(p,"Working capital / debt",Rect2(20,10,680,30),21)
	loan_label=game.paragraph(p,"",Rect2(20,48,690,85),14)
	borrow_button=game.button(p,"Borrow $5,000",Rect2(780,26,185,42),func():game.ask("Borrow $5,000?","Cash increases by $5,000. Interest increases by $2.50 per game hour. Principal must be repaid separately. Credit limit: $20,000.",func():game.complete_action(sim.borrow(),"Loan received. Interest is included in hourly costs.")))
	repay_button=game.button(p,"Repay $5,000",Rect2(780,82,185,42),func():game.complete_action(sim.repay(),"Loan principal repaid."))
	p=board.card(parent,83+Economy.CATEGORIES.size()*28)
	game.label(p,"INCOME / EXPENSES",Rect2(20,11,630,27),19)
	game.label(p,"THIS DAY",Rect2(580,14,170,22),12,game.MUTED)
	game.label(p,"SINCE START",Rect2(780,14,185,22),12,game.MUTED)
	var y=52
	for category in Economy.CATEGORIES:
		game.label(p,Economy.CATEGORIES[category],Rect2(20,y,530,25),14)
		var today=game.label(p,"",Rect2(580,y,180,25),14)
		var total=game.label(p,"",Rect2(780,y,185,25),14)
		rows.append({"category":category,"today":today,"total":total})
		y+=28
	if not sim.finance.history.is_empty():
		p=board.card(parent,62+sim.finance.history.size()*31)
		game.label(p,"DAILY CASH / SALES LESS COSTS / FINANCING IS SEPARATE",Rect2(20,10,930,28),13,game.MINT)
		y=49
		for day in sim.finance.history:
			game.label(p,"Day %d · Cash %s → %s · Operations %s" % [day.day,game.money_detail(day.opening),game.money_detail(day.closing),game.money_detail(Economy.total(day.totals,Economy.OPERATING))],Rect2(20,y,930,27),14)
			y+=31
	p=board.card(parent,100)
	hardware_heading=p
	game.label(p,"Server hardware and refits",Rect2(20,11,930,29),22)
	game.paragraph(p,"Choose hardware before building in the property inspector. Refit existing halls below: pay the stated cost, then lose that hall's output for 2 game hours. Upgrades retain the chosen hardware profile.",Rect2(20,49,930,47),14)
	for lot in sim.lots:
		if lot.kind!="datacenter": continue
		hardware_card(parent,lot)

func hardware_card(parent:Node,lot:Dictionary) -> void:
	var sim=game.sim
	var idx=sim.cell(int(lot.x),int(lot.y))
	var p=board.card(parent,250)
	game.label(p,"Server hall %02d-%02d · Tier %d" % [lot.x+1,lot.y+1,lot.level],Rect2(20,10,930,29),22)
	var status=game.label(p,"",Rect2(20,46,930,26),14,game.MINT)
	var option=OptionButton.new()
	option.position=Vector2(20,88);option.size=Vector2(400,36)
	var choices=Economy.HARDWARE.keys()
	for profile in choices:
		option.add_item(Economy.HARDWARE[profile].name)
		option.set_item_disabled(option.item_count-1,not sim.hardware_unlocked(profile))
		option.get_popup().set_item_tooltip(option.item_count-1,Economy.HARDWARE[profile].brief)
	option.selected=choices.find(lot.get("hardware","balanced"))
	p.add_child(option)
	var preview=game.paragraph(p,"",Rect2(20,137,930,99),14,game.INK)
	var refit_button=game.button(p,"Refit hall",Rect2(780,86,185,42),func():
		var profile:String=choices[option.selected]
		game.ask("Refit server hall?","%s: %s. This hall is offline for %d game hours. Active contracts keep their deadlines.\n\n%s" % [Economy.HARDWARE[profile].name,game.money_detail(sim.refit_cost(sim.lots[idx],profile)),sim.Workforce.duration(sim,2),Economy.HARDWARE[profile].brief],func():game.complete_action(sim.refit(idx,profile),"Hardware refit started. See the equipment timer for completion.")))
	var update_preview=func():
		var profile:String=choices[option.selected]
		var candidate=lot.duplicate();candidate.hardware=profile
		var b=sim.building_stats(candidate)
		preview.text="%s\nAfter refit: %d compute · %.1f MW · %.1f cooling · %s/h equipment and staff\nRefit cost: %s · %dh downtime · Condition carries over · Energy is billed separately" % [Economy.HARDWARE[profile].brief,b.capacity,b.power,b.cooling,game.money_detail(b.upkeep),game.money_detail(sim.refit_cost(lot,profile)),game.sim.Workforce.duration(game.sim,2)]
		refit_button.disabled=profile==lot.get("hardware","balanced") or int(lot.get("refit_until",0))>sim.hour
	option.item_selected.connect(func(_i):update_preview.call())
	halls.append({"lot":lot,"status":status,"button":refit_button,"option":option,"choices":choices})
	update_preview.call()

func update_live() -> void:
	if live_label==null or not is_instance_valid(live_label): return
	var sim=game.sim;var m=sim.metrics()
	live_label.text="Cash income %s/h = spot %s + recurring %s\nCosts %s/h = upkeep %s + staff %s + energy %s\nResilience operations %s/h + interest %s/h included above.\nProject payouts and service bonuses arrive separately; hourly net excludes future payouts." % [game.money_detail(m.revenue),game.money_detail(m.spot_revenue),game.money_detail(m.service_revenue),game.money_detail(m.upkeep),game.money_detail(m.maintenance),game.money_detail(m.staff),game.money_detail(m.energy),game.money_detail(m.operations),game.money_detail(m.interest)]
	balance_label.text="Opening cash %s + all recorded cash flows %s = %s\nReports begin on day %d at %02d:00; imported towns retain their starting cash." % [game.money_detail(sim.finance.opening_cash),game.money_detail(Economy.total(sim.finance.totals)),game.money_detail(sim.cash),int(sim.finance.since_hour)/24+1,int(sim.finance.since_hour)%24]
	loan_label.text="Principal %s / $20,000 · Interest %s per hour (0.05%%)\nBorrowing is financing, not revenue. Repayment reduces cash and debt.\nCash after full repayment: %s" % [game.money_detail(sim.finance.debt),game.money_detail(m.interest),game.money_detail(sim.cash-sim.finance.debt)]
	borrow_button.disabled=sim.finance.debt+5000>Economy.LOAN_LIMIT
	repay_button.disabled=sim.finance.debt<=0 or sim.cash<minf(5000,sim.finance.debt)
	repay_button.text="Repay "+game.money_detail(minf(5000,sim.finance.debt))
	for row in rows:
		for pair in [[row.today,sim.finance.current],[row.total,sim.finance.totals]]:
			var amount=pair[1].get(row.category,0.0)
			pair[0].text=game.money_detail(amount)
			pair[0].add_theme_color_override("font_color",game.GOLD if amount<0 else game.MINT)
	for item in halls:
		var lot:Dictionary=item.lot
		var remaining=maxi(0,int(lot.get("refit_until",0))-sim.hour)
		item.status.text=Economy.HARDWARE[lot.get("hardware","balanced")].name+(" · REFITTING · %dh left" % remaining if remaining>0 else " · Ready")
		var profile:String=item.choices[item.option.selected]
		item.button.disabled=remaining>0 or profile==lot.get("hardware","balanced") or sim.cash<sim.refit_cost(lot,profile)
