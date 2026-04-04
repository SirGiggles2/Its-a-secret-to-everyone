# Intro Scroll Diff — Triage Summary

- Paired frames: 631
- Semantic alignment: best_k=20, ratio=0.954, growing_drift=False
- meanDelta (raw Y0): avg=13.86  median=12.13
- meanDelta (Y+8 shifted): avg=16.68
- Spikes (>3× median): 0

## Suspect signatures detected

- No strong signature match; inspect `intro_diff_strip.png` manually.

## Worst 12 frames (by meanRaw)

| nes_f | gen_f | meanRaw | meanShifted | top | mid | bot | vsram0 |
|---|---|---|---|---|---|---|---|
| 1442 | 1462 | 35.2 | 44.9 | 120.2 | 122.9 | 91.6 | 0010 |
| 1440 | 1460 | 34.9 | 44.6 | 118.7 | 123.2 | 92.4 | 000F |
| 1436 | 1456 | 34.9 | 44.2 | 113.0 | 122.3 | 88.8 | 000D |
| 1438 | 1458 | 34.8 | 44.1 | 114.9 | 123.0 | 91.4 | 000E |
| 1432 | 1452 | 34.3 | 43.4 | 108.5 | 120.0 | 88.1 | 000B |
| 1434 | 1454 | 34.3 | 43.4 | 110.8 | 121.3 | 88.3 | 000C |
| 1430 | 1450 | 34.0 | 43.0 | 110.5 | 118.7 | 87.9 | 000A |
| 1428 | 1448 | 33.6 | 42.5 | 112.9 | 117.2 | 92.8 | 0009 |
| 1426 | 1446 | 33.6 | 42.4 | 115.2 | 116.3 | 95.9 | 0008 |
| 1424 | 1444 | 33.6 | 42.3 | 117.4 | 115.9 | 98.9 | 0007 |
| 1422 | 1442 | 33.5 | 42.3 | 119.2 | 116.5 | 101.4 | 0006 |
| 1420 | 1440 | 33.5 | 42.2 | 120.5 | 115.3 | 102.9 | 0005 |
