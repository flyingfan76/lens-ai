//
//  libgphoto2-bridge.h
//  Direct libgphoto2 integration for Swift
//

#ifndef libgphoto2_bridge_h
#define libgphoto2_bridge_h

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <gphoto2/gphoto2.h>

// Simplified C wrapper functions for Swift integration
typedef struct {
    Camera *camera;
    GPContext *context;
    int is_connected;
} GPhoto2Camera;

// Camera initialization and cleanup
int gp2_init_camera(GPhoto2Camera *gp_cam);
void gp2_cleanup_camera(GPhoto2Camera *gp_cam);

// Camera detection
int gp2_detect_cameras(char *camera_list, int max_size);

// Test function (no libgphoto2 calls)
int gp2_test_bridge();

// Live view functionality
int gp2_start_liveview(GPhoto2Camera *gp_cam);
int gp2_capture_preview(GPhoto2Camera *gp_cam, unsigned char **data, unsigned long *size);
int gp2_stop_liveview(GPhoto2Camera *gp_cam);

// Camera controls
int gp2_set_config_value(GPhoto2Camera *gp_cam, const char *key, const char *value);
int gp2_get_config_value(GPhoto2Camera *gp_cam, const char *key, char *value, int max_size);

#endif /* libgphoto2_bridge_h */