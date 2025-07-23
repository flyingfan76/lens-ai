#include "sony_wrapper.h"
#include <iostream>
#include <cstring>
#include <chrono>

using namespace v8;

// Static member initialization
SCRSDK::ICrCameraObjectInfo* SonyWrapper::s_camera_list = nullptr;
CrInt32u SonyWrapper::s_camera_count = 0;
SCRSDK::CrDeviceHandle SonyWrapper::s_device_handle = 0;
bool SonyWrapper::s_is_connected = false;
bool SonyWrapper::s_live_view_enabled = false;
Nan::Persistent<Function> SonyWrapper::s_EventCallback;
Nan::Persistent<Function> SonyWrapper::s_LiveViewCallback;
uv_async_t SonyWrapper::s_AsyncEvent;
uv_async_t SonyWrapper::s_AsyncLiveView;
std::thread SonyWrapper::s_LiveViewThread;
std::mutex SonyWrapper::s_LiveViewMutex;
std::condition_variable SonyWrapper::s_LiveViewCondition;
bool SonyWrapper::s_LiveViewThreadRunning = false;

SonyWrapper::SonyWrapper() {}
SonyWrapper::~SonyWrapper() {}

void SonyWrapper::Init(Local<Object> exports) {
    Nan::HandleScope scope;

    // Prepare constructor template
    Local<FunctionTemplate> tpl = Nan::New<FunctionTemplate>(New);
    tpl->SetClassName(Nan::New("SonySDK").ToLocalChecked());
    tpl->InstanceTemplate()->SetInternalFieldCount(1);

    // Prototype methods
    Nan::SetPrototypeMethod(tpl, "initialize", Initialize);
    Nan::SetPrototypeMethod(tpl, "terminate", Terminate);
    Nan::SetPrototypeMethod(tpl, "discoverCameras", DiscoverCameras);
    Nan::SetPrototypeMethod(tpl, "connectCamera", ConnectCamera);
    Nan::SetPrototypeMethod(tpl, "disconnectCamera", DisconnectCamera);
    Nan::SetPrototypeMethod(tpl, "getDeviceProperties", GetDeviceProperties);
    Nan::SetPrototypeMethod(tpl, "setDeviceProperty", SetDeviceProperty);
    Nan::SetPrototypeMethod(tpl, "getShootingSettings", GetShootingSettings);
    Nan::SetPrototypeMethod(tpl, "startLiveView", StartLiveView);
    Nan::SetPrototypeMethod(tpl, "stopLiveView", StopLiveView);
    Nan::SetPrototypeMethod(tpl, "getLiveViewImage", GetLiveViewImage);
    Nan::SetPrototypeMethod(tpl, "takePicture", TakePicture);
    Nan::SetPrototypeMethod(tpl, "startBulbShooting", StartBulbShooting);
    Nan::SetPrototypeMethod(tpl, "endBulbShooting", EndBulbShooting);
    Nan::SetPrototypeMethod(tpl, "setEventCallback", SetEventCallback);
    Nan::SetPrototypeMethod(tpl, "setLiveViewCallback", SetLiveViewCallback);

    constructor.Reset(tpl->GetFunction());
    exports->Set(Nan::New("SonySDK").ToLocalChecked(), tpl->GetFunction());
}

void SonyWrapper::New(const Nan::FunctionCallbackInfo<Value>& info) {
    if (info.IsConstructCall()) {
        SonyWrapper* obj = new SonyWrapper();
        obj->Wrap(info.This());
        info.GetReturnValue().Set(info.This());
    } else {
        const int argc = 1;
        Local<Value> argv[argc] = { info[0] };
        Local<Function> cons = Nan::New<Function>(constructor);
        info.GetReturnValue().Set(cons->NewInstance(argc, argv));
    }
}

void SonyWrapper::Initialize(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    try {
        InitializeSDK();
        
        // Initialize async handles for callbacks
        uv_async_init(uv_default_loop(), &s_AsyncEvent, AsyncEventCallback);
        uv_async_init(uv_default_loop(), &s_AsyncLiveView, AsyncLiveViewCallback);

        info.GetReturnValue().Set(Nan::True());
        
    } catch (const std::exception& e) {
        Nan::ThrowError(e.what());
    }
}

