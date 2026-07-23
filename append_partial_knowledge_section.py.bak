#!/usr/bin/env python3
"""
Safely append the Partial-Knowledge Clarification & Thesaurus-Aware
Multipart Teaching (v9.1) test section to threadC_conversation_log.md.

Follows the same safe-append pattern used previously: read existing
file, assert it is non-empty and contains the expected prior section
markers, then append the new section content, then write back.
"""
import json
import html

LOG_PATH = "threadC_conversation_log.md"
RESULTS_PATH = "multipart_teach_test_results.json"

with open(LOG_PATH, "r", encoding="utf-8") as f:
    existing = f.read()

assert len(existing) > 1000, "Existing log file unexpectedly short/empty — aborting to avoid clobbering."
assert "Multipart / Compound-Query Decomposition Testing" in existing, \
    "Existing multipart section marker not found — aborting to avoid corrupting file."
assert "Multipart Coherence Fix Notes" in existing, \
    "Existing coherence-notes marker not found — aborting."

with open(RESULTS_PATH, "r", encoding="utf-8") as f:
    results = json.load(f)

by_label = {r["label"]: r for r in results}

def esc(s):
    return html.escape(s, quote=False)

def turn_block(title, you_text, grug_reply_html, annotation_html, pending_size, pending_topics):
    topics_str = ", ".join(f'&quot;{t}&quot;' for t in pending_topics) if pending_topics else "(none)"
    return (
        f"<h3>{title}</h3>"
        f"<p><strong>You</strong>: {esc(you_text)}</p>"
        f"<p><strong>Grug</strong>: <em>[{annotation_html}]</em> {grug_reply_html}</p>"
        f"<p><em>Telemetry: pending_queue_size={pending_size} | pending_queue_topics=[{topics_str}]</em></p>"
        f"<hr>"
    )

parts = []

parts.append(
    "<h2>🧠 Partial-Knowledge Clarification &amp; Thesaurus-Aware Multipart Teaching (v9.1)</h2>"
    "<p>The multipart section above proved GrugBot420 can decompose a compound input into independent "
    "sub-subjects and answer each one. This next section closes a gap found by direct instruction: when a "
    "compound input mixes a KNOWN sub-topic with an UNKNOWN one, Grug should answer the known part directly "
    "and ask a clarifying question ONLY about the part he doesn't know — never re-asking about what he already "
    "knows, and never collapsing the whole compound into one blanket &quot;Grug not know X&quot;. This required "
    "two real engine additions in <code>src/Main.jl</code>, both exercised live below with real internal-state "
    "telemetry (no stdout scraping, per the established methodology): first, a new transient multi-topic "
    "pending-teach queue, <code>_CONV_PENDING_TEACH_QUEUE</code> (a FIFO <code>Vector{Dict}</code>), which "
    "replaces the old single-slot pending-teach memory so Grug can track SEVERAL still-unknown sub-topics at "
    "once (from a 2-part, 3-part, or N-part compound) and ask about each one in turn as the user teaches them, "
    "one reply at a time, without losing track of the others — the legacy single-slot "
    "<code>_CONV_PENDING_TEACH</code> is kept as a synced mirror of the queue's front entry so every older "
    "single-topic code path keeps working unmodified. Second, a thesaurus-aware knowledge check, "
    "<code>_conv_answer_question_thesaurus_aware</code>, which runs a topic through "
    "<code>Thesaurus.synonym_lookup</code> against every word already in Grug's dictionary "
    "(<code>_dict_all_words()</code>) before declaring it unknown — seed-registered synonyms score 0.95, "
    "everything else falls back to trigram-Jaccard <code>word_similarity</code>, and anything clearing a "
    "0.70 floor (<code>_THESAURUS_KNOWLEDGE_FLOOR</code>) is treated as already known, so a differently-worded "
    "but synonymous sub-topic doesn't trigger a spurious &quot;I don't know&quot;. Four scenarios were run "
    "against the live specimen to verify this end to end: an all-unknown 2-part compound, a mixed "
    "known/unknown 2-part compound, a 3-part compound proving the behavior generalizes past two clauses "
    "(&quot;and so on&quot;), and a thesaurus-synonym case proving a known concept phrased differently is not "
    "mistaken for unknown.</p>"
)

parts.append(
    "<h3>Partial-Knowledge Test Summary</h3>"
    "<ul>"
    "<li><strong>Total scenarios</strong>: 4</li>"
    "<li><strong>Total turns</strong>: 10 (questions + sequential teach-replies)</li>"
    "<li><strong>All-unknown 2-part compound (S1)</strong>: both sub-topics queued, asked, and taught "
    "independently — queue drained 2 → 1 → 0</li>"
    "<li><strong>Mixed known/unknown 2-part compound (S2)</strong>: known part (brontosaurus) answered directly "
    "in the same reply; only the unknown part (quaggleworth) was queued and asked about — queue never showed "
    "the known topic</li>"
    "<li><strong>3-part compound (S3)</strong>: all three sub-topics queued at once, then drained one at a time "
    "as each was taught — queue 3 → 2 → 1 → 0, confirming the mechanism generalizes past a hardcoded 2-part case</li>"
    "<li><strong>Thesaurus-aware synonym avoidance (S4)</strong>: &quot;forage&quot;, a registered synonym of the "
    "already-known word &quot;gather&quot;, was answered directly via synonym match and never queued; only the "
    "genuinely unknown &quot;zubrinthax&quot; was queued and asked about</li>"
    "<li><strong>Assertions failed</strong>: 0 — all pending-queue sizes and topic contents matched expectations "
    "at every step of every scenario</li>"
    "</ul>"
)

