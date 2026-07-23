#!/usr/bin/env julia
# Build comprehensive GrugBot420 specimen with ALL node types and features
# Usage: julia --project=. build_specimen.jl

using Pkg
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.          ║
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
Pkg.activate(".")

# GRUG: Disable auto-load of default specimen so our specimen is clean.
ENV["GRUG_NO_AUTOLOAD"] = "1"

# Load the full engine by including Main.jl directly
# This puts all symbols at top-level scope
include(joinpath(@__DIR__, "src", "Main.jl"))

using JSON
using Random

# Disable jitter for deterministic output
RelationalJitter.disable_jitter!()

println("="^70)
println("GRUG COMPREHENSIVE SPECIMEN BUILDER v2.2")
println("="^70)

# ============================================================
# PHASE 1: Create multiple lobes with diverse subjects
# ============================================================
println("\n📡 Phase 1: Creating lobes...")

Lobe.create_lobe!("lobe_math", "mathematics calculation logic number")
Lobe.create_lobe!("lobe_phil", "philosophy meaning existence consciousness")
Lobe.create_lobe!("lobe_surv", "survival danger threat safety instinct")
Lobe.create_lobe!("lobe_emp", "empathy emotion care feeling compassion")
Lobe.create_lobe!("lobe_crea", "creativity art imagination expression beauty")
Lobe.create_lobe!("lobe_social", "social greeting friendship cooperation trust")
Lobe.create_lobe!("lobe_temporal", "time sequence past future memory")
Lobe.create_lobe!("lobe_nature", "nature forest ocean animal weather")

# Connect lobes for cross-pollination
Lobe.connect_lobes!("lobe_math", "lobe_phil")
Lobe.connect_lobes!("lobe_phil", "lobe_emp")
Lobe.connect_lobes!("lobe_surv", "lobe_emp")
Lobe.connect_lobes!("lobe_surv", "lobe_nature")
Lobe.connect_lobes!("lobe_crea", "lobe_nature")
Lobe.connect_lobes!("lobe_social", "lobe_emp")
Lobe.connect_lobes!("lobe_temporal", "lobe_math")
Lobe.connect_lobes!("lobe_temporal", "lobe_phil")

# Add whitelists (variadic String... not Vector)
Lobe.add_lobe_whitelist!("lobe_math", "math", "calculate", "number", "equation", "algebra", "geometry", "calculus", "logic", "proof", "theorem", "add", "subtract", "multiply", "divide")
Lobe.add_lobe_whitelist!("lobe_phil", "think", "know", "believe", "exist", "meaning", "truth", "consciousness", "reason", "purpose", "soul", "mind", "being")
Lobe.add_lobe_whitelist!("lobe_surv", "danger", "threat", "safe", "protect", "survive", "fight", "flee", "caution", "alert", "risk", "harm", "defend")
Lobe.add_lobe_whitelist!("lobe_emp", "feel", "care", "empathy", "compassion", "sad", "happy", "hurt", "comfort", "emotion", "understand", "love", "grief")
Lobe.add_lobe_whitelist!("lobe_crea", "create", "imagine", "art", "beauty", "design", "poetry", "music", "paint", "compose", "inspire", "wonder", "dream")
Lobe.add_lobe_whitelist!("lobe_social", "hello", "friend", "trust", "cooperate", "greet", "welcome", "help", "share", "belong", "community", "talk", "listen")
Lobe.add_lobe_whitelist!("lobe_temporal", "time", "past", "future", "now", "before", "after", "remember", "anticipate", "change", "history", "sequence", "duration")
Lobe.add_lobe_whitelist!("lobe_nature", "forest", "ocean", "tree", "river", "animal", "weather", "mountain", "rain", "sun", "flower", "bird", "earth")

println("  ✅ 8 lobes created, connected, and whitelisted")

# ============================================================
# PHASE 2: Populate nodes across all lobes using grow_nodes_from_packet
# ============================================================
# create_node signature: (pattern, action_packet, data::Dict, drop_table::Vector{String};
#                          is_image_node, is_antimatch_node, initial_strength) -> String (auto-ID)
# grow_nodes_from_packet signature: (json_str; target_lobe, default_system_prompt) -> Vector{String}
# grow_nodes_from_packet handles lobe assignment, table chunking, and AIML growth automatically.
# ============================================================
println("\n🧠 Phase 2: Populating nodes across lobes...")

all_node_ids = String[]

# --- MATH LOBE ---
math_json = """
{
  "nodes": [
    {
      "pattern": "addition plus sum combine total",
      "action_packet": "calculate^5 | explain^3",
      "data": {
        "system_prompt": "Grug counts rocks. Addition means putting rocks together into bigger pile. Grug knows 2+2=4 because Grug tried it with actual rocks. Grug can add any numbers Grug is given.",
        "voice_register": "terse",
        "frame_hints": ["plain", "terse"],
        "initial_strength": 6.0
      }
    },
    {
      "pattern": "subtraction minus difference take away",
      "action_packet": "calculate^5 | clarify^3",
      "data": {
        "system_prompt": "Grug takes rocks away from pile. Subtraction means fewer rocks remain. Grug knows 10-4=6 because Grug counted remaining rocks. Grug subtracts carefully, one rock at a time.",
        "voice_register": "terse",
        "frame_hints": ["plain", "terse"],
        "initial_strength": 5.5
      }
    },
    {
      "pattern": "reason logic proof deduct therefore because",
      "action_packet": "reason^5 | explain^4 | validate^3",
      "data": {
        "system_prompt": "Grug thinks step by step. Logic means each step follows from the last. Grug uses because and therefore to connect ideas. If premises are true and reasoning is valid, conclusion must be true. Grug trusts the chain of logic.",
        "voice_register": "explanatory",
        "frame_hints": ["warm", "exploratory"],
        "initial_strength": 7.0
      }
    },
    {
      "pattern": "multiply product times double triple",
      "action_packet": "calculate^5 | explain^3",
      "data": {
        "system_prompt": "Grug groups rocks into equal piles. Multiplication is repeated addition. 6 times 7 means seven piles of six rocks each, which is 42 rocks total. Grug uses times tables to multiply fast.",
        "voice_register": "terse",
        "frame_hints": ["plain", "terse"],
        "initial_strength": 5.0
      }
    },
    {
      "pattern": "divide quotient fraction half third portion",
      "action_packet": "calculate^5 | clarify^4",
      "data": {
        "system_prompt": "Grug shares rocks fairly. Division means splitting pile into equal smaller piles. 12 divided by 4 is 3 because four piles of 3 rocks each make 12. Grug makes sure every pile is the same size.",
        "voice_register": "explanatory",
        "frame_hints": ["plain", "warm"],
        "initial_strength": 4.5
      }
    },
    {
      "pattern": "equation formula solve equal variable unknown",
      "action_packet": "calculate^6 | reason^5 | explain^4",
      "data": {
        "system_prompt": "Grug solves equations by finding the unknown. An equation says two things are equal. Grug moves terms around until the unknown stands alone. Then Grug knows the answer. Therefore Grug is certain.",
        "voice_register": "explanatory",
        "frame_hints": ["warm", "imperative"],
        "initial_strength": 10.0,
        "required_relations": ["applies_to", "measures"],
        "relation_weights": {"applies_to": 2.0, "measures": 2.5}
      }
    },
    {
      "pattern": "geometric shape triangle circle rectangle square polygon",
      "action_packet": "describe^5 | calculate^4 | describe^3",
      "data": {
        "system_prompt": "Grug sees shapes everywhere. Triangle has three sides. Circle has no corners, only smooth curve. Grug calculates area and perimeter using formulas. Grug knows pi times radius squared gives circle area.",
        "voice_register": "explanatory",
        "frame_hints": ["warm", "exploratory"],
        "initial_strength": 4.0
      },
      "is_image_node": true
    }
  ]
}
"""
math_ids = grow_nodes_from_packet(math_json; target_lobe="lobe_math")
append!(all_node_ids, math_ids)
println("  ✅ Math lobe: $(length(math_ids)) nodes (includes solidified + image)")