void SonyWrapper::InitializeSDK() {
    // Initialize Sony Camera Remote SDK
    SCRSDK::CrSdkApi_Initialize();
    
    // Set up enum callback for camera discovery
    auto enum_func = [](SCRSDK::ICrEnumCameraObjectInfo* camera_list) {
        if (camera_list) {
            s_camera_count = camera_list->GetCount();
            s_camera_list = camera_list->GetCameraObjectInfo();
        }
    };
    
    // Enumerate cameras initially
    SCRSDK::CrSdkApi_EnumCameraObjects(enum_func);
}

void SonyWrapper::Terminate(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    CleanupSDK();
    info.GetReturnValue().Set(Nan::True());
}

void SonyWrapper::CleanupSDK() {
    if (s_is_connected) {
        SCRSDK::CrSdkApi_Disconnect(s_device_handle);
        s_is_connected = false;
        s_device_handle = 0;
    }
    
    StopLiveViewThread();
    
    // Close async handles
    uv_close(reinterpret_cast<uv_handle_t*>(&s_AsyncEvent), nullptr);
    uv_close(reinterpret_cast<uv_handle_t*>(&s_AsyncLiveView), nullptr);
    
    // Finalize Sony SDK
    SCRSDK::CrSdkApi_Finalize();
}

void SonyWrapper::DiscoverCameras(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    // Re-enumerate cameras
    auto enum_func = [](SCRSDK::ICrEnumCameraObjectInfo* camera_list) {
        if (camera_list) {
            s_camera_count = camera_list->GetCount();
            s_camera_list = camera_list->GetCameraObjectInfo();
        }
    };
    
    SCRSDK::CrSdkApi_EnumCameraObjects(enum_func);
    
    Local<Array> cameraArray = Nan::New<Array>();
    
    for (CrInt32u i = 0; i < s_camera_count; i++) {
        Local<Object> cameraObj = CreateCameraInfo(s_camera_list[i]);
        Nan::Set(cameraArray, i, cameraObj);
    }
    
    info.GetReturnValue().Set(cameraArray);
}

void SonyWrapper::ConnectCamera(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (info.Length() < 1 || !info[0]->IsNumber()) {
        Nan::ThrowTypeError("Camera index required");
        return;
    }

    CrInt32u cameraIndex = info[0]->Uint32Value();
    
    if (cameraIndex >= s_camera_count) {
        Nan::ThrowError("Invalid camera index");
        return;
    }

    if (s_is_connected) {
        Nan::ThrowError("Camera already connected");
        return;
    }

    // Connect to selected camera
    SCRSDK::CrSdkApi_Connect(&s_camera_list[cameraIndex], CameraEventCallback, nullptr);
    
    // Get device handle after connection
    s_device_handle = s_camera_list[cameraIndex].GetDeviceHandle();
    s_is_connected = true;

    // Create camera info object
    Local<Object> cameraInfo = CreateCameraInfo(s_camera_list[cameraIndex]);
    info.GetReturnValue().Set(cameraInfo);
}

void SonyWrapper::DisconnectCamera(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (!s_is_connected) {
        info.GetReturnValue().Set(Nan::True());
        return;
    }

    StopLiveViewThread();
    SCRSDK::CrSdkApi_Disconnect(s_device_handle);
    
    s_is_connected = false;
    s_device_handle = 0;
    
    info.GetReturnValue().Set(Nan::True());
}

void SonyWrapper::GetDeviceProperties(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (!s_is_connected) {
        Nan::ThrowError("No camera connected");
        return;
    }

    // Get all device properties
    SCRSDK::CrDeviceProperty* properties = nullptr;
    CrInt32u num_properties = 0;
    
    SCRSDK::CrSdkApi_GetDeviceProperties(s_device_handle, &properties, &num_properties);
    
    Local<Object> propsObj = Nan::New<Object>();
    
    for (CrInt32u i = 0; i < num_properties; i++) {
        Local<Object> propObj = CreatePropertyObject(properties[i]);
        
        // Use property ID as key
        char propIdStr[32];
        sprintf(propIdStr, "0x%08X", properties[i].GetCode());
        
        Nan::Set(propsObj, Nan::New(propIdStr).ToLocalChecked(), propObj);
    }
    
    // Release properties memory
    SCRSDK::CrSdkApi_ReleaseDeviceProperties(s_device_handle, properties);
    
    info.GetReturnValue().Set(propsObj);
}

