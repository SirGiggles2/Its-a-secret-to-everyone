# Intro Scroll Diff — Triage Summary

- Paired frames: 2092
- Semantic alignment: best_k=59, ratio=0.938, growing_drift=False
- Capture sizes: NES=(256, 224), GEN=(256, 224)
- meanDelta (raw Y0): avg=4.62  median=2.17
- meanDelta (Y+8 shifted): avg=4.62
- inkMismatch (raw Y0): avg=0.0184  median=0.0010
- inkMismatch (Y+8 shifted): avg=0.0184
- Spikes (>3× median): 978

## Suspect signatures detected

- **#1 H-int dead-zone skip timing** — 4 spikes in F1440–1460 wrap window. `src/nes_io.asm:330-345`.

## Worst 12 Frames (By inkMismatch)

| nes_f | gen_f | maskRaw | maskShifted | meanRaw | top | mid | bot | vsram0 |
|---|---|---|---|---|---|---|---|---|
| 1442 | 1501 | 0.1935 | 0.1935 | 35.0 | 94.5 | 97.9 | 81.4 | 002E |
| 1440 | 1499 | 0.1917 | 0.1917 | 34.8 | 92.4 | 97.9 | 81.4 | 002D |
| 1438 | 1497 | 0.1894 | 0.1894 | 34.6 | 92.4 | 97.9 | 81.4 | 002C |
| 1436 | 1495 | 0.1865 | 0.1865 | 34.3 | 92.4 | 97.9 | 81.4 | 002B |
| 1434 | 1493 | 0.1832 | 0.1832 | 34.0 | 92.4 | 97.9 | 81.4 | 002A |
| 1432 | 1491 | 0.1804 | 0.1804 | 33.7 | 92.4 | 97.9 | 85.0 | 0029 |
| 1430 | 1489 | 0.1781 | 0.1781 | 33.6 | 92.4 | 97.9 | 85.0 | 0028 |
| 1443 | 1502 | 0.1617 | 0.1617 | 30.5 | 93.5 | 96.8 | 78.6 | 002F |
| 1441 | 1500 | 0.1599 | 0.1599 | 30.3 | 93.5 | 96.8 | 78.6 | 002E |
| 1439 | 1498 | 0.1576 | 0.1576 | 30.1 | 93.5 | 96.8 | 78.6 | 002D |
| 1437 | 1496 | 0.1547 | 0.1547 | 29.7 | 93.5 | 96.8 | 78.6 | 002C |
| 1435 | 1494 | 0.1515 | 0.1515 | 29.5 | 93.5 | 96.8 | 78.6 | 002B |
