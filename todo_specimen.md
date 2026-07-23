# Comprehensive Specimen + Interaction Log + Auto-Learning — Task Tracker

## Phase 1: Verify Codebase Loads (Fix Anything Broken)
- [x] Confirm Julia env instantiates (Pkg.instantiate)
- [x] Load src/Main.jl cleanly (catch any compile/include errors)
- [x] Load existing comprehensive_specimen_v81.json — verify no load errors (133 nodes, 8 lobes, 10 AIML nodes, 16 sigils, 526 thesaurus)
- [x] Fix any broken includes / functions / module references found (none — clean load)

## Phase 2: Build Comprehensive Specimen
- [x] Audit all node types Grug supports (match, time, aiml, antimatch, image, grave, sigil)
- [x] Audit all side rules / side systems (immune, mitosis, phagy, chatter, hippocampal, MLP, coherence, etc.)
- [x] Audit full CLI command surface (70+ commands) + language features (thesaurus, verbs, relations, sigils, negthes)
- [x] Build enrichment command script: new lobes, image nodes, antimatch, cross-lobe bridges, crystalized bridges, relation classes/verbs, synonyms, sigils, negthes inhibitions, AIML nodes, time nodes
- [x] **FIXED CRITICAL BUG**: Main.jl never included/used AutoGrowth + AutoLinker → standalone run = auto-learning silently dead (UndefVarError swallowed by try/catch). Added isdefined-guarded include+using after TemporalGrowth.
- [x] **FIXED CRITICAL BUG**: coherence_config missing from allowed_keys → specimen load rejection
- [x] **FIXED CRITICAL BUG**: /grow image node not flagged as image_node, SDF signal not applied
- [x] Run enrichment against v81 base + save comprehensive specimen (175 nodes, 11 lobes)
- [x] Validate comprehensive specimen loads without errors after fixes
- [x] **FIXED CRITICAL BUG**: JSON.parse returns JSON.Object{String,Any}, not Dict{String,Any}. All isa(x,Dict) checks in specimen load path silently failing — added _is_dict_like() helper using AbstractDict, fixed 50+ type checks across Main.jl, ImmuneSystem.jl, AIMLNodeSystem.jl, AutoGrowth.jl, AutoLinker.jl, CoherenceField.jl, EphemeralMLP.jl, ChatterResiduals.jl, EphemeralAutomaton.jl, InputLedger.jl, RelationalGovernance.jl, InputDecomposer.jl, LobeTable.jl

## Phase 3: Interact With Grug + Record Log
- [ ] Write interaction harness (input -> process_mission -> capture response + telemetry)
- [ ] Run multi-turn conversation covering all answer families (greet, reason, explain, ponder, analyze, etc.)
- [ ] Capture telemetry (node fires, arousal, lobe routing, votes, growth, links)
- [ ] Write everything to a Markdown interaction log

## Phase 4: Verify Auto-Learning Works
- [ ] Confirm AutoGrowth accumulates evidence during conversation
- [ ] Confirm AutoGrowth grows nodes (lazy coinflip) — check /autoGrowStatus
- [ ] Confirm AutoLinker accumulates link evidence — check /autoLinkStatus
- [ ] Confirm AutoLinker bridges nodes (cross-lobe priority)
- [ ] Verify node count / bridge count grows over the session
- [ ] Record auto-learning evidence in the MD log

## Phase 5: Save + Deliver
- [ ] Save the post-conversation specimen (with learned nodes/bridges)
- [ ] Deliver specimen JSON + interaction MD log
- [ ] Commit + push fixes + specimen to GitHub
