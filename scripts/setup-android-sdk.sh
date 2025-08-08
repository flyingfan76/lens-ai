#!/bin/bash

# Android SDK Setup Script for Lens AI
# Requirements: JDK 17+ installed

echo "Setting up Android SDK for Flutter development..."

# Check Java version
JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F '.' '{print $1}')
if [ "$JAVA_VERSION" -lt 17 ]; then
    echo "❌ Error: JDK 17+ is required. Current version: $JAVA_VERSION"
    echo "Please ask your IT department to install OpenJDK 17 or higher."
    exit 1
fi

# Set environment variables
export JAVA_HOME=$(/usr/libexec/java_home)
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

echo "✅ Java version $JAVA_VERSION detected"
echo "✅ ANDROID_HOME: $ANDROID_HOME"

# Create SDK directory if it doesn't exist
mkdir -p "$ANDROID_HOME"

# Install Android SDK components
echo "📱 Installing Android SDK components..."

cd "$ANDROID_HOME/cmdline-tools/latest/bin"

# Accept licenses
yes | ./sdkmanager --licenses

# Install essential components
./sdkmanager "platform-tools"
./sdkmanager "platforms;android-34"
./sdkmanager "platforms;android-33"
./sdkmanager "build-tools;34.0.0"
./sdkmanager "build-tools;33.0.2"
./sdkmanager "system-images;android-34;google_apis;x86_64"
./sdkmanager "emulator"

echo "✅ Android SDK setup complete!"
echo ""
echo "Add these to your shell profile (~/.zshrc or ~/.bash_profile):"
echo "export ANDROID_HOME=\"$HOME/Library/Android/sdk\""
echo "export PATH=\"\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools\""
echo ""
echo "Then run: flutter doctor"