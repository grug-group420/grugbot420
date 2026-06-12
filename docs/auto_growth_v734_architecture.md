# Auto Growth Architecture — v7.34 Design Discussion

## The Problem

Growth was disabled in v7.33 because `grow_nodes_from_packet` was a flat JSON bulk-insert — every new node landed as a full citizen with full scan participation. At scale this crushes Big O. The scan loop touches every node in the relevant lobe; adding N new nodes per growth cycle means the scan cost grows linearly with population, and unbounded growth means unbounded scan time.

But the system needs growth. Without it the knowledge graph is frozen — what the specimen author wrote is all there is. The question is: **how do you grow without crushing Big O?**

## The Multipart Precedent: Pseudo Non-Linear Node Behavior

Multipart reasoning already solved a version of this problem. The insight was:

> You don't need all nodes to participate in all scans. You need the RIGHT nodes to participate in the RIGHT scans, and you need a cheap way to find them.

InputDecomposer splits "what is 2+2 and what is a cat" into two independent clauses. Each clause gets its own mission with its own SigilMediator bindings. The math clause only activates math sigil nodes; the cat clause only activates nature/language nodes. This is pseudo non-linear — the total work is NOT proportional to the full node population. It's proportional to the RELEVANT subpopulation per clause.

The key mechanisms that make this work:

1. **Clause scoping**: Each decomposed clause has its own objective_id, and votes are stamped with that ID. MultipartOrchestrator groups votes by objective_id, so each group only contains votes from nodes that actually matched the clause.

2. **Per-clause mediation**: SigilMediator runs independently per clause. Math bindings don't bleed into non-math clauses. This prevents the cross-contamination that would otherwise require scanning ALL nodes for ALL clauses.

3. **Sequential lobe orchestration**: LobeOrchestrator doesn't scan all lobes simultaneously. It ranks lobes by topicality, fires the highest first, and only fires additional lobes if they pass a threshold. This is a natural Big O control — most inputs only activate 1-2 lobes, not all 8.

4. **Hard caps**: 1000 active nodes per lobe per turn. 1000 total cross-talk nodes. These are safety valves, not architectural solutions, but they prevent catastrophic blowup.

## Applying the Same Thinking to Growth

The growth problem is structurally similar to the multipart problem:

- **Multipart**: "Don't scan all nodes for all clauses" → solution: clause scoping + per-clause mediation
- **Growth**: "Don't let all grown nodes participate in all scans" → solution: ???

The answer is: **grown nodes should start in a probationary layer with restricted scan participation, and graduate to full citizenship only after earning it through repeated activation.**

### Phase 1: Sprout Layer (Probationary Nodes)

When a growth cycle creates new nodes, they don't go directly into NODE_MAP as full citizens. Instead they go into a **SPROUT_MAP** — a separate dictionary with the same Node structure but a different scan tier.

```
SPROUT_MAP: Dict{String, Node}   # probationary nodes
NODE_MAP:   Dict{String, Node}   # full citizens
```

Sprout nodes have these restrictions:
- They only participate in scans when the TOP VOTE from a full citizen has already matched, AND the sprout's pattern is a more specific version of the same match. This is like the "companion vote" concept from multipart — sprouts ride along with citizens, they don't initiate.
- Their confidence is capped at 0.7x of a full citizen's confidence. They can never out-vote a citizen.
- They don't participate in lobe topicality computation. They're invisible to LobeOrchestrator ranking.
- They don't contribute to chatter, phagy, or idle cycles.

This means adding N sprouts costs O(1) in the main scan — they're not scanned at all unless a citizen already matched in the same lobe.

### Phase 2: Promotion (Graduation to Full Citizen)

A sprout promotes to NODE_MAP when it meets ANY of:

