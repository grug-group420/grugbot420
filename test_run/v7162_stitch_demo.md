# v7.16.2 Composition-Roll — Live Demo Output

Captured by running `_compose_support_stitch` directly in a Julia session
with the same (primary, support) claim pair under different relation
conditions. Each scenario ran 5 times to show the roll varies.

---

## Scenario 1: Fallbacks only (no gates unlock)

- reasons: `String[]`
- certainty: `SURE`
- pool: `{simple_connective, rhetorical_hook}`

```
run 1: the sun is bright, and stars emit light.
run 2: If the sun is bright, then stars emit light too.
run 3: If the sun is bright, then stars emit light too.
run 4: the sun is bright, and stars emit light.
run 5: If the sun is bright, then stars emit light too.
```

Weighted roll between two equal-weight (1/1) fallbacks — both surface.

---

## Scenario 2: All gated stitches unlocked

- reasons: `["triples+2 (sun,stars)", "action-class+1", "same-lobe+2"]`
- certainty: `UNSURE`
- pool: all 6 stitches — `{simple_connective (w=1), rhetorical_hook (w=1), shared_subject (w=4), consequence (w=3), concession (w=2), elaboration (w=2)}`

```
run 1: the sun is bright; stars emit light.                         <- shared_subject
run 2: the sun is bright, though Grug also sees stars emit light.   <- concession
run 3: the sun is bright, and stars emit light.                      <- simple_connective
run 4: If the sun is bright, then stars emit light too.              <- rhetorical_hook
run 5: the sun is bright. That is why stars emit light.              <- consequence
```

Five distinct phrasings across five runs. The same facts, different sentence
structure each time — no template, no linear concatenation.

---

## Scenario 3: UNSURE only (concession unlocks)

- reasons: `String[]`
- certainty: `UNSURE`
- pool: `{simple_connective, rhetorical_hook, concession (w=2)}`

```
run 1: the sun is bright, and stars emit light.
run 2: the sun is bright, though Grug also sees stars emit light.
run 3: the sun is bright, though Grug also sees stars emit light.
run 4: If the sun is bright, then stars emit light too.
run 5: the sun is bright, though Grug also sees stars emit light.
```

Concession wins 3/5 as its weight (2) suggests relative to fallbacks (1 each).

---

## Scenario 4: action-class only (consequence unlocks)

- reasons: `["action-class+1"]`
- certainty: `SURE`
- pool: `{simple_connective, rhetorical_hook, consequence (w=3)}`

```
run 1: the sun is bright, and stars emit light.
run 2: the sun is bright, and stars emit light.
run 3: the sun is bright. That is why stars emit light.
run 4: the sun is bright, and stars emit light.
run 5: the sun is bright. That is why stars emit light.
```

Consequence fires when its roll wins. When it doesn't, a fallback catches.

---

## Key observation

There is no branch that says "if action-class, use consequence." The roll
itself is the decision. Heavier stitches (like `shared_subject @ w=4`) win
more often, but not always. That's the point: **two runs on the same facts
can produce different prose**, which is how spoken language works.
