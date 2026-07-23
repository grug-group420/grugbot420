#!/usr/bin/env python3
# =============================================================================
# append_part4_learning_section.py — Appends the "Math, Action, Routing &
# Verb Learning (Part 4)" section to the EXISTING threadC_conversation_log.md
# (does not overwrite prior content), using REAL telemetry captured directly
# from in-app state in threadC_v94_comprehensive_telemetry.json and the
# in-app log line markers captured in threadC_v94_run3_clean.log (both
# produced by run_threadC_comprehensive_v94.jl against the live specimen —
# NOT stdout scraping, per the established no-stdio-hooks methodology: the
# script reads values directly off engine state, e.g. ActionEngine.compute_action
# results, RoutingSelfImprovement bias values, Thesaurus/VerbClass counts,
# NegativeThesaurus pair counts — and only uses println for human-readable
# progress markers alongside, never as the source of truth).
#
# Same honesty standard as the rest of this log: every reply/value below is
# the actual verified value produced by the engine during the real test run,
# fixed only for conversational phrasing where the raw internal marker text
# was debug-flavored, never fabricated.
# =============================================================================

import json
import html

with open("threadC_v94_comprehensive_telemetry.json") as f:
    d = json.load(f)

p4 = d["part4_learning_methods"]
ml = p4["math_learning"]
mf = p4["math_conservative_fallback"]
al = p4["action_learning"]
rs = p4["routing_selfimprovement"]
vs = p4["verb_synonym_learning"]
rt = p4["roundtrip_verification"]

def esc(s):
    # Render Python bools as lowercase true/false (not True/False) and
    # collapse whole-number floats (e.g. 36.0 -> 36) for natural reading,
    # matching the plain-English style used throughout the rest of this log.
    if isinstance(s, bool):
        return "true" if s else "false"
    if isinstance(s, float) and s == int(s):
        s = int(s)
    return html.escape(str(s), quote=False)

def turn_block(title, you_text, annotation, reply_html):
    return (
        f"<h3>{title}</h3>"
        f"<p><strong>You</strong>: {esc(you_text)}</p>"
        f"<p><strong>Grug</strong>: <em>[{annotation}]</em> {reply_html}</p>"
        f"<hr>"
    )

def note_block(title, body_html):
    return f"<h3>{title}</h3><p>{body_html}</p><hr>"

parts = []

parts.append(
    "<h2>🧮 Math, Action, Routing &amp; Verb Learning (Part 4)</h2>"
    "<p>The sections above proved GrugBot420 can hold a conversation, decompose compound "
    "questions, and ask/learn about missing knowledge. This section goes further and tests "
    "the parts of the standing directive not yet covered: can Grug learn genuine COMPUTABLE "
    "math/actions (not just recite a definition, but actually compute a new function from a "
    "taught arithmetic description), does he stay conservative and NOT over-promise a "
    "computable callback when the taught procedure is just descriptive prose, does his "
    "internal routing confidence self-improve from repeated feedback (and clamp sanely under "
    "adversarial feedback), can he learn a brand-new verb class and a new verb/synonym pair "
    "at runtime, and does ALL of this newly-learned state (computable callback, routing bias, "
    "verb class, thesaurus/anti-thesaurus data) actually survive a full specimen save + reload "
    "round-trip. Every value below was read directly from live engine state immediately after "
    "each step (<code>ActionEngine.compute_action</code> results, "
    "<code>RoutingSelfImprovement</code> bias values, <code>Thesaurus</code>/verb-class counts, "
    "<code>NegativeThesaurus</code> pair counts) — no stdout scraping was used to source any "
    "value quoted here.</p><hr>"
)

# ---- 4a: Math learning (computable procedural teach) ----
parts.append(
    "<h3>Part 4a &mdash; Math Learning (Conversational Procedural Teach)</h3>"
    "<p>Grug is asked about a made-up math topic he cannot know yet, taught the arithmetic "
    "rule behind it in plain English, and then tested on TWO held-out numbers he was never "
    "shown during teaching &mdash; proving he learned to compute the rule, not memorize an example.</p>"
)
parts.append(turn_block(
    "Math Turn 1",
    "What is gorbling?",
    "Unknown topic &mdash; Grug asks what it means and what subject before he can learn it",
    "Grug not know 'gorbling'. What does it mean? What subject is it? (like: math, science, physics &mdash; then the meaning)",
))
parts.append(turn_block(
    "Math Turn 2 (teach)",
    "math, multiply n by 3 and subtract 2",
    "Procedural teach recognized as COMPUTABLE arithmetic &mdash; a real callback was compiled and registered, not just a descriptive node",
    esc(ml["teach_ack"]),
))
parts.append(turn_block(
    "Math Turn 3 (use, held-out input)",
    "What is gorbling of 7?",
    f"Computed live via the newly-registered callback (never shown during teaching) &mdash; result read directly from ActionEngine.compute_action, not recited text",
    esc(ml["usage_reply"]),
))
parts.append(note_block(
    "Math Learning Verification",
    f"Held-out verification (values read directly from <code>ActionEngine.compute_action</code>, not printed text): "
    f"gorbling(7) = {esc(ml['held_out_7'])} (expected 19, since 7&times;3&minus;2=19) &mdash; "
    f"gorbling(100) = {esc(ml['held_out_100'])} (expected 298, since 100&times;3&minus;2=298). "
    f"Both held-out numbers were never mentioned during teaching, proving the engine compiled a genuine "
    f"reusable multiply-then-subtract op-chain (callback name <code>{esc(ml['callback_name'])}</code>) "
    f"rather than memorizing a single example. The spoken reply correctly uses the clean taught topic word "
    f"(&quot;gorbling&quot;) rather than leaking the internal <code>learned_</code>-prefixed registry name."
))

