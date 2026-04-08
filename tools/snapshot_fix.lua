local OUT_PATH = "C:/Users/Jake Diggity/.gemini/antigravity/brain/be7d052a-6a53-47ff-8d5e-b58d7bdc152f/"

for i = 1, 2601 do 
    emu.frameadvance() 
end
client.screenshot(OUT_PATH .. "fix_gen_2601.png")
print("Captured frame 2601")

for i = 1, 59 do 
    emu.frameadvance() 
end
client.screenshot(OUT_PATH .. "fix_gen_2660.png")
print("Captured frame 2660")

client.exit()
