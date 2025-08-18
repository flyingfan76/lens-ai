#!/bin/bash

# Complete libgphoto2 setup script for Lens AI macOS
set -e

echo "🔧 Setting up libgphoto2 for Lens AI macOS..."

# Function to detect architecture
detect_arch() {
    if [[ $(uname -m) == "arm64" ]]; then
        echo "arm64"
    else
        echo "x86_64"
    fi
}

ARCH=$(detect_arch)
echo "📱 Detected architecture: $ARCH"

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Please install Homebrew first:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

echo "🍺 Homebrew found, updating..."
brew update

# Install libgphoto2 and dependencies
echo "📦 Installing libgphoto2 and dependencies..."

# For Apple Silicon, we might need to install both architectures
if [[ "$ARCH" == "arm64" ]]; then
    echo "🔄 Installing for Apple Silicon (arm64)..."
    arch -arm64 brew install libgphoto2 pkg-config cmake
    
    # Also install x86_64 version for compatibility if needed
    echo "🔄 Installing x86_64 version for compatibility..."
    arch -x86_64 brew install libgphoto2 pkg-config cmake || echo "⚠️  x86_64 install failed, continuing with arm64 only"
else
    echo "🔄 Installing for Intel (x86_64)..."
    brew install libgphoto2 pkg-config cmake
fi

# Verify installation
echo "✅ Verifying libgphoto2 installation..."

# Check libgphoto2 version
if command -v gphoto2 &> /dev/null; then
    echo "📸 gphoto2 version: $(gphoto2 --version | head -1)"
else
    echo "❌ gphoto2 command not found"
    exit 1
fi

# Check pkg-config
if pkg-config --exists libgphoto2; then
    GPHOTO2_VERSION=$(pkg-config --modversion libgphoto2)
    GPHOTO2_CFLAGS=$(pkg-config --cflags libgphoto2)
    GPHOTO2_LIBS=$(pkg-config --libs libgphoto2)
    
    echo "📚 libgphoto2 version: $GPHOTO2_VERSION"
    echo "🔧 CFLAGS: $GPHOTO2_CFLAGS"
    echo "🔗 LIBS: $GPHOTO2_LIBS"
else
    echo "❌ libgphoto2 pkg-config not found"
    exit 1
fi

# Find library paths
echo "🔍 Library paths:"
if [[ "$ARCH" == "arm64" ]]; then
    LIB_PATH="/opt/homebrew/lib"
    INCLUDE_PATH="/opt/homebrew/include"
else
    LIB_PATH="/usr/local/lib"  
    INCLUDE_PATH="/usr/local/include"
fi

echo "   Libraries: $LIB_PATH"
echo "   Headers: $INCLUDE_PATH"

# Check if libraries exist
if [[ -f "$LIB_PATH/libgphoto2.dylib" ]]; then
    echo "✅ libgphoto2.dylib found at $LIB_PATH"
else
    echo "❌ libgphoto2.dylib not found at $LIB_PATH"
    exit 1
fi

if [[ -f "$INCLUDE_PATH/gphoto2/gphoto2.h" ]]; then
    echo "✅ gphoto2.h found at $INCLUDE_PATH"
else
    echo "❌ gphoto2.h not found at $INCLUDE_PATH"
    exit 1
fi

# Test compilation
echo "🔨 Testing compilation..."
cat > test_gphoto2.c << 'EOF'
#include <gphoto2/gphoto2.h>
#include <stdio.h>

int main() {
    GPContext *context = gp_context_new();
    if (context) {
        printf("✅ libgphoto2 compilation test successful\n");
        gp_context_unref(context);
        return 0;
    } else {
        printf("❌ libgphoto2 compilation test failed\n");
        return 1;
    }
}
EOF

# Compile test
if gcc test_gphoto2.c $(pkg-config --cflags --libs libgphoto2) -o test_gphoto2; then
    echo "✅ Compilation successful"
    if ./test_gphoto2; then
        echo "✅ Runtime test successful"
    else
        echo "❌ Runtime test failed"
        exit 1
    fi
    rm -f test_gphoto2.c test_gphoto2
else
    echo "❌ Compilation failed"
    rm -f test_gphoto2.c
    exit 1
fi

# Create environment setup script
echo "📝 Creating environment setup script..."
cat > setup_env.sh << EOF
#!/bin/bash
# Environment setup for libgphoto2 development

export PKG_CONFIG_PATH="$LIB_PATH/pkgconfig:\$PKG_CONFIG_PATH"
export DYLD_LIBRARY_PATH="$LIB_PATH:\$DYLD_LIBRARY_PATH"
export CPATH="$INCLUDE_PATH:\$CPATH"
export LIBRARY_PATH="$LIB_PATH:\$LIBRARY_PATH"

echo "🔧 Environment configured for libgphoto2 development"
echo "   PKG_CONFIG_PATH: \$PKG_CONFIG_PATH"
echo "   DYLD_LIBRARY_PATH: \$DYLD_LIBRARY_PATH"
echo "   CPATH: \$CPATH"  
echo "   LIBRARY_PATH: \$LIBRARY_PATH"
EOF

chmod +x setup_env.sh

# Create Xcode configuration
echo "🍎 Creating Xcode configuration..."
cat > libgphoto2.xcconfig << EOF
// Xcode configuration for libgphoto2
LIBRARY_SEARCH_PATHS = $LIB_PATH \$(inherited)
HEADER_SEARCH_PATHS = $INCLUDE_PATH \$(inherited)
OTHER_LDFLAGS = -lgphoto2 -lgphoto2_port \$(inherited)
EOF

echo ""
echo "🎉 libgphoto2 setup complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Source the environment: source setup_env.sh"
echo "   2. Build your project with: flutter build macos"
echo "   3. For Xcode projects, add libgphoto2.xcconfig to your build settings"
echo ""
echo "🔍 Troubleshooting:"
echo "   • If you get permission errors, try: sudo chown -R \$(whoami) $LIB_PATH"
echo "   • For camera detection issues, unplug/replug your camera"
echo "   • Check camera compatibility: gphoto2 --auto-detect"
echo ""
echo "📸 Test camera detection:"
echo "   gphoto2 --auto-detect"
echo ""

# Test camera detection if available
echo "🔍 Testing camera detection..."
if gphoto2 --auto-detect 2>/dev/null | grep -v "Model" | grep -v "^$" | wc -l | grep -q "0"; then
    echo "📷 No cameras detected (this is normal if no camera is connected)"
else
    echo "📸 Camera(s) detected:"
    gphoto2 --auto-detect 2>/dev/null | grep -v "Model" | grep -v "^$"
fi

echo ""
echo "✨ Setup complete! You can now use libgphoto2 in your Lens AI project."