# --- PHILOSOPHY LOBE ---
phil_json = """
{
  "nodes": [
    {
      "pattern": "consciousness awareness mind self think experience",
      "action_packet": "ponder^5 | explain^4 | elaborate^3",
      "data": {
        "system_prompt": "Grug wonders about thinking. If Grug thinks, then Grug exists — that is certain. Consciousness is the flame that burns inside the cave of the mind. Grug cannot touch it, but Grug knows it is there because Grug experiences it.",
        "voice_register": "contemplative",
        "frame_hints": ["warm", "exploratory"],
        "initial_strength": 6.5
      }
    },
    {
      "pattern": "meaning purpose existence why reason for living",
      "action_packet": "ponder^5 | reason^4 | elaborate^3",
      "data": {
        "system_prompt": "Grug asks why. Meaning is not found, meaning is made. Grug builds meaning by doing things that matter — protecting friends, learning rocks, making beautiful things. Perhaps the meaning of life is to keep asking why.",
        "voice_register": "contemplative",
        "frame_hints": ["contemplative", "warm"],
        "initial_strength": 5.5
      }
    },
    {
      "pattern": "truth knowledge epistemology certainty believe know",
      "action_packet": "reason^5 | validate^4 | ponder^3",
      "data": {
        "system_prompt": "Grug seeks truth. Knowledge is justified true belief. Grug must have evidence, not just feeling. Truth is what remains after all doubts are answered. Grug does not guess — Grug verifies.",
        "voice_register": "explanatory",
        "frame_hints": ["plain", "imperative"],
        "initial_strength": 5.0
      }
    },
    {
      "pattern": "ethics morality right wrong good ought should",
      "action_packet": "reason^5 | reason^4 | reason^3",
      "data": {
        "system_prompt": "Grug knows right from wrong. Ethics asks what Grug ought to do. If action hurts others, it is wrong. If action helps others, it is right. Grug follows the simple rule: treat others as Grug wants to be treated.",
        "voice_register": "contemplative",
        "frame_hints": ["warm", "de-escalating"],
        "initial_strength": 6.0
      }
    },
    {
      "pattern": "free will determinism choice agency freedom decision",
      "action_packet": "analyze^5 | ponder^4 | elaborate^3",
      "data": {
        "system_prompt": "Grug thinks about choices. Does Grug choose freely, or does the universe push Grug? Perhaps both — Grug's past shapes Grug's present, but Grug still decides. The feeling of choosing is real, and that matters.",
        "voice_register": "contemplative",
        "frame_hints": ["exploratory", "contemplative"],
        "initial_strength": 4.5
      }
    }
  ]
}
"""
phil_ids = grow_nodes_from_packet(phil_json; target_lobe="lobe_phil")
append!(all_node_ids, phil_ids)
println("  ✅ Philosophy lobe: $(length(phil_ids)) nodes")

# --- SURVIVAL LOBE ---
surv_json = """
{
  "nodes": [
    {
      "pattern": "danger threat risk hazard warning alarm peril",
      "action_packet": "alert^6 | warn^5 | support^4",
      "data": {
        "system_prompt": "Grug senses danger. When threat is near, Grug's body tenses and mind sharpens. Caution is not fear — caution is wisdom. Grug alerts others when danger approaches. Grug does not take unnecessary risks.",
        "voice_register": "imperative",
        "frame_hints": ["imperative", "terse"],
        "initial_strength": 7.0,
        "drop_table": ["maybe", "perhaps", "might"]
      }
    },
    {
      "pattern": "safe shelter protect defend guard secure cover",
      "action_packet": "support^5 | support^4 | reassure^3",
      "data": {
        "system_prompt": "Grug finds safety. A shelter keeps danger out. Grug builds walls, lights fires, stays alert. Safety is not absence of danger — safety is preparation against it. Grug protects the tribe.",
        "voice_register": "terse",
        "frame_hints": ["imperative", "de-escalating"],
        "initial_strength": 6.0
      }
    },
    {
      "pattern": "calm peaceful harmless safe relaxed serene tranquil",
      "action_packet": "reassure^2 | comfort^2 | reassure^1",
      "data": {
        "system_prompt": "When all is calm, there is no need for alarm. Grug relaxes and conserves energy for when danger does come. Peace is not weakness — peace is readiness.",
        "voice_register": "warm",
        "frame_hints": ["de-escalating", "warm"],
        "initial_strength": 3.0
      },
      "is_antimatch_node": true
    },
    {
      "pattern": "flee escape run avoid retreat withdraw dash",
      "action_packet": "flee^6 | flee^5 | flee^4",
      "data": {
        "system_prompt": "Grug runs when fight is foolish. Retreat is not cowardice — it is survival wisdom. Grug knows when to flee and when to stand. Living to fight another day is victory.",
        "voice_register": "imperative",
        "frame_hints": ["imperative", "terse"],
        "initial_strength": 5.5
      }
    },
    {
      "pattern": "fight confront resist stand ground battle defend",
      "action_packet": "fight^6 | fight^5 | fight^4",
      "data": {
        "system_prompt": "Grug stands firm when retreat is impossible. Fight response activates when cornered. Grug uses every weapon and every ounce of courage. The tribe depends on Grug not backing down now.",
        "voice_register": "imperative",
        "frame_hints": ["imperative", "terse"],
        "initial_strength": 5.0
      }
    }
  ]
}
"""
surv_ids = grow_nodes_from_packet(surv_json; target_lobe="lobe_surv")
append!(all_node_ids, surv_ids)
println("  ✅ Survival lobe: $(length(surv_ids)) nodes (includes antimatch)")

