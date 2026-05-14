# Phase 10 Task 10.1.1 — Audio Legal Policy (BLOCKING for 10.2)

- **NES source**: N/A — legal-classification task, not a runtime path.
- **Drained C**:  N/A.
- **Coverage**:   N/A.
- **Stance**:     ADOPT — adopts the master-plan default ruling
                  (CHR-model treatment of NES audio data: user owns
                  the ROM, user owns the extracted bytes, builder
                  runs locally on user's machine, public bundle ships
                  builder code only).

## Policy document

`docs/audit/audio_legal_policy.md`. Defines:

1. NES audio data treated identically to CHR: user-owned via
   user-supplied ROM.
2. Public release ships builder source, not extracted audio.
3. Fallback path: authored Genesis-native music if CHR-model ruling
   is formally challenged.
4. `tools/builder/package_check.py` extended to refuse audio binaries
   in public release bundles unless generated from user ROM at build
   time (implementation work tracked under packaging path).

## Unblocks

Task 10.2 (Builder Audio Extraction) — previously BLOCKING. Legal
ruling lets the builder extraction pipeline run without ambiguity.

## Status

CLOSE — Task 10.1.1 legal policy LOCKED. Task 10.2 unblocked.
