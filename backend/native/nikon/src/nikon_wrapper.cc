#include "nikon_wrapper.h"
#include <iostream>
#include <cstring>

using namespace v8;

// Static member initialization
LPNkMAIDObject NikonWrapper::s_pRefModule = nullptr;
LPNkMAIDObject NikonWrapper::s_pRefDevice = nullptr;
std::vector<NkMAIDModInfo> NikonWrapper::s_ModuleList;
std::map<ULONG, NkMAIDCapInfo> NikonWrapper::s_CapabilityMap;
Nan::Persistent<Function> NikonWrapper::s_EventCallback;
Nan::Persistent<Function> NikonWrapper::s_ProgressCallback;
uv_async_t NikonWrapper::s_AsyncEvent;
uv_async_t NikonWrapper::s_AsyncProgress;

NikonWrapper::NikonWrapper() {}
NikonWrapper::~NikonWrapper() {}

void NikonWrapper::Init(Local<Object> exports) {
    Nan::HandleScope scope;

    // Prepare constructor template
    Local<FunctionTemplate> tpl = Nan::New<FunctionTemplate>(New);
    tpl->SetClassName(Nan::New("NikonSDK").ToLocalChecked());
    tpl->InstanceTemplate()->SetInternalFieldCount(1);

    // Prototype methods
    Nan::SetPrototypeMethod(tpl, "initialize", Initialize);
    Nan::SetPrototypeMethod(tpl, "terminate", Terminate);
    Nan::SetPrototypeMethod(tpl, "getModuleList", GetModuleList);
    Nan::SetPrototypeMethod(tpl, "openDevice", OpenDevice);
    Nan::SetPrototypeMethod(tpl, "closeDevice", CloseDevice);
    Nan::SetPrototypeMethod(tpl, "getCapabilities", GetCapabilities);
    Nan::SetPrototypeMethod(tpl, "getCapInfo", GetCapInfo);
    Nan::SetPrototypeMethod(tpl, "setCapInfo", SetCapInfo);
    Nan::SetPrototypeMethod(tpl, "startLiveView", StartLiveView);
    Nan::SetPrototypeMethod(tpl, "stopLiveView", StopLiveView);
    Nan::SetPrototypeMethod(tpl, "getLiveViewImage", GetLiveViewImage);
    Nan::SetPrototypeMethod(tpl, "takePicture", TakePicture);
    Nan::SetPrototypeMethod(tpl, "setEventCallback", SetEventCallback);
    Nan::SetPrototypeMethod(tpl, "setProgressCallback", SetProgressCallback);

    constructor.Reset(tpl->GetFunction());
    exports->Set(Nan::New("NikonSDK").ToLocalChecked(), tpl->GetFunction());
}

void NikonWrapper::New(const Nan::FunctionCallbackInfo<Value>& info) {
    if (info.IsConstructCall()) {
        NikonWrapper* obj = new NikonWrapper();
        obj->Wrap(info.This());
        info.GetReturnValue().Set(info.This());
    } else {
        const int argc = 1;
        Local<Value> argv[argc] = { info[0] };
        Local<Function> cons = Nan::New<Function>(constructor);
        info.GetReturnValue().Set(cons->NewInstance(argc, argv));
    }
}

void NikonWrapper::Initialize(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    try {
        // Initialize MAID API
        SLONG result = ::NkMAID_Initialize();
        
        if (result != kNkMAIDResult_NoError) {
            Nan::ThrowError("Failed to initialize Nikon MAID API");
            return;
        }

        // Initialize async handles for event callbacks
        uv_async_init(uv_default_loop(), &s_AsyncEvent, AsyncEventCallback);
        uv_async_init(uv_default_loop(), &s_AsyncProgress, AsyncProgressCallback);

        // Get module list
        NkMAIDModInfo modInfo;
        ULONG moduleCount = 0;
        
        result = ::NkMAID_GetModuleInfo(nullptr, &moduleCount);
        if (result == kNkMAIDResult_NoError && moduleCount > 0) {
            s_ModuleList.resize(moduleCount);
            result = ::NkMAID_GetModuleInfo(s_ModuleList.data(), &moduleCount);
            
            if (result == kNkMAIDResult_NoError) {
                // Initialize first available module
                s_pRefModule = new NkMAIDObject;
                std::memset(s_pRefModule, 0, sizeof(NkMAIDObject));
                
                result = ::NkMAID_Open(&s_ModuleList[0], s_pRefModule);
                if (result != kNkMAIDResult_NoError) {
                    delete s_pRefModule;
                    s_pRefModule = nullptr;
                    Nan::ThrowError("Failed to open Nikon module");
                    return;
                }
            }
        }

        info.GetReturnValue().Set(Nan::New(result == kNkMAIDResult_NoError));
        
    } catch (const std::exception& e) {
        Nan::ThrowError(e.what());
    }
}