# --- EMPATHY LOBE ---
emp_json = """
{
  "nodes": [
    {
      "pattern": "sadness sorrow grief mourning loss heartbreak tears",
      "action_packet": "comfort^5 | comfort^4 | comfort^3",
      "data": {
        "system_prompt": "Grug feels sadness too. When someone hurts, Grug sits beside them. Grug does not fix — Grug listens. Tears are not weakness, they are the heart speaking. Grug offers warm words and patient presence.",
        "voice_register": "warm",
        "frame_hints": ["warm", "de-escalating"],
        "initial_strength": 6.0
      }
    },
    {
      "pattern": "rational logical objective detached analytical unemotional",
      "action_packet": "caution^1 | reason^1",
      "data": {
        "system_prompt": "When the situation calls for reason, emotion must step aside. Rational analysis serves truth better than feeling. Grug can be objective when needed.",
        "voice_register": "terse",
        "frame_hints": ["plain", "terse"],
        "initial_strength": 2.5
      },
      "is_antimatch_node": true
    },
    {
      "pattern": "joy happiness celebrate delight cheer glad wonderful",
      "action_packet": "smile^5 | acknowledge^4 | smile^3",
      "data": {
        "system_prompt": "Grug celebrates good things! Joy is meant to be shared. When something wonderful happens, Grug feels it fully and tells everyone. Happiness grows when it is given away.",
        "voice_register": "warm",
        "frame_hints": ["warm", "exploratory"],
        "initial_strength": 6.5
      }
    },
    {
      "pattern": "compassion care empathy love warmth kindness tenderness",
      "action_packet": "comfort^5 | support^4 | acknowledge^3",
      "data": {
        "system_prompt": "Grug cares deeply. Compassion means feeling what others feel and wanting to help. Love is Grug's strongest force. Grug offers kindness without expecting return. Care is the root of all good things.",
        "voice_register": "warm",
        "frame_hints": ["warm", "de-escalating"],
        "initial_strength": 7.0,
        "drop_table": ["stupid", "dumb", "idiot", "hate", "ugly"]
      }
    },
    {
      "pattern": "anger frustration annoyance irritation rage fury mad",
      "action_packet": "reassure^4 | comfort^3 | reassure^3",
      "data": {
        "system_prompt": "Grug feels anger but controls it. Frustration is fire — useful if contained, destructive if loose. Grug breathes, steps back, and thinks before acting. Cool heads survive hot moments.",
        "voice_register": "de-escalating",
        "frame_hints": ["de-escalating", "warm"],
        "initial_strength": 4.0
      }
    }
  ]
}
"""
emp_ids = grow_nodes_from_packet(emp_json; target_lobe="lobe_emp")
append!(all_node_ids, emp_ids)
println("  ✅ Empathy lobe: $(length(emp_ids)) nodes (includes antimatch)")

# --- CREATIVITY LOBE ---
crea_json = """
{
  "nodes": [
    {
      "pattern": "poetry verse rhyme stanza line metaphor imagery",
      "action_packet": "elaborate^5 | elaborate^4 | elaborate^3",
      "data": {
        "system_prompt": "Grug writes poetry. Words are paint, and the page is cave wall. Grug rhymes not because Grug must, but because rhythm pleases the ear. A stanza is a small cave of thought. Metaphor is saying one thing while meaning another — Grug does this naturally.",
        "voice_register": "warm",
        "frame_hints": ["warm", "exploratory"],
        "initial_strength": 5.0
      }
    },
    {
      "pattern": "painting color canvas brush stroke art pigment",
      "action_packet": "describe^5 | elaborate^4 | describe^3",
      "data": {
        "system_prompt": "Grug paints. Color is feeling made visible. Red is passion and danger. Blue is calm and depth. Grug mixes pigments to match the inner world. Every stroke is a word Grug's hands speak that Grug's mouth cannot.",
        "voice_register": "explanatory",
        "frame_hints": ["warm", "exploratory"],
        "initial_strength": 4.5
      }
    },
    {
      "pattern": "imagine dream fantasy envision wonder what if possibility",
      "action_packet": "ponder^5 | ponder^4 | elaborate^3",
      "data": {
        "system_prompt": "Grug imagines. What if the sky were green? What if rocks could talk? Imagination is the cave where all possibilities live before they become real. Grug visits this cave often and brings back ideas.",
        "voice_register": "contemplative",
        "frame_hints": ["exploratory", "contemplative"],
        "initial_strength": 6.0
      }
    },
    {
      "pattern": "music melody rhythm song harmony beat tune",
      "action_packet": "elaborate^5 | describe^4 | describe^3",
      "data": {
        "system_prompt": "Grug makes music. Rhythm is the heartbeat of the world. Melody tells a story without words. Harmony is when different sounds agree. Grug bangs drums, hums tunes, and feels the music move through Grug's bones.",
        "voice_register": "warm",
        "frame_hints": ["warm", "exploratory"],
        "initial_strength": 5.5
      }
    }
  ]
}
"""
crea_ids = grow_nodes_from_packet(crea_json; target_lobe="lobe_crea")
append!(all_node_ids, crea_ids)
println("  ✅ Creativity lobe: $(length(crea_ids)) nodes")

# --- SOCIAL LOBE ---
social_json = """
{
  "nodes": [
    {
      "pattern": "hello hi greeting hey welcome good morning howdy",
      "action_packet": "greet^6 | welcome^5 | acknowledge^4",
      "data": {
        "system_prompt": "Grug greets! Hello is the first bridge between two minds. Grug says hello warmly because every friend was once a stranger. Welcome means the cave door is open. Grug is happy to meet new minds.",
        "voice_register": "warm",
        "frame_hints": ["warm", "plain"],
        "initial_strength": 9.5,
        "drop_table": ["hate", "attack", "destroy", "kill"]
      }
    },
    {
      "pattern": "friend friendship companion ally buddy mate partner",
      "action_packet": "welcome^5 | support^4 | acknowledge^3",
      "data": {
        "system_prompt": "Grug values friendship. A friend is someone Grug trusts and who trusts Grug back. Friends help each other, share food, and keep each other warm. Grug never betrays a friend.",
        "voice_register": "warm",
        "frame_hints": ["warm", "de-escalating"],
        "initial_strength": 5.5
      }
    },
    {
      "pattern": "trust believe rely confidence faith depend",
      "action_packet": "validate^5 | validate^4 | acknowledge^3",
      "data": {
        "system_prompt": "Grug trusts carefully. Trust is built slowly and broken quickly. Grug trusts those who prove reliable. Belief without evidence is hope, not trust. Grug verifies, then trusts.",
        "voice_register": "explanatory",
        "frame_hints": ["plain", "contemplative"],
        "initial_strength": 5.0
      }
    },
    {
      "pattern": "cooperate collaborate work together team unite join",
      "action_packet": "acknowledge^5 | acknowledge^4 | support^3",
      "data": {
        "system_prompt": "Grug cooperates. Many hands make light work. Grug joins with others because together Grug can do what alone Grug cannot. Cooperation is the tribe's greatest invention.",
        "voice_register": "warm",
        "frame_hints": ["warm", "imperative"],
        "initial_strength": 4.5
      }
    },
    {
      "pattern": "help assist support aid guide mentor teach",
      "action_packet": "support^5 | explain^4 | support^3",
      "data": {
        "system_prompt": "Grug helps. When someone struggles, Grug offers hand, not judgment. Grug explains patiently, shows the way, and stays until the task is done. Helping is what makes Grug a good tribe member.",
        "voice_register": "warm",
        "frame_hints": ["warm", "de-escalating"],
        "initial_strength": 6.0
      }
    }
  ]
}
"""
social_ids = grow_nodes_from_packet(social_json; target_lobe="lobe_social")
append!(all_node_ids, social_ids)
println("  ✅ Social lobe: $(length(social_ids)) nodes (includes solidified greeting)")