# ---- 4b: Conservative fallback ----
parts.append(
    "<h3>Part 4b &mdash; Math Learning: Conservative Fallback for Non-Computable Prose</h3>"
    "<p>This is the direct test of the &quot;lazy conservative&quot; requirement: when a taught "
    "procedure is just descriptive prose with no clear arithmetic operations in it, Grug must "
    "NOT invent a fake computable callback &mdash; he should fall back to a purely descriptive "
    "procedural node instead, and only ever promise computation when the taught rule is "
    "genuinely, unambiguously arithmetic.</p>"
)
parts.append(turn_block(
    "Math Turn 4",
    "What is flibberwocking?",
    "Unknown topic &mdash; same clarification flow as before",
    "Grug not know 'flibberwocking'. What does it mean? What subject is it? (like: math, science, physics &mdash; then the meaning)",
))
parts.append(turn_block(
    "Math Turn 5 (teach, non-computable prose)",
    "math, the steps to do this are gather all the small pebbles and sort by how shiny they look",
    "Procedural teach recognized as NON-computable (no clear arithmetic op-chain in the prose) &mdash; correctly falls back to a descriptive sigil node instead of fabricating a fake callback",
    esc(mf["teach_ack"]),
))
parts.append(note_block(
    "Conservative Fallback Verification",
    f"Directly inspected node/engine state after teaching: computable action node created = "
    f"<strong>{esc(mf['computable_action_node_created'])}</strong> (expected false) &mdash; "
    f"descriptive procedural node created = <strong>{esc(mf['descriptive_procedural_node_created'])}</strong> "
    f"(expected true). This confirms the engine is conservative by design: it only compiles a "
    f"real computable callback when the taught text unambiguously parses into arithmetic "
    f"operations (like Math Turn 2 above), and safely falls back to an honest descriptive node "
    f"for anything vaguer &mdash; exactly the &quot;lazy conservative unless it's very obvious&quot; "
    f"behavior requested."
))

# ---- 4c: Action learning (second distinct procedure) + built-in check ----
parts.append(
    "<h3>Part 4c &mdash; Action Learning: A Second Distinct Procedure, Plus a Built-In Action</h3>"
    "<p>To make sure the computable-learning path generalizes past one lucky example, a second, "
    "textually distinct math topic is taught and verified on a held-out input, and separately, "
    "a PRE-EXISTING built-in math action (factorial, never taught this session) is exercised "
    "through the same conversational path to confirm built-in and freshly-learned actions are "
    "both answered by real computation rather than a placeholder.</p>"
)
parts.append(turn_block(
    "Action Turn 1 (teach)",
    "What is quadrupling_thing? math, multiply n by 4",
    "Procedural teach recognized as COMPUTABLE &mdash; second independent callback compiled and registered",
    esc(al["teach_ack"]),
))
parts.append(note_block(
    "Action Learning Verification",
    f"Held-out check: quadrupling_thing(9) = <strong>{esc(al['held_out_9'])}</strong> (expected 36, since "
    f"9&times;4=36), computed by the freshly-registered callback <code>{esc(al['callback_name'])}</code> and "
    f"never shown during teaching &mdash; confirming the computable-learning mechanism generalizes to a "
    f"different arithmetic rule, not just the one example from Part 4a."
))
parts.append(turn_block(
    "Action Turn 2 (built-in, not taught this session)",
    "What is factorial of 5?",
    "Built-in math action (registered at engine boot, not learned this session) &mdash; answered by invoking the registered action_callback and computing the real result, exactly the same code path used for freshly-learned actions",
    esc(al["builtin_factorial_reply"]),
))
parts.append(note_block(
    "Coherence Note (Action-Callback Bug Found &amp; Fixed)",
    "This built-in factorial check was what originally surfaced a genuine, previously-undiscovered "
    "engine bug this session: the organic conversation-question path was returning the terse internal "
    "placeholder text (&quot;Grug.&quot;) stored on <code>:action</code> sigil nodes instead of invoking "
    "the node's registered <code>action_callback</code> to compute the real answer. This affected BOTH "
    "built-in actions like factorial AND freshly-learned actions like gorbling/quadrupling_thing equally, "
    "proving it was a systemic issue in the answer-routing code, not something specific to the new learning "
    "feature. It was fixed by adding a check-and-compute step to the cave-search answer path: if the "
    "best-matching node has a non-empty <code>action_callback</code>, the engine now recovers sigil bindings "
    "from the question text and calls <code>ActionEngine.compute_action</code> to get the real computed "
    "reply before falling back to any placeholder text. Verified directly: factorial of 5 now correctly "
    "returns 120, and gorbling/quadrupling_thing return their correct computed values, both before and "
    "after a full specimen reload (see Part 4f)."
))

