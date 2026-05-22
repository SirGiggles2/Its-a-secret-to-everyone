# NES vs Genesis Enemy Parity Diff

Types compared: 30

## Per-cell summary

| Type | Name | Cell matches | Score |
|---|---|---|---|
| $01 | 01_BlueLynel | 8/11 | PARTIAL |
| $02 | 02_RedLynel | 9/11 | PARTIAL |
| $03 | 03_BlueMoblin | 9/11 | PARTIAL |
| $04 | 04_RedMoblin | 9/11 | PARTIAL |
| $05 | 05_BlueGoriya | 9/11 | PARTIAL |
| $06 | 06_RedGoriya | 9/11 | PARTIAL |
| $0B | 0B_BlueDarknut | 10/11 | PARTIAL |
| $0C | 0C_RedDarknut | 9/11 | PARTIAL |
| $0F | 0F_BlueLeever | 8/11 | PARTIAL |
| $10 | 10_RedLeever | 5/11 | PARTIAL |
| $11 | 11_Zora | 7/11 | PARTIAL |
| $12 | 12_Vire | 9/11 | PARTIAL |
| $13 | 13_Zol | 9/11 | PARTIAL |
| $15 | 15_Gel | 9/11 | PARTIAL |
| $16 | 16_PolsVoice | 9/11 | PARTIAL |
| $17 | 17_LikeLike | 11/11 | GREEN |
| $1A | 1A_Peahat | 7/11 | PARTIAL |
| $1B | 1B_BlueKeese | 8/11 | PARTIAL |
| $1C | 1C_RedKeese | 8/11 | PARTIAL |
| $1D | 1D_BlackKeese | 8/11 | PARTIAL |
| $1E | 1E_Armos | 9/11 | PARTIAL |
| $21 | 21_Ghini | 10/11 | PARTIAL |
| $22 | 22_FlyingGhini | 9/11 | PARTIAL |
| $27 | 27_Wallmaster | 6/11 | PARTIAL |
| $28 | 28_Rope | 8/11 | PARTIAL |
| $2A | 2A_Stalfos | 9/11 | PARTIAL |
| $2B | 2B_BlueBubble | 10/11 | PARTIAL |
| $2C | 2C_RedBubble | 10/11 | PARTIAL |
| $2D | 2D_BlueBubble2 | 10/11 | PARTIAL |
| $30 | 30_Gibdo | 9/11 | PARTIAL |

## Per-cell detail

