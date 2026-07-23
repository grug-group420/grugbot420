# SemanticVerbs.jl
# ==============================================================================
# !!! GRUG REMINDER — RELATIONAL TRIPLES CAN USE SIGILS !!!
# A RelationalTriple's subject / relation / object may contain sigil tokens
# (&n, &word, &noun, specimen macros). Verb extraction and relation building
# here must NOT assume triple fields are always literal words — sigil holes
# are valid. Resolve via SigilRegistry where appropriate. See SigilRegistry.jl.
# ==============================================================================
# GRUG: This is the living verb cave. User can add new verb rocks at runtime!
# Old static CAUSAL/SPATIAL/TEMPORAL const sets used to be frozen in engine.jl.
# Now they live here, warm and mutable. User can /addVerb, /addRelationClass,
# /addSynonym at any time and the change takes effect on the very next /mission.
# No restart. No recompile. Cave grows with the tribe.
# ==============================================================================

module SemanticVerbs
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.          ║
# ║     If you find yourself writing antimatch code, STOP — you are              ║
# ║     reimplementing a removed feature.                                        ║
# ║                                                                              ║
# ║  2. SIGILS CAN AND DO APPEAR IN RELATIONAL TRIPLES. A triple like           ║
# ║     (&n, is_greater_than, &n) is DYNAMIC — it evaluates at match time        ║
# ║     with sigil-bound values, NOT a fixed string comparison. Relational       ║
# ║     triples are not limited to literal words. Any triple field may            ║
# ║     contain &sigil tokens. Code that consumes triples MUST handle this.      ║
# ║     Forgetting this means you break arithmetic, comparisons, and             ║
# ║     any dynamic relational outcome.                                          ║
# ║                                                                              ║
# ║  3. HOPFIELD CACHING WAS REMOVED. The hopfield_key field on Node is         ║
# ║     a DEAD FIELD — it exists only for specimen save/load round-trip           ║
# ║     compatibility. Do not use it for caching, lookups, or any logic.         ║
# ║     Pattern scanning does NOT use hopfield caching. It was disabled          ║
# ║     ages ago. New code must never depend on hopfield_key.                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝


using Base.Threads: ReentrantLock

export add_verb!, add_relation_class!, add_synonym!, remove_synonym!,
       get_all_verbs, get_verbs_in_class, get_relation_classes,
       normalize_synonyms, get_synonym_map, verb_class_of,
       VERB_REGISTRY_LOCK

# ==============================================================================
# VERB REGISTRY
# GRUG: Three stone tablets at boot. User can carve more tablets and more words.
# _VERB_REGISTRY  : class_name -> Set of verbs in that class
# _VERB_TO_CLASS  : verb -> class_name (reverse map, rebuilt on every mutation)
# _SYNONYM_MAP    : alias -> canonical (normalized before triple extraction)
# ==============================================================================

const _VERB_REGISTRY = Dict{String, Set{String}}(
    "causal"   => Set(["hits", "makes", "causes", "increases", "reduces",
                        "routes", "contradicts"]),
    "spatial"  => Set(["is", "are", "was", "were", "connects"]),
    "temporal" => Set(["chasing", "follows", "precedes"]),
    # GRUG v8.16: Arithmetic verbs — math operation words that appear in
    # user inputs like "what is 5 plus 3" or "7 minus 2". Without these,
    # triple extraction skips math operators and the &arithmetic relation
    # sigil can't gate sigil math nodes properly.
    "arithmetic" => Set(["plus", "minus", "times", "divided", "multiply",
                         "add", "subtract", "over", "mod", "modulo",
                         "power", "equals"])
)

# GRUG: This lock guards ALL three dicts below. One lock, one cave door.
const VERB_REGISTRY_LOCK = ReentrantLock()

# GRUG: Reverse map rebuilt on every write. Read path pays zero allocation cost.
const _VERB_TO_CLASS = Dict{String, String}()

# GRUG: Synonym table. Alias words get swapped for canonical BEFORE triple extraction.
const _SYNONYM_MAP = Dict{String, String}()

# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

# GRUG: Rebuild verb->class reverse map. Always called while holding VERB_REGISTRY_LOCK.
# Never call this without the lock — map will be in partial state otherwise!
function _rebuild_verb_to_class!()
    empty!(_VERB_TO_CLASS)
    for (cls, verbs) in _VERB_REGISTRY
        for v in verbs
            _VERB_TO_CLASS[v] = cls
        end
    end
