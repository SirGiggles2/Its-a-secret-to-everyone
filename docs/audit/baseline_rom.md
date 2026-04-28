<!-- docs/audit/baseline_rom.md -->
# Baseline Genesis ROM (locked at S0)

| Field | Value |
|---|---|
| Path | `builds/whatif.md` |
| SHA256 | `4bcfc1d916f44f31f36ee5bc0862b6b696313a264ffcc8373abde87d318befb4` |
| Build date | `2026-04-28T03:59:36Z` |
| Commit | `7f0173d199b8cfe8548cba0e0f442061c2ede682` |

This is the **FINAL TRY known-good ROM** referenced by the design spec
(Section 0). All Genesis-vs-Genesis logical parity checks in S1 diff against
captures from this exact ROM.

WHAT IF builds are **not** the parity baseline.

## S0 build-reproducibility note

S0 locks the hash of the ROM as it currently stands on disk; a fresh
`build.bat` run was deferred to avoid burning toolchain time during audit
work. Reproducibility (re-running the build from this committed source
produces the same hash) is verified at S1 Stage acceptance, not at S0
close. If the S1 reproducibility check produces a different hash, the
locked baseline is updated by spec amendment with the rationale recorded.
