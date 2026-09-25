# T-123 InitLinkSpeed + T-124 room entry / OW object tail

Build: Debug.bat (main), lockstep suite tags t122/t123/t124 (%TEMP%\claude\suite).

## T-123
Preset `tools/lockstep/presets/t123_slow_tiles.json`: route $77->$78->$68->$58->$48->$38->$28->$27->$17,
then Link at (col 4, row 5) holding Up over the $74/$75 column.
Per-frame NES vs GEN (same frame index), f1630-f1692: $3BC (q-speed $60 -> $30 at f1636),
$3A8 frac, $84 Y, $394 grid, $49E ($26 -> $75) all equal.

## T-124
NES sources: Z_05.asm InitMode_EnterRoom (ClearRam0300UpTo $051F, SetupObjRoomBounds),
Z_04.asm CheckZora / UpdateZora, Z_07.asm UpdateMode5Play tail (heart warning, sea sound, CheckZora),
Z_07.asm @LoopObject ("Update objects from $B to 1").
- Zora $11 + ZoraActive $514: NES/GEN spawn in the same slot (10 or 11) on NES frame +1 in rooms
  $48 $38 $28 $27 $17 (before: never spawned on GEN).
- Fireball $55 (slot 9, room $48): after loop-order fix the init/move sequence matches NES
  (before: destroyed on the first move frame because RoomBound $346-$349 were 0).
- RoomBounds $346-$34A = $11 $E0 $4E $CD $89 (OW) = NES.
- Suite (slotmatch.py, enemy slots 1..11 type/X/Y/state vs NES within gen lag 0-2):
  t050_layout_plain 33.3 -> 63.3%, t050_layout_secret 16.7 -> 54.2%, t050_rock 25.7 -> 38.5%,
  t050_tree 19.4 -> 33.5%, t114_uw_wall 22.6 -> 32.1%, t050_pond_fairy 43.9 -> 49.1%; others equal.
- ClearRam0300UpTo long-word fast path: removed the room-entry lag frame the byte loop added (t114 f988).
- Lag total gen/nes: t124 105/108. Over NES: t114 39/37, t123_slow_tiles 18/16 -> T-125.
