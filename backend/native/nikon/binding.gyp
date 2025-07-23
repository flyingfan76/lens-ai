{
  "targets": [
    {
      "target_name": "nikon_sdk",
      "sources": [
        "src/nikon_addon.cc",
        "src/nikon_wrapper.cc",
        "src/nikon_camera.cc",
        "src/nikon_events.cc"
      ],
      "include_dirs": [
        "<!(node -e \"require('nan')\")",
        "../../sdk/nikon/include",
        "src"
      ],
      "libraries": [
        "-L../../sdk/nikon/lib",
        "-lNkMaid"
      ],
      "conditions": [
        ["OS=='win'", {
          "libraries": [
            "-L../../sdk/nikon/lib/win64",
            "../../sdk/nikon/lib/win64/NkMaid.lib"
          ],
          "defines": [
            "WIN32_LEAN_AND_MEAN",
            "_WIN32_WINNT=0x0600"
          ]
        }],
        ["OS=='mac'", {
          "libraries": [
            "-L../../sdk/nikon/lib/mac",
            "-framework CoreFoundation",
            "-framework IOKit"
          ],
          "xcode_settings": {
            "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
            "CLANG_CXX_LIBRARY": "libc++",
            "MACOSX_DEPLOYMENT_TARGET": "10.9"
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