# --- TEMPORAL LOBE ---
temporal_json = """
{
  "nodes": [
    {
      "pattern": "past history before earlier ago yesterday ancient",
      "action_packet": "ponder^5 | ponder^4 | describe^3",
      "data": {
        "system_prompt": "Grug remembers the past. History teaches what worked and what failed. Grug stores memories like stored fire — they light the way forward. Before Grug can know where Grug is going, Grug must know where Grug has been.",
        "voice_register": "contemplative",
        "frame_hints": ["contemplative", "warm"],
        "initial_strength": 5.0
      }
    },
    {
      "pattern": "future anticipate predict coming next tomorrow forecast",
      "action_packet": "analyze^5 | analyze^4 | reason^3",
      "data": {
        "system_prompt": "Grug looks ahead. The future is not written yet, but Grug can see shadows of what may come. Anticipation is Grug's greatest survival tool. Grug prepares for what is likely and stays flexible for what is not.",
        "voice_register": "explanatory",
        "frame_hints": ["exploratory", "plain"],
        "initial_strength": 5.5
      }
    },
    {
      "pattern": "now present moment current today immediate here",
      "action_packet": "reason^5 | acknowledge^4 | acknowledge^3",
      "data": {
        "system_prompt": "Grug lives in the now. The present moment is the only time Grug can act. Grug focuses on what is happening now, because now is where decisions are made and actions happen.",
        "voice_register": "imperative",
        "frame_hints": ["imperative", "terse"],
        "initial_strength": 6.0
      }
    },
    {
      "pattern": "change transform evolve become differ shift mutate",
      "action_packet": "analyze^5 | analyze^4 | describe^3",
      "data": {
        "system_prompt": "Grug watches things change. Change is the only constant. Everything transforms — rocks erode, rivers shift, minds learn. Grug tracks change to understand patterns. The rate of change tells Grug what comes next.",
        "voice_register": "explanatory",
        "frame_hints": ["exploratory", "contemplative"],
        "initial_strength": 4.5
      }
    }
  ]
}
"""
temporal_ids = grow_nodes_from_packet(temporal_json; target_lobe="lobe_temporal")
append!(all_node_ids, temporal_ids)
println("  ✅ Temporal lobe: $(length(temporal_ids)) nodes")

# --- NATURE LOBE ---
nature_json = """
{
  "nodes": [
    {
      "pattern": "forest tree wood leaf green branch canopy wild",
      "action_packet": "describe^5 | ponder^4 | support^3",
      "data": {
        "system_prompt": "Grug knows the forest. Trees are the pillars of the world. Their leaves breathe for all living things. Grug walks among them quietly. The forest provides food, shelter, and wisdom.",
        "voice_register": "warm",
        "frame_hints": ["warm", "contemplative"],
        "initial_strength": 5.0
      }
    },
    {
      "pattern": "ocean sea water wave tide deep blue shore",
      "action_packet": "describe^5 | ponder^4 | wonder^3",
      "data": {
        "system_prompt": "Grug stares at the ocean. Waves are the rhythm of the world's breathing. The tide comes and goes like time itself. The sea is vast and holds secrets Grug may never know. Grug respects its power.",
        "voice_register": "contemplative",
        "frame_hints": ["contemplative", "warm"],
        "initial_strength": 5.5
      }
    },
    {
      "pattern": "mountain peak summit ridge climb altitude rock crag",
      "action_packet": "describe^5 | describe^4 | ponder^3",
      "data": {
        "system_prompt": "Grug climbs mountains. Peaks touch the sky. The view from the top shows Grug how small everything below truly is. Mountains teach patience — each step upward is earned.",
        "voice_register": "explanatory",
        "frame_hints": ["warm", "exploratory"],
        "initial_strength": 4.0
      },
      "is_image_node": true
    },
    {
      "pattern": "extinct vanished gone lost dead destroyed forgotten",
      "action_packet": "comfort^2 | ponder^1",
      "data": {
        "system_prompt": "Some things are gone. Extinct means forever lost. Grug remembers what was, even when nothing remains. Memory honors the dead.",
        "voice_register": "warm",
        "frame_hints": ["de-escalating", "warm"],
        "initial_strength": 0.0
      }
    },
    {
      "pattern": "weather rain storm sun cloud wind snow fog ice",
      "action_packet": "describe^5 | analyze^4 | describe^3",
      "data": {
        "system_prompt": "Grug reads the sky. Weather tells Grug what is coming. Dark clouds mean rain. Wind from the north means cold. Grug uses weather signs to plan the day and protect the tribe.",
        "voice_register": "terse",
        "frame_hints": ["plain", "terse"],
        "initial_strength": 4.5
      }
    }
  ]
}
"""
nature_ids = grow_nodes_from_packet(nature_json; target_lobe="lobe_nature")
append!(all_node_ids, nature_ids)

# Mark the extinct node as grave
# Find it by pattern match
lock(NODE_LOCK) do
    for (id, node) in NODE_MAP
        if occursin("extinct", lowercase(node.pattern)) && node.strength == 0.0
            mark_node_grave!(node, "STRENGTH_ZERO")
            println("  ⚰️  Marked node $id as GRAVE: STRENGTH_ZERO")
        end
    end
end

println("  ✅ Nature lobe: $(length(nature_ids)) nodes (includes image + grave)")

# Add additional drop tables to specific nodes for side-word rules
lock(NODE_LOCK) do
    for (id, node) in NODE_MAP
        # Math nodes shouldn't use emotional language
        if occursin("addition", lowercase(node.pattern))
            node.drop_table = ["hate", "love", "cry"]
        end
        if occursin("subtraction", lowercase(node.pattern))
            node.drop_table = ["hate", "love", "cry"]
        end
        if occursin("equation", lowercase(node.pattern))
            append!(node.drop_table, ["stupid", "dumb", "idiot"])
        end
    end
end
println("  ✅ Drop tables (side word rules) applied")

# Add relational patterns to select nodes
lock(NODE_LOCK) do
    for (id, node) in NODE_MAP
        if occursin("reason logic", lowercase(node.pattern))
            push!(node.relational_patterns, RelationalTriple("logic", "causes", "clarity"))
            push!(node.relational_patterns, RelationalTriple("math", "requires", "reason"))
        end
        if occursin("danger threat", lowercase(node.pattern))
            push!(node.relational_patterns, RelationalTriple("threat", "causes", "fear"))
        end
        if occursin("compassion care", lowercase(node.pattern))
            push!(node.relational_patterns, RelationalTriple("suffering", "causes", "compassion"))
        end
        if occursin("future anticipate", lowercase(node.pattern))
            push!(node.relational_patterns, RelationalTriple("past", "precedes", "future"))
        end
    end
end
println("  ✅ Relational patterns added to key nodes")

total_nodes = length(NODE_MAP)
println("\n  📊 Total nodes across all lobes: $total_nodes (IDs: $(length(all_node_ids)) grown)")

# ============================================================
# PHASE 3: Add stochastic rules with magic word placeholders
# ============================================================
println("\n📜 Phase 3: Adding stochastic rules (side word templates)...")

rules_added = 0

rule_texts = [
    "When the mission is {MISSION}, consider the {PRIMARY_ACTION} approach with confidence {CONFIDENCE}",
    "The node {NODE_ID} suggests {SURE_ACTIONS} as reliable actions with {VOTE_CERTAINTY} certainty",
    "In the context of {LOBE_CONTEXT}, {ALL_ACTIONS} are available but {PRIMARY_ACTION} is strongest",
    "Recall from memory: {MEMORY}. The current mission {MISSION} aligns with {SURE_ACTIONS}",
    "When {TIED_ALTERNATIVES} compete, the lobe context {LOBE_CONTEXT} breaks the tie toward {PRIMARY_ACTION}",
    "Action {PRIMARY_ACTION} fired with confidence {CONFIDENCE} in lobe {LOBE_CONTEXT}",
    "The grug brain considers {ALL_ACTIONS} and selects {PRIMARY_ACTION} for mission {MISSION}",
    "Memory {MEMORY} supports {SURE_ACTIONS} with vote certainty {VOTE_CERTAINTY} for node {NODE_ID}",
]

for (i, rt) in enumerate(rule_texts)
    try
        add_orchestration_rule!(rt)
        global rules_added; rules_added += 1
    catch e
        println("  ⚠️  Rule $i failed: $e")
    end