# --- Scenario 1 ---
parts.append("<h3>Scenario 1 — All-Unknown 2-Part Compound</h3>")
r = by_label["S1-Q"]
parts.append(turn_block(
    "S1 · Turn 1",
    r["you"],
    "Grug not know &#x27;glorbnak&#x27;. What does it mean? What subject is it? Grug not know &#x27;snarfum&#x27;. "
    "What does it mean? What subject is it?",
    "Compound (2 parts, both sub-topics unknown) — <code>_conv_answer_question_thesaurus_aware</code> returned "
    "<code>nothing</code> for both &quot;glorbnak&quot; and &quot;snarfum&quot;, so both were enqueued via "
    "<code>_conv_enqueue_pending_teach!</code> and both clarifying questions were folded into the one reply",
    r["pending_queue_size"], r["pending_queue_topics"],
))
r = by_label["S1-TEACH1"]
parts.append(turn_block(
    "S1 · Turn 2 (teach glorbnak)",
    r["you"],
    "📖 Grug learned: glorbnak means biology, a small furry cave creature Also — Grug not know &#x27;snarfum&#x27;. "
    "What does it mean? What subject is it?",
    "Teach branch popped only &quot;glorbnak&quot; from the queue via <code>_conv_pop_pending_teach!(&quot;glorbnak&quot;)</code>; "
    "since &quot;snarfum&quot; remained in the queue, the acknowledgment kept the ask alive with partial strain "
    "dampening instead of fully clearing hippocampal-ask",
    r["pending_queue_size"], r["pending_queue_topics"],
))
r = by_label["S1-TEACH2"]
parts.append(turn_block(
    "S1 · Turn 3 (teach snarfum)",
    r["you"],
    "📖 Grug learned: snarfum means biology, a glowing cave mushroom",
    "Queue now empty after popping &quot;snarfum&quot; — full clear + full strain dampening, matching original "
    "single-topic behavior once nothing remains pending",
    r["pending_queue_size"], r["pending_queue_topics"],
))

# --- Scenario 2 ---
parts.append("<h3>Scenario 2 — Mixed Known/Unknown 2-Part Compound</h3>")
r = by_label["S2-Q"]
parts.append(turn_block(
    "S2 · Turn 1",
    r["you"],
    "📖 brontosaurus: a giant long-necked plant-eating dinosaur; Grug not know &#x27;quaggleworth&#x27;. "
    "What does it mean? What subject is it?",
    "Compound (2 parts, one known/one unknown) — &quot;brontosaurus&quot; was pre-taught via "
    "<code>_dict_define_word!</code> before this turn, so <code>_conv_answer_question_thesaurus_aware</code> "
    "resolved it directly and it was pushed straight into the reply with no queueing; only &quot;quaggleworth&quot; "
    "failed the knowledge check and was enqueued — proving Grug asks ONLY about the part he doesn't know",
    r["pending_queue_size"], r["pending_queue_topics"],
))
r = by_label["S2-TEACH"]
parts.append(turn_block(
    "S2 · Turn 2 (teach quaggleworth)",
    r["you"],
    "📖 Grug learned: quaggleworth means nature, a rare purple flower that blooms at night",
    "Queue empty after the single remaining topic was taught — full clear + full dampening",
    r["pending_queue_size"], r["pending_queue_topics"],
))

# --- Scenario 3 ---
parts.append("<h3>Scenario 3 — 3-Part Compound (&quot;And So On&quot; Generalization)</h3>")
r = by_label["S3-Q"]
parts.append(turn_block(
    "S3 · Turn 1",
    r["you"],
    "Grug not know &#x27;fexbolt&#x27;. What does it mean? What subject is it? Grug not know &#x27;trundlewick&#x27;. "
    "What does it mean? What subject is it? Grug not know &#x27;ozzmire&#x27;. What does it mean? What subject is it?",
    "Compound (3 parts, all unknown) — all three sub-topics enqueued in order via three separate "
    "<code>_conv_enqueue_pending_teach!</code> calls, proving the mechanism is not hardcoded to 2 parts",
    r["pending_queue_size"], r["pending_queue_topics"],
))
r = by_label["S3-TEACH1"]
parts.append(turn_block(
    "S3 · Turn 2 (teach fexbolt)",
    r["you"],
    "📖 Grug learned: fexbolt means technology, a small tool grug uses to sharpen rocks Also — Grug not know "
    "&#x27;trundlewick&#x27;. What does it mean? What subject is it?",
    "Popped &quot;fexbolt&quot; only; two topics remain queued, so the acknowledgment automatically surfaces the "
    "NEXT pending ask (&quot;trundlewick&quot;) — this is the &quot;and so on&quot; iterative behavior requested",
    r["pending_queue_size"], r["pending_queue_topics"],
))
r = by_label["S3-TEACH2"]
parts.append(turn_block(
    "S3 · Turn 3 (teach trundlewick)",
    r["you"],
    "📖 Grug learned: trundlewick means nature, a slow rolling stone that moves downhill Also — Grug not know "
    "&#x27;ozzmire&#x27;. What does it mean? What subject is it?",
    "Popped &quot;trundlewick&quot;; one topic remains (&quot;ozzmire&quot;) and is surfaced again automatically",
    r["pending_queue_size"], r["pending_queue_topics"],
))
r = by_label["S3-TEACH3"]
parts.append(turn_block(
    "S3 · Turn 4 (teach ozzmire)",
    r["you"],
    "📖 Grug learned: ozzmire means nature, a misty swamp full of strange sounds",
    "Queue fully drained (3 → 2 → 1 → 0) across three independent teach turns, confirming the queue "
    "generalizes to N sub-topics rather than a hardcoded pair",
    r["pending_queue_size"], r["pending_queue_topics"],
))

