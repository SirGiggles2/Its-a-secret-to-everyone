/* main.c — midi_demo entry: upload Link sprite, start music, idle in vblank loop. */

typedef unsigned char  u8;
typedef unsigned short u16;
typedef unsigned long  u32;

extern const unsigned short link_palette[16];
extern const unsigned char  link_sprite_chr[128];

extern void ym_init(void);
extern void midi_init(void);
extern void midi_tick(void);

#define VDP_DATA_W (*(volatile u16 *)0x00C00000)
#define VDP_DATA_L (*(volatile u32 *)0x00C00000)
#define VDP_CTRL_W (*(volatile u16 *)0x00C00004)
#define VDP_CTRL_L (*(volatile u32 *)0x00C00004)

static inline u32 vram_write_cmd(u16 addr) {
    return ((u32)(addr & 0x3FFF) << 16) | ((addr & 0xC000) >> 14) | 0x40000000UL;
}

static inline u32 cram_write_cmd(u16 addr) {
    return ((u32)(addr & 0x3FFF) << 16) | ((addr & 0xC000) >> 14) | 0xC0000000UL;
}

static void vram_clear_first_pages(void) {
    /* Zero first 4KB of VRAM: covers blank tile 0 and most of plane A name table.
     * Plane A lives at $C000, so also zero $C000..$C7FF (2KB) for a clean
     * background. */
    VDP_CTRL_L = vram_write_cmd(0x0000);
    for (int i = 0; i < (4096 / 2); i++) VDP_DATA_W = 0;

    VDP_CTRL_L = vram_write_cmd(0xC000);
    for (int i = 0; i < (2048 / 2); i++) VDP_DATA_W = 0;

    /* Zero plane B name table at $E000 too. */
    VDP_CTRL_L = vram_write_cmd(0xE000);
    for (int i = 0; i < (2048 / 2); i++) VDP_DATA_W = 0;
}

static void upload_palette(void) {
    VDP_CTRL_L = cram_write_cmd(0x0000);
    for (int i = 0; i < 16; i++) VDP_DATA_W = link_palette[i];
}

static void upload_link_chr(void) {
    /* CHR -> VRAM starting at tile index 1 ($0020), skipping blank tile 0. */
    VDP_CTRL_L = vram_write_cmd(0x0020);
    const u8 *p = link_sprite_chr;
    for (int i = 0; i < 128; i += 2) {
        u16 w = ((u16)p[i] << 8) | p[i + 1];
        VDP_DATA_W = w;
    }
}

static void write_sat_link(void) {
    /* Single 2x2 sprite, centered on H32 V32 screen (256x224).
     * Position offset is +128 on both axes. */
    VDP_CTRL_L = vram_write_cmd(0xF800);
    VDP_DATA_W = 128 + 104;          /* y: 104 from top */
    VDP_DATA_W = (5 << 8) | 0;       /* size = 2x2, link=0 (only sprite) */
    VDP_DATA_W = 0x0000 | 1;         /* attr: pal0, lo prio, no flip, tile=1 */
    VDP_DATA_W = 128 + 120;          /* x: 120 from left */
}

static void enable_display(void) {
    /* Reg 1 with display ON (bit 6 set), VBlank IRQ on, M5. */
    VDP_CTRL_W = 0x8174;
}

static void wait_vblank(void) {
    while ( (VDP_CTRL_W & 0x0008));
    while (!(VDP_CTRL_W & 0x0008));
}

int main(void) {
    vram_clear_first_pages();
    upload_palette();
    upload_link_chr();
    write_sat_link();

    ym_init();
    midi_init();

    enable_display();

    for (;;) {
        wait_vblank();
        midi_tick();
    }
    return 0;
}
