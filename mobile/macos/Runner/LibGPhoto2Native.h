//
//  LibGPhoto2Native.h
//  libgphoto2 C bridge header for Swift
//

#ifndef LibGPhoto2Native_h
#define LibGPhoto2Native_h

#include <stdio.h>

// Initialize/cleanup functions
int gphoto2_init(void);
void gphoto2_cleanup(void);

// Camera detection and connection
int gphoto2_detect_cameras(char ***camera_list, int *count);
int gphoto2_connect(void);
int gphoto2_disconnect(void);
int gphoto2_is_connected(void);

// Live view functions
int gphoto2_start_live_view(void);
int gphoto2_stop_live_view(void);
int gphoto2_is_live_view_active(void);
void gphoto2_set_live_view_callback(void (*callback)(unsigned char *data, unsigned long size));

// Photo capture functions
int gphoto2_capture_photo(char **filename, char **filepath);
int gphoto2_download_file(const char *folder, const char *filename, unsigned char **data, unsigned long *size);

// Camera settings functions
int gphoto2_set_setting(const char *setting_name, const char *value);
int gphoto2_get_setting(const char *setting_name, char **value);
int gphoto2_get_setting_choices(const char *setting_name, char ***choices, int *choice_count);

// Error handling
const char* gphoto2_get_last_error(void);

// Memory management helpers
void gphoto2_free_string(char *str);
void gphoto2_free_data(unsigned char *data);
void gphoto2_free_string_array(char **array, int count);

#endif /* LibGPhoto2Native_h */