1. **Activation threshold**: The sprout has been activated (rode along with a citizen match) K times (e.g., K=5). Each activation is a "coin flip earned" — the node proved it belongs by being relevant multiple times.
2. **Right feedback**: The user gave /right feedback that explicitly references the sprout's contribution. This is a direct signal — the human confirmed the node was useful.
3. **Strength threshold**: The sprout's strength (from bump_strength! coinflips on activation) crosses a threshold (e.g., strength >= 5.0). This is the organic path — nodes that keep getting stronger through normal use graduate naturally.

Promotion is cheap: move the Node from SPROUT_MAP to NODE_MAP, update node_to_lobe_idx, done. No re-scan, no re-index.

### Phase 3: Growth Trigger (When to Grow)

The old system grew on `/grow` command — manual, human-driven. The new system needs automatic growth with bounded cost:

1. **Co-occurrence growth**: When two nodes in the same lobe are both activated in the same mission, and their patterns share significant token overlap, a sprout is created that covers the intersection. This is the "missing middle" — the gap between two related nodes that should have a bridge.

   Example: Node "photosynthesis" and node "chlorophyll" both fire → sprout "photosynthesis chlorophyll plant green pigment light absorption" is created to cover the overlap.

2. **Thesaurus gap growth**: When the thesaurus expands a user's input and the expansion reveals tokens that don't match any existing node, a sprout is created to cover those tokens. This is the "vocabulary gap" — words the system knows but can't route to any node.

3. **Pattern failure growth**: When a scan produces no matches above threshold in a lobe (NoMatchFoundError), but the lobe's topicality was high, a sprout is created from the mission text itself. This is the "obvious gap" — the user asked something clearly in a lobe's domain but the lobe had no node for it.

All three triggers are bounded:
- Co-occurrence: max N sprouts per mission (e.g., N=3). Not every co-occurrence pair spawns a sprout — only the top-N by overlapping token count.
- Thesaurus gap: max 1 sprout per lobe per mission. The gap is the strongest unmatched token.
- Pattern failure: max 1 sprout per failed lobe per mission. One gap at a time.

### The Big O Argument

**Without sprouts** (old system): Growth adds N nodes to NODE_MAP → scan cost goes from O(|lobe|) to O(|lobe| + N) → unbounded.

**With sprouts**: Growth adds N nodes to SPROUT_MAP → scan cost stays O(|lobe|) because sprouts aren't scanned → growth is O(1) in scan cost. The only additional cost is the "ride-along" check when a citizen already matched: O(1) per matched citizen, not per sprout.

Promotion cost: O(1) per promoted node (just a dict move). The scan cost increases by 1 per promotion, but promotions are earned through repeated activation, which is a natural rate limiter. You can't promote faster than you activate, and activation requires real user input hitting real matches.

**Population cap**: The system already has a 1000-node active cap per lobe. Sprouts don't count toward this cap. Promoted nodes do. So the effective population of NODE_MAP is bounded by 1000 × 8 lobes = 8000. The sprout population is bounded by a separate cap (e.g., 500 sprouts per lobe). Total system capacity: 12000 nodes, but only 8000 participate in the main scan.

## Growth and Polarity

The universal polarity gate (v7.34) now applies to ALL nodes, including sprouts. This means:

- "Don't tell me about X" → polarity NEGATIVE → X sprout is suppressed at 0.3x → X sprout doesn't earn activation → X sprout never promotes → the system naturally rejects unwanted growth.
- "Maybe explain Y" → polarity NEUTRAL → Y sprout attenuated at 0.7x → Y sprout earns partial activation → slower promotion path.
- "Explain Y" → polarity POSITIVE → Y sprout fires at 1.0x → Y sprout earns full activation → faster promotion path.

This is the self-regulating property: **the polarity gate is the immune system for growth.** Unwanted growth (negative polarity) is naturally suppressed. Ambiguous growth (neutral) is naturally slowed. Desired growth (positive) is naturally accelerated. No external filter needed — the same gate that protects existing nodes also protects the growth system from pollution.

## Growth and Phagy

Phagy is the death-side counterpart to growth. The existing PhagyMode already handles:
- Grave node cleanup (dead nodes from strength decay)
- Group organization (clustering related nodes)
- Memory forensics (debugging why nodes died)

