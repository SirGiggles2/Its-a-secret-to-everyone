-- Diagnostic: dump scene + key cells every 30 frames for 900 frames.
local OUT = "C:\\tmp\\g_sweep\\diag.txt"
local f = io.open(OUT, "w")
f:write("frame\tscene_byte\ts_scene\troom_id\tgamemode\tlevel\tlink_x\tlink_y\n")

for frame = 1, 900 do
    if frame >= 30 and frame <= 300 and (frame % 30) == 0 then
        joypad.set({["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
    end
    emu.frameadvance()
    if (frame % 15) == 0 then
        local scene = memory.read_u8(0x027E, "68K RAM")
        local gm    = memory.read_u8(0x8012, "68K RAM")
        local lvl   = memory.read_u8(0x8010, "68K RAM")
        local room  = memory.read_u8(0x80EB, "68K RAM")
        local lx    = memory.read_u8(0x8070, "68K RAM")
        local ly    = memory.read_u8(0x8084, "68K RAM")
        f:write(string.format("%d\t$%02X\t%d\t$%02X\t$%02X\t$%02X\t$%02X\t$%02X\n",
                              frame, scene, scene, room, gm, lvl, lx, ly))
    end
end

f:close()
print("Diag dump -> " .. OUT)
client.exit()
