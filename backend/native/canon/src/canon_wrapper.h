#ifndef CANON_WRAPPER_H
#define CANON_WRAPPER_H

#include <nan.h>
#include <node.h>
#include <uv.h>
#include <vector>
#include <memory>
#include <thread>
#include <mutex>

// Canon EDSDK includes
#ifdef CANON_SDK_WINDOWS
#include "EDSDK.h"
#elif defined(CANON_SDK_MAC)
#include "EDSDK.h"
#endif

using namespace v8;

class CanonWrapper : public Nan::ObjectWrap {
public:
    static void Init(Local<Object> exports);
    static void New(const Nan::FunctionCallbackInfo<Value>& info);

    // Core SDK methods
    static void Initialize(const Nan::FunctionCallbackInfo<Value>& info);
    static void Terminate(const Nan::FunctionCallbackInfo<Value>& info);
    
    // Camera discovery and connection
    static void GetCameraList(const Nan::FunctionCallbackInfo<Value>& info);
    static void OpenSession(const Nan::FunctionCallbackInfo<Value>& info);
    static void CloseSession(const Nan::FunctionCallbackInfo<Value>& info);
    
    // Camera properties and settings
    static void GetPropertyData(const Nan::FunctionCallbackInfo<Value>& info);
    static void SetPropertyData(const Nan::FunctionCallbackInfo<Value>& info);
    static void GetPropertyDesc(const Nan::FunctionCallbackInfo<Value>& info);
    
    // Live view operations
    static void StartLiveView(const Nan::FunctionCallbackInfo<Value>& info);
    static void EndLiveView(const Nan::FunctionCallbackInfo<Value>& info);
    static void DownloadEvfImage(const Nan::FunctionCallbackInfo<Value>& info);
    
    // Image capture
    static void TakePicture(const Nan::FunctionCallbackInfo<Value>& info);
    static void PressPictureButton(const Nan::FunctionCallbackInfo<Value>& info);
    static void ReleasePictureButton(const Nan::FunctionCallbackInfo<Value>& info);
    
    // Event handling
    static void SetEventHandler(const Nan::FunctionCallbackInfo<Value>& info);
    static void SetPropertyEventHandler(const Nan::FunctionCallbackInfo<Value>& info);
    static void SetObjectEventHandler(const Nan::FunctionCallbackInfo<Value>& info);

private:
    explicit CanonWrapper();
    ~CanonWrapper();

    // Canon EDSDK handles and state
    static EdsCameraListRef s_camera_list;
    static EdsUInt32 s_camera_count;
    static EdsCameraRef s_camera;
    static bool s_session_open;
    static bool s_live_view_active;
    
    // Event callbacks
    static Nan::Persistent<Function> s_EventCallback;
    static Nan::Persistent<Function> s_PropertyEventCallback;
    static Nan::Persistent<Function> s_ObjectEventCallback;
    
    // Threading support
    static uv_async_t s_AsyncEvent;
    static uv_async_t s_AsyncPropertyEvent;
    static uv_async_t s_AsyncObjectEvent;
    
    // Canon EDSDK callback implementations
    static EdsError EDSCALLBACK HandleCameraAddedEvent(EdsVoid* context);
    static EdsError EDSCALLBACK HandlePropertyEvent(
        EdsPropertyEvent inEvent,
        EdsPropertyID inPropertyID,
        EdsUInt32 inParam,
        EdsVoid* inContext
    );
    static EdsError EDSCALLBACK HandleObjectEvent(
        EdsObjectEvent inEvent,
        EdsBaseRef inRef,
        EdsVoid* inContext
    );
    static EdsError EDSCALLBACK HandleStateEvent(
        EdsStateEvent inEvent,
        EdsUInt32 inEventData,
        EdsVoid* inContext
    );
    
    // Helper methods
    static void InitializeSDK();
    static void CleanupSDK();
    static Local<Object> CreateCameraInfo(EdsCameraRef camera);
    static Local<Value> ConvertPropertyValue(EdsPropertyID propertyID, EdsDataType dataType, void* data, EdsUInt32 size);
    static EdsError ConvertJSValueToProperty(Local<Value> jsValue, EdsPropertyID propertyID, void** data, EdsUInt32* size);
    
    // Async event handlers for Node.js thread safety
    static void AsyncEventCallback(uv_async_t* handle);
    static void AsyncPropertyEventCallback(uv_async_t* handle);
    static void AsyncObjectEventCallback(uv_async_t* handle);
    
    static Nan::Persistent<Function> constructor;
};

// Event data structures for async callbacks
struct CanonEventData {
    EdsUInt32 event;
    EdsVoid* context;
};

struct CanonPropertyEventData {
    EdsPropertyEvent event;
    EdsPropertyID propertyID;
    EdsUInt32 param;
};

struct CanonObjectEventData {
    EdsObjectEvent event;
    EdsBaseRef ref;
};

#endif // CANON_WRAPPER_H