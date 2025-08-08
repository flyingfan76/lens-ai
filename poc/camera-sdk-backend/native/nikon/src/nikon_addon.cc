#include <nan.h>
#include <node.h>
#include "nikon_wrapper_stub.h"

using namespace v8;

// Initialize the addon
void InitAll(Local<Object> exports) {
    NikonWrapper::Init(exports);
}

NODE_MODULE(nikon_sdk, InitAll)