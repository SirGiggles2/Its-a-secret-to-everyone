-- live_capture.lua — single screenshot of current state.
client.screenshot("C:\\tmp\\live.png")
local f = io.open("C:\\tmp\\live_state.txt", "w")
local function R(o) return memory.read_u8(o, "68K RAM") end
f:write(string.format("Link X=$%02X Y=$%02X face=%d  Room=$%02X Scene=%d\n",
  R(0x8070), R(0x8084), R(0x809C), R(0x80EB), R(0x7204)))
f:write("Slots:\n")
for s=0,11 do
  local t = R(0x834F + s)
  if t ~= 0 then
    f:write(string.format("  slot %d: type=$%02X X=$%02X Y=$%02X dir=$%02X state=$%02X\n",
      s, t, R(0x8070+s), R(0x8084+s), R(0x8098+s), R(0x80AC+s)))
  end
end
f:close()
