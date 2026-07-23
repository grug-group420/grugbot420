# GrugBot420 v8.19 — Sigil CLI Registration Test Log

Date: 2026-06-21T13:58:06.309

## Results: 40 ✅ / 0 ❌


======================================================================
# TEST 1: /sigil add bodypart lambda match type=bodypart promote=true predicate=head,arm,leg,torso,hand,foot
======================================================================
  ✅ bodypart sigil registered without error
  ✅ bodypart found in sigil table
  ✅ class == :lambda
  ✅ sigil_type == :bodypart
  ✅ promote_at_tokenize == true
  ✅ promote_predicate is set
  ✅ provenance == user-cli-test

======================================================================
# TEST 2: /sigil add topic lambda match type=topic promote=true predicate=notstop
======================================================================
  ✅ topic sigil registered without error
  ✅ topic found in sigil table

======================================================================
# TEST 3: /sigil add colormacro macro bind lexicon=red,blue,green,yellow,purple promote=true predicate=lexicon
======================================================================
  ✅ colormacro sigil registered without error
  ✅ colormacro found in sigil table
  ✅ class == :macro
  ✅ lexicon has 5 words
  ✅ promote_predicate set (lexicon-based)

======================================================================
# TEST 4: /sigil add coded lambda match type=coded promote=true predicate=regex=^[A-Z]{2,4}$
======================================================================
  ✅ coded sigil registered without error

======================================================================
# TEST 5: /sigil list shows user-registered sigils
======================================================================
  ✅ 4 user-cli-test sigils in registry
  ✅ &n (engine-default) still in table
  ✅ &op (engine-default) still in table
  ✅ &concept (engine-default) still in table

======================================================================
# TEST 6: Promote pipeline — bodypart sigil captures tokens
======================================================================
  ✅ predicate('head') → true
  ✅ predicate('arm') → true
  ✅ predicate('the') → false (correct, not in bodypart list)
  ✅ predicate('42') → false (not in bodypart list)
  📎 Found binding: &bodypart = head @ pos 2
  ✅ 'head' promoted to &bodypart via promote pipeline

======================================================================
# TEST 7: Shape predicate fallback — custom sigil_type with promote_predicate
======================================================================
  ✅ _try_lambda_promote(bodypart, 'head') → "head" (fallback works!)
  ℹ️  _try_lambda_promote(bodypart, 'the') → the (shape branch doesn't re-check predicate — that's _predicate_allows' job)

======================================================================
# TEST 8: /sigil remove — protection & removal
======================================================================
  ✅ &n provenance == engine-default (protected)
  ✅ &coded removed from registry

======================================================================
# TEST 9: notstop predicate — broad token coverage
======================================================================
  ✅ predicate('photosynthesis') → true (content word)
  ✅ predicate('democracy') → true (content word)
  ✅ predicate('the') → false (stopword filtered)
  ✅ predicate('what') → false (query word filtered)
  ✅ predicate('42') → false (number filtered)
  ✅ predicate('+') → false (operator filtered)

======================================================================
# TEST 10: colormacro promote — lexicon membership predicate
======================================================================
  ✅ predicate('red') → true (in lexicon)
  ✅ predicate('blue') → true (in lexicon)
  ✅ predicate('chair') → false (not in lexicon)

======================================================================
# TEST 11: Full promote pipeline — concept sigil captures content words
======================================================================
  📎 &concept = sky @ pos 1
  📎 &definition = is @ pos 2
  📎 &concept = blue @ pos 3
  ✅ 'blue' promoted to &concept (engine-default takes priority over colormacro)
  ✅ 'sky' promoted to &concept

======================================================================
# TEST 12: Overwrite protection — can't re-register without overwrite=true
======================================================================
  ✅ Duplicate registration correctly threw: SigilConfigError
  ✅ Overwrite registration succeeded

======================================================================
# SUMMARY
======================================================================

Results: 40 ✅ / 0 ❌

