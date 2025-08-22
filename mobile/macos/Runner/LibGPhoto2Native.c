// Complete libgphoto2 C wrapper for professional camera control
#include <gphoto2/gphoto2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <stdarg.h>

// Logging levels
typedef enum {
    LOG_ERROR,
    LOG_WARNING, 
    LOG_INFO,
    LOG_DEBUG
} log_level_t;

// Forward declarations
static void gphoto2_log(log_level_t level, const char *format, ...);
static void set_error(const char *format, ...);
static int kill_ptpcamerad(void);
void gphoto2_cleanup(void);
int gphoto2_stop_live_view(void);

// Global context and camera state
static GPContext *context = NULL;
static Camera *camera = NULL;
static pthread_mutex_t camera_mutex = PTHREAD_MUTEX_INITIALIZER;
static int is_connected = 0;
static int live_view_active = 0;

// Live view streaming
static pthread_t live_view_thread;
static int live_view_running = 0;
static void (*live_view_callback)(unsigned char *data, unsigned long size) = NULL;

// Error handling
static char last_error[256] = {0};

static void gphoto2_log(log_level_t level, const char *format, ...) {
    const char *level_str[] = {"ERROR", "WARNING", "INFO", "DEBUG"};
    printf("LibGPhoto2[%s]: ", level_str[level]);
    
    va_list args;
    va_start(args, format);
    vprintf(format, args);
    va_end(args);
    printf("\n");
}

// Error handling helpers
static void set_error(const char *format, ...) {
    va_list args;
    va_start(args, format);
    vsnprintf(last_error, sizeof(last_error), format, args);
    va_end(args);
    gphoto2_log(LOG_ERROR, "%s", last_error);
}

const char* gphoto2_get_last_error() {
    return last_error;
}