The growth system should integrate with phagy:
- A sprout that never activates after T idle cycles should be pruned (removed from SPROUT_MAP). This is the natural death rate for probationary nodes.
- A promoted node that decays back below the promotion threshold should be demoted back to SPROUT_MAP, not killed. Demotion preserves the node's learned strength but removes it from the main scan.
- Co-occurrence growth should check phagy logs to avoid re-creating nodes that were recently pruned. The system should learn from its mistakes — if a sprout was pruned 3 times for the same pattern, stop creating sprouts for that pattern.

## Implementation Sketch

```julia
# engine.jl additions

const SPROUT_MAP = Dict{String, Node}()        # probationary nodes
const SPROUT_LOCK = ReentrantLock()
const SPROUT_ACTIVATION = Dict{String, Int}()   # node_id → activation count
const SPROUT_PROMOTION_THRESHOLD = 5            # activations to graduate
const SPROUT_STRENGTH_THRESHOLD = 5.0           # strength to graduate
const SPROUT_MAX_PER_LOBE = 500                 # cap per lobe
const SPROUT_IDLE_PRUNE_CYCLES = 50             # idle cycles before pruning

function create_sprout(pattern, action_packet, json_data, drop_table; lobe_idx, is_image_node=false)
    # Same as create_node but puts into SPROUT_MAP instead of NODE_MAP
    # Initialize SPROUT_ACTIVATION[id] = 0
    # Does NOT add to node_to_lobe_idx for main scan
end

function activate_sprout!(id)
    # Called when a sprout rides along with a citizen match
    # Increment SPROUT_ACTIVATION[id]
    # Check promotion criteria
    # If promoted: move from SPROUT_MAP to NODE_MAP
end

function sprout_ride_along(citizen_id, lobe_idx, mission_tokens)
    # Called AFTER a citizen node matches in a scan
    # Check SPROUT_MAP for sprouts in the same lobe
    # If a sprout's pattern tokens overlap with mission_tokens, activate it
    # Return Vector of activated sprout IDs (for audit logging)
end

function prune_idle_sprouts!()
    # Called during idle phagy cycles
    # Remove sprouts that haven't activated in SPROUT_IDLE_PRUNE_CYCLES
    # Record pruned patterns in phagy log (to avoid re-creation)
end
```

The `sprout_ride_along` function is the key — it's the pseudo non-linear behavior. Instead of scanning all sprouts for every mission, it only checks sprouts in the same lobe as an already-matched citizen. This is O(|sprouts_in_lobe|) but only when a citizen already matched, not on every mission. And it's bounded by SPROUT_MAX_PER_LOBE.

## Open Questions

1. **Sprout pattern generation**: How should co-occurrence growth synthesize the sprout's pattern? Simple token intersection? LLM-assisted? The pattern needs to be a valid patternscanner pattern — a sequence of tokens that the scanner can match against future inputs.

2. **Ride-along matching criterion**: Should sprout ride-along use the same pattern matching as the main scan (patternscanner), or a cheaper heuristic (token overlap)? The cheaper option is faster but less precise.

3. **Demotion vs. death**: Should decayed promoted nodes be demoted to sprouts or killed outright? Demotion preserves knowledge but adds complexity. Death is simpler but loses learned weights.

4. **Multi-lobe sprouts**: Should a sprout be restricted to a single lobe, or can it span multiple? Single-lobe is simpler and matches the existing lobe_idx model. Multi-lobe would require a different indexing structure.

5. **Growth and sigil nodes**: Should growth ever create sigil nodes? Currently sigil nodes are hand-authored (they need @sigil: tags, bindings, and a fire handler). Auto-growth should probably be restricted to :none (knowledge) nodes only, since sigil nodes require structural knowledge that growth can't synthesize.

6. **RESOLVE integration**: Can RESOLVE be used as a growth trigger? E.g., "check the date" activates the doaction sigil → RESOLVE resolves → the result could seed a sprout about the current date context. This would give growth temporal awareness without time nodes.