void SonyWrapper::SetDeviceProperty(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (info.Length() < 2 || !info[0]->IsNumber()) {
        Nan::ThrowTypeError("Property ID and value required");
        return;
    }

    if (!s_is_connected) {
        Nan::ThrowError("No camera connected");
        return;
    }

    SCRSDK::CrPropertyId propertyId = static_cast<SCRSDK::CrPropertyId>(info[0]->Uint32Value());
    SCRSDK::CrPropertyValue propertyValue = ConvertJSValueToProperty(info[1], propertyId);
    
    SCRSDK::CrDeviceProperty property;
    property.SetCode(propertyId);
    property.SetCurrentValue(propertyValue);
    
    CrInt32s result = SCRSDK::CrSdkApi_SetDeviceProperty(s_device_handle, &property);
    
    info.GetReturnValue().Set(Nan::New(result == SCRSDK::CrSdkApi_Result_Ok));
}

void SonyWrapper::StartLiveView(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (!s_is_connected) {
        Nan::ThrowError("No camera connected");
        return;
    }

    if (s_live_view_enabled) {
        info.GetReturnValue().Set(Nan::True());
        return;
    }

    // Start live view
    CrInt32s result = SCRSDK::CrSdkApi_StartLiveView(s_device_handle);
    
    if (result == SCRSDK::CrSdkApi_Result_Ok) {
        s_live_view_enabled = true;
        StartLiveViewThread();
        info.GetReturnValue().Set(Nan::True());
    } else {
        Nan::ThrowError("Failed to start live view");
    }
}

void SonyWrapper::StopLiveView(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (!s_live_view_enabled) {
        info.GetReturnValue().Set(Nan::True());
        return;
    }

    StopLiveViewThread();
    SCRSDK::CrSdkApi_StopLiveView(s_device_handle);
    s_live_view_enabled = false;
    
    info.GetReturnValue().Set(Nan::True());
}

void SonyWrapper::TakePicture(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (!s_is_connected) {
        Nan::ThrowError("No camera connected");
        return;
    }

    // Trigger shutter
    CrInt32s result = SCRSDK::CrSdkApi_SendCommand(
        s_device_handle, 
        SCRSDK::CrCommandId_Release, 
        SCRSDK::CrCommandParam_Down
    );
    
    if (result == SCRSDK::CrSdkApi_Result_Ok) {
        // Release shutter
        result = SCRSDK::CrSdkApi_SendCommand(
            s_device_handle, 
            SCRSDK::CrCommandId_Release, 
            SCRSDK::CrCommandParam_Up
        );
    }
    
    info.GetReturnValue().Set(Nan::New(result == SCRSDK::CrSdkApi_Result_Ok));
}

// Sony SDK callback implementation
void SCRSDK_API SonyWrapper::CameraEventCallback(
    SCRSDK::CrDeviceHandle handle,
    SCRSDK::CrSdkApi api,
    SCRSDK::CrCommandId command,
    SCRSDK::CrCommandParam param,
    void* context) {
    
    // Queue event for main thread processing
    SonyEventData* eventData = new SonyEventData{handle, api, command, param};
    s_AsyncEvent.data = eventData;
    uv_async_send(&s_AsyncEvent);
}

void SonyWrapper::StartLiveViewThread() {
    if (s_LiveViewThreadRunning) return;
    
    s_LiveViewThreadRunning = true;
    s_LiveViewThread = std::thread(LiveViewThreadFunction);
}

void SonyWrapper::StopLiveViewThread() {
    if (!s_LiveViewThreadRunning) return;
    
    s_LiveViewThreadRunning = false;
    s_LiveViewCondition.notify_all();
    
    if (s_LiveViewThread.joinable()) {
        s_LiveViewThread.join();
    }
}

