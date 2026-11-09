# Credits and asset provenance

Hyperscale: Datacenter Tycoon is an original Godot project developed in this workspace
with the project owner and AI-assisted implementation. Public developer/publisher
credit is intentionally left for the owner to supply before a store release.

- Engine: Godot 4.5.1, MIT licensed. The distribution includes GODOT-LICENSE.txt
  and GODOT-THIRD-PARTY-NOTICES.txt, including the engine's bundled dependencies.
- Town artwork: original painted sprites generated for this project:
  - sources, prompts and anchors are in `assets/art/` (`README.md`, `manifest.json`);
  - `dev/pack_town_art.gd` packs them into `assets/town_art_*.png`.

  The earlier code-drawn scenery (`scripts/town_art.gd`, baked by `tests/bake_art.gd`)
  remains as a fallback. No artwork was taken from other games.
- Brand icon, logo and title illustration: generated for this project; files, sizes and
  generation prompts are recorded in `assets/branding/README.md`. The Windows `.ico` is
  converted from the icon PNG by `dev/bake_brand_icon.gd`.
- Interface and key art: project-native code and the engine's bundled fallback font.
- Music, ambience and AI chirp: original procedural synthesis in `dev/generate_audio.py`.
  Seven reproducible WAV assets are included; no commercial recordings or voice
  impersonations are used.
- Company names: fictional names supplied by the project owner. Backgrounds, mottos
  and mission dialogue are original comic fiction.
- Design research: links and lessons are recorded in `docs/PHASES.md`; they are
  references for design, not licenses for other games' assets or an endorsement.

The standalone game does not call hosted AI APIs or require a model account. Customer
work, research, the companion and citizens are simulation systems running locally.