end

# GRUG: Julia has no built-in Regex.escape. Roll own.
# Escapes all regex metacharacters so user-provided verb strings are safe in patterns.
# Without this, a verb like "a+b" would be treated as regex, not literal text.
function _regex_escape(s::String)::String
    return replace(s, r"([\\^$.|?*+(){}\[\]])" => s"\\\1")
end

# Initialize reverse map on module load
_rebuild_verb_to_class!()

# ==============================================================================
# PUBLIC MUTATION API
# ==============================================================================

"""
    add_relation_class!(class_name::String)

Create a new empty relation class bucket. Subsequent `add_verb!` calls can
then populate it. Warns and no-ops if class already exists (idempotent).
Errors on empty or whitespace-only name.
"""
function add_relation_class!(class_name::String)
    name = strip(lowercase(class_name))

    # GRUG: Empty name is a cave naming error. Scream before touching the registry.
    if isempty(name)
        error("!!! FATAL: Grug cannot add relation class with empty name! !!!")
    end

    lock(VERB_REGISTRY_LOCK) do
        if haskey(_VERB_REGISTRY, name)
            # GRUG: Already exists. Warn and move on. Not a crash.
            @warn "[SEMANTIC] Relation class '$(name)' already exists. No change."
            return
        end
        _VERB_REGISTRY[name] = Set{String}()
        _rebuild_verb_to_class!()
        @info "[SEMANTIC] ✅  New relation class added: '$(name)'"
    end
end

"""
    add_verb!(verb::String, class_name::String)

Add a verb to an existing relation class. The verb is lowercased and stripped
before storage. Warns and no-ops if the verb already exists in that class.
Warns (does not error) if the verb exists in a *different* class (polysemy).
Errors if the class doesn't exist — use `add_relation_class!` first.
"""
function add_verb!(verb::String, class_name::String)
    v   = strip(lowercase(verb))
    cls = strip(lowercase(class_name))

    # GRUG: Validate both args before touching the lock. Fast fail.
    if isempty(v)
        error("!!! FATAL: Grug cannot add empty verb string! !!!")
    end
    if isempty(cls)
        error("!!! FATAL: Grug cannot add verb — class name is empty! !!!")
    end

    lock(VERB_REGISTRY_LOCK) do
        # GRUG: Class must exist. User must create it first with /addRelationClass.
        if !haskey(_VERB_REGISTRY, cls)
            error("!!! FATAL: Relation class '$(cls)' does not exist! " *
                  "Use /addRelationClass '$(cls)' first! !!!")
        end

        # GRUG: Already in this class? Idempotent no-op.
        if v in _VERB_REGISTRY[cls]
            @warn "[SEMANTIC] Verb '$(v)' already in class '$(cls)'. No change."
            return
        end

        # GRUG: In a DIFFERENT class? That is polysemy — unusual but allowed.
        # Warn so the user knows their verb now lives in multiple classes.
        if haskey(_VERB_TO_CLASS, v)
            existing_cls = _VERB_TO_CLASS[v]
            if existing_cls != cls
                @warn "[SEMANTIC] Verb '$(v)' already registered under class " *
                      "'$(existing_cls)'. Adding to '$(cls)' too. " *
                      "Polysemy cave — verb may match multiple relation types."
            end
        end

        push!(_VERB_REGISTRY[cls], v)
        _rebuild_verb_to_class!()
        @info "[SEMANTIC] ✅  Verb '$(v)' added to class '$(cls)'"
    end
end

