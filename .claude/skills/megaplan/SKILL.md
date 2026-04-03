---
name: megaplan
description: Plan an implementation with full codebase exploration, then adversarial-review the plan via Codex before presenting it. Use when planning non-trivial changes that benefit from a second opinion.
argument-hint: [task description]
user-invocable: true
disable-model-invocation: true
---

# Megaplan: Plan + Adversarial Review

You are running the /megaplan workflow. This is a 3-phase process: Plan, Review, Present.

## Phase 1: Plan (standard /plan workflow)

1. Enter plan mode via EnterPlanMode.
2. Explore the codebase using Explore agents (up to 3 in parallel) to understand the scope.
3. Launch a Plan agent to design the implementation approach.
4. Write the plan to the plan file. The plan must include:
   - **Context**: why this change is needed
   - **Files to modify**: with specific line ranges and existing functions to reuse
   - **Implementation steps**: concrete, ordered, with code-level detail
   - **Verification**: how to test the changes end-to-end
   - **Assumptions**: what you're taking as given

## Phase 2: Adversarial Review via Codex

Once the plan is written to the plan file, **before** calling ExitPlanMode:

1. Read the plan file content back.
2. Launch a `codex:codex-rescue` agent with this prompt structure:

   > **Adversarial review of implementation plan.**
   >
   > You are reviewing a plan for correctness, completeness, and risk. Your job is to find flaws, not to approve. Be skeptical.
   >
   > [paste the full plan content here]
   >
   > Find and report:
   > - **Wrong assumptions**: Does the plan assume something about the code that isn't true?
   > - **Missing steps**: What will break if we follow this plan exactly as written?
   > - **Edge cases**: What inputs, states, or timing conditions does the plan not account for?
   > - **Ordering risks**: Are any steps in the wrong order? Will a later step undo an earlier one?
   > - **Verification gaps**: Can the test plan actually catch the bugs this change is meant to fix?
   > - **Scope creep**: Does the plan do more than necessary? Could it be simpler?
   >
   > Be specific. Reference file paths and line numbers. If the plan is solid, say so — but look hard first.

3. Read the Codex response.
4. Update the plan file with a new section called **"Adversarial Review Findings"** that includes:
   - Each finding from Codex (quoted)
   - Your response: accepted (with plan change) or rejected (with reasoning)
5. If any findings were accepted, update the relevant plan sections to incorporate the fixes.

## Phase 3: Present

1. Call ExitPlanMode to present the reviewed plan to the user.
2. The user sees a plan that has already survived adversarial scrutiny.

## Rules

- Do NOT skip the Codex review. The whole point of /megaplan over /plan is the adversarial pass.
- Do NOT soft-pedal the review prompt. Ask Codex to be harsh.
- Do NOT hide Codex findings that you disagree with. Show them and explain why you rejected them.
- The plan file is the single source of truth. All changes go there.
