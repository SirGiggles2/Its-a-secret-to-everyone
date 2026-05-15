/* Phase 9.7 — Mode 8 ContinueQuestion public API.
 *
 * NES source: reference/aldonunez/Z_05.asm:2207 UpdateMode8ContinueQuestion_Full.
 * Drained C:  NONE (greenfield REPLACE per Drain Rule D1).
 * Coverage:   FULL — verbatim per-line transcription.
 * Stance:     REPLACE.
 *
 * Caller must populate ButtonsPressed (RAM $F7) before invoking.
 * Caller is the gameplay-mode dispatcher (Phase 9.7 follow-up).
 */

#ifndef MODE_CONTINUE_QUESTION_H
#define MODE_CONTINUE_QUESTION_H

void mode8_continue_question_update(void);

#endif
