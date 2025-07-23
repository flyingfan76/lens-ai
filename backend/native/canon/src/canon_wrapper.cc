#include "canon_wrapper.h"
#include <iostream>
#include <cstring>

using namespace v8;

// Static member initialization
EdsCameraListRef CanonWrapper::s_camera_list = nullptr;
EdsUInt32 CanonWrapper::s_camera_count = 0;
EdsCameraRef CanonWrapper::s_camera = nullptr;
bool CanonWrapper::s_session_open = false;
bool CanonWrapper::s_live_view_active = false;
Nan::Persistent<Function> CanonWrapper::s_EventCallback;
Nan::Persistent<Function> CanonWrapper::s_PropertyEventCallback;
Nan::Persistent<Function> CanonWrapper::s_ObjectEventCallback;
uv_async_t CanonWrapper::s_AsyncEvent;
uv_async_t CanonWrapper::s_AsyncPropertyEvent;
uv_async_t CanonWrapper::s_AsyncObjectEvent;

CanonWrapper::CanonWrapper() {}
CanonWrapper::~CanonWrapper() {}

void CanonWrapper::Init(Local<Object> exports) {
    Nan::HandleScope scope;

    // Prepare constructor template
    Local<FunctionTemplate> tpl = Nan::New<FunctionTemplate>(New);
    tpl->SetClassName(Nan::New("CanonSDK").ToLocalChecked());
    tpl->InstanceTemplate()->SetInternalFieldCount(1);

    // Prototype methods
    Nan::SetPrototypeMethod(tpl, "initialize", Initialize);
    Nan::SetPrototypeMethod(tpl, "terminate", Terminate);
    Nan::SetPrototypeMethod(tpl, "getCameraList", GetCameraList);
    Nan::SetPrototypeMethod(tpl, "openSession", OpenSession);
    Nan::SetPrototypeMethod(tpl, "closeSession", CloseSession);
    Nan::SetPrototypeMethod(tpl, "getPropertyData", GetPropertyData);
    Nan::SetPrototypeMethod(tpl, "setPropertyData", SetPropertyData);
    Nan::SetPrototypeMethod(tpl, "getPropertyDesc", GetPropertyDesc);
    Nan::SetPrototypeMethod(tpl, "startLiveView", StartLiveView);
    Nan::SetPrototypeMethod(tpl, "endLiveView", EndLiveView);
    Nan::SetPrototypeMethod(tpl, "downloadEvfImage", DownloadEvfImage);
    Nan::SetPrototypeMethod(tpl, "takePicture", TakePicture);
    Nan::SetPrototypeMethod(tpl, "pressPictureButton", PressPictureButton);
    Nan::SetPrototypeMethod(tpl, "releasePictureButton", ReleasePictureButton);
    Nan::SetPrototypeMethod(tpl, "setEventHandler", SetEventHandler);
    Nan::SetPrototypeMethod(tpl, "setPropertyEventHandler", SetPropertyEventHandler);
    Nan::SetPrototypeMethod(tpl, "setObjectEventHandler", SetObjectEventHandler);

    constructor.Reset(tpl->GetFunction());
    exports->Set(Nan::New("CanonSDK").ToLocalChecked(), tpl->GetFunction());
}

void CanonWrapper::New(const Nan::FunctionCallbackInfo<Value>& info) {
    if (info.IsConstructCall()) {
        CanonWrapper* obj = new CanonWrapper();
        obj->Wrap(info.This());
        info.GetReturnValue().Set(info.This());
    } else {
        const int argc = 1;
        Local<Value> argv[argc] = { info[0] };
        Local<Function> cons = Nan::New<Function>(constructor);
        info.GetReturnValue().Set(cons->NewInstance(argc, argv));
    }
}

void CanonWrapper::Initialize(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    try {
        InitializeSDK();
        
        // Initialize async handles for callbacks
        uv_async_init(uv_default_loop(), &s_AsyncEvent, AsyncEventCallback);
        uv_async_init(uv_default_loop(), &s_AsyncPropertyEvent, AsyncPropertyEventCallback);
        uv_async_init(uv_default_loop(), &s_AsyncObjectEvent, AsyncObjectEventCallback);

        info.GetReturnValue().Set(Nan::True());
        
    } catch (const std::exception& e) {
        Nan::ThrowError(e.what());
    }
}

void CanonWrapper::InitializeSDK() {
    // Initialize Canon EDSDK
    EdsError error = EdsInitializeSDK();
    if (error != EDS_ERR_OK) {
        throw std::runtime_error("Failed to initialize Canon EDSDK");
    }
    
    // Set camera added handler
    error = EdsSetCameraAddedHandler(HandleCameraAddedEvent, nullptr);
    if (error != EDS_ERR_OK) {
        std::cerr << "Warning: Failed to set camera added handler" << std::endl;
    }
}

