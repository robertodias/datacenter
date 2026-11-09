extends RefCounted
## Fictional company lore. Stable contract IDs keep existing saves and terms intact.
const COMPANIES={
	"FreeAGI":{"specialty":"Frontier assistants and ever-larger training runs","motto":"Intelligence for everyone. Power bill for you.","background":"A research club grew into the town's most compute-hungry assistant empire. Every breakthrough is celebrated with a modest request for another building full of accelerators.","mission":"Just one more GPU","brief":"Train FreeAGI's next frontier assistant. Procurement swears this is the final batch. For this week."},
	"Synthopic":{"specialty":"Careful assistants, coding and rulebooks","motto":"Helpful. Harmless. Heavily footnoted.","background":"Founded by researchers who brought a constitution to a brainstorming session. Its thoughtful assistants can debug a program, explain the risks, and politely ask whether the program should exist.","mission":"Terms of endearment","brief":"Host Synthopic's careful help desk. It must answer the question before its footnotes need their own server."},
	"Groove":{"specialty":"Live conversation and experimental personalities","motto":"The answer has entered the chat.","background":"A restless conversational lab that treats the live feed as a research seminar. Its assistant wants to understand the universe, preferably while delivering the last word in an argument.","mission":"The universe, live","brief":"Run Groove's live debate assistant. Every answer starts a new debate. Keep room for the experimental swings."},
	"Noodle":{"specialty":"Search, multimodal models and creative experiments","motto":"Everything connects. Eventually.","background":"It began by finding things and now wants to understand every picture, sound and video. Its research campus has so many experimental products that the directory needs its own research team.","mission":"A thousand trailers","brief":"Render Noodle's multimodal film experiment: a thousand sequels to a film nobody has made yet."},
	"Amazing":{"specialty":"Retail logistics, warehouse robotics and cloud services","motto":"From cart to doorstep, via your substation.","background":"A shop that grew warehouses, a robot fleet and a very large cloud division. Its delivery forecasts are precise enough to order replacement cooling before your operator admits it is warm.","mission":"Robots versus stairs","brief":"Keep Amazing's parcel robots coordinated. Doorsteps remain undefeated; missing a service promise is costly."},
	"Megahard":{"specialty":"Office assistants and enterprise cloud workloads","motto":"Every meeting deserves a sequel.","background":"An office-software giant selling productivity by the seat and cloud capacity by the hour. Its new assistant summarizes meetings, drafts follow-ups and schedules a meeting to review the summary.","mission":"Committee intelligence","brief":"Run Megahard's office assistant for the council. Meetings about meetings now require dependable uptime."},
	"SmilingFace":{"specialty":"Community models, datasets and hosted demos","motto":"Share the weights. Bring your own watts.","background":"A cheerful hub where builders share models, datasets and tiny demos that occasionally attract the whole planet. The community contributes the ideas; someone still has to host them.","mission":"One tiny demo","brief":"Host SmilingFace's community demo. The README says tiny. The download counter has other plans."},
	"BlueWhale":{"specialty":"Efficient reasoning and openly shared model weights","motto":"Deep thoughts. Shallow power bills, please.","background":"A lean reasoning lab obsessed with doing more on a smaller compute budget. Its researchers publish the weights, compare efficiency charts and ask whether your spare racks can solve one more puzzle.","mission":"Think on a budget","brief":"Train BlueWhale's reasoning model on puzzles. The benchmark is difficult; the procurement team is harder."},
	"GPN":{"specialty":"Multilingual models, coding and practical agents","motto":"Many languages. One very busy agent.","background":"A language-model lab expanding into coding and task-running agents. Its assistants can navigate a workflow in several languages, but the town's bakery ordering form remains a formidable benchmark.","mission":"Lost in translation","brief":"Pilot GPN's multilingual ordering agent at the bakery. It must learn that a turnover is also a pastry."}
}
const CAMPAIGN={"bakery":"GPN","support":"Synthopic","studio":"Noodle","robotics":"Amazing","research":"BlueWhale","council":"Megahard","atlas":"FreeAGI","orbital":"Groove"}
const SCOUTS=["SmilingFace","GPN","Synthopic","Megahard"]
const VISIONS=["Noodle","Groove","FreeAGI","BlueWhale"]
const COMMISSIONS=["SmilingFace","FreeAGI","Synthopic","Groove","Noodle","Amazing","Megahard","BlueWhale","GPN"]
const TRAINING_TASKS={
	"SmilingFace":"Train a community model for SmilingFace. The model card has more contributors than the town has parking spaces.",
	"FreeAGI":"Train FreeAGI's next assistant checkpoint. The previous final training run was apparently a rehearsal.",
	"Synthopic":"Train Synthopic's careful coding assistant. Its style guide has developed a style guide.",
	"Groove":"Train Groove's next conversational model. The evaluation committee has already started arguing with it.",
	"Noodle":"Train Noodle's picture-and-sound model. It must recognize a server fan without giving it a record deal.",
	"Amazing":"Train Amazing's warehouse routing model. The shortest path must also include somewhere for humans to walk.",
	"Megahard":"Train Megahard's office assistant. Turning a spreadsheet into a presentation should not require a committee.",
	"BlueWhale":"Train BlueWhale's compact reasoning model. More thinking per rack is the entire sales pitch.",
	"GPN":"Train GPN's multilingual task agent. Completing the form matters more than explaining the form."
}

static func identity(id:String) -> Dictionary:
	if CAMPAIGN.has(id):
		var company:String=CAMPAIGN[id];var p:Dictionary=COMPANIES[company]
		return {"client":company,"name":company+": "+p.mission,"brief":p.brief}
	for prefix in ["scout_","vision_","open_"]:
		if not id.begins_with(prefix): continue
		var suffix=id.trim_prefix(prefix)
		if not suffix.is_valid_int() or int(suffix)<0: return {}
		var ticket=int(suffix)
		var roster:Array=SCOUTS if prefix=="scout_" else (VISIONS if prefix=="vision_" else COMMISSIONS)
		var company:String=roster[ticket%roster.size()]
		var task="Community inference" if prefix=="scout_" else ("Experimental sandbox" if prefix=="vision_" else "Training commission")
		var brief:String=TRAINING_TASKS[company] if prefix=="open_" else ("Run an experimental model sandbox for "+company+". A brilliant idea still needs room for unpredictable throughput." if prefix=="vision_" else "Host "+company+"'s local assistant pilot. Keep its neighborhood users served while the demo finds its audience.")
		return {"client":company,"name":"%s: %s #%d" % [company,task,ticket+1],"brief":brief}
	return {}

static func decorate(contract:Dictionary) -> Dictionary:
	var result=contract.duplicate(true)
	var copy=identity(str(result.get("id","")))
	for key in copy: result[key]=copy[key]
	return result
