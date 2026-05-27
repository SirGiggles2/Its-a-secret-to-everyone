"""Inspect a Phase G capture bundle's STAT region."""
from __future__ import annotations
import struct, sys, pathlib

def main(path):
    data = pathlib.Path(path).read_bytes()
    print(f"File: {path}  ({len(data)} bytes)")
    print(f"Magic: {data[:4]!r}  Version: {struct.unpack('<I', data[4:8])[0]}  Frame: {struct.unpack('<I', data[8:12])[0]}  Hash: ${struct.unpack('<I', data[12:16])[0]:08X}")
    idx = 16
    while idx < len(data) - 8:
        tag = data[idx:idx+4]
        ln = struct.unpack('<I', data[idx+4:idx+8])[0]
        if tag == b'END_':
            break
        if tag == b'STAT':
            stat = data[idx+8:idx+8+ln]
            print(f"\nSTAT (len={ln}):")
            print(f"  GameMode={stat[0]:#04x}  RoomId={stat[1]:#04x}  CurLevel={stat[2]:#04x}")
            print(f"  LinkX={stat[3]:#04x}  LinkY={stat[4]:#04x}  LinkDir={stat[5]:#04x}  LinkState={stat[6]:#04x}")
            print(f"  CavePersonState={stat[7]:#04x}  CaveFlags={stat[8]:#04x}")
            print(f"  CurQuest={stat[9]:#04x}  PersonTextSelector={stat[10]:#04x}  FrameCounter={stat[11]:#04x}")
            print(f"  ObjType[0..15]= " + " ".join(f"{b:02X}" for b in stat[12:28]))
        elif tag == b'CRAM':
            cram = data[idx+8:idx+8+ln]
            print(f"\nCRAM (len={ln}): first 32 bytes = " + " ".join(f"{b:02X}" for b in cram[:32]))
        else:
            print(f"  {tag.decode('ascii', 'ignore')}: len={ln}")
        idx += 8 + ln

if __name__ == "__main__":
    for p in sys.argv[1:]:
        main(p)