"""
    add_synonym!(canonical::String, synonym::String)

Register an alias that normalizes to a canonical verb before triple extraction.
Example: `add_synonym!("causes", "triggers")` → every "triggers" in user input
becomes "causes" before the dialectical matcher runs.

Rules:
- Canonical verb must already exist in a registered class.
- Alias cannot equal canonical (pointless rock).
- If alias already maps to a *different* canonical, errors loudly (no silent remap).
- If alias already maps to the same canonical, warns and no-ops (idempotent).
"""
function add_synonym!(canonical::String, synonym::String)
    canon = strip(lowercase(canonical))
    alias = strip(lowercase(synonym))

    # GRUG: Validate both args up front. No lock contention on bad input.
    if isempty(canon)
        error("!!! FATAL: Grug cannot add synonym for empty canonical verb! !!!")
    end
    if isempty(alias)
        error("!!! FATAL: Grug cannot add empty synonym string! !!!")
    end
    if canon == alias
        error("!!! FATAL: Grug refuses synonym identical to canonical — " *
              "'$(canon)' == '$(alias)' is a pointless rock! !!!")
    end

    lock(VERB_REGISTRY_LOCK) do
        # GRUG: Canonical must live in at least one class or the alias points at a ghost.
        if !haskey(_VERB_TO_CLASS, canon)
            error("!!! FATAL: Canonical verb '$(canon)' not found in any relation class! " *
                  "Register it with /addVerb first! !!!")
        end

        if haskey(_SYNONYM_MAP, alias)
            existing = _SYNONYM_MAP[alias]
            if existing == canon
                # GRUG: Already maps to same target. Idempotent no-op.
                @warn "[SEMANTIC] Synonym '$(alias)' -> '$(canon)' already registered. No change."
                return
            else
                # GRUG: Collision — alias points to DIFFERENT canonical. Hard stop.
                # Silent remap would corrupt all existing normalized triples.
                error("!!! FATAL: Synonym '$(alias)' already maps to '$(existing)'. " *
                      "Cannot remap to '$(canon)' without explicit removal! " *
                      "Use remove_synonym!(\"$(alias)\") first! !!!")
            end
        end

        _SYNONYM_MAP[alias] = canon
        @info "[SEMANTIC] ✅  Synonym registered: '$(alias)' -> '$(canon)'"
    end
end

"""
    remove_synonym!(synonym::String)

Remove a registered synonym alias. Safe to call even if alias doesn't exist
(warns and no-ops). Useful when you need to remap an alias to a new canonical.
"""
function remove_synonym!(synonym::String)
    alias = strip(lowercase(synonym))

    if isempty(alias)
        error("!!! FATAL: Grug cannot remove synonym with empty alias string! !!!")
    end

    lock(VERB_REGISTRY_LOCK) do
        if !haskey(_SYNONYM_MAP, alias)
            @warn "[SEMANTIC] Synonym '$(alias)' not found in registry. Nothing to remove."
            return
        end
        old_canon = _SYNONYM_MAP[alias]
        delete!(_SYNONYM_MAP, alias)
        @info "[SEMANTIC] 🗑  Synonym removed: '$(alias)' (was -> '$(old_canon)')"
    end
end

# ==============================================================================
# QUERY API
# ==============================================================================

"""
    get_all_verbs()::Set{String}

Return a flat snapshot of ALL verbs currently registered across all classes.
Reflects any runtime mutations immediately. Thread-safe copy.
"""
function get_all_verbs()::Set{String}
    lock(VERB_REGISTRY_LOCK) do
        result = Set{String}()
        for verbs in values(_VERB_REGISTRY)
            union!(result, verbs)
        end
        return result
    end
end

"""
    get_verbs_in_class(class_name::String)::Set{String}

Return a snapshot of all verbs registered under a specific class.
Errors if the class doesn't exist.
"""
function get_verbs_in_class(class_name::String)::Set{String}
    cls = strip(lowercase(class_name))
    if isempty(cls)
        error("!!! FATAL: get_verbs_in_class got empty class name! !!!")
    end
    lock(VERB_REGISTRY_LOCK) do
        if !haskey(_VERB_REGISTRY, cls)
            error("!!! FATAL: Relation class '$(cls)' not found in verb registry! !!!")
        end
        return copy(_VERB_REGISTRY[cls])
    end
end

"""
    get_relation_classes()::Vector{String}

Return sorted list of all currently registered relation class names.
"""
function get_relation_classes()::Vector{String}
    lock(VERB_REGISTRY_LOCK) do
        return sort(collect(keys(_VERB_REGISTRY)))
    end
end

"""
    get_synonym_map()::Dict{String, String}

Return a copy of the full synonym alias -> canonical mapping table.
"""
function get_synonym_map()::Dict{String, String}
    lock(VERB_REGISTRY_LOCK) do
        return copy(_SYNONYM_MAP)
    end
end

