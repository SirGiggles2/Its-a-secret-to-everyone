# Phase 17 Task 17.4 — Release Documentation

- **NES source**: N/A — release docs.
- **Drained C**:  N/A.
- **Coverage**:   PARTIAL — `README.md` exists at root (126 LOC);
                  `CLAUDE.md` documents operating rules; per-phase
                  drain findings docs cover technical history.
                  User-build instructions + troubleshooting +
                  contributor guide for release packaging NOT
                  unified into one user-facing doc.
- **Stance**:     PARTIAL — substrate doc set ADOPT; release-shaped
                  user docs deferred.

## Master plan checklist

| Item                                                           | Status |
|----------------------------------------------------------------|--------|
| User build instructions                                        | DEFERRED (release docs PR) |
| Supported ROM hash                                             | ✓ (pinned in `data/audio/MANIFEST.json` + per-extractor manifests) |
| Optional Redux input instructions                              | DEFERRED |
| Troubleshooting                                                | DEFERRED |
| Legal note: user must supply their own ROM                     | ✓ (Phase 10.1.1 legal policy locked at `docs/audit/audio_legal_policy.md`) |
| Contributor guide: do not commit generated copyrighted assets  | ✓ (CLAUDE.md + audio_legal_policy.md) |
| Verification guide                                             | DEFERRED |

## Deferral

`phase17_release_documentation` — unified user-facing release docs
at `docs/RELEASE.md` (user build instructions + troubleshooting +
ROM hash list + Redux toggles + verification guide). Builds on
existing `README.md` + `CLAUDE.md` + `docs/audit/audio_legal_policy.md`.

## Status

PARTIAL — Task 17.4 substrate docs ADOPT; user-facing release
documentation deferred.
