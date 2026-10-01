## Open (bug candidates)

| Cell | Name | Presets | Earliest (preset@tick) |
|---|---|---|---|
| $0059 | EmptyMonsterSlot | 15 | t123_slow_tiles@172, hud_marker@185, ow_walk@185, t050_pond_fairy@241 |
| $0065 | UndergroundEntranceTile | 11 | t111_dark_candle@32, t123_slow_tiles@32, t054_uw_block42_nes@668, t114_uw_wall@668 |
| $0010 | CurLevel | 10 | t054_uw_block42_nes@787, t114_uw_wall@787, t128_uw_blocks@787, t129_enemy_sweep@787 |
| $005B | TargetMode | 10 | t054_uw_block42_nes@787, t114_uw_wall@787, t128_uw_blocks@787, t129_enemy_sweep@787 |
| $03D0 | ObjAnimCounter | 9 | t134_cave_exit@443, t011_exit_idle@709, t011_sword_cave@709, t011_sword_swing_exit@709 |
| $0011 | IsUpdatingMode | 6 | t134_cave_exit@443, t011_exit_idle@709, t011_sword_cave@709, t011_sword_swing_exit@709 |
| $0394 | ObjRemDistance | 6 | t134_cave_exit@443, t011_exit_idle@709, t011_sword_cave@709, t011_sword_swing_exit@709 |
| $03A8 | Item_ObjItemLifetime | 6 | t134_cave_exit@443, t011_exit_idle@709, t011_sword_cave@709, t011_sword_swing_exit@709 |
| $03E4 | ObjAnimFrame | 4 | t012_route@140, t013_route@140, t114_uw_wall@1044, t131_uw_ndoor@1056 |
| $0052 | ProcessedNarrowObj | 3 | t121_ring1@106, t121_ring2@106, t013_route@4111 |
| $00C1 | ObjShoveDir+1 | 3 | save_roundtrip@131, t013_save@255, t013_route@7467 |
| $00C2 | ObjShoveDir+2 | 3 | save_roundtrip@131, t013_save@255, t013_route@6734 |
| $00C3 | ObjShoveDir+3 | 3 | save_roundtrip@131, t013_save@255, t013_route@6773 |
| $00C5 | ObjShoveDir+5 | 3 | save_roundtrip@131, t013_save@255, t013_route@4620 |
| $005A | UndergroundExitType | 2 | t132_uw_exit@911, t013_route@8465 |
| $00C0 | ObjShoveDir | 2 | save_roundtrip@132, t013_save@256 |
| $00C4 | ObjShoveDir+4 | 2 | save_roundtrip@131, t013_save@255 |
| $00C6 | ObjShoveDir+6 | 2 | save_roundtrip@131, t013_save@255 |
| $00C7 | ObjShoveDir+7 | 2 | save_roundtrip@131, t013_save@255 |
| $00C8 | ObjShoveDir+8 | 2 | save_roundtrip@131, t013_save@255 |
| $00C9 | ObjShoveDir+9 | 2 | save_roundtrip@131, t013_save@255 |
| $00CA | ObjShoveDir+10 | 2 | save_roundtrip@131, t013_save@255 |
| $00CB | ObjShoveDir+11 | 2 | save_roundtrip@131, t013_save@255 |
| $00CC | ObjShoveDir+12 | 2 | save_roundtrip@131, t013_save@255 |
| $00CD | ObjShoveDir+13 | 2 | save_roundtrip@131, t013_save@255 |
| $00CE | ObjShoveDir+14 | 2 | save_roundtrip@131, t013_save@255 |
| $00CF | ObjShoveDir+15 | 2 | save_roundtrip@131, t013_save@255 |
| $00EE | CurOpenedDoors | 2 | t132_uw_exit@911, t013_route@5421 |
| $0027 | DoorTimer | 1 | t013_route@5413 |
| $0054 | TriggeredDoorCmd | 1 | t013_route@5413 |
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
| $042D | Gleook_HeadInfo1 | 1 | t129_enemy_sweep@6400 |
| $04CE | ShutterTrigger | 1 | t013_route@5413 |
| $04E5 | StatusBarMapTrigger | 1 | t013_route@6987 |
| $0521 | PrevOpenedDoors | 1 | t132_uw_exit@911 |

## Accepted (Genesis-native or better)

| Cell | Name | Presets | Reason |
|---|---|---|---|
| $0342 | FirstSpriteIndex | 51 | FirstSpriteIndex: same NES OAM flicker rotation (better) |
| $0341 | RollingSpriteIndex | 24 | RollingSpriteIndex: NES OAM rotation for 8-per-line flicker; Genesis draws all sprites, no flicker (better) |
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