### 01_BlueLynel (8/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $01 | $01 | ✓ |
| x | $80 | $80 | ✓ |
| y | $96 | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $00 | ✗ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $55 | $00 | ✗ |
| hp | $60 | $60 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $00 | $00 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 02_RedLynel (9/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $02 | $02 | ✓ |
| x | $75 | $80 | ✗ |
| y | $6A | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $00 | $00 | ✓ |
| hp | $40 | $40 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $00 | $00 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 03_BlueMoblin (9/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $03 | $03 | ✓ |
| x | $7B | $80 | ✗ |
| y | $88 | $88 | ✓ |
| dir | $00 | $00 | ✓ |
| qspd | $00 | $00 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $7F | $00 | ✗ |
| hp | $30 | $30 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $00 | $00 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 04_RedMoblin (9/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $04 | $04 | ✓ |
| x | $70 | $80 | ✗ |
| y | $91 | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $00 | $00 | ✓ |
| hp | $20 | $20 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $00 | $00 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 05_BlueGoriya (9/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $05 | $05 | ✓ |
| x | $80 | $80 | ✓ |
| y | $7E | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $1D | $00 | ✗ |
| hp | $50 | $50 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $00 | $00 | ✓ |

- OAM diff: 243/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 06_RedGoriya (9/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $06 | $06 | ✓ |
| x | $72 | $80 | ✗ |
| y | $69 | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $00 | $00 | ✓ |
| hp | $30 | $30 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $00 | $00 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 0B_BlueDarknut (10/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $0B | $0B | ✓ |
| x | $53 | $80 | ✗ |
| y | $88 | $88 | ✓ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $00 | $00 | ✓ |
| hp | $40 | $40 | ✓ |
| inv | $F6 | $F6 | ✓ |
| attr | $81 | $81 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 0C_RedDarknut (9/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $0C | $0C | ✓ |
| x | $6D | $80 | ✗ |
| y | $63 | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $28 | $28 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $00 | $00 | ✓ |
| hp | $80 | $80 | ✓ |
| inv | $F6 | $F6 | ✓ |
| attr | $81 | $81 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 0F_BlueLeever (8/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $0F | $0F | ✓ |
| x | $62 | $80 | ✗ |
| y | $88 | $88 | ✓ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $20 | ✓ |
| st | $03 | $03 | ✓ |
| ms | $00 | $01 | ✗ |
| tm | $D5 | $EB | ✗ |
| hp | $40 | $40 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $01 | $01 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 10_RedLeever (5/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $10 | $10 | ✓ |
| x | $99 | $78 | ✗ |
| y | $A5 | $6D | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $00 | ✗ |
| st | $03 | $02 | ✗ |
| ms | $00 | $01 | ✗ |
| tm | $FF | $07 | ✗ |
| hp | $20 | $20 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $01 | $01 | ✓ |

- OAM diff: 253/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 11_Zora (7/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $11 | $11 | ✓ |
| x | $80 | $80 | ✓ |
| y | $88 | $88 | ✓ |
| dir | $00 | $00 | ✓ |
| qspd | $0A | $20 | ✗ |
| st | $05 | $00 | ✗ |
| ms | $00 | $01 | ✗ |
| tm | $48 | $00 | ✗ |
| hp | $20 | $20 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $81 | $81 | ✓ |

- OAM diff: 253/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 12_Vire (9/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $12 | $12 | ✓ |
| x | $72 | $80 | ✗ |
| y | $71 | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $00 | $00 | ✓ |
| hp | $40 | $40 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $01 | $01 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 13_Zol (9/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $13 | $13 | ✓ |
| x | $80 | $80 | ✓ |
| y | $75 | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $18 | $18 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $00 | $18 | ✗ |
| hp | $20 | $20 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $01 | $01 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 15_Gel (9/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $15 | $15 | ✓ |
| x | $80 | $80 | ✓ |
| y | $7A | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $40 | $40 | ✓ |
| st | $02 | $02 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $32 | $08 | ✗ |
| hp | $00 | $00 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $43 | $43 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 16_PolsVoice (9/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $16 | $16 | ✓ |
| x | $6D | $80 | ✗ |
| y | $AD | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $00 | $00 | ✓ |
| hp | $A0 | $A0 | ✓ |
| inv | $FE | $FE | ✓ |
| attr | $81 | $81 | ✓ |

- OAM diff: 212/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 17_LikeLike (11/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $17 | $17 | ✓ |
| x | $80 | $80 | ✓ |
| y | $88 | $88 | ✓ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $00 | $00 | ✓ |
| hp | $90 | $90 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $81 | $81 | ✓ |

- OAM diff: 212/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 1A_Peahat (7/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $1A | $1A | ✓ |
| x | $7F | $80 | ✗ |
| y | $92 | $88 | ✗ |
| dir | $08 | $00 | ✗ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $00 | $01 | ✗ |
| tm | $00 | $00 | ✓ |
| hp | $20 | $20 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $01 | $01 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 1B_BlueKeese (8/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $1B | $1B | ✓ |
| x | $80 | $80 | ✓ |
| y | $8B | $88 | ✗ |
| dir | $01 | $00 | ✗ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $08 | $00 | ✗ |
| hp | $00 | $00 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $81 | $81 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 1C_RedKeese (8/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $1C | $1C | ✓ |
| x | $80 | $80 | ✓ |
| y | $8B | $88 | ✗ |
| dir | $01 | $00 | ✗ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $0E | $00 | ✗ |
| hp | $00 | $00 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $81 | $81 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 1D_BlackKeese (8/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $1D | $1D | ✓ |
| x | $80 | $80 | ✓ |
| y | $8B | $88 | ✗ |
| dir | $01 | $00 | ✗ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $0E | $00 | ✗ |
| hp | $00 | $00 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $81 | $81 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 1E_Armos (9/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $1E | $1E | ✓ |
| x | $80 | $80 | ✓ |
| y | $B5 | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $00 | $01 | ✗ |
| tm | $00 | $00 | ✓ |
| hp | $30 | $30 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $01 | $01 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 21_Ghini (10/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $21 | $21 | ✓ |
| x | $80 | $80 | ✓ |
| y | $B5 | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $00 | $00 | ✓ |
| hp | $90 | $90 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $81 | $81 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 22_FlyingGhini (9/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $22 | $22 | ✓ |
| x | $80 | $80 | ✓ |
| y | $88 | $88 | ✓ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $00 | $01 | ✗ |
| tm | $58 | $00 | ✗ |
| hp | $F0 | $F0 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $81 | $81 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 27_Wallmaster (6/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $27 | $27 | ✓ |
| x | $92 | $80 | ✗ |
| y | $BD | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $18 | $20 | ✗ |
| st | $01 | $00 | ✗ |
| ms | $01 | $01 | ✓ |
| tm | $07 | $00 | ✗ |
| hp | $20 | $20 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $89 | $89 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 28_Rope (8/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $28 | $28 | ✓ |
| x | $53 | $80 | ✗ |
| y | $88 | $88 | ✓ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $60 | ✗ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $08 | $00 | ✗ |
| hp | $10 | $10 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $89 | $89 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 2A_Stalfos (9/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $2A | $2A | ✓ |
| x | $6F | $80 | ✗ |
| y | $6C | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $00 | $00 | ✓ |
| hp | $20 | $20 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $81 | $81 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 2B_BlueBubble (10/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $2B | $2B | ✓ |
| x | $80 | $80 | ✓ |
| y | $4D | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $40 | $40 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $00 | $00 | ✓ |
| hp | $F0 | $F0 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $89 | $89 | ✓ |

- OAM diff: 241/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 2C_RedBubble (10/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $2C | $2C | ✓ |
| x | $80 | $80 | ✓ |
| y | $4D | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $40 | $40 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $00 | $00 | ✓ |
| hp | $F0 | $F0 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $89 | $89 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 2D_BlueBubble2 (10/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $2D | $2D | ✓ |
| x | $80 | $80 | ✓ |
| y | $C6 | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $40 | $40 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $00 | $00 | ✓ |
| hp | $F0 | $F0 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $89 | $89 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

### 30_Gibdo (9/11)

| Cell | NES | Gen | Match |
|---|---|---|---|
| t | $30 | $30 | ✓ |
| x | $76 | $80 | ✗ |
| y | $AC | $88 | ✗ |
| dir | $00 | $00 | ✓ |
| qspd | $20 | $20 | ✓ |
| st | $00 | $00 | ✓ |
| ms | $01 | $01 | ✓ |
| tm | $00 | $00 | ✓ |
| hp | $70 | $70 | ✓ |
| inv | $00 | $00 | ✓ |
| attr | $81 | $81 | ✓ |

- OAM diff: 251/256 bytes differ
- NES palram: `0f3000120f1627360f1a37120f173712002927170002223000162730000f1c16`
- Gen cram:   `00000eee08880e600000004e04ae0ace000000a00ace0e600000026c0ace0e60`

