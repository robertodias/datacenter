extends Control
## The live management screen: contracts reserve capacity, surplus earns spot income.
const Economy=preload("res://scripts/economy.gd")
const ClientPanel=preload("res://scripts/client_panel.gd")
var client_filter=""
const AchievementPanel=preload("res://scripts/achievement_panel.gd")
const TutorialPanel=preload("res://scripts/tutorial_panel.gd")
const ScenarioPanel=preload("res://scripts/scenario_panel.gd")
const WorkforcePanel=preload("res://scripts/workforce_panel.gd")
const ResearchPanel=preload("res://scripts/research_panel.gd")
const FinancePanel=preload("res://scripts/finance_panel.gd")
const TownPanel=preload("res://scripts/town_panel.gd")
const OperationsPanel=preload("res://scripts/operations_panel.gd")
var game
var tutorial_view
var scenario_view
var workforce_view
var research_view
var finance_view
var town_view
var ward="oldtown"
var operations_view
var content_scroll:ScrollContainer
var rendered_tab=""
var render_generation=0
var body: Panel
var tab = "offers"
var bindings: Array = []
var signature = ""
var summary: Label
var run_button: Button
var progress_timer = 0.0

func _ready() -> void:
	visible=false
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade=ColorRect.new()
	shade.color=Color(0.02,0.08,0.07,0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	body=game.panel(self,Rect2(0,0,1060,680),Color("122c2b"))

func open(section:String="offers") -> void:
	get_parent().move_child(self,get_parent().get_child_count()-1)
	if game.map_tools!=null: game.map_tools.visible=false
	tab="finance" if section=="hardware" else section
	visible=true
	refresh()
	if section=="hardware": call_deferred("show_hardware")

func fit() -> void:
	size=game.stage.size
	body.position=(size-body.size)/2

func current_signature() -> String:
	var ids:Array=[]
	for c in game.sim.active: ids.append(c.id)
	var equipment=[]
	for lot in game.sim.lots:
		if lot.kind in game.sim.BUILDINGS: equipment.append([lot.x,lot.y,lot.kind,lot.level,lot.get("hardware",""),lot.get("refit_until",0),lot.get("service_until",0),lot.get("failed",false)])
	var civic_stages=[]
	for w in game.sim.civic.wards.values(): civic_stages.append(w.stage)
	var phases=[]
	for e in game.sim.ops.events: phases.append([e.id,e.phase])
	return str([ids,game.sim.completed.size(),tab,game.sim.campaign_won,equipment,int(game.sim.hour/24),phases,game.sim.ops.results.size(),civic_stages,ward,game.sim.research.completed,game.sim.research.ticket,game.sim.research.vision_ticket,game.sim.achievements])

func _process(delta:float) -> void:
	if not visible: return
	fit()
	progress_timer+=delta
	if progress_timer<0.15: return
	progress_timer=0
	if signature!=current_signature(): refresh()
	update_live()

func refresh() -> void:
	if body==null: return
	var previous_scroll=content_scroll.scroll_vertical if is_instance_valid(content_scroll) and rendered_tab==tab else 0
	rendered_tab=tab;render_generation+=1
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	bindings.clear()
	tutorial_view=null
	scenario_view=null
	workforce_view=null
	research_view=null
	finance_view=null
	operations_view=null
	town_view=null
	signature=current_signature()
	var headings={"offers":"CUSTOMER CONTRACTS","active":"ACTIVE CONTRACTS","company":"COMPANY","finance":"FINANCES","operations":"CAMPUS OPERATIONS","town":"TOWN COUNCIL","research":"RESEARCH  /  FEED THE AI","workforce":"PEOPLE  /  STAFFING","scenario":"TOWN CHARTER","tutorial":"FIRST STEPS","clients":"MEET YOUR CUSTOMERS","achievements":"COMPANY ACHIEVEMENTS"}
	var glyphs={"offers":"contracts","active":"check","company":"company","finance":"cash","operations":"operations","town":"council","research":"research","workforce":"people","scenario":"flag","tutorial":"guide","clients":"company","achievements":"trophy"}
	game.icon(body,glyphs.get(tab,"company"),Rect2(24,20,30,30),game.MINT)
	game.label(body,headings.get(tab,"COMPANY"),Rect2(64,17,680,35),26)
	var close=game.button(body,"Close  ·  Esc",Rect2(890,20,145,36),func():visible=false)
	close.tooltip_text="Return to the town"
	summary=game.label(body,"",Rect2(25,61,1010,28),14,game.MINT)
	var company_tabs=["company","town","research","workforce","scenario","tutorial","clients","achievements"]
	tab_button("Offers","contracts",Rect2(25,105,130,40),"offers",tab=="offers")
	tab_button("Active","check",Rect2(161,105,130,40),"active",tab=="active")
	tab_button("Company","company",Rect2(297,105,140,40),"company",tab in company_tabs)
	tab_button("Finances","cash",Rect2(443,105,140,40),"finance",tab=="finance")
	tab_button("Operations","operations",Rect2(589,105,152,40),"operations",tab=="operations")
	run_button=game.button(body,"",Rect2(812,105,118,40),func():game.toggle_pause();update_live())
	run_button.set_meta("glyph",game.icon(run_button,"play",Rect2(12,11,18,18)))
	var speed=game.button(body,"Speed",Rect2(936,105,99,40),func():game.cycle_speed();update_live())
	speed.tooltip_text="Cycle 1x / 3x / 6x  [F4]"
	if tab in company_tabs and tab!="company":
		var back=game.button(body,"<  Company",Rect2(752,20,130,36),func():tab="company";refresh())
		back.tooltip_text="Back to the company overview"
	var scroll=ScrollContainer.new()
	content_scroll=scroll
	scroll.position=Vector2(25,160)
	scroll.size=Vector2(1010,442)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var content=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	if tab=="offers":
		for offer in game.sim.offers(): offer_card(content,offer)
	elif tab=="active":
		if game.sim.active.is_empty():
			var empty=card(content,170)
			game.label(empty,"No active contracts",Rect2(20,20,800,32),22)
			game.paragraph(empty,"Sign a customer on the offers tab. You can reserve up to three contracts at once; any surplus compute continues earning on the open market.",Rect2(20,64,900,70),16)
		for c in game.sim.active: active_card(content,c)
		if not game.sim.history.is_empty():
			var h=card(content,52+game.sim.history.size()*25)
			game.label(h,"RECENT RESULTS · COMPLETION PAYOUTS / PENALTIES",Rect2(20,10,800,25),12,game.MUTED)
			var y=43
			for entry in game.sim.history:
				game.label(h,"%s  ·  %s" % [entry.outcome,entry.name],Rect2(20,y,700,22),14)
				game.label(h,game.money(entry.amount),Rect2(790,y,180,22),14,game.MINT if entry.amount>=0 else game.GOLD)
				y+=25
	elif tab=="finance":
		finance_view=FinancePanel.new(self);finance_view.draw(content)
	elif tab=="operations":
		operations_view=OperationsPanel.new(self);operations_view.draw(content)
	elif tab=="achievements":
		AchievementPanel.new(self).draw(content)
	elif tab=="clients":
		ClientPanel.new(self).draw(content)
	elif tab=="tutorial":
		tutorial_view=TutorialPanel.new(self);tutorial_view.draw(content)
	elif tab=="scenario":
		scenario_view=ScenarioPanel.new(self);scenario_view.draw(content)
	elif tab=="workforce":
		workforce_view=WorkforcePanel.new(self);workforce_view.draw(content)
	elif tab=="research":
		research_view=ResearchPanel.new(self);research_view.draw(content)
	elif tab=="town":
		town_view=TownPanel.new(self);town_view.draw(content)
	else: company_cards(content)
	var footers={
		"town":"Review each district's cause, cost and recovery target. Scroll for negotiation, redesign, relocation and public projects.",
		"tutorial":"The guide follows real actions. Skip it, resume it, or build freely. Gold outlines identify a useful next control without moving keyboard focus.",
		"scenario":"Each town has its own charter, saved progress and optional distinctions. Completing it keeps this town playable and offers a fresh start in the next town.",
		"workforce":"Specialist wages are billed every simulation hour; visit fees are separate. Team size and priority affect new dispatches, not work already underway.",
		"research":"Research takes capacity first. Watch customer delivery before increasing its share. Progress, discoveries, campaigns and observations are saved.",
		"clients":"Browse each company's background and mission. Contract reviews show the actual capacity, workload, deadline and financial terms before you sign.",
		"achievements":"Earned achievements stay with this saved company. Sandbox does not award them. Open Company to return to your charter and management tools."}
	game.paragraph(body,footers.get(tab,"Active contracts reserve physical compute in priority order. Hardware changes delivered work per unit. Project payouts and service bonuses are separate from hourly cash flow."),Rect2(25,619,1010,47),13,game.MUTED)
	fit()
	update_live()
	if previous_scroll>0: call_deferred("restore_scroll",previous_scroll,render_generation)

func tab_button(text:String,glyph:String,rect:Rect2,target:String,active:bool) -> Button:
	var b=game.button(body,text,rect,func():tab=target;refresh(),active)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var sb=b.get_theme_stylebox(state).duplicate();sb.content_margin_left=34;b.add_theme_stylebox_override(state,sb)
	game.icon(b,glyph,Rect2(12,11,18,18),Color("152d2c") if active else game.MINT)
	return b

## Accent stripe on the left edge groups each card visually, like a ledger row.
static func accent(sb:StyleBoxFlat,color:Color=Color("3c6b5a")) -> StyleBoxFlat:
	sb.border_width_left=4
	sb.border_color=color
	return sb

func card(parent:Node,height:float) -> Panel:
	var p=game.panel(parent,Rect2(0,0,990,height),Color("1d3833"))
	p.add_theme_stylebox_override("panel",accent(p.get_theme_stylebox("panel").duplicate()))
	p.custom_minimum_size=Vector2(970,height)
	p.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return p

func offer_card(parent:Node,c:Dictionary) -> void:
	var ui=ResearchPanel.new(self)
	var box=ui.section(parent,c.name)
	ui.copy(box,c.client.to_upper()+" / "+Economy.WORKLOADS[c.workload].name.to_upper()+" / "+c.type.to_upper(),12,game.MINT)
	ui.copy(box,c.brief,15)
	var facts=[["RESERVES","%d compute" % c.compute],["DEADLINE","%dh" % c.deadline]]
	if c.type=="service": facts+= [["DELIVERY","%d%% required" % roundi(c.min_delivery*100)],["PAYS","%s/h + %s bonus" % [game.money(c.compute*c.rate),game.money(c.reward)]]]
	else: facts+= [["WORK","%d compute-h" % c.work],["PAYS ON DELIVERY",game.money(c.reward)]]
	fact_row(box,facts)
	var quote=ui.copy(box,"",14)
	ui.copy(box,Economy.WORKLOADS[c.workload].brief,13,game.MUTED)
	var reason=ui.copy(box,"",13,game.MUTED)
	var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",12);box.add_child(actions)
	var b=ui.action(actions,"Review & sign",func():review_contract(c))
	ui.action(actions,"About "+c.client,func():client_filter=c.client;open("clients"))
	bindings.append({"type":"offer","button":b,"c":c,"reason":reason,"quote":quote,"card":box.get_parent()})

func review_contract(offered:Dictionary) -> void:
	var c:Dictionary=game.sim.contract_definition(offered.id)
	if c.is_empty(): c=offered
	var q=game.sim.contract_quote(c)
	var risk="Worst-case deadline slack: %dh" % q.slack if c.type=="project" else "Delivery requirement: %d%%" % roundi(c.min_delivery*100)
	game.ask("Sign "+c.name+"?","Reserve up to %d physical compute. Estimated delivery: %.1f work/h.\nContribution versus spot: %s/h (project payouts averaged).\nCampus cash flow while working: %s/h; bonuses pay later.\n%s. Failure / cancellation fee: %s.\nReputation %d: payouts x%.3f. Late: -5 reputation. Cancelling: -3, or -5 in the final quarter of the term.\n%s\n\n%s\n\nExisting campus uses %.1f MW and %.1f cooling. Signing uses those machines; no new construction is included." % [c.compute,q.delivery,game.money_detail(q.margin),game.money_detail(q.cash_profit),risk,game.money(q.penalty),game.sim.reputation,game.sim.reputation_factor(),q.warning,Economy.WORKLOADS[c.workload].brief,q.power,q.cooling],func():game.complete_action(game.sim.accept_contract(c.id),"Signed: "+c.name))

func active_card(parent:Node,c:Dictionary) -> void:
	var p=card(parent,236)
	game.label(p,c.name,Rect2(20,12,720,32),22)
	var live=game.label(p,"",Rect2(20,50,720,25),14,game.MINT)
	var bar=ProgressBar.new()
	bar.position=Vector2(20,88)
	bar.size=Vector2(720,20)
	bar.max_value=c.work
	bar.show_percentage=false
	bar.add_theme_stylebox_override("background",game.style(Color("102b29")))
	bar.add_theme_stylebox_override("fill",game.style(game.MINT))
	p.add_child(bar)
	var status=game.label(p,"",Rect2(20,118,720,26),14)
	game.label(p,"%s %s" % ["On delivery:" if c.type=="project" else "Completion bonus:",game.money(c.reward)],Rect2(20,154,720,24),14,game.GOLD)
	game.button(p,"Cancel contract",Rect2(780,63,185,43),func():game.ask("Cancel "+c.name+"?","Cancellation fee: %s. Reputation: -%d%s." % [game.money(roundi(c.reward*c.penalty_rate)),game.sim.cancel_reputation(c)," (final quarter counts as a missed deadline)" if game.sim.cancel_reputation(c)==5 else ""],func():game.complete_action(game.sim.cancel_contract(c.id),"Contract cancelled.");refresh()))
	game.button(p,"↑ Up",Rect2(780,120,88,36),func():game.complete_action(game.sim.prioritize(c.id,-1),"Contract moved earlier in the queue."))
	game.button(p,"↓ Down",Rect2(878,120,87,36),func():game.complete_action(game.sim.prioritize(c.id,1),"Contract moved later in the queue."))
	game.paragraph(p,"Fee: "+game.money(roundi(c.reward*c.penalty_rate)),Rect2(780,173,185,43),12)
	game.label(p,Economy.WORKLOADS[c.workload].name+" · priority controls who receives scarce compute first",Rect2(20,192,735,27),12,game.MUTED)
	bindings.append({"type":"active","c":c,"live":live,"bar":bar,"status":status})

func company_cards(parent:Node) -> void:
	var sim=game.sim
	var clients_card=card(parent,72)
	game.label(clients_card,"Meet your customers / nine fictional companies",Rect2(20,18,710,32),20)
	game.button(clients_card,"Companies",Rect2(780,17,185,38),func():client_filter="";open("clients"))
	var charter_card=card(parent,72)
	game.label(charter_card,sim.Scenarios.info(sim.scenario_id).name+" / objectives and next town",Rect2(20,18,710,32),20)
	game.button(charter_card,"Town charter",Rect2(780,17,185,38),func():open("scenario"))
	var awards_card=card(parent,72)
	game.label(awards_card,"Company achievements / %d earned" % sim.achievements.size(),Rect2(20,18,710,32),20)
	game.button(awards_card,"Achievements",Rect2(780,17,185,38),func():open("achievements"))
	var research_card=card(parent,72)
	game.label(research_card,"Feed the AI / research and companion",Rect2(20,18,710,32),20)
	game.button(research_card,"Open research",Rect2(780,17,185,38),func():open("research"))
	var teams_card=card(parent,72)
	game.label(teams_card,"People / staffing, priorities and dispatches",Rect2(20,18,710,32),20)
	game.button(teams_card,"Manage teams",Rect2(780,17,185,38),func():open("workforce"))
	var council_card=card(parent,72)
	game.label(council_card,"Town council / neighborhood impacts and adoption",Rect2(20,18,720,32),20)
	game.button(council_card,"Open council",Rect2(780,17,185,38),func():game.open_town())
	var p=card(parent,145)
	game.label(p,sim.Scenarios.info(sim.scenario_id).name.to_upper()+" COMPLETE" if sim.campaign_won else sim.company_name,Rect2(20,12,800,30),23,game.GOLD if sim.campaign_won else game.INK)
	game.label(p,"%d / 8 delivered  ·  Reputation %d / 100 (new contracts pay %+.1f%%)  ·  Tier %d" % [sim.campaign_count(),sim.reputation,(sim.reputation_factor()-1.0)*100,sim.tech_level()],Rect2(20,51,930,26),16,game.MINT)
	game.paragraph(p,"The town charter is complete. Continue with new commissions, or open Town charter to move on." if sim.campaign_won else sim.Scenarios.info(sim.scenario_id).goal,Rect2(20,88,920,48),15)
	var goals=[
		["First campus","Earn $1,200 from operating servers.","campus",2000],
		["Trusted provider","Deliver 2 customers. Unlock tier 2 GPU clusters and utilities.","gpu",3000],
		["AI infrastructure leader","Deliver 4 customers. Unlock tier 3 neural superclusters.","neural",4500],
		["Frontier operator","Deliver 6 customers. Unlock FreeAGI and Groove contracts.","frontier",6000],
		["Town charter complete","Deliver eight customers and meet the town-specific objectives.","v1",10000]]
	for goal in goals:
		p=card(parent,90)
		game.label(p,("[DONE]  " if goal[2] in sim.milestone_claims else "[   ]  ")+goal[0],Rect2(20,10,760,27),18,game.MINT if goal[2] in sim.milestone_claims else game.INK)
		game.label(p,goal[1],Rect2(20,46,750,27),14)
		game.label(p,"Grant "+game.money(goal[3]),Rect2(790,24,180,28),15,game.GOLD)
	p=card(parent,120)
	game.label(p,"Give something back",Rect2(20,11,720,30),21)
	game.paragraph(p,"A $1,000 community grant restores 10 public approval. Available once every 24 game hours.",Rect2(20,52,700,50),14)
	game.button(p,"Invest $1,000",Rect2(780,35,185,43),func():game.complete_action(sim.invest_community(),"Community investment: +10 approval.");refresh())

## Key contract terms as a row of labelled boxes, so they scan like a spec sheet.
func fact_row(parent:Node,facts:Array) -> void:
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",10);parent.add_child(row)
	for fact in facts:
		var cell=PanelContainer.new();cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var sb=game.style(Color("15302c"),Color("2a4a43"),8);sb.content_margin_top=6;sb.content_margin_bottom=6
		cell.add_theme_stylebox_override("panel",sb);row.add_child(cell)
		var stack=VBoxContainer.new();stack.add_theme_constant_override("separation",0);cell.add_child(stack)
		var cap=Label.new();cap.text=fact[0];cap.add_theme_color_override("font_color",game.MUTED)
		cap.set_meta("base_font_size",11);cap.add_theme_font_size_override("font_size",roundi(11*game.settings.ui_scale));stack.add_child(cap)
		var value=Label.new();value.text=fact[1];value.add_theme_color_override("font_color",game.GOLD if fact[0].begins_with("PAYS") else game.INK)
		value.set_meta("base_font_size",16);value.add_theme_font_size_override("font_size",roundi(16*game.settings.ui_scale));stack.add_child(value)

func update_live() -> void:
	if summary==null: return
	var m=game.sim.metrics()
	summary.text="Cash %s   ·   Online %d   ·   Reserved %d   ·   Free %d   ·   Net %s / h   ·   Slots %d / 3" % [game.money(game.sim.cash),m.compute,m.reserved,m.free,game.money(m.profit),game.sim.active.size()]
	run_button.text="      "+("Run" if game.paused else "Pause")+"  "+str(game.speed)+"×"
	run_button.get_meta("glyph").glyph="play" if game.paused else "pause"
	run_button.add_theme_stylebox_override("normal",game.style(Color("6b5a2c") if game.paused else Color("203c37"),game.GOLD if game.paused else Color("314b46")))
	for b in bindings:
		var c:Dictionary=b.c
		if b.type=="offer":
			var reason=""
			if game.sim.campaign_count()<c.unlock: reason="Unlocks after %d deliveries" % c.unlock
			elif game.sim.active.size()>=3: reason="All 3 slots occupied"
			elif m.free<c.compute: reason="Need %d more online compute" % ceili(c.compute-m.free)
			b.button.disabled=reason!=""
			b.reason.text=reason if reason!="" else "Reserve %d compute\nFee: %s" % [c.compute,game.money(roundi(c.reward*c.penalty_rate))]
			if reason!="":
				b.quote.text="Delivery estimate appears once this contract can be signed."
				b.quote.add_theme_color_override("font_color",game.MUTED)
				b.reason.add_theme_color_override("font_color",game.GOLD)
				b.card.modulate.a=0.62 if reason.begins_with("Unlocks") else 1.0
				continue
			b.reason.add_theme_color_override("font_color",game.MUTED)
			b.card.modulate.a=1.0
			var q=game.sim.contract_quote(c)
			b.quote.text="Contribution vs spot %s/h · Campus cash net %s/h\n%.1f work/h · %s" % [game.money_detail(q.margin),game.money_detail(q.cash_profit),q.delivery,("ETA %dh · worst slack %dh" % [q.eta,q.slack]) if c.type=="project" else "Bonus requires %d%% of promised work" % roundi(c.min_delivery*100)]
			if not q.warning.is_empty(): b.reason.text+="\nIncident warning: review Operations"
			b.quote.add_theme_color_override("font_color",game.GOLD if c.type=="project" and q.slack<0 else game.INK)
		else:
			var allocation=m.allocations.get(c.id,0)
			var work=m.deliveries.get(c.id,0)
			b.live.text="%d / %d compute allocated   ·   %dh remaining   ·   %d%% delivered" % [allocation,c.compute,c.remaining,roundi(c.progress/c.work*100)]
			b.bar.value=c.progress
			var eta=ceili((c.work-c.progress)/work) if work>0 else 9999
			if c.type=="project":
				b.status.text=("NO CAPACITY · restore service or change priority · %dh left" % c.remaining) if work<=0 else ("On track · estimated %dh to delivery" % eta if eta<=c.remaining else "DEADLINE AT RISK · %dh needed / %dh left" % [eta,c.remaining])
			else:
				b.status.text="Service forecast healthy · income "+game.money(work*c.rate) if (c.progress+work*c.remaining)/c.work>=c.min_delivery else "BONUS AT RISK · prioritize or restore capacity; deadlines keep running"

	if tutorial_view!=null: tutorial_view.update_live()
	if scenario_view!=null: scenario_view.update_live()
	if workforce_view!=null: workforce_view.update_live()
	if research_view!=null: research_view.update_live()
	if finance_view!=null: finance_view.update_live()
	if operations_view!=null: operations_view.update_live()
	if town_view!=null: town_view.update_live()

func show_hardware() -> void:
	if finance_view!=null and finance_view.hardware_heading!=null:
		content_scroll.scroll_vertical=roundi(finance_view.hardware_heading.position.y)

func restore_scroll(offset:int,generation:int) -> void:
	if generation==render_generation: content_scroll.scroll_vertical=offset