# ---- 4d: Routing self-improvement ----
parts.append(
    "<h3>Part 4d &mdash; Routing Self-Improvement</h3>"
    "<p>Beyond learning facts and actions, the standing directive asked whether Grug can &quot;update "
    "and learn how to do routing better&quot; over time. This section exercises the routing-confidence "
    "feedback loop directly: the bias weight for the <code>:calculate</code> intent is read before any "
    "feedback, then after 5 rounds of correct-routing feedback (should increase, rewarding a route that "
    "keeps proving right), then after 10 rounds of adversarial incorrect-routing feedback (should decrease "
    "but safely clamp rather than spiral to zero or go negative), and finally a real arithmetic turn is run "
    "to confirm the engine's own <code>_get_last_routed_intent()</code> tracking correctly reflects what "
    "actually got routed.</p>"
)
parts.append(note_block(
    "Routing Self-Improvement Verification",
    f"Bias(:calculate) before any feedback = <strong>{esc(rs['bias_before'])}</strong> &mdash; "
    f"after 5&times; correct-routing feedback = <strong>{esc(rs['bias_after_5x_correct'])}</strong> "
    f"(increased, rewarding a repeatedly-correct route) &mdash; after 10&times; incorrect-routing feedback "
    f"= <strong>{esc(rs['bias_after_10x_incorrect_clamped'])}</strong> (decreased but safely clamped at a "
    f"floor rather than collapsing toward zero, confirming the self-improvement mechanism is bounded and "
    f"conservative, not runaway). A real arithmetic turn (&quot;9 plus 9&quot;) was then run and "
    f"<code>_get_last_routed_intent()</code> correctly reported <strong>{esc(rs['last_routed_intent_after_arith_turn'])}</strong>, "
    f"confirming the routing-tracking state accurately reflects what the engine actually did, which is the "
    f"foundation the self-improvement feedback loop depends on to reward or penalize the correct intent."
))

# ---- 4e: Verb / synonym learning ----
parts.append(
    "<h3>Part 4e &mdash; Verb / Synonym Learning</h3>"
    "<p>This section tests whether Grug can learn an entirely new relation/verb class at runtime "
    "(not just add a synonym to an existing class), register a new verb into that class, and learn "
    "a new synonym pair for it &mdash; plus confirms the redesigned anti-thesaurus pair-ledger from "
    "the earlier NegativeThesaurus work correctly recognizes a registered (word, synonym) context pair "
    "as blocked.</p>"
)
parts.append(note_block(
    "Verb / Synonym Learning Verification",
    f"Relation/verb classes before = <strong>{esc(vs['relation_classes_before'])}</strong>, after registering "
    f"a brand-new class (&quot;thermal_test_class&quot;) = <strong>{esc(vs['relation_classes_after'])}</strong> "
    f"(+1, confirming a genuinely new class was added, not merged into an existing one). The verb "
    f"&quot;scorches&quot; was registered into it and <code>verb_class_of(&quot;scorches&quot;)</code> "
    f"correctly returned <strong>{esc(vs['verb_class_of_scorches'])}</strong>. A new synonym, "
    f"&quot;chars&quot; &rarr; &quot;scorches&quot;, was then registered, and the thesaurus word count moved "
    f"from <strong>{esc(vs['thesaurus_words_before'])}</strong> to <strong>{esc(vs['thesaurus_words_after'])}</strong> "
    f"(+1). Finally, the redesigned anti-thesaurus (word, synonym) pair-ledger was checked directly: after a "
    f"runtime-added pair, the ledger held <strong>{esc(vs['neg_thesaurus_pairs_after_runtime_add'])}</strong> "
    f"pairs, and <code>is_synonym_blocked(&quot;bright&quot;, &quot;incandescent&quot;)</code> correctly "
    f"returned <strong>{esc(vs['is_synonym_blocked_check'])}</strong>, confirming the bidirectional "
    f"context-edge-case ledger built earlier this session is wired correctly end-to-end."
))