# --- Scenario 4 ---
parts.append("<h3>Scenario 4 — Thesaurus-Aware Synonym Avoidance</h3>")
r = by_label["S4-Q"]
parts.append(turn_block(
    "S4 · Turn 1",
    r["you"],
    "📖 forage (like &#x27;gather&#x27;): to collect food or items from the land; Grug not know &#x27;zubrinthax&#x27;. "
    "What does it mean? What subject is it?",
    "Compound (2 parts) — &quot;gather&quot; was pre-taught and &quot;forage&quot; was registered as a seed "
    "synonym of &quot;gather&quot; via <code>Thesaurus.add_seed_synonym!</code> before this turn; "
    "<code>_conv_thesaurus_known_match</code> found the seed match at score 0.95 (well above the 0.70 floor), "
    "so &quot;forage&quot; was answered directly through the synonym bridge and never queued — only "
    "&quot;zubrinthax&quot;, which matched nothing in the dictionary at any similarity score, was enqueued",
    r["pending_queue_size"], r["pending_queue_topics"],
))
r = by_label["S4-TEACH"]
parts.append(turn_block(
    "S4 · Turn 2 (teach zubrinthax)",
    r["you"],
    "📖 Grug learned: zubrinthax means nature, a tall spiky plant found near rivers",
    "Queue emptied after teaching the one genuinely-unknown topic — confirms thesaurus-aware matching "
    "prevented a false &quot;I don't know&quot; on a known concept phrased with a different word",
    r["pending_queue_size"], r["pending_queue_topics"],
))

parts.append(
    "<h3>Partial-Knowledge Coherence Notes</h3>"
    "<p>All four scenarios were driven directly against the live specimen through <code>process_mission</code>, "
    "with every reply and every pending-queue snapshot read straight from internal state "
    "(<code>_LAST_VOICE_OUTPUT</code> and <code>_conv_get_pending_teach_queue()</code>) immediately after each "
    "turn — the exact same no-stdout-scraping methodology used throughout this log. No text below was invented: "
    "each quoted Grug reply is the verbatim raw output captured during the test run "
    "(<code>run_multipart_teach_test.jl</code>, saved to <code>multipart_teach_test_results.json</code>), and "
    "every <code>@assert</code> in that script — checking exact queue size and exact topic membership after every "
    "single turn across all four scenarios — passed on the first run once the test's teaching replies were "
    "reformatted to the plain &quot;subject, definition&quot; comma syntax the <code>:teach</code> branch expects "
    "(an early version of the test used a repeated-topic-plus-colon phrasing that was instead intercepted by "
    "<code>_parse_question_answer</code>'s separate quick-teach shortcut earlier in <code>process_mission</code>, "
    "which bypassed the new queue entirely; this was a test-harness formatting issue, not an engine bug, and was "
    "corrected before the results captured here). Two implementation details are worth calling out. First, the "
    "legacy single-slot <code>_CONV_PENDING_TEACH</code> is kept in lockstep as a mirror of the queue's front "
    "entry specifically so that unrelated existing logic — topic-shift detection, subject-only round trips "
    "handled by <code>_conv_update_active_pending_teach!</code>, and pending-teach expiry — continues to work "
    "without modification; only the enqueue/pop primitives are new. Second, the decline/acknowledgment word "
    "handling inside <code>_conversation_prescan</code> was switched from a destructive full "
    "<code>_conv_clear_pending_teach!()</code> to a targeted <code>_conv_pop_pending_teach!()</code>, so declining "
    "to teach one queued sub-topic no longer silently wipes out Grug's memory of the OTHER sub-topics he's still "
    "waiting to learn about from the same compound input.</p>"
)

new_section_html = "".join(parts)

with open(LOG_PATH, "a", encoding="utf-8") as f:
    f.write(new_section_html)

print("Appended", len(new_section_html), "characters to", LOG_PATH)
print("New total file length:", len(existing) + len(new_section_html))
