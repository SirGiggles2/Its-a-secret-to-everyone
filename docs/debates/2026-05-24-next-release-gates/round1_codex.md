1. Make the release artifact reproducible before anything else.
Close: `phase17_from_scratch_build_gate` plus the hard part of `phase17_package_check_tool` in `tools/builder/from_scratch_gate.py` and `tools/builder/package_check.py`.
Blast radius: if skipped, v1.0 is just "Jake's machine built something"; the zip can silently carry stale/generated/banned files, and no one can prove `Debug.md` came from the tree.
Effort: 1 focused day, assuming SGDK/toolchain paths are sane.

2. Turn dungeon/live captures from SKIP placeholders into GREEN evidence.
Close: `phase17_final_release_gate` by clearing `phase14_dungeon_harness_population` and `phase11_live_capture_pass`. Files: `tools/dungeon_harness/manifest.json`, `tools/probes/captures/`, `tools/builder/release_gate.py`.
Blast radius: if skipped, the release can pass infrastructure while rooms/dungeons are empirically untested. This is the highest gameplay-risk gap.
Effort: 1-2 days of capture/probe churn.

3. Link and probe runtime audio, then freeze the WIP.
Close: `phase17_final_release_gate` by clearing `task_10_3_audio_link_into_debug_md` and `task_10_5_audio_probes_runtime`. Files: `data/audio_music/ow_theme_vgm.c`, `data/audio_music/ow_theme_pcm.{c,h}`, `src/sgdk_adapter/audio_adapter.c`, `builds/Debug.md`.
Blast radius: if skipped, shipped v1.0 either has missing/regressed music or unasserted audio behavior; that is release-visible, not cosmetic.
Effort: 0.5-1 day.

Codex — Round 1 opening