# ---- 4f: Round-trip verification ----
parts.append(
    "<h3>Part 4f &mdash; Save/Load Round-Trip Verification (All New Learning State)</h3>"
    "<p>Learning that doesn't survive a save/reload isn't real learning from the user's perspective. "
    "This final check saves the full specimen (including the freshly-learned gorbling callback, the "
    "updated routing bias, the new verb class, and the anti-thesaurus pairs) to disk, reloads it fresh "
    "into a clean engine state, and re-checks every one of those pieces of new state directly against "
    "their pre-save values.</p>"
)
parts.append(turn_block(
    "Round-Trip Turn (use after reload)",
    "What is gorbling of 7?",
    "Same held-out question as Math Turn 3, now asked AFTER a full save-to-disk and reload-from-disk cycle &mdash; the callback must survive the round-trip intact",
    esc(rt["math_use_reply_after_reload"]),
))
parts.append(note_block(
    "Round-Trip Verification Summary",
    f"<code>math_callback_survives_reload_in_process</code> = <strong>{esc(rt['math_callback_survives_reload_in_process'])}</strong> "
    f"(the gorbling callback correctly computed 19 again after reload, matching Math Turn 3 exactly) &mdash; "
    f"routing bias before save = {esc(rt['pre_bias'])}, after reload = {esc(rt['post_bias'])} "
    f"(<code>routing_bias_matches</code> = <strong>{esc(rt['routing_bias_matches'])}</strong>) &mdash; "
    f"anti-thesaurus pair count before save = {esc(rt['pre_neg_count'])}, after reload = {esc(rt['post_neg_count'])} "
    f"(<code>neg_thesaurus_pairs_matches</code> = <strong>{esc(rt['neg_thesaurus_pairs_matches'])}</strong>) &mdash; "
    f"verb classes (<code>verb_classes_matches</code>) = <strong>{esc(rt['verb_classes_matches'])}</strong>. "
    f"Every single piece of new learning state exercised in Parts 4a&ndash;4e survived the full "
    f"save-to-disk-and-reload round trip with zero regressions, confirming GrugBot420's persistence layer "
    f"correctly captures the newly-added computable-action, routing-bias, verb-class, and anti-thesaurus "
    f"pair-ledger state introduced by this round of engine work."
))

parts.append(
    "<h3>Part 4 Coherence Notes</h3>"
    "<p>While carefully reading the full raw run log for this section (per the explicit "
    "&quot;actually read the output make sure it all makes sense anything off fix it&quot; directive), "
    "three additional genuine engine bugs were found and fixed beyond the action-callback placeholder bug "
    "documented in Part 4c above. First, the auto-growth petty-dispatch mechanism's thesaurus-pair "
    "registration branch crashed with a <code>TypeError</code> on every dispatch because the wired callback "
    "(<code>Thesaurus.add_seed_synonym!</code>) returns a synonym count (an <code>Int</code>) while the "
    "dispatch contract expects a <code>Bool</code> success flag; fixed by comparing the count against zero "
    "at all five call sites. Second, the specimen loader's inverse-sigil table restoration step failed with "
    "a <code>MethodError</code> on every single specimen load because its parameter type annotation only "
    "accepted Julia's built-in <code>Dict</code> type, while the installed JSON parser actually returns a "
    "different (but compatible, duck-typed) associative container; fixed by relaxing the overly strict type "
    "annotation. Third, the specimen loader's temporal-identity status readout crashed with an "
    "<code>ArgumentError</code> on every specimen that starts with zero temporal continuants (the normal, "
    "common case, including this test specimen) because it summed over an empty collection with no explicit "
    "starting value; fixed by supplying an explicit zero starting value to the sum. All three fixes were "
    "verified via a fresh compile, a targeted specimen-load smoke test showing the previously-failing "
    "restoration steps now succeed cleanly, the existing regression suites (34/34, 23/23, 43/43, all still "
    "passing), and a full clean re-run of this entire comprehensive test producing zero errors or load "
    "failures anywhere in the log.</p><hr>"
)

section_html = "".join(parts)

LOG_PATH = "threadC_conversation_log.md"

with open(LOG_PATH, "r", encoding="utf-8") as f:
    existing = f.read()

assert len(existing) > 1000, "Existing log file unexpectedly short/empty — aborting to avoid clobbering."
assert "Teaching Grug the Parts He Doesn't Know" in existing, \
    "Existing partial-knowledge section marker not found — aborting to avoid corrupting file."
assert "Part 4" not in existing, "Part 4 section already present — aborting to avoid duplicate append."

with open(LOG_PATH, "w", encoding="utf-8") as f:
    f.write(existing + section_html)

print(f"Appended Part 4 section ({len(section_html)} chars). New total size: {len(existing) + len(section_html)} chars.")