void SonyWrapper::LiveViewThreadFunction() {
    static uint32_t frameCounter = 0;
    
    while (s_LiveViewThreadRunning) {
        if (!s_live_view_enabled) {
            std::this_thread::sleep_for(std::chrono::milliseconds(33));
            continue;
        }
        
        // Get live view image from Sony SDK
        SCRSDK::CrLiveViewProperty* liveViewProperty = nullptr;
        CrInt32s result = SCRSDK::CrSdkApi_GetLiveViewImage(s_device_handle, &liveViewProperty);
        
        if (result == SCRSDK::CrSdkApi_Result_Ok && liveViewProperty) {
            // Create live view data
            SonyLiveViewData* lvData = new SonyLiveViewData();
            
            CrInt8u* imageData = nullptr;
            CrInt32u imageSize = 0;
            liveViewProperty->GetImageData(&imageData, &imageSize);
            
            if (imageData && imageSize > 0) {
                lvData->imageData.assign(imageData, imageData + imageSize);
                lvData->width = liveViewProperty->GetImageWidth();
                lvData->height = liveViewProperty->GetImageHeight();
                lvData->frameNumber = ++frameCounter;
                
                // Send to main thread
                s_AsyncLiveView.data = lvData;
                uv_async_send(&s_AsyncLiveView);
            } else {
                delete lvData;
            }
            
            // Release live view property
            SCRSDK::CrSdkApi_ReleaseLiveViewProperty(s_device_handle, liveViewProperty);
        }
        
        // Target 30 FPS
        std::this_thread::sleep_for(std::chrono::milliseconds(33));
    }
}

// Helper method implementations
Local<Object> SonyWrapper::CreateCameraInfo(const SCRSDK::ICrCameraObjectInfo& cameraInfo) {
    Local<Object> info = Nan::New<Object>();
    
    Nan::Set(info, Nan::New("model").ToLocalChecked(), 
             Nan::New(cameraInfo.GetModel()).ToLocalChecked());
    Nan::Set(info, Nan::New("serialNumber").ToLocalChecked(), 
             Nan::New(cameraInfo.GetId()).ToLocalChecked());
    Nan::Set(info, Nan::New("connectionType").ToLocalChecked(), 
             Nan::New(cameraInfo.GetConnectionTypeName()).ToLocalChecked());
    
    return info;
}

Local<Object> SonyWrapper::CreatePropertyObject(const SCRSDK::CrDeviceProperty& property) {
    Local<Object> propObj = Nan::New<Object>();
    
    Nan::Set(propObj, Nan::New("code").ToLocalChecked(), 
             Nan::New(property.GetCode()));
    Nan::Set(propObj, Nan::New("currentValue").ToLocalChecked(), 
             ConvertPropertyToJSValue(property));
    Nan::Set(propObj, Nan::New("writable").ToLocalChecked(), 
             Nan::New(property.IsSetEnableCurrentValue()));
    
    return propObj;
}

// Async event callbacks for Node.js thread
void SonyWrapper::AsyncEventCallback(uv_async_t* handle) {
    Nan::HandleScope scope;
    
    SonyEventData* eventData = static_cast<SonyEventData*>(handle->data);
    if (!eventData) return;
    
    if (!s_EventCallback.IsEmpty()) {
        Local<Function> callback = Nan::New(s_EventCallback);
        Local<Value> argv[] = {
            Nan::New(static_cast<uint32_t>(eventData->api)),
            Nan::New(static_cast<uint32_t>(eventData->command)),
            Nan::New(static_cast<uint32_t>(eventData->param))
        };
        
        Nan::Call(callback, Nan::GetCurrentContext()->Global(), 3, argv);
    }
    
    delete eventData;
}

void SonyWrapper::AsyncLiveViewCallback(uv_async_t* handle) {
    Nan::HandleScope scope;
    
    SonyLiveViewData* lvData = static_cast<SonyLiveViewData*>(handle->data);
    if (!lvData) return;
    
    if (!s_LiveViewCallback.IsEmpty()) {
        Local<Function> callback = Nan::New(s_LiveViewCallback);
        
        // Convert image data to Node.js Buffer
        Local<Object> buffer = Nan::CopyBuffer(
            reinterpret_cast<const char*>(lvData->imageData.data()), 
            lvData->imageData.size()
        ).ToLocalChecked();
        
        Local<Value> argv[] = {
            buffer,
            Nan::New(lvData->width),
            Nan::New(lvData->height),
            Nan::New(lvData->frameNumber)
        };
        
        Nan::Call(callback, Nan::GetCurrentContext()->Global(), 4, argv);
    }
    
    delete lvData;
}

Nan::Persistent<Function> SonyWrapper::constructor;