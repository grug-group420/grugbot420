# v9 Meta-Cognitive Extensions — Implementation Plan

## Phase 1: GeometryKit ✅ DONE
- [x] Create src/GeometryKit.jl
- [x] Wire into GrugBot420.jl (include, using, exports)
- [x] Add /phaseSpace + /geometry CLI handlers in Main.jl
- [x] Add specimen save/load for geometry_config

## Phase 2: PatternMiner (Operator Genesis)
- [x] Create src/PatternMiner.jl
- [x] Wire PatternMiner.jl into GrugBot420.jl (include, using, exports)
- [x] Add /mineShapes CLI match patterns + handlers in Main.jl
- [x] Add specimen save/load for pattern_miner_config
- [x] Add /mineShapes to HELP_MSG

## Phase 3: TemporalIdentity (Continuants)
- [x] Create src/TemporalIdentity.jl (~250 lines)
- [x] Wire TemporalIdentity.jl into GrugBot420.jl
- [x] Add /identity CLI handlers in Main.jl
- [x] Add specimen save/load for temporal identities
- [x] Add /identity to HELP_MSG

## Phase 4: Structure Sigils (:structure class)
- [ ] Add :structure to SIGIL_CLASSES in SigilRegistry.jl
- [ ] Add /sigil addStructure and /sigil expand CLI handlers in Main.jl
- [ ] Add specimen save/load for structure sigil expansions
- [ ] Add structure sigil commands to HELP_MSG

## Phase 5: Testing
- [ ] Write comprehensive v9 test script
- [ ] Run test and fix any issues