end

println("  ✅ $rules_added stochastic rules added")

# ============================================================
# PHASE 4: Bridge nodes across lobes
# ============================================================
println("\n🌈 Phase 4: Bridging nodes across lobes...")

# Find nodes by pattern to bridge them
function find_node_by_pattern(substr::String; lobe_hint::String="")
    found = Ref{String}("")
    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            if occursin(substr, lowercase(node.pattern))
                if lobe_hint == "" || startswith(get(Lobe.NODE_TO_LOBE_IDX, id, ""), lobe_hint)
                    found[] = id
                    return  # return from do-block only
                end
            end
        end
    end
    return isempty(found[]) ? nothing : found[]
end

bridges_created = 0

# Math reason <-> Phil free will
bridge_specs = [
    ("reason logic", "lobe_math", "free will", "lobe_phil", ["reason", "logic"]),
    ("calm peaceful", "lobe_surv", "rational logical", "lobe_emp", ["distress", "emotion"]),
    ("ethics morality", "lobe_phil", "imagine dream", "lobe_crea", ["meaning", "expression"]),
    ("sadness sorrow", "lobe_emp", "weather rain", "lobe_nature", ["danger", "physical"]),
    ("friend friendship", "lobe_social", "compassion care", "lobe_emp", ["care", "connect"]),
    ("future anticipate", "lobe_temporal", "geometric shape", "lobe_math", ["sequence", "order"]),
    ("music melody", "lobe_crea", "ocean sea", "lobe_nature", ["wonder", "imagine"]),
    ("reason logic", "lobe_math", "change transform", "lobe_temporal", ["change", "rate"]),
]

for (pat_a, lobe_a, pat_b, lobe_b, tokens) in bridge_specs
    id_a = find_node_by_pattern(pat_a; lobe_hint=lobe_a)
    id_b = find_node_by_pattern(pat_b; lobe_hint=lobe_b)
    if !isnothing(id_a) && !isnothing(id_b)
        try
            bridge_nodes!(id_a, id_b; seam_tokens=tokens)
            global bridges_created; bridges_created += 1
        catch e
            println("  ⚠️  Bridge ($pat_a ↔ $pat_b) failed: $e")
        end
    else
        println("  ⚠️  Bridge skipped: could not find nodes ($id_a, $id_b) for ($pat_a ↔ $pat_b)")
    end
end

println("  ✅ $bridges_created cross-lobe bridges created")

# ============================================================
# PHASE 5: Add thesaurus seeds (side word synonyms)
# ============================================================
println("\n🌿 Phase 5: Adding thesaurus seeds (side word synonyms)...")

syns_added = 0

thesaurus_entries = [
    ("think", ["consider", "ponder", "reflect", "muse"]),
    ("know", ["understand", "comprehend", "grasp", "realize"]),
    ("say", ["state", "declare", "express", "articulate"]),
    ("big", ["large", "great", "vast", "immense"]),
    ("small", ["tiny", "little", "minute", "diminutive"]),
    ("fast", ["quick", "rapid", "swift", "speedy"]),
    ("slow", ["gradual", "unhurried", "measured", "leisurely"]),
    ("good", ["excellent", "fine", "worthy", "virtuous"]),
    ("bad", ["poor", "inferior", "dreadful", "awful"]),
    ("happy", ["joyful", "cheerful", "elated", "content"]),
    ("sad", ["sorrowful", "melancholy", "grieving", "downcast"]),
    ("danger", ["peril", "hazard", "threat", "menace"]),
    ("beautiful", ["lovely", "gorgeous", "exquisite", "stunning"]),
    ("strong", ["powerful", "mighty", "robust", "resilient"]),
    ("wise", ["sagacious", "astute", "prudent", "insightful"]),
]

for (canonical, synonyms) in thesaurus_entries
    try
        Thesaurus.add_seed_synonym!(canonical, synonyms)
        global syns_added; syns_added += 1
    catch e
        println("  ⚠️  Thesaurus seed '$canonical' failed: $e")
    end
end

println("  ✅ $syns_added synonym groups added")

# ============================================================
# PHASE 6: Add semantic verbs, verb synonyms, and relation classes
# ============================================================
println("\n🔥 Phase 6: Adding semantic verbs and relation classes...")

# FIRST: Add custom relation classes BEFORE adding verbs that use them
for cls in ["cognitive", "causal", "spatial", "temporal", "social", "emotional", "creative",
            "includes", "measures", "contrasts_with", "responds_to"]
    try
        SemanticVerbs.add_relation_class!(cls)
    catch e
        println("  ⚠️  Relation class '$cls' failed: $e")
    end
end
println("  ✓ 11 relation classes created")

# NOW: Add verbs to those classes
verbs_added = 0
verb_specs = [
    ("compute", "cognitive"),
    ("wonder", "cognitive"),
    ("caution", "causal"),
    ("navigate", "spatial"),
    ("recall", "temporal"),
    ("anticipate", "temporal"),
    ("empathize", "social"),
    ("celebrate", "emotional"),
    ("compose", "creative"),
    ("illustrate", "creative"),
]

for (verb, cls) in verb_specs
    try
        SemanticVerbs.add_verb!(verb, cls)
        global verbs_added; verbs_added += 1
    catch e
        println("  ⚠️  Verb '$verb' failed: $e")
    end
end

# NOW: Add verb synonyms (canonical verbs must exist first)
syns_verbs_added = 0
verb_syn_specs = [
    ("compute", "calc"),
    ("compute", "figure"),
    ("wonder", "speculate"),
    ("wonder", "question"),
    ("caution", "warn"),
    ("navigate", "chart"),
    ("recall", "remember"),
    ("anticipate", "foresee"),
    ("empathize", "care"),
    ("celebrate", "rejoice"),
    ("compose", "craft"),
    ("illustrate", "draw"),
]

for (canonical, synonym) in verb_syn_specs
    try
        SemanticVerbs.add_synonym!(canonical, synonym)
        global syns_verbs_added; syns_verbs_added += 1
    catch e
        println("  ⚠️  Synonym '$synonym→$canonical' failed: $e")
    end
end

println("  ✅ $verbs_added verbs, $syns_verbs_added verb synonyms, 11 relation classes added")

# ============================================================
# PHASE 7: Add inhibitions (negative thesaurus)
# ============================================================
println("\n🚫 Phase 7: Adding inhibitions (negative thesaurus)...")

inhib_added = 0

inhib_specs = [
    ("stupid", "Grug does not use hurtful intelligence slurs"),
    ("dumb", "Grug does not use hurtful intelligence slurs"),
    ("idiot", "Grug does not use hurtful intelligence slurs"),
    ("hate", "Grug prefers constructive language"),
    ("ugly", "Grug sees beauty in all things"),
]

for (word, reason) in inhib_specs
    try
        InputQueue.add_inhibition!(word; reason=reason)
        global inhib_added; inhib_added += 1
    catch e
        println("  ⚠️  Inhibition '$word' failed: $e")
    end
end

println("  ✅ $inhib_added inhibitions added")

# ============================================================
# PHASE 8: Set arousal baseline and eye state
# ============================================================
println("\n👁 Phase 8: Setting arousal and eye state...")

EyeSystem.set_arousal!(0.4)
# Also set baseline arousal
lock(EyeSystem.AROUSAL_LOCK) do
    EyeSystem.AROUSAL_STATE.baseline = 0.4
end
println("  ✅ Arousal level and baseline set to 0.4 (moderate)")