void CanonWrapper::Terminate(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    CleanupSDK();
    info.GetReturnValue().Set(Nan::True());
}

void CanonWrapper::CleanupSDK() {
    if (s_session_open && s_camera) {
        EdsCloseSession(s_camera);
        s_session_open = false;
    }
    
    if (s_camera) {
        EdsRelease(s_camera);
        s_camera = nullptr;
    }
    
    if (s_camera_list) {
        EdsRelease(s_camera_list);
        s_camera_list = nullptr;
    }
    
    // Close async handles
    uv_close(reinterpret_cast<uv_handle_t*>(&s_AsyncEvent), nullptr);
    uv_close(reinterpret_cast<uv_handle_t*>(&s_AsyncPropertyEvent), nullptr);
    uv_close(reinterpret_cast<uv_handle_t*>(&s_AsyncObjectEvent), nullptr);
    
    // Terminate Canon EDSDK
    EdsTerminateSDK();
}

void CanonWrapper::GetCameraList(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    // Release previous camera list
    if (s_camera_list) {
        EdsRelease(s_camera_list);
        s_camera_list = nullptr;
    }

    // Get camera list
    EdsError error = EdsGetCameraList(&s_camera_list);
    if (error != EDS_ERR_OK) {
        Nan::ThrowError("Failed to get camera list");
        return;
    }

    // Get camera count
    error = EdsGetChildCount(s_camera_list, &s_camera_count);
    if (error != EDS_ERR_OK) {
        Nan::ThrowError("Failed to get camera count");
        return;
    }

    Local<Array> cameraArray = Nan::New<Array>();
    
    for (EdsUInt32 i = 0; i < s_camera_count; i++) {
        EdsCameraRef camera;
        error = EdsGetChildAtIndex(s_camera_list, i, &camera);
        
        if (error == EDS_ERR_OK) {
            Local<Object> cameraObj = CreateCameraInfo(camera);
            Nan::Set(cameraObj, Nan::New("index").ToLocalChecked(), Nan::New(i));
            Nan::Set(cameraArray, i, cameraObj);
            EdsRelease(camera);
        }
    }
    
    info.GetReturnValue().Set(cameraArray);
}

void CanonWrapper::OpenSession(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (info.Length() < 1 || !info[0]->IsNumber()) {
        Nan::ThrowTypeError("Camera index required");
        return;
    }

    EdsUInt32 cameraIndex = info[0]->Uint32Value();
    
    if (cameraIndex >= s_camera_count) {
        Nan::ThrowError("Invalid camera index");
        return;
    }

    if (s_session_open) {
        Nan::ThrowError("Session already open");
        return;
    }

    // Get camera reference
    EdsError error = EdsGetChildAtIndex(s_camera_list, cameraIndex, &s_camera);
    if (error != EDS_ERR_OK) {
        Nan::ThrowError("Failed to get camera reference");
        return;
    }

    // Open session
    error = EdsOpenSession(s_camera);
    if (error != EDS_ERR_OK) {
        EdsRelease(s_camera);
        s_camera = nullptr;
        Nan::ThrowError("Failed to open camera session");
        return;
    }

    s_session_open = true;

    // Set event handlers
    EdsSetPropertyEventHandler(s_camera, kEdsPropertyEvent_All, HandlePropertyEvent, nullptr);
    EdsSetObjectEventHandler(s_camera, kEdsObjectEvent_All, HandleObjectEvent, nullptr);
    EdsSetCameraStateEventHandler(s_camera, kEdsStateEvent_All, HandleStateEvent, nullptr);

    // Get camera info
    Local<Object> cameraInfo = CreateCameraInfo(s_camera);
    info.GetReturnValue().Set(cameraInfo);
}

void CanonWrapper::CloseSession(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (!s_session_open) {
        info.GetReturnValue().Set(Nan::True());
        return;
    }

    if (s_live_view_active) {
        EdsEvfOutputDevice device = kEdsEvfOutputDevice_None;
        EdsSetPropertyData(s_camera, kEdsPropID_Evf_OutputDevice, 0, sizeof(device), &device);
        s_live_view_active = false;
    }

    EdsCloseSession(s_camera);
    EdsRelease(s_camera);
    s_camera = nullptr;
    s_session_open = false;
    
    info.GetReturnValue().Set(Nan::True());
}

