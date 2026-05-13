---

## Session summary

| Metric                              | Value                         |
|-------------------------------------|-------------------------------|
| Total CLI turns                     | 31                            |
| /mission prompts                    | 17                            |
| /mission successful votes           | 13                            |
| /mission cave-silent                | ~4                            |
| Feedback turns (/right, /wrong)     | 2                             |
| /brainstorm turns                   | 1                             |
| Inspection turns (/status etc.)    | 7                             |
| Total nodes in cave                 | 51 (3 boot + 48 seeded)       |
| Lobes                               | 6 (science, technology,       |
|                                     | philosophy, nature,           |
|                                     | daily_life, emotions)         |
| Lobe connections                    | 5                             |
| Node attachments                    | 12                            |
| Groups registered                   | 5 (16 members total)          |
| Crystalized nodes                   | 4                             |
| Orchestration rules                 | 7                             |
| Pinned memories                     | 6                             |
| Verb classes                        | 7 (27 verbs, 4 synonyms)      |
| Negative thesaurus entries          | 3                             |
| AIML tribe nodes                    | 6 (one per lobe)              |
| Specimen file size (gzipped)        | ~25 KB                        |
| Specimen file size (expanded JSON)  | ~163 KB                       |
| Errors encountered during test      | 0 (after fixes; see           |
|                                     | V7.15.3_SEED_LIVE_TEST_FIXES) |
| Pkg.test() status after fixes       | 36/36 passing                 |

## Bugs found and fixed during this run

1. **`/newLobe` created a LobeTable in the wrong module** — every
   `/lobeGrow` failed with `No table found for lobe 'X'`. Fixed by
   reusing the parent-module copy in `src/Lobe.jl` and dropping the
   duplicate `include("LobeTable.jl")` from `src/Main.jl`.
2. **Nine `$VAR!` interpolation landmines** — one of them
   (`$MAX_ATTACHMENTS!` in `/nodeAttach`) was already crashing in
   production. All fixed by wrapping in `$(var)`.
3. **`MESSAGE_LOCK` typo silently disabled pinned-memory citations**
   — the surrounding `try/catch ... @warn` demoted the
   `UndefVarError` to a warning. Fixed to lock the real global
   `MESSAGE_HISTORY_LOCK`. Pinned notes now reach the synthesis path.

See `V7.15.3_SEED_LIVE_TEST_FIXES.md` for full root-cause writeups.
