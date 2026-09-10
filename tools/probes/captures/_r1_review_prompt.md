Review ONE small change to a BizHawk Lua probe (RULE V2) BEFORE running it. Genesis (genplus Waterbox) Zelda port. The probe enters a cave to capture the descent; I'm fixing a probe artifact where Link's DESCENT-window X was $78 (teleport-park) instead of NES's $70.

## Facts (verified)
- Real `players[]` struct = M68K $FF1570 (nm Debug.out: `players`=e0ff1570; objdump roomrom_debug_get_link_y reads players+0x2). .x word @ $FF1570, .y word @ $FF1572. 68K = big-endian (hi byte at lower addr).
- `w8(o,v)` writes M68K BUS at $FF0000+o. So w8(0x1570,..) = $FF1570.
- The probe's `write_link_xy` uses legacy offset $1564 (a NO-OP for this build) — kept ONLY so `navigate_to_room`'s pre-teleport park doesn't disrupt the MODE_TELEPORT state machine (setting the real addr DURING teleport crashed the run last time).
- nes_ram ObjX mirror ($FF8070) is re-synced from the real players[].x each frame; that's why seeding only the mirror didn't hold.
- Cave-entry gate (main.c) fires on `players[0].y & 0x0F == 0x0D` + standing tile $24; NO X constraint.
- This change sets the REAL players[] AFTER navigate_to_room returns (teleport done) + idle(30), BEFORE fill_tiles/arm.

## The change (in arm_descent)
```lua
    write_link_xy(0x70, 0x8D)
    w8(0x8000 + 0x70, 0x70)   -- nes mirror seed (harmless)
    w8(0x1570, 0x00); w8(0x1571, 0x70)   -- players[0].x = $0070 (112)
    w8(0x1572, 0x00); w8(0x1573, 0x8D)   -- players[0].y = $008D (y_low=$D)
    fill_tiles(0x24)
    force_mode_walk()
    emu.frameadvance()        -- arm frame
```

## Check (severity + fix)
1. Endianness: is `w8(0x1570,0x00); w8(0x1571,0x70)` the correct way to set a 68K big-endian 16-bit word to $0070 (=112)? hi byte at $1570, lo at $1571?
2. Safe frame: setting real players[].x/.y AFTER navigate_to_room returns + idle(30), BEFORE the arm frame — is this the documented "safe post-teleport frame", or could a game-tick between teleport-exit and this write clobber it / could this write break the subsequent cave-entry gate?
3. Gate: players[0].y=$008D → y_low=$D ✓. Will the gate still fire (saw_cave) with the real .y now explicitly $8D? Any risk the real-.y write moves Link off a valid descent column / outside playfield?
4. Does leaving the no-op write_link_xy($1564) + the redundant nes-mirror seed cause any harm?
5. Any crash/range risk (M68K BUS $FF1570-1573 in 16MB domain — fine)?

VERDICT: APPROVE / APPROVE-WITH-CHANGES / REWORK + highest-priority fix. Terse.
