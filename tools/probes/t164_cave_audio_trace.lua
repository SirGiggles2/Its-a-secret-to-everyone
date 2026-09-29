-- T-164: observe native song state during the existing controller cave route.
-- CAPTURE is the generated t011_sword_cave lockstep script; it owns boot,
-- input and exit. This wrapper only observes and writes a small trace.
local mus = tonumber("@SYM:audio_music_state@") - 0xFF0000
local out = assert(io.open("@OUT@", "w"))
local last = nil
out:write("frame,mode,target,person,tune0_request,native_song,xgm_owner\n")
event.onframeend(function()
    local function r(a) return memory.read_u8(a, "68K RAM") end
    local mode = r(0x8012)
    local target = r(0x805B)
    local person = r(0x8350)
    local request = r(0x8604)
    local song = r(mus)
    local owner = r(mus + 0x2C)
    local state = string.format("%02X,%02X,%02X,%02X,%02X,%02X",
                                mode, target, person, request, song, owner)
    if state ~= last then
        out:write(string.format("%d,%s\n", emu.framecount(), state))
        out:flush()
        last = state
    end
end, "t164_cave_audio")
dofile("@CAPTURE@")
out:close()
