# $4B..$52 UW Person family

- **NES source**: reference/aldonunez/Z_01.asm:1000 InitUnderworldPerson_Full + UpdateUnderworldPerson
- **Drained C**:  src/game/cave/uw_person_dispatch.c uw_person_init_dispatch_by_level + uw_person_update_person_full + uw_person_update_life_or_money_full
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: dungeon hint/sell NPCs. Per-level dispatch via CurLevel
($0010):
- L0=DoNothing
- L1/L2/L5/L7=A
- L3/L4/L6/L8=B
- L9=C

Types $4B-$50, $52 = UpdateUnderworldPerson (dispatch by NES table).
$51 = UpdateUnderworldPersonLifeOrMoney (gambling NPC). Text/dialog
driven; no movement/attack parity work (NPC).
