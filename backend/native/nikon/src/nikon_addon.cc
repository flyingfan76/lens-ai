#include <nan.h>
#include <node.h>
#include "nikon_wrapper.h"

using namespace v8;

// Initialize the addon
void InitAll(Local<Object> exports) {
    Nan::Set(exports, Nan::New("NikonSDK").ToLocalChecked(),
             Nan::GetFunction(Nan::New<FunctionTemplate>(NikonWrapper::New)).ToLocalChecked());
}

NODE_MODULE(nikon_sdk, InitAll)