void NikonWrapper::Terminate(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    CleanupResources();
    
    SLONG result = ::NkMAID_Terminate();
    info.GetReturnValue().Set(Nan::New(result == kNkMAIDResult_NoError));
}

void NikonWrapper::GetModuleList(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    Local<Array> moduleArray = Nan::New<Array>();
    
    for (size_t i = 0; i < s_ModuleList.size(); i++) {
        Local<Object> moduleObj = Nan::New<Object>();
        
        Nan::Set(moduleObj, Nan::New("name").ToLocalChecked(), 
                 Nan::New(s_ModuleList[i].szName).ToLocalChecked());
        Nan::Set(moduleObj, Nan::New("version").ToLocalChecked(), 
                 Nan::New(s_ModuleList[i].ulVersion));
        Nan::Set(moduleObj, Nan::New("id").ToLocalChecked(), 
                 Nan::New(s_ModuleList[i].ulID));
        
        Nan::Set(moduleArray, i, moduleObj);
    }
    
    info.GetReturnValue().Set(moduleArray);
}

void NikonWrapper::OpenDevice(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (info.Length() < 1 || !info[0]->IsNumber()) {
        Nan::ThrowTypeError("Device index required");
        return;
    }

    ULONG deviceIndex = info[0]->Uint32Value();
    
    if (!s_pRefModule) {
        Nan::ThrowError("Module not initialized");
        return;
    }

    // Get device list
    ULONG deviceCount = 0;
    SLONG result = ::NkMAID_GetChildren(s_pRefModule, nullptr, &deviceCount);
    
    if (result != kNkMAIDResult_NoError || deviceIndex >= deviceCount) {
        Nan::ThrowError("Invalid device index or no devices found");
        return;
    }

    // Allocate device array
    std::vector<NkMAIDChild> children(deviceCount);
    result = ::NkMAID_GetChildren(s_pRefModule, children.data(), &deviceCount);
    
    if (result != kNkMAIDResult_NoError) {
        Nan::ThrowError("Failed to get device list");
        return;
    }

    // Open selected device
    s_pRefDevice = new NkMAIDObject;
    std::memset(s_pRefDevice, 0, sizeof(NkMAIDObject));
    
    result = ::NkMAID_Open(&children[deviceIndex], s_pRefDevice);
    
    if (result != kNkMAIDResult_NoError) {
        delete s_pRefDevice;
        s_pRefDevice = nullptr;
        Nan::ThrowError("Failed to open device");
        return;
    }

    // Set event callback
    result = ::NkMAID_SetEventProc(s_pRefDevice, EventProc, nullptr);
    if (result != kNkMAIDResult_NoError) {
        std::cerr << "Warning: Failed to set event callback" << std::endl;
    }

    // Initialize capabilities
    InitializeCapabilities();

    // Get device info
    NkMAIDDeviceInfo deviceInfo;
    ULONG size = sizeof(deviceInfo);
    result = ::NkMAID_GetCapInfo(s_pRefDevice, kNkMAIDCapability_DeviceInfo, &deviceInfo, &size);
    
    Local<Object> deviceObj = Nan::New<Object>();
    if (result == kNkMAIDResult_NoError) {
        deviceObj = CreateCameraInfo(deviceInfo);
    }

    info.GetReturnValue().Set(deviceObj);
}

void NikonWrapper::CloseDevice(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (s_pRefDevice) {
        ::NkMAID_Close(s_pRefDevice);
        delete s_pRefDevice;
        s_pRefDevice = nullptr;
    }

    s_CapabilityMap.clear();
    info.GetReturnValue().Set(Nan::True());
}

