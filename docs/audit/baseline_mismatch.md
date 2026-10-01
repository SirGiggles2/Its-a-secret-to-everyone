## Open (bug candidates)

| Cell | Name | Presets | Earliest (preset@tick) |
|---|---|---|---|
| $049E | ObjCollidedTile | 11 | t111_dark_candle@33, t123_slow_tiles@33, t012_route@140, t013_route@140 |
| $03D0 | ObjAnimCounter | 8 | t134_cave_exit@443, t011_exit_idle@709, t011_sword_cave@709, t011_sword_swing_exit@709 |
| $0052 | ProcessedNarrowObj | 3 | t121_ring1@106, t121_ring2@106, t013_route@4111 |
| $03E4 | ObjAnimFrame | 3 | t114_uw_wall@1044, t131_uw_ndoor@1056, t013_route@6878 |
| $005A | UndergroundExitType | 2 | t132_uw_exit@911, t013_route@8465 |
| $00EE | CurOpenedDoors | 2 | t132_uw_exit@911, t013_route@5421 |
| $0027 | DoorTimer | 1 | t013_route@5413 |
| $0054 | TriggeredDoorCmd | 1 | t013_route@5413 |
| $0059 | EmptyMonsterSlot | 1 | t129_enemy_sweep@4829 |
| $00C1 | ObjShoveDir+1 | 1 | t013_route@7467 |
| $00C2 | ObjShoveDir+2 | 1 | t013_route@6734 |
| $00C3 | ObjShoveDir+3 | 1 | t013_route@6773 |
| $00C5 | ObjShoveDir+5 | 1 | t013_route@4620 |
| $00D4 | ObjShoveDistance+1 | 1 | t013_route@7467 |
| $00D5 | ObjShoveDistance+2 | 1 | t013_route@6734 |
| $00D6 | ObjShoveDistance+3 | 1 | t013_route@6773 |
| $00D8 | ObjShoveDistance+5 | 1 | t013_route@4620 |
| $00EC | NextRoomId | 1 | t132_uw_exit@911 |
| $03BC | Moldorm_ObjBounceDir | 1 | t111_dark_candle@1108 |
| $0406 | ObjMetastate+1 | 1 | t013_route@7467 |
| $0407 | ObjMetastate+2 | 1 | t013_route@6734 |
| $0408 | ObjMetastate+3 | 1 | t013_route@6773 |
| $040A | ObjMetastate+5 | 1 | t013_route@4620 |
| $04CE | ShutterTrigger | 1 | t013_route@5413 |
| $04E5 | StatusBarMapTrigger | 1 | t013_route@6987 |
| $0521 | PrevOpenedDoors | 1 | t132_uw_exit@911 |

## Accepted (Genesis-native or better)

| Cell | Name | Presets | Reason |
|---|---|---|---|
| $0342 | FirstSpriteIndex | 67 | FirstSpriteIndex: same NES OAM flicker rotation (better) |
| $0341 | RollingSpriteIndex | 40 | RollingSpriteIndex: NES OAM rotation for 8-per-line flicker; Genesis draws all sprites, no flicker (better) |
| $0058 | VScrollAddrHi | 16 | VScrollAddrHi: NES PPU name-table address of the vertical scroll; Genesis scrolls planes |
| $0412 | TriforceGlowTimer | 8 | TriforceGlowTimer ($412+0): one-tick sprite-helper scratch at cave entry, cleared by InitMode_EnterRoom the next tick |
| $00E3 | IsSprite0CheckActive | 7 | IsSprite0CheckActive: NES sprite-0 status-bar split; Genesis HUD is a window plane |
| $00E9 | CurRow | 7 | CurRow: NES row-by-row PPU transfer counter during loads; Genesis loads faster (better) |
| $005C | SwitchNameTablesReq | 5 | SwitchNameTablesReq: NES pause-menu name-table switch; native Genesis menu (T-165, user: function not memory) |
| $005D | CurScanRoomId | 5 | CurScanRoomId: NES pause-menu map scan; native Genesis menu (T-165) |
| $005E | SubmenuScrollProgress | 5 | SubmenuScrollProgress: NES pause-menu scroll; native Genesis menu (T-165) |
| $00E1 | MenuState | 5 | MenuState: NES pause-menu scroll states; native Genesis menu (T-165) |
| $00FC | CurVScroll | 5 | CurVScroll: NES pause-menu vertical scroll; native Genesis menu (T-165) |
| $00ED | PrevRow | 1 | PrevRow: NES PPU row bookkeeping of the scroll transfer |
| $052F | MazeStep | 1 | MazeStep: same value ~1 tick earlier (Genesis runs CheckMazes at the screen edge to stage the next room) |
