## Open (bug candidates)

| Cell | Name | Presets | Earliest (preset@tick) |
|---|---|---|---|

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
| $0052 | ProcessedNarrowObj | 3 | ProcessedNarrowObj: Anim_WriteItemSprites scratch, last value set by NES status-bar item draws (Genesis HUD is native); read only by the item-lift draw right after setting it |
| $052F | MazeStep | 1 | MazeStep: same value ~1 tick earlier (Genesis runs CheckMazes at the screen edge to stage the next room) |