void CanonWrapper::GetPropertyData(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (info.Length() < 1 || !info[0]->IsNumber()) {
        Nan::ThrowTypeError("Property ID required");
        return;
    }

    if (!s_session_open) {
        Nan::ThrowError("No camera session open");
        return;
    }

    EdsPropertyID propertyID = static_cast<EdsPropertyID>(info[0]->Uint32Value());
    EdsUInt32 param = info.Length() > 1 ? info[1]->Uint32Value() : 0;
    
    EdsDataType dataType;
    EdsUInt32 size;
    
    // Get property size and type
    EdsError error = EdsGetPropertySize(s_camera, propertyID, param, &dataType, &size);
    if (error != EDS_ERR_OK) {
        Nan::ThrowError("Failed to get property size");
        return;
    }
    
    // Allocate buffer and get property data
    std::vector<EdsUInt8> buffer(size);
    error = EdsGetPropertyData(s_camera, propertyID, param, size, buffer.data());
    
    if (error != EDS_ERR_OK) {
        Nan::ThrowError("Failed to get property data");
        return;
    }
    
    // Convert to JavaScript value
    Local<Value> result = ConvertPropertyValue(propertyID, dataType, buffer.data(), size);
    info.GetReturnValue().Set(result);
}

void CanonWrapper::SetPropertyData(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (info.Length() < 2 || !info[0]->IsNumber()) {
        Nan::ThrowTypeError("Property ID and value required");
        return;
    }

    if (!s_session_open) {
        Nan::ThrowError("No camera session open");
        return;
    }

    EdsPropertyID propertyID = static_cast<EdsPropertyID>(info[0]->Uint32Value());
    EdsUInt32 param = info.Length() > 2 ? info[2]->Uint32Value() : 0;
    
    void* data;
    EdsUInt32 size;
    
    EdsError error = ConvertJSValueToProperty(info[1], propertyID, &data, &size);
    if (error != EDS_ERR_OK) {
        Nan::ThrowError("Failed to convert property value");
        return;
    }
    
    error = EdsSetPropertyData(s_camera, propertyID, param, size, data);
    
    // Free allocated data
    if (data) {
        free(data);
    }
    
    info.GetReturnValue().Set(Nan::New(error == EDS_ERR_OK));
}

void CanonWrapper::StartLiveView(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (!s_session_open) {
        Nan::ThrowError("No camera session open");
        return;
    }

    if (s_live_view_active) {
        info.GetReturnValue().Set(Nan::True());
        return;
    }

    // Set live view output device to PC
    EdsEvfOutputDevice device = kEdsEvfOutputDevice_PC;
    EdsError error = EdsSetPropertyData(s_camera, kEdsPropID_Evf_OutputDevice, 0, sizeof(device), &device);
    
    if (error == EDS_ERR_OK) {
        s_live_view_active = true;
        info.GetReturnValue().Set(Nan::True());
    } else {
        Nan::ThrowError("Failed to start live view");
    }
}

void CanonWrapper::EndLiveView(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (!s_live_view_active) {
        info.GetReturnValue().Set(Nan::True());
        return;
    }

    EdsEvfOutputDevice device = kEdsEvfOutputDevice_None;
    EdsSetPropertyData(s_camera, kEdsPropID_Evf_OutputDevice, 0, sizeof(device), &device);
    s_live_view_active = false;
    
    info.GetReturnValue().Set(Nan::True());
}

void CanonWrapper::DownloadEvfImage(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (!s_live_view_active) {
        Nan::ThrowError("Live view not active");
        return;
    }

    EdsEvfImageRef evfImage = nullptr;
    EdsError error = EdsCreateEvfImageRef(kEdsEvfImageFormat_JPEG, &evfImage);
    
    if (error != EDS_ERR_OK) {
        Nan::ThrowError("Failed to create EVF image reference");
        return;
    }

    error = EdsDownloadEvfImage(s_camera, evfImage);
    
    if (error == EDS_ERR_OK) {
        // Get image data
        EdsStreamRef stream = nullptr;
        error = EdsCreateMemoryStream(0, &stream);
        
        if (error == EDS_ERR_OK) {
            error = EdsGetImage(evfImage, kEdsImageSrc_FullView, kEdsTargetImageType_JPEG, 
                               EdsRect{0, 0, 0, 0}, kEdsImageSize_Full, stream);
            
            if (error == EDS_ERR_OK) {
                EdsVoid* buffer;
                EdsUInt64 size;
                EdsGetPointer(stream, &buffer);
                EdsGetLength(stream, &size);
                
                // Create Node.js Buffer
                Local<Object> nodeBuffer = Nan::CopyBuffer(static_cast<char*>(buffer), size).ToLocalChecked();
                info.GetReturnValue().Set(nodeBuffer);
            }
            
            EdsRelease(stream);
        }
    }
    
    if (evfImage) {
        EdsRelease(evfImage);
    }
    
    if (error != EDS_ERR_OK) {
        Nan::ThrowError("Failed to download EVF image");
    }
}

