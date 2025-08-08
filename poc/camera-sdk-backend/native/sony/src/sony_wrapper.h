#ifndef SONY_WRAPPER_H
#define SONY_WRAPPER_H

#include <nan.h>
#include <node.h>
#include <uv.h>
#include <vector>
#include <memory>
#include <thread>
#include <mutex>
#include <condition_variable>

// Sony Camera Remote SDK includes
#ifdef SONY_SDK_WINDOWS
#include "CrSDK.h"
#include "SonyAPI.h"
#elif defined(SONY_SDK_MAC)
#include "CameraRemoteSDK_Mac.h"
#elif defined(SONY_SDK_LINUX)
#include "CameraRemoteSDK_Linux.h"
#endif

using namespace v8;

class SonyWrapper : public Nan::ObjectWrap {
public:
    static void Init(Local<Object> exports);
    static void New(const Nan::FunctionCallbackInfo<Value>& info);

    // Core SDK methods
    static void Initialize(const Nan::FunctionCallbackInfo<Value>& info);
    static void Terminate(const Nan::FunctionCallbackInfo<Value>& info);
    
    // Camera discovery and connection
    static void DiscoverCameras(const Nan::FunctionCallbackInfo<Value>& info);
    static void ConnectCamera(const Nan::FunctionCallbackInfo<Value>& info);
    static void DisconnectCamera(const Nan::FunctionCallbackInfo<Value>& info);
    
    // Camera properties and settings
    static void GetDeviceProperties(const Nan::FunctionCallbackInfo<Value>& info);
    static void SetDeviceProperty(const Nan::FunctionCallbackInfo<Value>& info);
    static void GetShootingSettings(const Nan::FunctionCallbackInfo<Value>& info);
    
    // Live view operations
    static void StartLiveView(const Nan::FunctionCallbackInfo<Value>& info);
    static void StopLiveView(const Nan::FunctionCallbackInfo<Value>& info);
    static void GetLiveViewImage(const Nan::FunctionCallbackInfo<Value>& info);
    
    // Image capture
    static void TakePicture(const Nan::FunctionCallbackInfo<Value>& info);
    static void StartBulbShooting(const Nan::FunctionCallbackInfo<Value>& info);
    static void EndBulbShooting(const Nan::FunctionCallbackInfo<Value>& info);
    
    // Event handling
    static void SetEventCallback(const Nan::FunctionCallbackInfo<Value>& info);
    static void SetLiveViewCallback(const Nan::FunctionCallbackInfo<Value>& info);

private:
    explicit SonyWrapper();
    ~SonyWrapper();

    // Sony SDK handles and state
    static SCRSDK::ICrCameraObjectInfo* s_camera_list;
    static CrInt32u s_camera_count;
    static SCRSDK::CrDeviceHandle s_device_handle;
    static bool s_is_connected;
    static bool s_live_view_enabled;
    
    // Callback functions
    static Nan::Persistent<Function> s_EventCallback;
    static Nan::Persistent<Function> s_LiveViewCallback;
    
    // Threading support
    static uv_async_t s_AsyncEvent;
    static uv_async_t s_AsyncLiveView;
    static std::thread s_LiveViewThread;
    static std::mutex s_LiveViewMutex;
    static std::condition_variable s_LiveViewCondition;
    static bool s_LiveViewThreadRunning;
    
    // Sony SDK callback implementations
    static void SCRSDK_API CameraEventCallback(
        SCRSDK::CrDeviceHandle handle,
        SCRSDK::CrSdkApi api,
        SCRSDK::CrCommandId command,
        SCRSDK::CrCommandParam param,
        void* context
    );
    
    static void SCRSDK_API LiveViewCallback(
        SCRSDK::CrLiveViewProperty* liveViewProperty,
        void* context
    );
    
    // Helper methods
    static void InitializeSDK();
    static void CleanupSDK();
    static Local<Object> CreateCameraInfo(const SCRSDK::ICrCameraObjectInfo& cameraInfo);
    static Local<Object> CreatePropertyObject(const SCRSDK::CrDeviceProperty& property);
    static void StartLiveViewThread();
    static void StopLiveViewThread();
    static void LiveViewThreadFunction();
    
    // Async event handlers for Node.js thread safety
    static void AsyncEventCallback(uv_async_t* handle);
    static void AsyncLiveViewCallback(uv_async_t* handle);
    
    // Property conversion utilities
    static SCRSDK::CrPropertyValue ConvertJSValueToProperty(Local<Value> jsValue, SCRSDK::CrPropertyId propertyId);
    static Local<Value> ConvertPropertyToJSValue(const SCRSDK::CrDeviceProperty& property);
    
    static Nan::Persistent<Function> constructor;
};

// Event data structures for async callbacks
struct SonyEventData {
    SCRSDK::CrDeviceHandle handle;
    SCRSDK::CrSdkApi api;
    SCRSDK::CrCommandId command;
    SCRSDK::CrCommandParam param;
};

struct SonyLiveViewData {
    std::vector<uint8_t> imageData;
    uint32_t width;
    uint32_t height;
    uint32_t frameNumber;
};

#endif // SONY_WRAPPER_H