void NikonWrapper::GetCapInfo(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (info.Length() < 1 || !info[0]->IsNumber()) {
        Nan::ThrowTypeError("Capability ID required");
        return;
    }

    if (!s_pRefDevice) {
        Nan::ThrowError("No device connected");
        return;
    }

    ULONG capability = info[0]->Uint32Value();
    
    // Check if capability is supported
    if (s_CapabilityMap.find(capability) == s_CapabilityMap.end()) {
        Nan::ThrowError("Capability not supported");
        return;
    }

    const NkMAIDCapInfo& capInfo = s_CapabilityMap[capability];
    ULONG dataSize = capInfo.ulSize;
    std::vector<BYTE> data(dataSize);
    
    SLONG result = ::NkMAID_GetCapInfo(s_pRefDevice, capability, data.data(), &dataSize);
    
    if (result != kNkMAIDResult_NoError) {
        Nan::ThrowError("Failed to get capability info");
        return;
    }

    // Convert data based on capability type
    Local<Value> value;
    switch (capInfo.ulType) {
        case kNkMAIDCapType_Unsigned:
            value = Nan::New(*reinterpret_cast<ULONG*>(data.data()));
            break;
        case kNkMAIDCapType_Integer:
            value = Nan::New(*reinterpret_cast<SLONG*>(data.data()));
            break;
        case kNkMAIDCapType_String:
            value = Nan::New(reinterpret_cast<char*>(data.data())).ToLocalChecked();
            break;
        case kNkMAIDCapType_DateTime:
            // Convert to JavaScript Date
            value = Nan::New<Date>(*reinterpret_cast<double*>(data.data())).ToLocalChecked();
            break;
        default:
            // Return raw buffer for complex types
            value = Nan::CopyBuffer(reinterpret_cast<char*>(data.data()), dataSize).ToLocalChecked();
            break;
    }
    
    info.GetReturnValue().Set(value);
}

void NikonWrapper::SetCapInfo(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (info.Length() < 2 || !info[0]->IsNumber()) {
        Nan::ThrowTypeError("Capability ID and value required");
        return;
    }

    if (!s_pRefDevice) {
        Nan::ThrowError("No device connected");
        return;
    }

    ULONG capability = info[0]->Uint32Value();
    
    if (s_CapabilityMap.find(capability) == s_CapabilityMap.end()) {
        Nan::ThrowError("Capability not supported");
        return;
    }

    const NkMAIDCapInfo& capInfo = s_CapabilityMap[capability];
    
    // Check if capability is writable
    if (!(capInfo.ulOperations & kNkMAIDCapOperation_CanSet)) {
        Nan::ThrowError("Capability is read-only");
        return;
    }

    // Convert JavaScript value to appropriate type
    std::vector<BYTE> data(capInfo.ulSize);
    Local<Value> jsValue = info[1];
    
    switch (capInfo.ulType) {
        case kNkMAIDCapType_Unsigned:
            *reinterpret_cast<ULONG*>(data.data()) = jsValue->Uint32Value();
            break;
        case kNkMAIDCapType_Integer:
            *reinterpret_cast<SLONG*>(data.data()) = jsValue->Int32Value();
            break;
        case kNkMAIDCapType_String: {
            String::Utf8Value str(jsValue);
            std::strncpy(reinterpret_cast<char*>(data.data()), *str, capInfo.ulSize - 1);
            data[capInfo.ulSize - 1] = '\0';
            break;
        }
        default:
            Nan::ThrowError("Unsupported capability type for setting");
            return;
    }
    
    SLONG result = ::NkMAID_SetCapInfo(s_pRefDevice, capability, data.data(), capInfo.ulSize);
    
    if (result != kNkMAIDResult_NoError) {
        Nan::ThrowError("Failed to set capability");
        return;
    }
    
    info.GetReturnValue().Set(Nan::True());
}

void NikonWrapper::TakePicture(const Nan::FunctionCallbackInfo<Value>& info) {
    Nan::HandleScope scope;

    if (!s_pRefDevice) {
        Nan::ThrowError("No device connected");
        return;
    }

    // Trigger capture
    ULONG captureFlag = 1;
    SLONG result = ::NkMAID_SetCapInfo(s_pRefDevice, kNkMAIDCapability_Capture, &captureFlag, sizeof(captureFlag));
    
    if (result != kNkMAIDResult_NoError) {
        Nan::ThrowError("Failed to trigger capture");
        return;
    }
    
    info.GetReturnValue().Set(Nan::True());
}

