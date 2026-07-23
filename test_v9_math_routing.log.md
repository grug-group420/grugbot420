# V9 Math Routing Test Log

_Generated: 2026-07-08T22:34:51.295_

## 1. Token-level arithmetic detection

- ✅ **5+5 detected as arithmetic**
- ✅ **3 - 2 detected as arithmetic**
- ✅ **12/4 detected as arithmetic**
- ✅ **7*8 detected as arithmetic**
- ✅ **five plus three detected as arithmetic**
- ✅ **two minus one detected as arithmetic**
- ✅ **3 times 7 detected as arithmetic**
- ✅ **love NOT detected as arithmetic**
- ✅ **meaning of life NOT detected as arithmetic**
- ✅ **fire NOT detected as arithmetic**

## 2. RoutingJudge intent classification

- ✅ **"what is 5+5" → :calculate** — kinds=calculate
- ✅ **"what is 5 plus 5" → :calculate** — kinds=calculate
- ✅ **"what is love" → :question (not :calculate)** — kinds=question
- ✅ **"what is 12 - 4" → :calculate** — kinds=calculate
- ✅ **"what is fire" → :question (not :calculate)** — kinds=question
- ✅ **"sum is 5+5" → :calculate (arithmetic definition)** — kinds=calculate

## 3. RoutingJudge resolve (pick winner)

- ✅ **resolve "what is 5+5" → (:calculate, ...)** — result=(:calculate, "5+5", "", "")
- ✅ **resolve "what is love" → (:question, ...)** — result=(:question, "love", "", "")
- ✅ **resolve "what is 3 plus 4" → (:calculate, ...)** — result=(:calculate, "3 plus 4", "", "")

## 4. Compound question splitting

- ✅ **"what is 5+5 and what is love" splits into 2 sub-intents** — n=2, kinds=calculate,question
- ✅ **  First sub-intent is :calculate**
- ✅ **  Second sub-intent is :question**
- ✅ **"12 - 4 and why is grass green" splits into 2 sub-intents** — n=2, kinds=calculate,question
- ✅ **"add 5 and 3" does NOT split (arithmetic context)** — n=1
- ✅ **"what is love" does NOT split (single question)** — n=1, kinds=nothing

## 5. Sub-text classification

- ✅ **_classify_sub_text "what is 5+5" → :calculate** — kind=calculate, topic=5+5
- ✅ **_classify_sub_text "what is love" → :question** — kind=question, topic=love
- ✅ **_classify_sub_text "5+5" → :calculate** — kind=calculate, topic=5+5
- ✅ **_classify_sub_text "why is grass green" → :question** — kind=question, topic=grass green

## 6. _conversation_prescan integration

- ✅ **_conversation_prescan "what is 5+5" → :calculate** — kind=calculate
- ✅ **_conversation_prescan "what is love" → :question** — kind=question
- ✅ **_conversation_prescan "what is 5+5 and what is love" → :compound** — kind=compound
- ✅ **_conversation_prescan "what is 3 plus 4" → :calculate** — kind=calculate

## 7. End-to-end arithmetic via process_mission

- ✅ **process_mission "what is 5+5" → answer contains 10** — voice='5 plus 5 equals 10'
- ✅ **process_mission "what is 3 plus 4" → answer contains 7** — voice='3 plus 4 equals 7'
- ✅ **process_mission "what is 12 - 4" → answer contains 8** — voice='12 minus 4 equals 8'

## 8. Compound question end-to-end

- ✅ **compound "what is 5+5 and what is love" → has 10** — voice='5 plus 5 equals 10; 📖 love: a deep affection'
- ✅ **compound "what is 5+5 and what is love" → has love info** — voice='5 plus 5 equals 10; 📖 love: a deep affection'
- ✅ **compound "what is 3 times 2 and why is grass green" → has 6** — voice='3 times 2 equals 6; Grug not know 'grass green'. What does it mean? What subject is it?'

## 9. Edge cases

- ✅ **"what is love and happiness" → :question (single topic)** — kinds=question
- ✅ **"5+5" → :calculate** — kinds=calculate
- ✅ **"sum is 5+5" → :calculate via prescan** — kind=calculate
- ✅ **"fire is oxidation and heat" → :define (not :calculate)** — kind=define

---

**Total:** 43  **Passed:** 43  **Failed:** 0

