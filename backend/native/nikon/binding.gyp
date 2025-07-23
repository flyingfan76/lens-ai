{
  "targets": [
    {
      "target_name": "nikon_sdk",
      "sources": [
        "src/nikon_addon.cc",
        "src/nikon_wrapper_stub.cc"
      ],
      "include_dirs": [
        "<!(node -e \"require('nan')\")",
        "src"
      ],
      "conditions": [
        ["OS=='mac'", {
          "xcode_settings": {
            "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
            "CLANG_CXX_LIBRARY": "libc++",
            "MACOSX_DEPLOYMENT_TARGET": "10.12"
          }
        }]
      ],
      "cflags_cc": [
        "-std=c++11",
        "-fexceptions"
      ],
      "defines": [
        "NAPI_DISABLE_CPP_EXCEPTIONS"
      ]
    }
  ]
}