"""
    verb_class_of(verb::String)::Union{String, Nothing}

Return the class name of a registered verb, or `nothing` if not found.
Useful for diagnostics and /listVerbs output.
"""
function verb_class_of(verb::String)::Union{String, Nothing}
    v = strip(lowercase(verb))
    lock(VERB_REGISTRY_LOCK) do
        return get(_VERB_TO_CLASS, v, nothing)
    end
end

# ==============================================================================
# SYNONYM NORMALIZATION
# GRUG: Run this BEFORE rewrite_passive_mission and BEFORE extract_relational_triples.
# Aliases get swapped for canonical forms here. All downstream logic sees clean verbs.
# ==============================================================================

"""
    normalize_synonyms(input::String)::String

Replace all registered synonym aliases in `input` with their canonical verb forms,
using word-boundary regex so partial words are never stomped.
Case-insensitive match. Empty input passes through unchanged (non-fatal).

Example:
```julia
add_synonym!("causes", "triggers")
normalize_synonyms("heat triggers ice_melt")  # => "heat causes ice_melt"
normalize_synonyms("unprecedented events")    # => "unprecedented events" (unchanged)
```
"""
function normalize_synonyms(input::String)::String
    # GRUG: Empty string in, empty string out. Not worth crashing over.
    if isempty(strip(input))
        return input
    end

    # GRUG: Snapshot the synonym map under lock. Never hold lock across string work —
    # string operations can be slow and we don't want to block other threads.
    synonym_snap = lock(VERB_REGISTRY_LOCK) do
        copy(_SYNONYM_MAP)
    end

    # GRUG: No synonyms registered? Skip all the regex work. Fast path.
    if isempty(synonym_snap)
        return input
    end

    result = input
    for (alias, canonical) in synonym_snap
        # GRUG: Escape alias so regex metacharacters in user-defined verbs don't explode.
        # Example: a verb named "a+b" would break Regex without escaping the "+".
        escaped = _regex_escape(alias)

        # GRUG: Word boundary \b ensures "precedes" doesn't match inside "unprecedented".
        # "i" flag = case-insensitive so "Triggers" and "TRIGGERS" both normalize.
        pattern = Regex("\\b$(escaped)\\b", "i")
        result  = replace(result, pattern => canonical)
    end

    return result
end

end # module SemanticVerbs

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: SEMANTIC VERB REGISTRY
#
# 1. MUTABLE LIVE REGISTRY:
# All verb sets are stored in a Dict{String, Set{String}} keyed by class name.
# Unlike static const sets, this registry supports runtime mutation via
# add_verb!, add_relation_class!, and add_synonym!. Changes take effect
# immediately on the next call to normalize_synonyms or get_all_verbs.
#
# 2. REVERSE MAP COHERENCE:
# _VERB_TO_CLASS is a derived structure — it is fully rebuilt from _VERB_REGISTRY
# on every mutation. This keeps the reverse lookup O(1) at read time while
# accepting O(n_verbs) write cost. Since mutations are rare (user CLI commands),
# this tradeoff is always correct. The rebuild is always called under
# VERB_REGISTRY_LOCK to prevent partial-state reads.
#
# 3. SYNONYM NORMALIZATION PIPELINE POSITION:
# normalize_synonyms() must be called as the FIRST transformation on raw user
# input, before rewrite_passive_mission() and before extract_relational_triples().
# This ordering ensures the dialectical matcher never sees alias forms — it only
# ever sees canonical verb strings. Downstream relation weight tables, required
# relation checks, and antimatch logic all key on canonical strings.
#
# 4. WORD BOUNDARY SAFETY:
# Synonym replacement uses \b (word boundary) anchors with case-insensitive
# matching. This prevents partial-word corruption (e.g., replacing "is" inside
# "this" or "precedes" inside "unprecedented"). The _regex_escape helper ensures
# user-defined verb strings containing regex metacharacters are treated as
# literal text, not as regex operators.
#
# 5. LOCK DISCIPLINE:
# VERB_REGISTRY_LOCK guards _VERB_REGISTRY, _VERB_TO_CLASS, and _SYNONYM_MAP
# atomically. normalize_synonyms() snapshots _SYNONYM_MAP under lock and then
# releases before doing string work, minimizing lock hold time. All mutation
# functions hold the lock for the full operation to maintain map coherence.
# ==============================================================================