#ifndef INTRO_HANDOFF_H
#define INTRO_HANDOFF_H
#ifdef __cplusplus
extern "C" {
#endif
typedef struct {
    unsigned char mode_value;
    unsigned char submode_value;
    unsigned char frontend_demo_subphase;
    unsigned char front_start_release_gate;
    unsigned char vram_force_blank_gate;
    unsigned char frontend_delay_timer;
    unsigned char room_mode_timer;
    unsigned char item_sfx_secondary;
    unsigned char room_transfer_buf_select;
} intro_handoff_state_t;

extern const intro_handoff_state_t INTRO_HANDOFF_EXPECTED;

void intro_handoff(void);
#ifdef __cplusplus
}
#endif
#endif
