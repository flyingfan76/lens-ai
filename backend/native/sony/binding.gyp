{
  "targets": [
    {
      "target_name": "sony_sdk",
      "sources": [
        "src/sony_addon.cc",
        "src/sony_wrapper.cc",
        "src/sony_camera.cc",
        "src/sony_discovery.cc"
      ],
      "include_dirs": [
        "<!(node -e \"require('nan')\")",
        "../../sdk/sony/include",
        "src"
      ],
      "libraries": [
        "-L../../sdk/sony/lib"
      ],
      "conditions": [
        ["OS=='win'", {
          "libraries": [
            "-L../../sdk/sony/lib/win64",
            "../../sdk/sony/lib/win64/CrSDK.lib",
            "../../sdk/sony/lib/win64/SonyAPI.lib",
            "-lws2_32",
            "-lwsock32"
          ],
          "defines": [
            "WIN32_LEAN_AND_MEAN",
            "_WIN32_WINNT=0x0600",
            "SONY_SDK_WINDOWS"
          ]
        }],
        ["OS=='mac'", {
          "libraries": [
            "-L../../sdk/sony/lib/mac",
            "-framework CoreFoundation",
            "-framework SystemConfiguration",
            "-framework Security"
          ],
          "xcode_settings": {
            "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
            "CLANG_CXX_LIBRARY": "libc++",
            "MACOSX_DEPLOYMENT_TARGET": "10.12"
          },
          "defines": [
            "SONY_SDK_MAC"
          ]
        }],
        ["OS=='linux'", {
          "libraries": [
            "-L../../sdk/sony/lib/linux",
            "-lCrSDK",
            "-lpthread",
            "-lcurl"
          ],
          "defines": [
            "SONY_SDK_LINUX"
          ]
        }]
      ],
      "cflags_cc": [
        "-std=c++14",
        "-fexceptions"
      ],
      "defines": [
        "NAPI_DISABLE_CPP_EXCEPTIONS"
      ]
    }
  ]
}