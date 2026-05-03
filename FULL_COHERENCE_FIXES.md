# Full Coherence Scan and Fixes - Comprehensive Specimen Builder

## Problem Summary

The test script `create_comprehensive_specimen.jl` was completely incoherent with the actual codebase:

1. **Hallucinated function signatures** - Used keyword arguments that don't exist
2. **Missing module prefixes** - Functions not properly qualified
3. **Wrong function names** - `create_node!` instead of `create_node`
4. **Non-existent features** - `relational_patterns=`, `json_data=` parameters don't exist

## What Was Wrong

### 1. create_node() Function Signature
**Test script expected (hallucinated):**
```julia
create_node!(
    "pattern text",
    relational_patterns=[...],
    json_data=Dict(...),
    drop_table=[...],
    action_packet=POS_ACTION_PACKET(...)
)
```

**Actual function signature:**
```julia
create_node(
    pattern::String,
    action_packet::String,
    data::Dict,
    drop_table::Vector{String};
    is_image_node::Bool = false,
    initial_strength::Float64 = 1.0
)::String
```

### 2. Module Prefixes Missing
Functions were called without module prefixes, but Main.jl loads modules with `using`, so they need proper qualification:

**Wrong:**
```julia
create_lobe!("science", "concepts"; node_cap=100)
add_node_to_lobe!(node_id, "science")
add_seed_synonym!("word", ["syn1", "syn2"])
```

**Correct:**
```julia
Lobe.create_lobe!("science", "concepts"; node_cap=100)
Lobe.add_node_to_lobe!(node_id, "science")
Thesaurus.add_seed_synonym!("word", ["syn1", "syn2"])
```

### 3. Engine Functions
Engine functions (`create_node`, `attach_node`, `add_orchestration_rule`) are top-level (not in a module) and are available without prefixes since Main.jl includes engine.jl directly.

## Complete Fixes Applied

### Function → Module Mapping (with correct signatures)

| Function | Module | Correct Signature |
|----------|--------|-------------------|
| `create_lobe!` | Lobe | `Lobe.create_lobe!(id, subject; node_cap=100)` |
| `add_node_to_lobe!` | Lobe | `Lobe.add_node_to_lobe!(node_id, "science")` |
| `connect_lobes!` | Lobe | `Lobe.connect_lobes!("science", "technology")` |
| `create_node` | (top-level) | `create_node(pattern, action_packet_string, data, drop_table; is_image_node=false, initial_strength=1.0)` |
| `attach_node!` | (top-level) | `attach_node!(target_id, attach_id, pattern)` |
| `add_orchestration_rule!` | (top-level) | `add_orchestration_rule!("rule text [prob=0.9]")` |
| `add_seed_synonym!` | Thesaurus | `Thesaurus.add_seed_synonym!("word", ["syn1", "syn2"])` |
| `add_relation_class!` | SemanticVerbs | `SemanticVerbs.add_relation_class!("class")` |
| `add_verb!` | SemanticVerbs | `SemanticVerbs.add_verb!("verb", "class")` |
| `add_synonym!` | SemanticVerbs | `SemanticVerbs.add_synonym!("canon", "synonym")` |

### Action Packet Format

**Important:** `action_packet` parameter must be a **String**, not a POS_ACTION_PACKET object!

**Wrong:**
```julia
action_packet=POS_ACTION_PACKET(["verb1", "verb2"], ["bad"], 0.1)
```

**Correct:**
```julia
"POS_ACTION_PACKET([\"verb1\", \"verb2\"], [\"bad\"], 0.1)"
```

### Node Creation Example (Fixed)

**Before (hallucinated):**
```julia
science_id_1 = create_node!(
    "Quantum mechanics studies subatomic particle behavior",
    json_data=Dict(
        "domain" => "physics",
        "complexity" => "high",
        "requires_math" => true
    ),
    action_packet=POS_ACTION_PACKET(
        ["explain", "describe", "analyze"],
        ["ignore"],
        0.1
    )
)
```

**After (correct):**
```julia
science_id_1 = create_node(
    "Quantum mechanics studies subatomic particle behavior",
    "POS_ACTION_PACKET([\"explain\", \"describe\", \"analyze\"], [\"ignore\"], 0.1)",
    Dict("domain" => "physics", "complexity" => "high", "requires_math" => true),
    String[]
)
```

## Complete Test Script Rewrite

The entire `create_comprehensive_specimen.jl` was rewritten to:
1. Use correct function signatures matching source code
2. Add proper module prefixes (Lobe., Thesaurus., SemanticVerbs.)
3. Use string representations for action packets
4. Use correct parameter order for create_node()
5. Remove all hallucinated features (relational_patterns=, json_data=, etc.)

## Next Steps

The `interact_with_specimen.jl` script also needs the same coherence scan and fixes, likely with similar issues.

## Verification

All function calls now verified against actual source code:
- ✅ Function names match source
- ✅ Module prefixes correct
- ✅ Parameter types correct
- ✅ Parameter order correct
- ✅ Keyword vs positional arguments correct
- ✅ No hallucinated features

## Status

✅ Test script completely rewritten with coherent function calls
✅ All function signatures verified against source code
✅ Ready for commit and push