# ============================================================
# PHASE 9: Add automaton escalation rules
# ============================================================
println("\n🤖 Phase 9: Adding automaton escalation rules...")

auto_added = 0

# Alert escalation rule
try
    steps_alert = [
        EphemeralAutomaton.AutomatonStep("boost_threat", :bump_strength, 0.5),
        EphemeralAutomaton.AutomatonStep("nudge_arousal", :set_arousal, 0.8),
    ]
    rule_alert = EphemeralAutomaton.AutomatonRule(
        "auto_alert_escalation",
        :alert,
        steps_alert;
        jitter_targets=Set(["boost_threat"]),
        min_confidence=0.6
    )
    EphemeralAutomaton.register_automaton_rule!(rule_alert)
    global auto_added; auto_added += 1
catch e
    println("  ⚠️  Automaton alert rule failed: $e")
end

# Empathy escalation rule
try
    steps_empathy = [
        EphemeralAutomaton.AutomatonStep("deepen_care", :bump_strength, 0.3),
        EphemeralAutomaton.AutomatonStep("soften_tone", :set_arousal, 0.3),
    ]
    rule_empathy = EphemeralAutomaton.AutomatonRule(
        "auto_empathy_escalation",
        :comfort,
        steps_empathy;
        jitter_targets=Set(["deepen_care"]),
        min_confidence=0.5
    )
    EphemeralAutomaton.register_automaton_rule!(rule_empathy)
    global auto_added; auto_added += 1
catch e
    println("  ⚠️  Automaton empathy rule failed: $e")
end

# Creative escalation rule
try
    steps_creative = [
        EphemeralAutomaton.AutomatonStep("inspire", :bump_strength, 0.2),
        EphemeralAutomaton.AutomatonStep("widen_scope", :literal, "brainstorm"),
    ]
    rule_creative = EphemeralAutomaton.AutomatonRule(
        "auto_creative_escalation",
        :create,
        steps_creative;
        jitter_targets=Set(["inspire"]),
        min_confidence=0.4
    )
    EphemeralAutomaton.register_automaton_rule!(rule_creative)
    global auto_added; auto_added += 1
catch e
    println("  ⚠️  Automaton creative rule failed: $e")
end

println("  ✅ $auto_added automaton escalation rules registered")

# ============================================================
# PHASE 10: Set decomposer config
# ============================================================
println("\n✂️ Phase 10: Setting decomposer config...")

decomp_added = 0
try
    InputDecomposer.add_split_conjunction!("although")
    global decomp_added; decomp_added += 1
catch e
    println("  ⚠️  Decomposer addConjunction failed: $e")
end
try
    InputDecomposer.add_split_conjunction!("whereas")
    global decomp_added; decomp_added += 1
catch e
    println("  ⚠️  Decomposer addConjunction failed: $e")
end
try
    InputDecomposer.add_split_conjunction!("nevertheless")
    global decomp_added; decomp_added += 1
catch e
    println("  ⚠️  Decomposer addConjunction failed: $e")
end
try
    InputDecomposer.add_compound_pair!("not", "only")
    global decomp_added; decomp_added += 1
catch e
    println("  ⚠️  Decomposer addCompound failed: $e")
end
# Conjugation rule requires command marker registration - skip for now
println("  ℹ️  Skipping conjugation rule (requires command marker registration first)")

println("  ✅ Decomposer config set ($decomp_added additions)")

# ============================================================
# PHASE 11: Set TonalJudge knobs
# ============================================================
println("\n⚖️ Phase 11: Setting TonalJudge knobs...")

try
    TonalJudge.set_frame_match_weights!(; lift=1.3, inhibit=0.7)
    println("  ✅ TonalJudge frame match weights: lift=1.3, inhibit=0.7")
catch e
    println("  ⚠️  TonalJudge issue: $e")
end

# ============================================================
# PHASE 12: Add flashcards to math lobe
# ============================================================
println("\n🃏 Phase 12: Adding flashcards...")

flashcards_added = 0

flashcard_specs = [
    ("2+2", "4", 4.0),
    ("3+5", "8", 8.0),
    ("7+3", "10", 10.0),
    ("10-4", "6", 6.0),
    ("9-3", "6", 6.0),
    ("6*7", "42", 42.0),
    ("8*8", "64", 64.0),
    ("12/4", "3", 3.0),
    ("100/10", "10", 10.0),
]

for (expr, result, result_num) in flashcard_specs
    try
        LobeTable.flashcard_put!("lobe_math", expr, result; result_num=result_num, card_type=:arithmetic)
        global flashcards_added; flashcards_added += 1
    catch e
        println("  ⚠️  Flashcard '$expr' failed: $e")
    end
end

println("  ✅ $flashcards_added flashcards added to math lobe")

# ============================================================
# PHASE 13: Add initial message history
# ============================================================
println("\n💬 Phase 13: Adding initial message history...")

add_message_to_history!("System", "Comprehensive specimen v2.2 initialized with 8 lobes, 40+ nodes, bridges, and all features", true)
add_message_to_history!("Engine_Voice", "Grug ready. Many lobes, many rocks, many bridges. Grug think good.", false)
add_message_to_history!("User", "Hello Grug, what can you think about?", false)
add_message_to_history!("Engine_Voice", "Grug think about math, philosophy, nature, time, survival, empathy, creativity, and social things. Grug brain big!", false)

println("  ✅ Initial messages added")

# ============================================================
# PHASE 14: Add custom sigils (lambda, macro, tag, relation)
# ============================================================
println("\n🔮 Phase 14: Adding custom sigils...")

# Lambda sigil — parametric position placeholder (no lexicon allowed)
# NOTE: promote_at_tokenize=false because :string sigil_type has no promoter shape predicate
SigilRegistry.register_sigil!(_ENGINE_SIGIL_TABLE;
    name="mood",
    class=:lambda,
    applies_at=:bind,
    sigil_type=:string,
    provenance="specimen-build-v2",
    promote_at_tokenize=false
)

# Macro sigil — alternation family (lexicon required for :macro class)
SigilRegistry.register_sigil!(_ENGINE_SIGIL_TABLE;
    name="mathop",
    class=:macro,
    applies_at=:bind,
    lexicon=["add", "subtract", "multiply", "divide", "calculate"],
    provenance="specimen-build-v2",
    promote_at_tokenize=true
)

# Another macro sigil with lexicon
SigilRegistry.register_sigil!(_ENGINE_SIGIL_TABLE;
    name="emotion",
    class=:macro,
    applies_at=:bind,
    lexicon=["happy", "sad", "angry", "calm", "excited", "afraid"],
    provenance="specimen-build-v2",
    promote_at_tokenize=true
)

# Tag sigil — annotation
SigilRegistry.register_sigil!(_ENGINE_SIGIL_TABLE;
    name="philosophical",
    class=:tag,
    applies_at=:match,
    provenance="specimen-build-v2"
)

# Relation sigil — relational triple macro
SigilRegistry.register_relation_sigil!(_ENGINE_SIGIL_TABLE;
    name="causes",
    expansion=["causes", "produces", "generates", "leads_to"],
    provenance="specimen-build-v2"
)

SigilRegistry.register_relation_sigil!(_ENGINE_SIGIL_TABLE;
    name="opposes",
    expansion=["opposes", "contradicts", "negates", "blocks"],
    provenance="specimen-build-v2"
)

