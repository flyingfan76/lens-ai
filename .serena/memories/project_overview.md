# Lens AI Project Overview

## Purpose
Lens AI is an **external camera control application** that enables remote operation of professional DSLR and mirrorless cameras (Nikon, Canon, Sony, etc.) via USB or WiFi connections. The app provides AI-powered photography suggestions by connecting to external LLM providers like OpenAI, Anthropic, or custom endpoints.

## Key Features
- **External camera control**: Remote operation of DSLR/mirrorless cameras via USB or WiFi
- **Multi-brand support**: Nikon (D90, D850), Canon (EOS series), Sony (A7 series), Fujifilm, Olympus, Panasonic  
- **LLM-based AI suggestions**: Photography recommendations from OpenAI, Anthropic, or custom AI providers
- **Camera detection**: Automatic discovery of USB and WiFi-connected cameras
- **Professional controls**: ISO, aperture, shutter speed, white balance, focus control
- **Remote capture**: Take photos and videos directly from the mobile app
- **Live view streaming**: Real-time camera preview for external cameras

## Repository
https://github.com/flyingfan76/lens-ai.git

## Platform Focus
- **Mobile Applications (iOS/Android/macOS)**: PRIMARY PLATFORM
- **Web Application**: BACKEND DEPENDENT (Development/POC only)

## Architecture
- **Hybrid AI Architecture**: Supports both cloud LLM providers AND local TensorFlow Lite processing
- **Multi-Platform Support**: Works on iOS, Android, and macOS (macOS supports external cameras only)
- **USB & WiFi Connectivity**: Supports both wired and wireless camera connections
- **Professional Photography**: Designed for photographers using external cameras, not mobile phone cameras
- **Intelligent AI Selection**: Automatically chooses between cloud AI (when connected) and local AI (offline)
- **Network Adaptive**: Fully functional offline with local AI, enhanced with cloud AI when online