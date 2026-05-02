/* RoomRom Phase 0 capability probe.
 *
 * Does the SGDK m68k gcc toolchain support C11 _Static_assert?
 *
 * Pass: this file compiles cleanly (-c). Atlas pipeline picks the
 *       _Static_assert path in RoomRom/src/atlas/atlas_static_assert.h.
 * Fail: gcc errors with "_Static_assert undeclared" or similar. Atlas
 *       pipeline falls back to the C89 typedef-array trick.
 *
 * Driver: tools/phase0_probe.bat (compiles this with the SGDK toolchain
 * and writes the result into atlas_static_assert.h).
 *
 * Spec: docs/superpowers/specs/2026-05-01-roomrom-z1-full-atlas-design.md
 *       Section 6.4 + Phase 0 in Section 10. */

_Static_assert(sizeof(int) >= 4, "C11 _Static_assert available");
_Static_assert(sizeof(char) == 1, "char is 1 byte (sanity)");

/* Ensure something stays in the .data section so the object file is
 * non-empty (some toolchains optimise empty TUs away). */
int phase0_static_assert_probe_ok = 1;