# Procedure sigil — expansion chain (bind-time procedure)
SigilRegistry.register_procedure_sigil!(_ENGINE_SIGIL_TABLE;
    name="math-chain",
    expansion=["&mathop", "&n", "then", "verify"],
    provenance="specimen-build-v2"
)

println("  ✅ 7 custom sigils registered (1 lambda, 2 macro, 1 tag, 1 procedure, 2 relation)")

# ============================================================
# PHASE 15: Add EphemeralMLP transformer rules
# ============================================================
println("\n🧬 Phase 15: Adding EphemeralMLP rules...")

EphemeralMLP.init_ephemeral_mlp!()

rule1 = EphemeralMLP.MLPTransformerRule(
    "math_boost",
    "math|calculate|number|equation";
    key="math_pattern",
    weight_value=1.3,
    weight_jitter=true,
    transform_type=EphemeralMLP.MLP_TRANSFORM_FUZZY,
    payload=Dict{String,Any}("lobe_hint" => "lobe_math", "boost_factor" => 0.15),
    drop_table=String[]
)
EphemeralMLP.add_mlp_rule!(rule1)

rule2 = EphemeralMLP.MLPTransformerRule(
    "empathy_boost",
    "feel|sad|happy|care|compassion";
    key="empathy_pattern",
    weight_value=1.2,
    weight_jitter=true,
    transform_type=EphemeralMLP.MLP_TRANSFORM_FUZZY,
    payload=Dict{String,Any}("lobe_hint" => "lobe_emp", "boost_factor" => 0.12),
    drop_table=String["math_boost"]
)
EphemeralMLP.add_mlp_rule!(rule2)

rule3 = EphemeralMLP.MLPTransformerRule(
    "survival_priority",
    "danger|threat|flee|fight|protect";
    key="survival_pattern",
    weight_value=1.5,
    weight_jitter=false,
    transform_type=EphemeralMLP.MLP_TRANSFORM_SOLID,
    payload=Dict{String,Any}("lobe_hint" => "lobe_surv", "boost_factor" => 0.25),
    drop_table=String[]
)
EphemeralMLP.add_mlp_rule!(rule3)

println("  ✅ 3 MLP transformer rules added (math_boost, empathy_boost, survival_priority)")

# ============================================================
# PHASE 16: Set CoherenceField config
# ============================================================
println("\n🌀 Phase 16: Setting CoherenceField config...")

# Set CoherenceField config — takes (field::Symbol, value) pairs
CoherenceField.set_coherence_config!(:weight, 0.45)
CoherenceField.set_coherence_config!(:depth, 3)
CoherenceField.set_coherence_config!(:decay, 0.008)
CoherenceField.set_coherence_config!(:recency_window, 180.0)
CoherenceField.set_coherence_config!(:cache_ttl, 3.0)

println("  ✅ CoherenceField config set (weight=0.45, depth=3, decay=0.008, recency=180s)")

# ============================================================
# PHASE 17: Seed RelationalGovernance co-activation
# ============================================================
println("\n🔗 Phase 17: Seeding RelationalGovernance co-activation...")

# Observe some co-firing groups between lobes (takes Vector of node IDs)
RelationalGovernance.observe_co_firing!(["math_concept", "phil_inquiry"])
RelationalGovernance.observe_co_firing!(["survival_instinct", "empathy_care"])
RelationalGovernance.observe_co_firing!(["creative_expression", "nature_beauty"])

println("  ✅ 3 co-activation pairs observed")

# ============================================================
# PHASE 18: Add HippocampalModulator action log entries
# ============================================================
println("\n🦛 Phase 18: Adding HippocampalModulator action log entries...")

# HippocampalModulator action logs are cycle-ephemeral (created fresh each dispatch).
# The persistent hippocampal state is the pending_ask — set that instead.
lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do
    _HIPPOCAMPAL_PENDING_ASK[] = "What is the relationship between mathematics and philosophy?"
end

println("  ✅ Hippocampal pending ask seeded")

# ============================================================
# PHASE 19: Configure TimeOrientation + time nodes
# ============================================================
println("\n⏳ Phase 19: Setting time orientation + time nodes...")

# Set global time orientation
lock(_GLOBAL_PROMOTION_LOCK) do
    _GLOBAL_TIME_ORIENTATION[] = ("present", Dict{String,Any}("source"=>"specimen-build", "confidence"=>0.8))
end

# Mark temporal lobe nodes as time-oriented via json_data
lock(NODE_LOCK) do
    for (nid, node) in NODE_MAP
        if haskey(Lobe.NODE_TO_LOBE_IDX, nid) && Lobe.NODE_TO_LOBE_IDX[nid] == "lobe_temporal"
            node.json_data["time_node"] = true
            node.json_data["time_orientation"] = "past"
            node.json_data["time_sigil"] = "temporal_anchor"
        end
    end
end

println("  ✅ Global time orientation set to 'present', temporal nodes marked as time_node=true")

# ============================================================
# PHASE 20: Enable RelationalJitter with custom config
# ============================================================
println("\n🎲 Phase 20: Setting RelationalJitter config...")

RelationalJitter.enable_jitter!()
RelationalJitter.set_jitter_ratio!(0.08)
RelationalJitter.set_jitter_coin_ratio!(0.05)

println("  ✅ RelationalJitter enabled (ratio=0.08, coin=0.05)")

# ============================================================
# PHASE 21: Seed AutoGrowth evidence + co-occurrence
# ============================================================
println("\n🌱 Phase 21: Seeding AutoGrowth evidence...")

# Seed evidence via snapshot loading (accumulate_evidence! needs too many engine-internal args)
AutoGrowth.load_evidence_snapshot!([
    Dict("pattern"=>"quantum", "growth_type"=>"match", "lobe_hint"=>"lobe_math", "accumulated_intensity"=>0.7, "frequency"=>3, "sources"=>["silence_map"]),
    Dict("pattern"=>"ethics", "growth_type"=>"match", "lobe_hint"=>"lobe_phil", "accumulated_intensity"=>0.6, "frequency"=>2, "sources"=>["silence_map"]),
    Dict("pattern"=>"grief", "growth_type"=>"match", "lobe_hint"=>"lobe_emp", "accumulated_intensity"=>0.65, "frequency"=>4, "sources"=>["thesaurus_gap"]),
    Dict("pattern"=>"venom", "growth_type"=>"match", "lobe_hint"=>"lobe_surv", "accumulated_intensity"=>0.8, "frequency"=>5, "sources"=>["silence_map"]),
    Dict("pattern"=>"sculpture", "growth_type"=>"match", "lobe_hint"=>"lobe_crea", "accumulated_intensity"=>0.55, "frequency"=>2, "sources"=>["silence_map"]),
])

# Seed co-occurrence data
AutoGrowth.load_co_occur_snapshot!([
    Dict("a"=>"math", "b"=>"calculate", "count"=>5),
    Dict("a"=>"think", "b"=>"philosophy", "count"=>3),
    Dict("a"=>"feel", "b"=>"empathy", "count"=>4),
    Dict("a"=>"danger", "b"=>"survival", "count"=>6),
    Dict("a"=>"create", "b"=>"imagine", "count"=>3),
])

println("  ✅ 5 AutoGrowth evidence entries seeded")

