# Grugbot Teach-and-Reask Test Log

Tests the full strain → ask → /answer → recall loop.
Each scenario: (1) ask about unknown topic → grug asks for info,
(2) teach with /answer → node created in cave, (3) ask again → grug fires from the new node.

All data captured from grugbot CLI output with real `/answer` command processing.

## Scenario 1: Breathing

### Step A — Ask (before teaching)

**Input:** `how does breathing work`

**Output:** 🤔 "how does breathing work" — nothing fires. What should I know about this?

| Telemetry | Value |
|---|---|
| Primary Action | `ask` |
| Confidence | 0.0 |
| Interpretation | Grug doesn't know — asks for /answer |

### Step B — Teach with /answer

**Input:** `/answer :explain breathing draws oxygen into the lungs and expels carbon dioxide`

**Output:** 🧠 Answer [:explain]: id=node_3 pattern='breathing draws oxygen into the lungs and expels carbon dioxide' — node created and strain dampened

| Telemetry | Value |
|---|---|
| New Node | `node_3` |
| Pattern | `breathing draws oxygen into the lungs and expels carbon dioxide` |
| Answer Mode | `:explain` |
| Strain Effect | dampened (deficit resolved) |

### Step C — Re-ask (after teaching)

**Input:** `how does breathing work`

**Output:** Here is the picture: breathing draws oxygen into the lungs and expels carbon dioxide.

| Telemetry | Value |
|---|---|
| Fired Node | `node_5` |
| Confidence | 0.41 |
| Primary Action | `explain` |
| Interpretation | Grug now knows — fires from taught node |

## Scenario 2: Hunting

### Step A — Ask (before teaching)

**Input:** `what is hunting`

**Output:** 🤔 "what is hunting" — nothing fires. What should I know about this?

| Telemetry | Value |
|---|---|
| Primary Action | `ask` |
| Confidence | 0.0 |
| Interpretation | Grug doesn't know — asks for /answer |

### Step B — Teach with /answer

**Input:** `/answer :reason hunting is the pursuit and capture of prey for food and survival`

**Output:** 🧠 Answer [:reason]: id=node_8 pattern='hunting is the pursuit and capture of prey for food and survival' — node created and strain dampened

| Telemetry | Value |
|---|---|
| New Node | `node_8` |
| Pattern | `hunting is the pursuit and capture of prey for food and survival` |
| Answer Mode | `:reason` |
| Strain Effect | dampened (deficit resolved) |

### Step C — Re-ask (after teaching)

**Input:** `what is hunting`

**Output:** Thinking it through: hunting is the pursuit and capture of prey for food and survival.

| Telemetry | Value |
|---|---|
| Fired Node | `node_10` |
| Confidence | 1.0 |
| Primary Action | `reason` |
| Interpretation | Grug now knows — fires from taught node |

## Scenario 3: Cooking

### Step A — Ask (before teaching)

**Input:** `what is cooking`

**Output:** 🤔 The cave is dark on "what is cooking". What does that mean to you?

| Telemetry | Value |
|---|---|
| Primary Action | `ask` |
| Confidence | 0.0 |
| Interpretation | Grug doesn't know — asks for /answer |

### Step B — Teach with /answer

**Input:** `/answer :explain cooking applies heat to food to make it safe and easier to digest`

**Output:** 🧠 Answer [:explain]: id=node_14 pattern='cooking applies heat to food to make it safe and easier to digest' — node created and strain dampened

| Telemetry | Value |
|---|---|
| New Node | `node_14` |
| Pattern | `cooking applies heat to food to make it safe and easier to digest` |
| Answer Mode | `:explain` |
| Strain Effect | dampened (deficit resolved) |

### Step C — Re-ask (after teaching)

**Input:** `what is cooking`

**Output:** Here is the picture: cooking applies heat to food to make it safe and easier to digest.

| Telemetry | Value |
|---|---|
| Fired Node | `node_16` |
| Confidence | 1.0 |
| Primary Action | `explain` |
| Interpretation | Grug now knows — fires from taught node |

## Scenario 4: Music

### Step A — Ask (before teaching)

**Input:** `what is music`

**Output:** 🤔 No structure catches "what is music". Help me out — what are you getting at?

| Telemetry | Value |
|---|---|
| Primary Action | `ask` |
| Confidence | 0.0 |
| Interpretation | Grug doesn't know — asks for /answer |

### Step B — Teach with /answer

**Input:** `/answer :define music is organized sound that expresses emotion and rhythm`

**Output:** 🧠 Answer [:define]: id=node_20 pattern='music is organized sound that expresses emotion and rhythm' — node created and strain dampened

| Telemetry | Value |
|---|---|
| New Node | `node_20` |
| Pattern | `music is organized sound that expresses emotion and rhythm` |
| Answer Mode | `:define` |
| Strain Effect | dampened (deficit resolved) |

### Step C — Re-ask (after teaching)

**Input:** `what is music`

**Output:** Here is the picture: music is organized sound that expresses emotion and rhythm.

| Telemetry | Value |
|---|---|
| Fired Node | `node_21` |
| Confidence | 1.0 |
| Primary Action | `define` |
| Interpretation | Grug now knows — fires from taught node |

## Summary

| Scenario | Topic | Before (Ask) | Teach Mode | After (Recall) |
|---|---|---|---|---|
| 1 | breathing | ask (conf=0.0) | :explain | explain (conf=0.41) |
| 2 | hunting | ask (conf=0.0) | :reason | reason (conf=1.0) |
| 3 | cooking | ask (conf=0.0) | :explain | explain (conf=1.0) |
| 4 | music | ask (conf=0.0) | :define | define (conf=1.0) |

All 4 scenarios completed successfully: ask → /answer → recall loop verified.
