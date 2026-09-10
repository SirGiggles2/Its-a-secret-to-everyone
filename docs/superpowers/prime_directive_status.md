# Prime Directive — Status

_Generated 2026-08-03T05:04:38.446881+00:00 by `prime_refresh.py`._

**Phase:** 17 — Public Builder Release
**Task:** ? — 
**Worktree:** `feat/cave-entry-transition-parity` at `C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY`
**Substrate writer:** False

**Gates:** 11 passed / 11 total

**Blockers:**
- **worktree** — Substrate edit on non-main worktree: data/audio_music/ow_theme_vgm.c (WT-1)
- **worktree** — Substrate edit on non-main worktree: data/audio_music/ow_theme_vgm.h (WT-1)
- **worktree** — Substrate edit on non-main worktree: src/sgdk_adapter/audio_adapter.c (WT-1)
- **worktree** — Substrate edit on non-main worktree: data/audio_music/lm_zelda_ow.bin (WT-1)
- **worktree** — Substrate edit on non-main worktree: data/audio_music/lm_zelda_ow_patched.vgm (WT-1)
- **worktree** — Substrate edit on non-main worktree: data/audio_music/ow_theme.bin (WT-1)
- **worktree** — Substrate edit on non-main worktree: data/audio_music/ow_theme_pcm.c (WT-1)
- **worktree** — Substrate edit on non-main worktree: data/audio_music/ow_theme_pcm.h (WT-1)
- **worktree** — Substrate edit on non-main worktree: data/audio_music/ow_theme_xgm.c (WT-1)
- **worktree** — Substrate edit on non-main worktree: data/audio_music/ow_theme_xgm.h (WT-1)
- **worktree** — Substrate edit on non-main worktree: data/audio_music/sonic1.bin (WT-1)
- **worktree** — Substrate edit on non-main worktree: data/audio_music/sonic1.xgm (WT-1)
- **worktree** — Substrate edit on non-main worktree: data/audio_music/uw_theme_xgm.c (WT-1)
- **worktree** — Substrate edit on non-main worktree: data/audio_music/uw_theme_xgm.h (WT-1)

**Out-of-phase tasks:** 16
- target PhPlan v5b Tier 5 + Tier 2 ship · stance REPLACE · T5.5 audio_dispatch_tick reorder AFTER GameMode-CD restore (
- target Phphase8 · stance PARTIAL · RULE V1 byte-exact parity unverified
- target Phcave-entry-transition · stance REPLACE · Byte-exact descent/load-hold/emerge/floor + 6-frame anim + s

**Next concrete action:** Phase 8 Task 8.1 Boss Framework: scaffold src/game/enemies/bosses/ + src/state/boss_state.h substrate; drain entry: python tools/audit/drain_coverage.py --phase 8
