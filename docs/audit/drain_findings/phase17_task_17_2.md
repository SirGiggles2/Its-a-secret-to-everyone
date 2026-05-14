# Phase 17 Task 17.2 — Builder UX

- **NES source**: N/A — release UX task.
- **Drained C**:  N/A — Python tooling layer.
- **Coverage**:   PARTIAL — individual builder tools exist
                  (`tools/extract_audio.py`,
                  `tools/extract_uw_collision.py`, CHR extractors).
                  Unified drag-and-drop builder UI NOT shipped.
- **Stance**:     PARTIAL — extractor tools ADOPT; UX shell deferred.

## Master plan checklist

| Item                              | Status                                |
|-----------------------------------|---------------------------------------|
| Drag NES ROM onto builder         | DEFERRED (UX shell)                    |
| Validate ROM                      | DEFERRED (sha256 check exists in `extract_audio.py` manifest) |
| Extract assets                    | ✓ (per-tool individually)             |
| Build final ROM                   | ✓ (`Debug.bat`)                       |
| Show output path                  | ✓ (`Debug.bat` prints `builds/Debug.md`) |
| Write manifest                    | ✓ (per-extractor MANIFEST.json)       |
| Show unsupported ROM error        | DEFERRED                               |
| Show missing dependency error     | DEFERRED (toolchain checks)            |
| Keep troubleshooting logs         | DEFERRED                               |

## Deferral

`phase17_builder_ux_shell` — unified drag-drop builder wrapping
the existing extractors + `Debug.bat`. Single-script entry-point at
`tools/builder/build.py` that orchestrates ROM validation +
extraction + asset cache + ROM build + error messages.

## Status

PARTIAL — Task 17.2 individual extractors + builder script ADOPT;
unified UX shell deferred.
