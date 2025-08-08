{
  "targets": [
    {
      "target_name": "canon_sdk",
      "sources": [
        "src/canon_addon.cc",
        "src/canon_wrapper.cc",
        "src/canon_camera.cc",
        "src/canon_liveview.cc"
      ],
      "include_dirs": [
        "<!(node -e \"require('nan')\")",
        "../../sdk/canon/include",
        "src"
      ],
      "libraries": [
        "-L../../sdk/canon/lib"
      ],
      "conditions": [
        ["OS=='win'", {
          "libraries": [
            "-L../../sdk/canon/lib/win64",
            "../../sdk/canon/lib/win64/EDSDK.lib"
          ],
          "defines": [
            "WIN32_LEAN_AND_MEAN",
            "_WIN32_WINNT=0x0600",
            "CANON_SDK_WINDOWS"
          ]
        }],
        ["OS=='mac'", {
          "libraries": [
            "-L../../sdk/canon/lib/mac",
            "-framework EDSDK",
            "-framework CoreFoundation",
            "-framework IOKit"
          ],
          "xcode_settings": {
            "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
            "CLANG_CXX_LIBRARY": "libc++",
            "MACOSX_DEPLOYMENT_TARGET": "10.9"
          },
          "defines": [
            "CANON_SDK_MAC"
          ]
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