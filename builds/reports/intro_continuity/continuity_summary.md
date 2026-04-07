# Intro Continuity Report

- NES transitions: 1303
- Genesis transitions: 1245
- Matched transitions: 1245
- Compare classes: {'ok': 4, 'display_timing': 1241}
- First-section matched transitions: 815
- First-section divergences: 813
- Genesis-only jump suspects in first section: 0

## First Matched Divergence

- NES 1701->1702 vs GEN 1759->1760: display_timing, shift -1->0, lineWrite 0->0

## First-Section Divergences

| nes | gen | class | segment | curV | line | ctr | lineDst | NES shift | GEN shift | NES write | GEN write |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1701->1702 | 1759->1760 | display_timing | first_section_scroll | 09 | 00 | 01 | 2900 | -1 | 0 | 0 | 0 |
| 1702->1703 | 1760->1761 | display_timing | first_section_scroll | 0A | 00 | 02 | 2900 | 0 | -1 | 0 | 0 |
| 1703->1704 | 1761->1762 | display_timing | first_section_scroll | 0A | 00 | 02 | 2900 | -1 | 0 | 0 | 0 |
| 1704->1705 | 1762->1763 | display_timing | first_section_scroll | 0B | 00 | 03 | 2900 | 0 | -1 | 0 | 0 |
| 1705->1706 | 1763->1764 | display_timing | first_section_scroll | 0B | 00 | 03 | 2900 | -1 | 0 | 0 | 0 |
| 1706->1707 | 1764->1765 | display_timing | first_section_scroll | 0C | 00 | 04 | 2900 | 0 | -1 | 0 | 0 |
| 1707->1708 | 1765->1766 | display_timing | first_section_scroll | 0C | 00 | 04 | 2900 | -1 | 0 | 0 | 0 |
| 1708->1709 | 1766->1767 | display_timing | first_section_scroll | 0D | 00 | 05 | 2900 | 0 | -1 | 0 | 0 |
| 1709->1710 | 1767->1768 | display_timing | first_section_scroll | 0D | 00 | 05 | 2900 | -1 | 0 | 0 | 0 |
| 1710->1711 | 1768->1769 | display_timing | first_section_scroll | 0E | 00 | 06 | 2900 | 0 | -1 | 0 | 0 |
| 1711->1712 | 1769->1770 | display_timing | first_section_scroll | 0E | 00 | 06 | 2900 | -1 | 0 | 0 | 0 |
| 1712->1713 | 1770->1771 | display_timing | first_section_scroll | 0F | 00 | 07 | 2900 | 0 | -1 | 0 | 0 |
| 1713->1714 | 1771->1772 | display_timing | first_section_scroll | 0F | 00 | 07 | 2900 | -1 | 0 | 0 | 0 |
| 1714->1715 | 1772->1773 | display_timing | first_section_line_write | 10 | 01 | 08 | 2920 | 0 | -1 | 1 | 1 |
| 1715->1716 | 1773->1774 | display_timing | first_section_scroll | 10 | 01 | 08 | 2920 | -1 | 0 | 0 | 0 |
| 1716->1717 | 1774->1775 | display_timing | first_section_scroll | 11 | 01 | 09 | 2920 | 0 | -1 | 0 | 0 |
| 1717->1718 | 1775->1776 | display_timing | first_section_scroll | 11 | 01 | 09 | 2920 | -1 | 0 | 0 | 0 |
| 1718->1719 | 1776->1777 | display_timing | first_section_scroll | 12 | 01 | 0A | 2920 | 0 | -1 | 0 | 0 |
| 1719->1720 | 1777->1778 | display_timing | first_section_scroll | 12 | 01 | 0A | 2920 | -1 | 0 | 0 | 0 |
| 1720->1721 | 1778->1779 | display_timing | first_section_scroll | 13 | 01 | 0B | 2920 | 0 | -1 | 0 | 0 |