// Initialize libgphoto2 with comprehensive setup
int gphoto2_init() {
    gphoto2_log(LOG_INFO, "Initializing libgphoto2 system");
    
    // Proactively kill PTP daemon before any camera operations
    kill_ptpcamerad();
    
    pthread_mutex_lock(&camera_mutex);
    
    // Clean up any existing resources
    if (context || camera) {
        gphoto2_log(LOG_WARNING, "Cleaning up existing resources before init");
        gphoto2_cleanup();
    }
    
    // Create context with error handling
    context = gp_context_new();
    if (!context) {
        set_error("Failed to create gphoto2 context");
        pthread_mutex_unlock(&camera_mutex);
        return -1;
    }
    
    // Set up context callbacks for better error reporting
    gp_context_set_error_func(context, NULL, NULL);
    gp_context_set_message_func(context, NULL, NULL);
    
    // Create camera object
    int ret = gp_camera_new(&camera);
    if (ret < GP_OK) {
        set_error("Failed to create camera object: %s", gp_result_as_string(ret));
        gp_context_unref(context);
        context = NULL;
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    gphoto2_log(LOG_INFO, "libgphoto2 initialized successfully");
    pthread_mutex_unlock(&camera_mutex);
    return GP_OK;
}

// Enhanced camera detection and connection
int gphoto2_detect_cameras(char ***camera_list, int *count) {
    gphoto2_log(LOG_INFO, "Detecting available cameras");
    
    if (!context) {
        set_error("libgphoto2 not initialized");
        return -1;
    }
    
    CameraList *list;
    int ret = gp_list_new(&list);
    if (ret < GP_OK) {
        set_error("Failed to create camera list: %s", gp_result_as_string(ret));
        return ret;
    }
    
    ret = gp_camera_autodetect(list, context);
    if (ret < GP_OK) {
        set_error("Failed to autodetect cameras: %s", gp_result_as_string(ret));
        gp_list_free(list);
        return ret;
    }
    
    *count = gp_list_count(list);
    gphoto2_log(LOG_INFO, "Found %d cameras", *count);
    
    if (*count > 0) {
        *camera_list = malloc(*count * sizeof(char*));
        for (int i = 0; i < *count; i++) {
            const char *name, *value;
            gp_list_get_name(list, i, &name);
            gp_list_get_value(list, i, &value);
            
            char *camera_info = malloc(512);
            snprintf(camera_info, 512, "%s on %s", name, value);
            (*camera_list)[i] = camera_info;
            
            gphoto2_log(LOG_INFO, "Camera %d: %s", i, camera_info);
        }
    }
    
    gp_list_free(list);
    return *count;
}

// Advanced PTP daemon management with exclusive USB access
static int kill_ptpcamerad() {
    gphoto2_log(LOG_INFO, "COMPREHENSIVE PTP SERVICE MANAGEMENT - DISABLING SYSTEM SERVICE");
    
    // Step 1: Unload the launchctl service completely (this prevents respawning)
    gphoto2_log(LOG_INFO, "Unloading com.apple.ptpcamerad service completely");
    system("launchctl unload -w /System/Library/LaunchDaemons/com.apple.ptpcamerad.plist 2>/dev/null");
    system("launchctl bootout system/com.apple.ptpcamerad 2>/dev/null");
    
    // Step 2: Kill all PTP-related processes with extreme prejudice
    gphoto2_log(LOG_INFO, "Killing ALL PTP-related processes");
    system("pkill -9 -f ptpcamerad 2>/dev/null");
    system("pkill -9 -f ptpcamera 2>/dev/null");
    system("killall -9 ptpcamerad 2>/dev/null");
    system("pkill -9 -f mscamerad 2>/dev/null");
    system("pkill -9 -f PTPCamera 2>/dev/null");
    
    // Step 3: Force disable any USB claiming by macOS
    gphoto2_log(LOG_INFO, "Forcing USB device release");
    system("launchctl stop com.apple.ptpcamerad 2>/dev/null");
    
    // Step 4: Brief stabilization period
    usleep(300000); // Wait 300ms for complete shutdown
    
    gphoto2_log(LOG_INFO, "COMPREHENSIVE PTP service shutdown completed");
    return 0;
}

// Enhanced camera connection with full validation
int gphoto2_connect() {
    gphoto2_log(LOG_INFO, "Connecting to camera");
    
    // Kill interfering macOS process first
    kill_ptpcamerad();
    
    pthread_mutex_lock(&camera_mutex);
    
    // Rapid retry connection up to 5 times with minimal delays
    int max_retries = 5;
    int retry_count = 0;
    
    if (!camera || !context) {
        set_error("libgphoto2 not initialized");
        pthread_mutex_unlock(&camera_mutex);
        return -1;
    }
    
    if (is_connected) {
        gphoto2_log(LOG_INFO, "Camera already connected");
        pthread_mutex_unlock(&camera_mutex);
        return GP_OK;
    }
    
    // Initialize camera connection with retry logic
    int ret = GP_ERROR;
    while (retry_count < max_retries) {
        gphoto2_log(LOG_INFO, "Connection attempt %d/%d", retry_count + 1, max_retries);
        
        ret = gp_camera_init(camera, context);
        if (ret >= GP_OK) {
            break; // Success!
        }
        
        gphoto2_log(LOG_WARNING, "Connection attempt %d failed: %s", retry_count + 1, gp_result_as_string(ret));
        retry_count++;
        
        if (retry_count < max_retries) {
            // Kill ptpcamerad again and wait before retry
            pthread_mutex_unlock(&camera_mutex);
            kill_ptpcamerad();
            pthread_mutex_lock(&camera_mutex);
            usleep(100000); // Wait 100ms only before retry
        }
    }
    
    if (ret < GP_OK) {
        set_error("Failed to connect to camera after %d attempts: %s", max_retries, gp_result_as_string(ret));
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    // Verify connection with camera summary
    CameraText summary;
    ret = gp_camera_get_summary(camera, &summary, context);
    if (ret < GP_OK) {
        set_error("Failed to get camera summary: %s", gp_result_as_string(ret));
        gp_camera_exit(camera, context);
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    // Get camera abilities for feature detection
    CameraAbilities abilities;
    ret = gp_camera_get_abilities(camera, &abilities);
    if (ret < GP_OK) {
        gphoto2_log(LOG_WARNING, "Failed to get camera abilities: %s", gp_result_as_string(ret));
    } else {
        gphoto2_log(LOG_INFO, "Camera model: %s", abilities.model);
        gphoto2_log(LOG_INFO, "Camera operations: 0x%x", abilities.operations);
        gphoto2_log(LOG_INFO, "File operations: 0x%x", abilities.file_operations);
        gphoto2_log(LOG_INFO, "Folder operations: 0x%x", abilities.folder_operations);
    }
    
    is_connected = 1;
    gphoto2_log(LOG_INFO, "Successfully connected to camera");
    gphoto2_log(LOG_DEBUG, "Camera summary: %s", summary.text);
    
    pthread_mutex_unlock(&camera_mutex);
    return GP_OK;
}

// Disconnect from camera
int gphoto2_disconnect() {
    gphoto2_log(LOG_INFO, "Disconnecting from camera");
    
    pthread_mutex_lock(&camera_mutex);
    
    if (!is_connected) {
        gphoto2_log(LOG_INFO, "Camera not connected");
        pthread_mutex_unlock(&camera_mutex);
        return GP_OK;
    }
    
    // Stop live view if active
    if (live_view_active) {
        gphoto2_stop_live_view();
    }
    
    // Exit camera connection
    if (camera && context) {
        int ret = gp_camera_exit(camera, context);
        if (ret < GP_OK) {
            gphoto2_log(LOG_WARNING, "Error during camera exit: %s", gp_result_as_string(ret));
        }
    }
    
    is_connected = 0;
    gphoto2_log(LOG_INFO, "Camera disconnected");
    
    pthread_mutex_unlock(&camera_mutex);
    return GP_OK;
}

// Live view thread function
static void* live_view_thread_func(void* arg) {
    gphoto2_log(LOG_INFO, "Live view thread started");
    
    while (live_view_running) {
        if (!is_connected || !live_view_active) {
            usleep(100000); // 100ms
            continue;
        }
        
        CameraFile *file;
        int ret = gp_file_new(&file);
        if (ret < GP_OK) {
            gphoto2_log(LOG_ERROR, "Failed to create file for live view: %s", gp_result_as_string(ret));
            usleep(100000);
            continue;
        }
        
        pthread_mutex_lock(&camera_mutex);
        ret = gp_camera_capture_preview(camera, file, context);
        pthread_mutex_unlock(&camera_mutex);
        
        if (ret < GP_OK) {
            gphoto2_log(LOG_WARNING, "Failed to capture preview: %s", gp_result_as_string(ret));
            gp_file_free(file);
            usleep(100000);
            continue;
        }
        
        // Get image data and send to callback
        const char *file_data;
        unsigned long file_size;
        ret = gp_file_get_data_and_size(file, &file_data, &file_size);
        if (ret >= GP_OK && live_view_callback && file_size > 0) {
            gphoto2_log(LOG_DEBUG, "Live view: captured frame %lu bytes", file_size);
            // Copy data for callback (callback owns the memory)
            unsigned char *data_copy = malloc(file_size);
            if (data_copy) {
                memcpy(data_copy, file_data, file_size);
                live_view_callback(data_copy, file_size);
            } else {
                gphoto2_log(LOG_ERROR, "Live view: failed to allocate memory for frame");
            }
        } else {
            gphoto2_log(LOG_WARNING, "Live view: no data or callback not set (size: %lu, callback: %p)", file_size, live_view_callback);
        }
        
        gp_file_free(file);
        
        // Target ~15 FPS
        usleep(66000); // ~66ms delay
    }
    
    gphoto2_log(LOG_INFO, "Live view thread ended");
    return NULL;
}

// Start live view with threading
int gphoto2_start_live_view() {
    gphoto2_log(LOG_INFO, "Starting live view");
    
    pthread_mutex_lock(&camera_mutex);
    
    if (!is_connected) {
        set_error("Camera not connected");
        pthread_mutex_unlock(&camera_mutex);
        return -1;
    }
    
    if (live_view_active) {
        gphoto2_log(LOG_INFO, "Live view already active");
        pthread_mutex_unlock(&camera_mutex);
        return GP_OK;
    }
    
    // Try to enable live view mode on camera
    CameraWidget *config;
    int ret = gp_camera_get_config(camera, &config, context);
    if (ret >= GP_OK) {
        CameraWidget *liveview_widget;
        ret = gp_widget_get_child_by_name(config, "liveview", &liveview_widget);
        if (ret >= GP_OK) {
            gp_widget_set_value(liveview_widget, "1");
            gp_camera_set_config(camera, config, context);
            gphoto2_log(LOG_INFO, "Live view mode enabled on camera");
        }
        gp_widget_free(config);
    }
    
    // Start live view streaming thread
    live_view_active = 1;
    live_view_running = 1;
    
    ret = pthread_create(&live_view_thread, NULL, live_view_thread_func, NULL);
    if (ret != 0) {
        set_error("Failed to create live view thread");
        live_view_active = 0;
        live_view_running = 0;
        pthread_mutex_unlock(&camera_mutex);
        return -1;
    }
    
    gphoto2_log(LOG_INFO, "Live view started successfully");
    pthread_mutex_unlock(&camera_mutex);
    return GP_OK;
}

// Stop live view
int gphoto2_stop_live_view() {
    gphoto2_log(LOG_INFO, "Stopping live view");
    
    if (!live_view_active) {
        gphoto2_log(LOG_INFO, "Live view not active");
        return GP_OK;
    }
    
    // Stop the thread
    live_view_running = 0;
    pthread_join(live_view_thread, NULL);
    
    pthread_mutex_lock(&camera_mutex);
    
    // Disable live view mode on camera
    if (is_connected) {
        CameraWidget *config;
        int ret = gp_camera_get_config(camera, &config, context);
        if (ret >= GP_OK) {
            CameraWidget *liveview_widget;
            ret = gp_widget_get_child_by_name(config, "liveview", &liveview_widget);
            if (ret >= GP_OK) {
                gp_widget_set_value(liveview_widget, "0");
                gp_camera_set_config(camera, config, context);
                gphoto2_log(LOG_INFO, "Live view mode disabled on camera");
            }
            gp_widget_free(config);
        }
    }
    
    live_view_active = 0;
    gphoto2_log(LOG_INFO, "Live view stopped");
    
    pthread_mutex_unlock(&camera_mutex);
    return GP_OK;
}

// Set live view callback
void gphoto2_set_live_view_callback(void (*callback)(unsigned char *data, unsigned long size)) {
    live_view_callback = callback;
    gphoto2_log(LOG_INFO, "Live view callback set");
}

// Enhanced photo capture with file management
int gphoto2_capture_photo(char **filename, char **filepath) {
    gphoto2_log(LOG_INFO, "Capturing photo");
    
    pthread_mutex_lock(&camera_mutex);
    
    if (!is_connected) {
        set_error("Camera not connected");
        pthread_mutex_unlock(&camera_mutex);
        return -1;
    }
    
    CameraFilePath camera_file_path;
    int ret = gp_camera_capture(camera, GP_CAPTURE_IMAGE, &camera_file_path, context);
    if (ret < GP_OK) {
        set_error("Failed to capture photo: %s", gp_result_as_string(ret));
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    gphoto2_log(LOG_INFO, "Photo captured: %s/%s", camera_file_path.folder, camera_file_path.name);
    
    // Copy filename and folder for Swift
    *filename = malloc(strlen(camera_file_path.name) + 1);
    strcpy(*filename, camera_file_path.name);
    
    *filepath = malloc(strlen(camera_file_path.folder) + 1);
    strcpy(*filepath, camera_file_path.folder);
    
    pthread_mutex_unlock(&camera_mutex);
    return GP_OK;
}

// Download captured image from camera
int gphoto2_download_file(const char *folder, const char *filename, unsigned char **data, unsigned long *size) {
    gphoto2_log(LOG_INFO, "Downloading file: %s/%s", folder, filename);
    
    pthread_mutex_lock(&camera_mutex);
    
    if (!is_connected) {
        set_error("Camera not connected");
        pthread_mutex_unlock(&camera_mutex);
        return -1;
    }
    
    CameraFile *file;
    int ret = gp_file_new(&file);
    if (ret < GP_OK) {
        set_error("Failed to create file object: %s", gp_result_as_string(ret));
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    ret = gp_camera_file_get(camera, folder, filename, GP_FILE_TYPE_NORMAL, file, context);
    if (ret < GP_OK) {
        set_error("Failed to download file: %s", gp_result_as_string(ret));
        gp_file_free(file);
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    // Get file data
    const char *file_data;
    ret = gp_file_get_data_and_size(file, &file_data, size);
    if (ret < GP_OK) {
        set_error("Failed to get file data: %s", gp_result_as_string(ret));
        gp_file_free(file);
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    // Copy data for caller
    *data = malloc(*size);
    if (!*data) {
        set_error("Failed to allocate memory for file data");
        gp_file_free(file);
        pthread_mutex_unlock(&camera_mutex);
        return -1;
    }
    
    memcpy(*data, file_data, *size);
    gp_file_free(file);
    
    gphoto2_log(LOG_INFO, "File downloaded successfully: %lu bytes", *size);
    
    pthread_mutex_unlock(&camera_mutex);
    return GP_OK;
}

// Enhanced camera settings management
int gphoto2_set_setting(const char *setting_name, const char *value) {
    gphoto2_log(LOG_INFO, "Setting %s = %s", setting_name, value);
    
    pthread_mutex_lock(&camera_mutex);
    
    if (!is_connected) {
        set_error("Camera not connected");
        pthread_mutex_unlock(&camera_mutex);
        return -1;
    }
    
    CameraWidget *config;
    int ret = gp_camera_get_config(camera, &config, context);
    if (ret < GP_OK) {
        set_error("Failed to get camera config: %s", gp_result_as_string(ret));
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    CameraWidget *setting_widget;
    ret = gp_widget_get_child_by_name(config, setting_name, &setting_widget);
    if (ret < GP_OK) {
        set_error("Setting '%s' not found: %s", setting_name, gp_result_as_string(ret));
        gp_widget_free(config);
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    // Get widget type for proper value setting
    CameraWidgetType widget_type;
    ret = gp_widget_get_type(setting_widget, &widget_type);
    if (ret < GP_OK) {
        set_error("Failed to get widget type: %s", gp_result_as_string(ret));
        gp_widget_free(config);
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    // Set value based on widget type
    switch (widget_type) {
        case GP_WIDGET_MENU:
        case GP_WIDGET_RADIO:
        case GP_WIDGET_TEXT:
            ret = gp_widget_set_value(setting_widget, value);
            break;
        case GP_WIDGET_RANGE: {
            float float_value = atof(value);
            ret = gp_widget_set_value(setting_widget, &float_value);
            break;
        }
        case GP_WIDGET_TOGGLE: {
            int int_value = atoi(value);
            ret = gp_widget_set_value(setting_widget, &int_value);
            break;
        }
        default:
            ret = gp_widget_set_value(setting_widget, value);
            break;
    }
    
    if (ret < GP_OK) {
        set_error("Failed to set widget value: %s", gp_result_as_string(ret));
        gp_widget_free(config);
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    ret = gp_camera_set_config(camera, config, context);
    if (ret < GP_OK) {
        set_error("Failed to apply camera config: %s", gp_result_as_string(ret));
        gp_widget_free(config);
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    gp_widget_free(config);
    gphoto2_log(LOG_INFO, "Setting '%s' applied successfully", setting_name);
    
    pthread_mutex_unlock(&camera_mutex);
    return GP_OK;
}

// Get camera setting value
int gphoto2_get_setting(const char *setting_name, char **value) {
    gphoto2_log(LOG_INFO, "Getting setting: %s", setting_name);
    
    pthread_mutex_lock(&camera_mutex);
    
    if (!is_connected) {
        set_error("Camera not connected");
        pthread_mutex_unlock(&camera_mutex);
        return -1;
    }
    
    CameraWidget *config;
    int ret = gp_camera_get_config(camera, &config, context);
    if (ret < GP_OK) {
        set_error("Failed to get camera config: %s", gp_result_as_string(ret));
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    CameraWidget *setting_widget;
    ret = gp_widget_get_child_by_name(config, setting_name, &setting_widget);
    if (ret < GP_OK) {
        set_error("Setting '%s' not found: %s", setting_name, gp_result_as_string(ret));
        gp_widget_free(config);
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    char *widget_value;
    ret = gp_widget_get_value(setting_widget, &widget_value);
    if (ret < GP_OK) {
        set_error("Failed to get widget value: %s", gp_result_as_string(ret));
        gp_widget_free(config);
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    // Copy value for caller
    *value = malloc(strlen(widget_value) + 1);
    strcpy(*value, widget_value);
    
    gp_widget_free(config);
    gphoto2_log(LOG_INFO, "Setting '%s' = '%s'", setting_name, *value);
    
    pthread_mutex_unlock(&camera_mutex);
    return GP_OK;
}

// Get available setting choices (for menu/radio widgets)
int gphoto2_get_setting_choices(const char *setting_name, char ***choices, int *choice_count) {
    gphoto2_log(LOG_INFO, "Getting setting choices: %s", setting_name);
    
    pthread_mutex_lock(&camera_mutex);
    
    if (!is_connected) {
        set_error("Camera not connected");
        pthread_mutex_unlock(&camera_mutex);
        return -1;
    }
    
    CameraWidget *config;
    int ret = gp_camera_get_config(camera, &config, context);
    if (ret < GP_OK) {
        set_error("Failed to get camera config: %s", gp_result_as_string(ret));
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    CameraWidget *setting_widget;
    ret = gp_widget_get_child_by_name(config, setting_name, &setting_widget);
    if (ret < GP_OK) {
        set_error("Setting '%s' not found: %s", setting_name, gp_result_as_string(ret));
        gp_widget_free(config);
        pthread_mutex_unlock(&camera_mutex);
        return ret;
    }
    
    *choice_count = gp_widget_count_choices(setting_widget);
    if (*choice_count <= 0) {
        gphoto2_log(LOG_INFO, "Setting '%s' has no choices", setting_name);
        gp_widget_free(config);
        pthread_mutex_unlock(&camera_mutex);
        return 0;
    }
    
    *choices = malloc(*choice_count * sizeof(char*));
    for (int i = 0; i < *choice_count; i++) {
        const char *choice;
        ret = gp_widget_get_choice(setting_widget, i, &choice);
        if (ret >= GP_OK) {
            (*choices)[i] = malloc(strlen(choice) + 1);
            strcpy((*choices)[i], choice);
            gphoto2_log(LOG_DEBUG, "Choice %d: %s", i, choice);
        }
    }
    
    gp_widget_free(config);
    gphoto2_log(LOG_INFO, "Setting '%s' has %d choices", setting_name, *choice_count);
    
    pthread_mutex_unlock(&camera_mutex);
    return *choice_count;
}

// Comprehensive cleanup with thread safety
void gphoto2_cleanup() {
    gphoto2_log(LOG_INFO, "Starting cleanup");
    
    // Stop live view if active
    if (live_view_active) {
        gphoto2_stop_live_view();
    }
    
    pthread_mutex_lock(&camera_mutex);
    
    // Disconnect camera if connected
    if (is_connected && camera && context) {
        gp_camera_exit(camera, context);
        is_connected = 0;
    }
    
    // Free camera object
    if (camera) {
        gp_camera_free(camera);
        camera = NULL;
    }
    
    // Free context
    if (context) {
        gp_context_unref(context);
        context = NULL;
    }
    
    // Clear error state
    memset(last_error, 0, sizeof(last_error));
    
    pthread_mutex_unlock(&camera_mutex);
    
    gphoto2_log(LOG_INFO, "Cleanup complete");
}

// Connection status
int gphoto2_is_connected() {
    return is_connected;
}

// Live view status
int gphoto2_is_live_view_active() {
    return live_view_active;
}

// Memory management helpers for Swift
void gphoto2_free_string(char *str) {
    if (str) {
        free(str);
    }
}

void gphoto2_free_data(unsigned char *data) {
    if (data) {
        free(data);
    }
}

void gphoto2_free_string_array(char **array, int count) {
    if (array) {
        for (int i = 0; i < count; i++) {
            if (array[i]) {
                free(array[i]);
            }
        }
        free(array);
    }
}