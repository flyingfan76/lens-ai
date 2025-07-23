#ifndef NIKON_WRAPPER_H
#define NIKON_WRAPPER_H

#include <nan.h>
#include <node.h>
#include <uv.h>
#include "NkMaid.h"
#include <vector>
#include <map>
#include <memory>

using namespace v8;

class NikonWrapper : public Nan::ObjectWrap {
public:
    static void Init(Local<Object> exports);
    static void New(const Nan::FunctionCallbackInfo<Value>& info);

    // Core SDK methods
    static void Initialize(const Nan::FunctionCallbackInfo<Value>& info);
    static void Terminate(const Nan::FunctionCallbackInfo<Value>& info);
    
    // Camera discovery and connection
    static void GetModuleList(const Nan::FunctionCallbackInfo<Value>& info);
    static void OpenDevice(const Nan::FunctionCallbackInfo<Value>& info);
    static void CloseDevice(const Nan::FunctionCallbackInfo<Value>& info);
    
    // Camera capabilities and properties
    static void GetCapabilities(const Nan::FunctionCallbackInfo<Value>& info);
    static void GetCapInfo(const Nan::FunctionCallbackInfo<Value>& info);
    static void SetCapInfo(const Nan::FunctionCallbackInfo<Value>& info);
    
    // Live view operations
    static void StartLiveView(const Nan::FunctionCallbackInfo<Value>& info);
    static void StopLiveView(const Nan::FunctionCallbackInfo<Value>& info);
    static void GetLiveViewImage(const Nan::FunctionCallbackInfo<Value>& info);
    
    // Image capture
    static void TakePicture(const Nan::FunctionCallbackInfo<Value>& info);
    
    // Event handling
    static void SetEventCallback(const Nan::FunctionCallbackInfo<Value>& info);
    static void SetProgressCallback(const Nan::FunctionCallbackInfo<Value>& info);

private:
    explicit NikonWrapper();
    ~NikonWrapper();

    // MAID API handles
    static LPNkMAIDObject s_pRefModule;
    static LPNkMAIDObject s_pRefDevice;
    static std::vector<NkMAIDModInfo> s_ModuleList;
    static std::map<ULONG, NkMAIDCapInfo> s_CapabilityMap;
    
    // Event callbacks
    static Nan::Persistent<Function> s_EventCallback;
    static Nan::Persistent<Function> s_ProgressCallback;
    
    // Threading support
    static uv_async_t s_AsyncEvent;
    static uv_async_t s_AsyncProgress;
    
    // Helper methods
    static SLONG SetCapabilityData(ULONG capability, LPVOID data, ULONG size);
    static SLONG GetCapabilityData(ULONG capability, LPVOID data, ULONG* size);
    static void InitializeCapabilities();
    static void CleanupResources();
    
    // Event handlers
    static SLONG CALLBACK EventProc(ULONG ulEvent, LPVOID pContext, LPVOID pData);
    static SLONG CALLBACK ProgressProc(ULONG ulCommand, ULONG ulParam, LPVOID pData, ULONG ulDataSize, LPVOID pContext);
    
    // Async event handlers for Node.js thread safety
    static void AsyncEventCallback(uv_async_t* handle);
    static void AsyncProgressCallback(uv_async_t* handle);
    
    // Utility functions
    static Local<Object> CreateCameraInfo(const NkMAIDDeviceInfo& deviceInfo);
    static Local<Array> CreateCapabilityArray(const std::vector<NkMAIDCapInfo>& capabilities);
    static bool IsCapabilitySupported(ULONG capability);
};

// Event data structures for async callbacks
struct EventData {
    ULONG event;
    LPVOID context;
    LPVOID data;
    ULONG dataSize;
};

struct ProgressData {
    ULONG command;
    ULONG param;
    LPVOID data;
    ULONG dataSize;
};

#endif // NIKON_WRAPPER_H