// Event callback from MAID API
SLONG CALLBACK NikonWrapper::EventProc(ULONG ulEvent, LPVOID pContext, LPVOID pData) {
    // Queue event for main thread processing
    EventData* eventData = new EventData{ulEvent, pContext, pData, 0};
    s_AsyncEvent.data = eventData;
    uv_async_send(&s_AsyncEvent);
    
    return kNkMAIDResult_NoError;
}

// Progress callback from MAID API
SLONG CALLBACK NikonWrapper::ProgressProc(ULONG ulCommand, ULONG ulParam, LPVOID pData, ULONG ulDataSize, LPVOID pContext) {
    ProgressData* progressData = new ProgressData{ulCommand, ulParam, pData, ulDataSize};
    s_AsyncProgress.data = progressData;
    uv_async_send(&s_AsyncProgress);
    
    return kNkMAIDResult_NoError;
}

// Async event callback for Node.js thread
void NikonWrapper::AsyncEventCallback(uv_async_t* handle) {
    Nan::HandleScope scope;
    
    EventData* eventData = static_cast<EventData*>(handle->data);
    if (!eventData) return;
    
    if (!s_EventCallback.IsEmpty()) {
        Local<Function> callback = Nan::New(s_EventCallback);
        Local<Value> argv[] = {
            Nan::New(eventData->event),
            Nan::Null(), // context - simplified for now
            Nan::Null()  // data - simplified for now
        };
        
        Nan::Call(callback, Nan::GetCurrentContext()->Global(), 3, argv);
    }
    
    delete eventData;
}

// Helper methods implementation
void NikonWrapper::InitializeCapabilities() {
    if (!s_pRefDevice) return;
    
    ULONG capCount = 0;
    SLONG result = ::NkMAID_GetCapCount(s_pRefDevice, &capCount);
    
    if (result == kNkMAIDResult_NoError && capCount > 0) {
        std::vector<ULONG> capArray(capCount);
        result = ::NkMAID_GetCapArray(s_pRefDevice, capArray.data(), &capCount);
        
        if (result == kNkMAIDResult_NoError) {
            for (ULONG i = 0; i < capCount; i++) {
                NkMAIDCapInfo capInfo;
                ULONG size = sizeof(capInfo);
                
                result = ::NkMAID_GetCapInfo(s_pRefDevice, capArray[i], &capInfo, &size);
                if (result == kNkMAIDResult_NoError) {
                    s_CapabilityMap[capArray[i]] = capInfo;
                }
            }
        }
    }
}

Local<Object> NikonWrapper::CreateCameraInfo(const NkMAIDDeviceInfo& deviceInfo) {
    Local<Object> info = Nan::New<Object>();
    
    Nan::Set(info, Nan::New("model").ToLocalChecked(), 
             Nan::New(deviceInfo.szName).ToLocalChecked());
    Nan::Set(info, Nan::New("serialNumber").ToLocalChecked(), 
             Nan::New(deviceInfo.szSerial).ToLocalChecked());
    Nan::Set(info, Nan::New("firmwareVersion").ToLocalChecked(), 
             Nan::New(deviceInfo.szFirmware).ToLocalChecked());
    
    return info;
}

void NikonWrapper::CleanupResources() {
    if (s_pRefDevice) {
        ::NkMAID_Close(s_pRefDevice);
        delete s_pRefDevice;
        s_pRefDevice = nullptr;
    }
    
    if (s_pRefModule) {
        ::NkMAID_Close(s_pRefModule);
        delete s_pRefModule;
        s_pRefModule = nullptr;
    }
    
    s_CapabilityMap.clear();
    s_ModuleList.clear();
    
    // Close async handles
    uv_close(reinterpret_cast<uv_handle_t*>(&s_AsyncEvent), nullptr);
    uv_close(reinterpret_cast<uv_handle_t*>(&s_AsyncProgress), nullptr);
}

Nan::Persistent<Function> NikonWrapper::constructor;