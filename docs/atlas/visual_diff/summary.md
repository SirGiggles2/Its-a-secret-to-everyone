# Visual Diff Summary

States total: 256
  - Missing captures: 0
  - Skipped (Genesis-only pages 2/3): 128
  - Clean (0 REAL_DIFF cells): 32
  - With REAL_DIFF: 96

## Cell category totals (across all audited states)

| Category | Cells |
|---|---|
| CLEAN | 79576 |
| REAL_DIFF | 12914 |
| SPARSE_BLANK | 18502 |
| COVERAGE_GAP | 3696 |

Category meanings:
- CLEAN: NES + Genesis identical (after 3-bit quantize + alignment).
- REAL_DIFF: both render content but pixels differ. Likely palette routing, atlas drift, or alignment slip — investigate.
- SPARSE_BLANK: Genesis renders blank; NES has content. Expected: bg_sparse_tile_lut deliberately excludes unused tile_ids (VRAM headroom design).
- COVERAGE_GAP: NES blank; Genesis has content. Anomalous — Genesis shows tile NES doesn't.

## REAL_DIFF cells per page

| Page | REAL_DIFF cells |
|---|---|
| 0 | 2548 |
| 1 | 8216 |

## States with REAL_DIFF (top 20)

| State | REAL_DIFF cells |
|---|---|
| bank1_sub0_page1_8x160 | 154 |
| bank1_sub0_page1_8x161 | 154 |
| bank1_sub1_page1_8x160 | 154 |
| bank1_sub1_page1_8x161 | 154 |
| bank1_sub2_page1_8x160 | 154 |
| bank1_sub2_page1_8x161 | 154 |
| bank1_sub3_page1_8x160 | 154 |
| bank1_sub3_page1_8x161 | 154 |
| bank6_sub0_page1_8x160 | 154 |
| bank6_sub0_page1_8x161 | 154 |
| bank6_sub1_page1_8x160 | 154 |
| bank6_sub1_page1_8x161 | 154 |
| bank6_sub2_page1_8x160 | 154 |
| bank6_sub2_page1_8x161 | 154 |
| bank6_sub3_page1_8x160 | 154 |
| bank6_sub3_page1_8x161 | 154 |
| bank5_sub0_page1_8x160 | 153 |
| bank5_sub0_page1_8x161 | 153 |
| bank5_sub1_page1_8x160 | 153 |
| bank5_sub1_page1_8x161 | 153 |