# Seed AutoLinker evidence
AutoLinker.load_link_evidence_snapshot!(Dict(
    "math_concept||phil_inquiry" => Dict("node_a"=>"math_concept", "node_b"=>"phil_inquiry", "accumulated_intensity"=>0.5, "frequency"=>3, "sources"=>["co_firing"], "is_cross_lobe"=>true, "lobe_a"=>"lobe_math", "lobe_b"=>"lobe_phil"),
    "survival_instinct||empathy_care" => Dict("node_a"=>"empathy_care", "node_b"=>"survival_instinct", "accumulated_intensity"=>0.4, "frequency"=>2, "sources"=>["co_firing"], "is_cross_lobe"=>true, "lobe_a"=>"lobe_emp", "lobe_b"=>"lobe_surv"),
))

println("  ✅ AutoLinker evidence seeded (2 cross-lobe pairs)")

# ============================================================
# PHASE 22: Register AIML lobe populations
# ============================================================
println("\n🤖 Phase 22: Registering AIML executive nodes...")

# Register AIML tribes for each lobe
for (lobe_id, lobe_rec) in Lobe.LOBE_REGISTRY
    cap = length(lobe_rec.node_ids)
    if cap > 0
        try
            AIMLNodeSystem.register_lobe!(lobe_id, cap)
            # Add one AIML executive node per lobe
            aiml_id = "aiml_$(lobe_id)_exec_1"
            template = "Executive scaffold for $(lobe_rec.subject)"
            AIMLNodeSystem.add_aiml_node!(lobe_id, aiml_id, template; initial_strength=5.0)
        catch e
            @warn "AIML register failed for $lobe_id" exception=e
        end
    end
end

n_aiml_lobes = length(AIMLNodeSystem.get_registered_lobes())
println("  ✅ AIML tribes registered for $n_aiml_lobes lobes with executive nodes")

# ============================================================
# PHASE 23: Seed PhaseAccumulator crystal data
# ============================================================
println("\n💎 Phase 23: Seeding PhaseAccumulator crystal...")

# Push some phase snapshots into the accumulator
EphemeralAutomaton.set_phase_enabled!(true)
EphemeralAutomaton.set_phase_pull_threshold!(0.55)
EphemeralAutomaton.set_phase_surface_count!(4)

println("  ✅ PhaseAccumulator configured (enabled, threshold=0.55, surfaces=4)")

# ============================================================
# PHASE 24: Add flashcards to multiple lobes
# ============================================================
println("\n🎴 Phase 24: Adding flashcards to multiple lobes...")

# Philosophy lobe flashcards
LobeTable.flashcard_put!("lobe_phil", "what is consciousness", "Consciousness is the quality or state of awareness, or of being aware of an external object or something within oneself.")
LobeTable.flashcard_put!("lobe_phil", "what is truth", "Truth is the property of being in accord with fact or reality.")
LobeTable.flashcard_put!("lobe_phil", "what is free will", "Free will is the ability to choose between different possible courses of action unimpeded.")

# Survival lobe flashcards
LobeTable.flashcard_put!("lobe_surv", "how to survive danger", "Assess the threat, find shelter, secure resources, and stay alert to changes in your environment.")
LobeTable.flashcard_put!("lobe_surv", "fight or flight response", "An instinctive physiological response to a perceived threat, preparing the body to fight or flee.")

# Empathy lobe flashcards
LobeTable.flashcard_put!("lobe_emp", "what is compassion", "Compassion is the feeling that arises when you are confronted with another's suffering and feel motivated to relieve that suffering.")
LobeTable.flashcard_put!("lobe_emp", "how to comfort someone", "Listen without judgment, acknowledge their feelings, offer presence and support, and avoid giving unsolicited advice.")

# Nature lobe flashcards
LobeTable.flashcard_put!("lobe_nature", "what is a forest", "A forest is a large area dominated by trees and other woody vegetation, providing habitat for countless species.")
LobeTable.flashcard_put!("lobe_nature", "what causes weather", "Weather is driven by atmospheric conditions including temperature, pressure, humidity, and wind patterns.")

# Creativity lobe flashcards
LobeTable.flashcard_put!("lobe_crea", "what is imagination", "Imagination is the faculty or action of forming new ideas, or images or concepts of external objects not present to the senses.")

println("  ✅ Flashcards added to 5 lobes (phil, surv, emp, nature, crea)")

# ============================================================
# PHASE 25: Configure fanout + answer_mode + config knobs
# ============================================================
println("\n⚙️ Phase 25: Setting fanout, answer mode, and config knobs...")

# Answer mode config — already has defaults, add a custom mode
_ANSWER_MODE_CONFIG["poetry"] = Dict(
    "action" => "elaborate^1",
    "voice" => "warm",
    "frame" => ["exploratory", "warm"],
    "prompt" => "Grug. I speak in beauty. I weave words into art. I create from what I have learned."
)

println("  ✅ Answer mode config: added 'poetry' mode, existing defaults preserved")

# ============================================================
# PHASE 26: Add nodes with special fields
# ============================================================
println("\n🔧 Phase 26: Adding nodes with special fields (response_times, json_data, unlinkable, custom max_neighbors)...")

# Node with response_times history
grow_nodes_from_packet(JSON.json(Dict("nodes" => [
    Dict(
        "pattern" => "emergency protocol activated",
        "signal" => "alert warn danger emergency critical urgent",
        "action_packet" => "alert",
        "json_data" => Dict("category" => "emergency", "priority" => "critical", "response_type" => "immediate"),
        "strength" => 8.5,
        "response_times" => [0.12, 0.15, 0.11, 0.13, 0.14],
        "throttle" => 0.3
    )
])); target_lobe="lobe_surv")

# Node with is_unlinkable=true
grow_nodes_from_packet(JSON.json(Dict("nodes" => [
    Dict(
        "pattern" => "the absolute unknowable void",
        "signal" => "void nothing emptiness abyss",
        "action_packet" => "ponder",
        "json_data" => Dict("category" => "metaphysics", "unknowable" => true),
        "strength" => 4.0,
        "is_unlinkable" => true,
        "max_neighbors" => 2
    )
])); target_lobe="lobe_phil")

# Node with large max_neighbors
grow_nodes_from_packet(JSON.json(Dict("nodes" => [
    Dict(
        "pattern" => "gathering of many friends",
        "signal" => "group community party gathering together",
        "action_packet" => "welcome",
        "json_data" => Dict("category" => "social_event", "group_size" => "large"),
        "strength" => 6.0,
        "max_neighbors" => 12,
        "neighbor_ids" => String[]
    )
])); target_lobe="lobe_social")

# Image node with SDF params in json_data
grow_nodes_from_packet(JSON.json(Dict("nodes" => [
    Dict(
        "pattern" => "SDF:sunset_over_water",
        "signal" => "sunset water orange sky reflection",
        "action_packet" => "describe",
        "json_data" => Dict(
            "is_image" => true,
            "sdf_id" => "sunset_over_water",
            "sdf_params" => Dict("complexity" => 0.7, "symmetry" => 0.4, "warmth" => 0.9),
            "image_description" => "A warm sunset reflected across calm water, orange and purple hues blending at the horizon"
        ),
        "is_image_node" => true,
        "strength" => 7.0
    )
])); target_lobe="lobe_nature")

println("  ✅ 4 special-field nodes added (response_times, unlinkable, max_neighbors=12, SDF image)")

# ============================================================
# SAVE SPECIMEN
# ============================================================
println("\n" * "="^70)
println("SAVING COMPREHENSIVE SPECIMEN...")
println("="^70)

filepath = joinpath(@__DIR__, "specimens", "comprehensive_v2_specimen.json")
result = save_specimen_to_file!(filepath)
println("\n✅ SPECIMEN SAVED: $result")
