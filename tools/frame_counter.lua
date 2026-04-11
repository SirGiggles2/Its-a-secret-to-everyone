-- Frame counter + scroll state overlay for debugging intro scroll issues

local RAM_BASE = 0xFF0000
local PPU_BASE = 0xFF0800

local frame = 0

local function main()
    frame = frame + 1

    local curV      = mainmemory.read_u8(RAM_BASE + 0xFC)
    local curH      = mainmemory.read_u8(RAM_BASE + 0xFD)
    local ppuCtrl   = mainmemory.read_u8(RAM_BASE + 0xFF)
    local switchReq = mainmemory.read_u8(RAM_BASE + 0x5C)
    local gameMode  = mainmemory.read_u8(RAM_BASE + 0x12)
    local phase     = mainmemory.read_u8(RAM_BASE + 0x042C)
    local subphase  = mainmemory.read_u8(RAM_BASE + 0x042D)
    local textIdx   = mainmemory.read_u8(RAM_BASE + 0x042E)
    local frameCtr  = mainmemory.read_u8(RAM_BASE + 0x15)
    local ppuScrlY  = mainmemory.read_u8(PPU_BASE + 7)
    local sprite0   = mainmemory.read_u8(RAM_BASE + 0xE3)
    local vsram     = mainmemory.read_u16_be(0xFF0830)

    local ntBit = bit.band(bit.rshift(ppuCtrl, 1), 1)

    local x, y = 2, 2

    gui.drawBox(x, y, x + 165, y + 102, 0xFF444444, 0x80000000)

    gui.drawText(x+2, y+2,  string.format("Frame: %d", frame), 0xFF00FF00)
    gui.drawText(x+2, y+12, string.format("FrmCtr: %02X", frameCtr), 0xFFFFFFFF)
    gui.drawText(x+2, y+22, string.format("CurV: %02X  CurH: %02X", curV, curH), 0xFFFFFFFF)
    gui.drawText(x+2, y+32, string.format("PPU_SCRL_Y: %02X", ppuScrlY), 0xFFFFFFFF)
    gui.drawText(x+2, y+42, string.format("PpuCtrl: %02X  NT:%d", ppuCtrl, ntBit), 0xFFFFFFFF)

    local swColor = 0xFFFFFFFF
    if switchReq ~= 0 then swColor = 0xFFFF4444 end
    gui.drawText(x+2, y+52, string.format("SwitchReq: %02X", switchReq), swColor)

    gui.drawText(x+2, y+62, string.format("VSRAM: %d", vsram), 0xFF00FF00)
    gui.drawText(x+2, y+72, string.format("Spr0: %02X", sprite0), 0xFFFFFFFF)
    gui.drawText(x+2, y+82, string.format("Mode:%d Ph:%d Sub:%d Txt:%d",
        gameMode, phase, subphase, textIdx), 0xFFFFFFFF)
end

event.onframeend(main)
console.log("Frame counter loaded.")