void CanonWrapper::TakePicture(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (!s_session_open) {
        Nan::ThrowError("No camera session open");
        return;
    }

    EdsError error = EdsSendCommand(s_camera, kEdsCameraCommand_TakePicture, 0);
    info.GetReturnValue().Set(Nan::New(error == EDS_ERR_OK));
}

// Canon EDSDK callback implementations
EdsError EDSCALLBACK CanonWrapper::HandleCameraAddedEvent(EdsVoid* context) {
    // Camera was connected - could trigger re-enumeration
    return EDS_ERR_OK;
}

EdsError EDSCALLBACK CanonWrapper::HandlePropertyEvent(
    EdsPropertyEvent inEvent,
    EdsPropertyID inPropertyID,
    EdsUInt32 inParam,
    EdsVoid* inContext) {
    
    // Queue property event for main thread
    CanonPropertyEventData* eventData = new CanonPropertyEventData{inEvent, inPropertyID, inParam};
    s_AsyncPropertyEvent.data = eventData;
    uv_async_send(&s_AsyncPropertyEvent);
    
    return EDS_ERR_OK;
}

EdsError EDSCALLBACK CanonWrapper::HandleObjectEvent(
    EdsObjectEvent inEvent,
    EdsBaseRef inRef,
    EdsVoid* inContext) {
    
    // Queue object event for main thread
    CanonObjectEventData* eventData = new CanonObjectEventData{inEvent, inRef};
    s_AsyncObjectEvent.data = eventData;
    uv_async_send(&s_AsyncObjectEvent);
    
    return EDS_ERR_OK;
}

EdsError EDSCALLBACK CanonWrapper::HandleStateEvent(
    EdsStateEvent inEvent,
    EdsUInt32 inEventData,
    EdsVoid* inContext) {
    
    // Handle state events (like shutdown, etc.)
    return EDS_ERR_OK;
}

// Helper method implementations
Local<Object> CanonWrapper::CreateCameraInfo(EdsCameraRef camera) {
    Local<Object> info = Nan::New<Object>();
    
    // Get device info
    EdsDeviceInfo deviceInfo;
    EdsError error = EdsGetDeviceInfo(camera, &deviceInfo);
    
    if (error == EDS_ERR_OK) {
        Nan::Set(info, Nan::New("model").ToLocalChecked(), 
                 Nan::New(deviceInfo.szDeviceDescription).ToLocalChecked());
        Nan::Set(info, Nan::New("portName").ToLocalChecked(), 
                 Nan::New(deviceInfo.szPortName).ToLocalChecked());
    }
    
    return info;
}

Local<Value> CanonWrapper::ConvertPropertyValue(EdsPropertyID propertyID, EdsDataType dataType, void* data, EdsUInt32 size) {
    switch (dataType) {
        case kEdsDataType_UInt32:
            return Nan::New(*static_cast<EdsUInt32*>(data));
        case kEdsDataType_Int32:
            return Nan::New(*static_cast<EdsInt32*>(data));
        case kEdsDataType_String:
            return Nan::New(static_cast<char*>(data)).ToLocalChecked();
        case kEdsDataType_ByteBlock:
            return Nan::CopyBuffer(static_cast<char*>(data), size).ToLocalChecked();
        default:
            return Nan::Null();
    }
}

// Async event callbacks for Node.js thread
void CanonWrapper::AsyncPropertyEventCallback(uv_async_t* handle) {
    Nan::HandleScope scope;
    
    CanonPropertyEventData* eventData = static_cast<CanonPropertyEventData*>(handle->data);
    if (!eventData) return;
    
    if (!s_PropertyEventCallback.IsEmpty()) {
        Local<Function> callback = Nan::New(s_PropertyEventCallback);
        Local<Value> argv[] = {
            Nan::New(static_cast<uint32_t>(eventData->event)),
            Nan::New(static_cast<uint32_t>(eventData->propertyID)),
            Nan::New(eventData->param)
        };
        
        Nan::Call(callback, Nan::GetCurrentContext()->Global(), 3, argv);
    }
    
    delete eventData;
}

void CanonWrapper::AsyncObjectEventCallback(uv_async_t* handle) {
    Nan::HandleScope scope;
    
    CanonObjectEventData* eventData = static_cast<CanonObjectEventData*>(handle->data);
    if (!eventData) return;
    
    if (!s_ObjectEventCallback.IsEmpty()) {
        Local<Function> callback = Nan::New(s_ObjectEventCallback);
        Local<Value> argv[] = {
            Nan::New(static_cast<uint32_t>(eventData->event)),
            Nan::New(static_cast<uint32_t>(reinterpret_cast<uintptr_t>(eventData->ref)))
        };
        
        Nan::Call(callback, Nan::GetCurrentContext()->Global(), 2, argv);
    }
    
    delete eventData;
}

Nan::Persistent<Function> CanonWrapper::constructor;