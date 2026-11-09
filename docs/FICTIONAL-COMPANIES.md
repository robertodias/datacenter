# Fictional customers

The game uses these nine fictional company names in profiles, contracts, tutorials,
notices and results. All backgrounds and mission dialogue are original comic fiction.
The campaign keeps its eight stable contract IDs so older saves retain their progress.

| Company | Personality and specialty | First mission |
| --- | --- | --- |
| GPN | Multilingual models and task-running agents | Lost in translation: a bakery ordering pilot |
| Synthopic | Careful assistants with an extensive rulebook | Terms of endearment: recurring help desk |
| Noodle | Search and multimodal experiments | A thousand trailers: experimental generation |
| Amazing | Retail, robotics and cloud logistics | Robots versus stairs: critical parcel coordination |
| BlueWhale | Efficient reasoning and shared model weights | Think on a budget: model training |
| Megahard | Office software and enterprise assistants | Committee intelligence: critical council service |
| FreeAGI | Frontier assistants and compute-hungry research | Just one more GPU: frontier training |
| Groove | Live conversations and experimental personalities | The universe, live: experimental service |
| SmilingFace | Community models, datasets and hosted demos | Community inference: research-unlocked service |

**Company → Companies** opens the complete directory. Each offer also has an
**About [company]** button. Profiles explain the company, its campaign mission and
the unlock route. Customer scout introduces SmilingFace first, then rotates local
inference pilots. Experimental scheduler introduces experimental commissions.
After eight campaign deliveries, training commissions rotate through all nine firms.

Narrative decoration is centralized in `scripts/clients.gd`. It changes only the
name, client and brief fields, including when loading an in-flight contract. It
does not change prices, rewards, workloads, progress, remaining time, negotiated
penalties, staffing effects or saved research counters. Earlier historical ledger
entries retain their original recorded description. New results include the sponsor.

Verification: 51 dedicated checks cover the roster, repeat commissions, migration of
two active preview contracts, exact continuation and scrollable enlarged-text UI.
The full campaign progression suite also passes 63 checks. Contract cards now use
content-sized containers to prevent their longer briefs overlapping financial terms.

Final build: `build/Hyperscale Datacenter Tycoon.exe` (1.2.0), launched with `Play.cmd`.
The earlier company preview remains available through `Play Preview.cmd`. A running
preview continues using its embedded build; save and close it before launching 1.2.0.
Normal saves retain the existing application-data directory. The older 1.1.1 executable
is preserved in `.tools/checkpoints`.
