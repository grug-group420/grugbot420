# AGENT_RULES — READ BEFORE TOUCHING THIS REPO

## RULE #1 — NEVER FORK / NEVER CREATE A NEW BRANCH

**DO NOT** create a new branch, fork, or working branch under any circumstance
unless the user has **explicitly and literally** said:

  > "fork this"  /  "make a new branch"  /  "branch off"

If the user just says "do X" or "add Y" or "fix Z":
  - Work directly on the branch that is **currently checked out**.
  - If you don't know which branch you should be on, **ASK FIRST** before doing anything.
  - Do NOT invent a `feat/...` or `fix/...` branch "to be safe". That is the
    opposite of safe. It splits the codebase and wastes the user's time.

This rule exists because in the v7.22 lobe-dynamics work, the agent created
`feat/v7.22-lobe-dynamics-followups` off `origin/main` and built parallel
inline patches there, while the user's actual work was already living on
`origin/v7.15-updates` (LobeOrchestrator, GroupRegistry, CrystalizeTag,
ChatterVoteSwap, DynamicActionTonePredictor, PhagyGroupOrganizer, etc.).

The result: two parallel implementations of the same spec, and hours of
the user's time burned. **Do not repeat this.**

## RULE #2 — BEFORE ANY WORK, ORIENT ON THE BRANCH GRAPH

First commands of any session that touches code:

```
git branch -a
git log --all --oneline | head -40
git log --all --oneline | grep -iE "<feature keywords from the user>"
```

If a branch matching the user's described work already exists, **that is the
branch you work on.** Switch to it. Do not start a new one off `main`.

## RULE #3 — IF YOU MUST DEVIATE, ASK

If after orienting you genuinely think a new branch is the right move,
**stop and ask the user** with the `ask` tool, in plain words, before
creating anything. Show them which existing branches you found and why
you think a new one is needed.

## RULE #4 — DO NOT DELETE BRANCHES WITHOUT EXPLICIT NAMED CONFIRMATION

`git push origin --delete <branch>` requires the user to have named the
exact branch to delete in this session. "Clean up" / "remove redundant"
is NOT permission to delete a branch. Ask first, every time.

## RULE #5 — "REMOVE REDUNDANT" MEANS CONSOLIDATE, NOT DUPLICATE

If the user says "remove redundant bullshit", that is a signal that
parallel implementations already exist. Find them (Rule #2) before
writing new code. Merging an existing branch into the working branch
is almost always the right move; writing a third parallel version is
almost always wrong.

---

These rules supersede any default "create a feature branch" instinct.
