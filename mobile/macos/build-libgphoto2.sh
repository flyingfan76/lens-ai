#!/bin/bash

# Build script for libgphoto2 native integration
set -e

echo "🔧 Building libgphoto2 native integration..."

# Configuration
BUILD_DIR="build-native"
CMAKE_BUILD_TYPE="Debug"
VERBOSE=${VERBOSE:-"OFF"}

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --release)
        CMAKE_BUILD_TYPE="Release"
        shift
        ;;
        --verbose)
        VERBOSE="ON"
        shift
        ;;
        --clean)
        echo "🧹 Cleaning build directory..."
        rm -rf "$BUILD_DIR"
        shift
        ;;
        *)
        echo "Unknown option: $1"
        echo "Usage: $0 [--release] [--verbose] [--clean]"
        exit 1
        ;;
    esac
done

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "📋 Build Configuration:"
echo "   🏗️  Type: $CMAKE_BUILD_TYPE"
echo "   📁 Directory: $(pwd)"
echo "   🔍 Verbose: $VERBOSE"

# Check dependencies
echo ""
echo "🔍 Checking dependencies..."

# Check libgphoto2
if ! pkg-config --exists libgphoto2; then
    echo "❌ libgphoto2 not found. Please install:"
    echo "   brew install libgphoto2"
    exit 1
fi

GPHOTO2_VERSION=$(pkg-config --modversion libgphoto2)
echo "✅ libgphoto2 $GPHOTO2_VERSION found"

# Check CMake
if ! command -v cmake &> /dev/null; then
    echo "❌ CMake not found. Please install:"
    echo "   brew install cmake"
    exit 1
fi

CMAKE_VERSION=$(cmake --version | head -1 | cut -d' ' -f3)
echo "✅ CMake $CMAKE_VERSION found"

# Configure with CMake
echo ""
echo "⚙️  Configuring CMake..."

CMAKE_ARGS=(
    -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE"
    -DCMAKE_OSX_DEPLOYMENT_TARGET=10.14
    -DCMAKE_C_COMPILER=clang
)

# Add architecture-specific settings
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES="arm64")
    echo "🏗️  Building for Apple Silicon (arm64)"
else
    CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES="x86_64")
    echo "🏗️  Building for Intel (x86_64)"
fi

# Set verbose output if requested
if [[ "$VERBOSE" == "ON" ]]; then
    CMAKE_ARGS+=(-DCMAKE_VERBOSE_MAKEFILE=ON)
fi

# Run CMake configure
if cmake "${CMAKE_ARGS[@]}" ..; then
    echo "✅ CMake configuration successful"
else
    echo "❌ CMake configuration failed"
    exit 1
fi

# Build
echo ""
echo "🔨 Building native library..."

BUILD_ARGS=(
    --build .
    --config "$CMAKE_BUILD_TYPE"
)

if [[ "$VERBOSE" == "ON" ]]; then
    BUILD_ARGS+=(--verbose)
fi

# Add parallel build
NCPUS=$(sysctl -n hw.ncpu)
BUILD_ARGS+=(--parallel "$NCPUS")

echo "🚀 Using $NCPUS parallel jobs"

if cmake "${BUILD_ARGS[@]}"; then
    echo "✅ Build successful"
else
    echo "❌ Build failed"
    exit 1
fi

# Verify output
echo ""
echo "🔍 Verifying build output..."

LIBRARY_PATH="lib/liblibgphoto2_native.a"
if [[ -f "$LIBRARY_PATH" ]]; then
    LIBRARY_SIZE=$(ls -lh "$LIBRARY_PATH" | awk '{print $5}')
    echo "✅ Library created: $LIBRARY_PATH ($LIBRARY_SIZE)"
    
    # Show library info
    echo "📊 Library information:"
    file "$LIBRARY_PATH" | sed 's/^/   /'
    
    # Check symbols
    echo "🔗 Library symbols (sample):"
    nm "$LIBRARY_PATH" 2>/dev/null | grep gphoto2 | head -5 | sed 's/^/   /' || echo "   (No symbols found - this is normal for release builds)"
    
else
    echo "❌ Library not found: $LIBRARY_PATH"
    echo "📁 Files in build directory:"
    find . -name "*.a" -o -name "*.dylib" | sed 's/^/   /'
    exit 1
fi

# Copy to Flutter build directory if it exists
FLUTTER_BUILD_DIR="../../../build/macos/Build/Products/$CMAKE_BUILD_TYPE"
if [[ -d "$FLUTTER_BUILD_DIR" ]]; then
    echo ""
    echo "📦 Copying to Flutter build directory..."
    cp "$LIBRARY_PATH" "$FLUTTER_BUILD_DIR/"
    echo "✅ Copied to: $FLUTTER_BUILD_DIR/liblibgphoto2_native.a"
else
    echo "ℹ️  Flutter build directory not found (this is normal if Flutter hasn't built yet)"
fi

echo ""
echo "🎉 libgphoto2 native integration build complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Run: flutter build macos"
echo "   2. The library will be automatically linked"
echo "   3. Enable LibGPhoto2Swift plugin in MainFlutterWindow.swift"
echo ""
echo "🔧 Build summary:"
echo "   📁 Build dir: $(pwd)"
echo "   📦 Library: $LIBRARY_PATH"
echo "   🏗️  Type: $CMAKE_BUILD_TYPE"
echo "   🎯 Target: $ARCH"
echo ""