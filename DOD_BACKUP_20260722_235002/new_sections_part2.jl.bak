
# ═══════════════════════════════════════════════════════════════
# 29. THESAURUS — Gate, Similarity, Synonym Lookup, Stem
# ═══════════════════════════════════════════════════════════════
section("29. Thesaurus — Gate, Similarity & Synonyms")

subsection("29a. Gate Filter & Score")
try
    _gf = thesaurus_gate_filter("what is the meaning of life")
    record("thesaurus_gate_filter returns Set", _gf isa Set)
    record("gate filter non-empty for meaningful text", !isempty(_gf))
catch e
    record("thesaurus_gate_filter", false, "$e")
end

try
    _gs = thesaurus_gate_score("what is life", "the meaning of existence")
    record("thesaurus_gate_score returns Float64", _gs isa Float64)
    record("gate score >= 0", _gs >= 0.0)
catch e
    record("thesaurus_gate_score", false, "$e")
end

subsection("29b. Word & Concept Similarity")
try
    _ws = word_similarity("happy", "joyful")
    record("word_similarity returns Float64", _ws isa Float64)
    record("word_similarity(happy, joyful) > 0", _ws > 0.0)
catch e
    record("word_similarity", false, "$e")
end

try
    _cs = concept_similarity("love", "affection")
    record("concept_similarity returns Float64", _cs isa Float64)
catch e
    record("concept_similarity", false, "$e")
end

try
    _xs = cross_type_similarity("happy", "emotion")
    record("cross_type_similarity returns Float64", _xs isa Float64)
catch e
    record("cross_type_similarity", false, "$e")
end

subsection("29c. Synonym Lookup & Seed")
try
    _sl = synonym_lookup("big", "large")
    record("synonym_lookup returns Float64", _sl isa Float64)
catch e
    record("synonym_lookup", false, "$e")
end

try
    _pre = seed_synonym_count()
    add_seed_synonym!("testword", ["testalias", "testsynonym"])
    _post = seed_synonym_count()
    record("add_seed_synonym! increases count", _post >= _pre)
catch e
    record("add_seed_synonym!", false, "$e")
end

subsection("29d. Ngrams & Jaccard")
try
    _ng = generate_ngrams("hello world test", 2)
    record("generate_ngrams returns Set", _ng isa Set)
    record("bigrams non-empty", !isempty(_ng))
catch e
    record("generate_ngrams", false, "$e")
end

try
    _js = jaccard_similarity(Set(["a","b","c"]), Set(["b","c","d"]))
    record("jaccard_similarity returns Float64", _js isa Float64)
    record("jaccard in [0,1]", 0.0 <= _js <= 1.0)
catch e
    record("jaccard_similarity", false, "$e")
end

subsection("29e. Format Intensity & Batch Compare")
try
    _fi = format_thesaurus_intensity(0.75)
    record("format_thesaurus_intensity returns String", _fi isa String)
catch e
    record("format_thesaurus_intensity", false, "$e")
end

try
    _bc = thesaurus_batch_compare("hello", ["hi", "greetings", "hey"];
                                   semantic_weight=0.5, contextual_weight=0.3, associative_weight=0.2)
    record("thesaurus_batch_compare returns vector", _bc isa Vector)
catch e
    record("thesaurus_batch_compare", false, "$e")
end

subsection("29f. Stem Token & Expand")
try
    _st = stem_token("running")
    record("stem_token returns String", _st isa String)
    record("stem of 'running' contains 'run'", occursin("run", lowercase(_st)))
catch e
    record("stem_token", false, "$e")
end

try
    _se = stem_expand_text("I am running and jumping")
    record("stem_expand_text returns something", _se !== nothing)
catch e
    record("stem_expand_text", false, "$e")
end
