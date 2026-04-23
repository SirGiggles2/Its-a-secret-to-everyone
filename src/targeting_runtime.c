#include "targeting_runtime.h"

unsigned char targrt_get_one_direction_and_distance_to_target(unsigned char target_coord,
                                                              unsigned char origin_coord) {
    TARGET_MIN_COORD = target_coord;
    TARGET_MAX_COORD = origin_coord;
    if (origin_coord < target_coord) {
        TARGET_MAX_COORD = target_coord;
        TARGET_MIN_COORD = origin_coord;
        TARGET_H_DIR >>= 1;
    }
    {
        unsigned char dist = (unsigned char)(TARGET_MAX_COORD - TARGET_MIN_COORD);
        if (dist < 9) {
            TARGET_DIR_ACCUM++;
        }
        return dist;
    }
}

void targrt_get_directions_and_distances_to_target(unsigned char target_slot,
                                                   unsigned int origin_slot) {
    TARGET_H_DIR = 2;
    TARGET_H_DIST = targrt_get_one_direction_and_distance_to_target(
        OBJ_X(target_slot), OBJ_X(origin_slot));
    TARGET_V_DIR = TARGET_H_DIR;
    TARGET_H_DIR = 8;
    TARGET_V_DIST = targrt_get_one_direction_and_distance_to_target(
        OBJ_Y(target_slot), OBJ_Y(origin_slot));
}

unsigned int targrt_calc_diagonal_speed_index(unsigned int mid_speed_idx) {
    TARGET_DIR_ACCUM = (unsigned char)mid_speed_idx;
    TARGET_MIN_COORD = 0xFF;
    {
        unsigned char h = TARGET_H_DIST;
        unsigned char v = TARGET_V_DIST;
        if (h < v) {
            TARGET_H_DIST = v;
            TARGET_V_DIST = h;
            TARGET_MIN_COORD = 1;
            {
                unsigned char tmp = h;
                h = v;
                v = tmp;
            }
        }
        if ((unsigned char)(h - v) < 8) {
            return (unsigned int)TARGET_DIR_ACCUM;
        }
    }
    for (;;) {
        unsigned char idx = (unsigned char)(TARGET_DIR_ACCUM + TARGET_MIN_COORD);
        TARGET_DIR_ACCUM = idx;
        if (idx == 0 || idx == 8) {
            break;
        }
        {
            unsigned char new_diff = (unsigned char)(TARGET_H_DIST - TARGET_V_DIST);
            TARGET_H_DIST = new_diff;
            if (new_diff < TARGET_V_DIST) {
                break;
            }
        }
    }
    return (unsigned int)TARGET_DIR_ACCUM;
}
