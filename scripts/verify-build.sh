#!/bin/bash

# Camera Companion Build Verification Script
# Usage: ./scripts/verify-build.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Camera Companion Build Verification${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verify prerequisites
verify_prerequisites() {
    print_info "Verifying prerequisites..."
    
    # Node.js
    if command_exists node; then
        NODE_VERSION=$(node --version)
        print_status "Node.js: $NODE_VERSION"
    else
        print_error "Node.js not found"
        return 1
    fi
    
    # NPM
    if command_exists npm; then
        NPM_VERSION=$(npm --version)
        print_status "npm: $NPM_VERSION"
    else
        print_error "npm not found"
        return 1
    fi
    
    # Flutter
    if command_exists flutter; then
        FLUTTER_VERSION=$(flutter --version | head -n 1)
        print_status "Flutter: $FLUTTER_VERSION"
    else
        print_warning "Flutter not found (required for mobile builds)"
    fi
    
    # Python
    if command_exists python3; then
        PYTHON_VERSION=$(python3 --version)
        print_status "Python: $PYTHON_VERSION"
    else
        print_warning "Python 3 not found (required for AI services)"
    fi
    
    # Docker
    if command_exists docker; then
        DOCKER_VERSION=$(docker --version)
        print_status "Docker: $DOCKER_VERSION"
    else
        print_warning "Docker not found (required for containerized builds)"
    fi
    
    print_status "Prerequisites verification completed"
}

# Verify backend build
verify_backend() {
    print_info "Verifying backend build..."
    
    if [[ ! -d "backend" ]]; then
        print_error "Backend directory not found"
        return 1
    fi
    
    cd backend
    
    # Check package.json
    if [[ -f "package.json" ]]; then
        print_status "package.json found"
    else
        print_error "package.json not found"
        cd ..
        return 1
    fi
    
    # Check node_modules
    if [[ -d "node_modules" ]]; then
        print_status "Dependencies installed"
    else
        print_warning "Dependencies not installed (run: npm install)"
    fi
    
    # Check native modules
    if [[ -d "native" ]]; then
        print_status "Native modules directory found"
        
        for sdk in canon sony nikon; do
            if [[ -d "native/$sdk" ]]; then
                print_status "Native $sdk module found"
                if [[ -f "native/$sdk/build/Release/binding.node" || -f "native/$sdk/build/Debug/binding.node" ]]; then
                    print_status "Native $sdk module built"
                else
                    print_warning "Native $sdk module not built"
                fi
            fi
        done
    else
        print_warning "Native modules directory not found"
    fi
    
    # Check app.js
    if [[ -f "src/app.js" ]]; then
        print_status "Main application file found"
    else
        print_error "Main application file not found"
    fi
    
    cd ..
    print_status "Backend verification completed"
}

# Verify mobile build
verify_mobile() {
    print_info "Verifying mobile build..."
    
    if [[ ! -d "mobile" ]]; then
        print_error "Mobile directory not found"
        return 1
    fi
    
    cd mobile
    
    # Check pubspec.yaml
    if [[ -f "pubspec.yaml" ]]; then
        print_status "pubspec.yaml found"
    else
        print_error "pubspec.yaml not found"
        cd ..
        return 1
    fi
    
    # Check dependencies
    if [[ -f "pubspec.lock" ]]; then
        print_status "Dependencies resolved"
    else
        print_warning "Dependencies not resolved (run: flutter pub get)"
    fi
    
    # Check main.dart
    if [[ -f "lib/main.dart" ]]; then
        print_status "Main Dart file found"
    else
        print_error "Main Dart file not found"
    fi
    
    # Check build outputs
    if [[ -d "build" ]]; then
        print_status "Build directory exists"
        
        # Check APK
        if [[ -f "build/app/outputs/flutter-apk/app-debug.apk" ]]; then
            print_status "Debug APK found"
        elif [[ -f "build/app/outputs/flutter-apk/app-release.apk" ]]; then
            print_status "Release APK found"
        else
            print_warning "No APK found (run: flutter build apk)"
        fi
        
        # Check iOS build (if on macOS)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if [[ -d "build/ios" ]]; then
                print_status "iOS build directory found"
            else
                print_warning "iOS build not found (run: flutter build ios)"
            fi
        fi
    else
        print_warning "Build directory not found"
    fi
    
    cd ..
    print_status "Mobile verification completed"
}

# Verify AI service
verify_ai() {
    print_info "Verifying AI service build..."
    
    if [[ ! -d "ai" ]]; then
        print_error "AI directory not found"
        return 1
    fi
    
    cd ai
    
    # Check requirements.txt
    if [[ -f "requirements.txt" ]]; then
        print_status "requirements.txt found"
    else
        print_error "requirements.txt not found"
        cd ..
        return 1
    fi
    
    # Check virtual environment
    if [[ -d "venv" ]]; then
        print_status "Virtual environment found"
        
        # Check if packages are installed
        if [[ -d "venv/lib/python*/site-packages" ]]; then
            print_status "Python packages installed"
        else
            print_warning "Python packages not installed (run: pip install -r requirements.txt)"
        fi
    else
        print_warning "Virtual environment not found (run: python3 -m venv venv)"
    fi
    
    # Check main files
    if [[ -f "main.py" ]]; then
        print_status "Main Python file found"
    else
        print_warning "Main Python file not found"
    fi
    
    # Check NeRF service
    if [[ -d "nerf" ]]; then
        print_status "NeRF service directory found"
        if [[ -f "nerf/nerf_service.py" ]]; then
            print_status "NeRF service file found"
        fi
    else
        print_warning "NeRF service directory not found"
    fi
    
    # Check Docker image
    if command_exists docker; then
        if docker images | grep -q "camera-companion-ai"; then
            print_status "AI Docker image found"
        else
            print_warning "AI Docker image not found (run: docker build -t camera-companion-ai .)"
        fi
    fi
    
    cd ..
    print_status "AI service verification completed"
}

# Verify Docker setup
verify_docker() {
    print_info "Verifying Docker setup..."
    
    # Check docker-compose.yml
    if [[ -f "docker-compose.yml" ]]; then
        print_status "docker-compose.yml found"
    else
        print_error "docker-compose.yml not found"
        return 1
    fi
    
    # Check Dockerfiles
    for service in backend ai; do
        if [[ -f "$service/Dockerfile" ]]; then
            print_status "$service Dockerfile found"
        else
            print_warning "$service Dockerfile not found"
        fi
    done
    
    # Check Docker images
    if command_exists docker; then
        if docker images | grep -q "camera-companion"; then
            print_status "Camera Companion Docker images found"
            docker images | grep "camera-companion" | while read line; do
                print_info "  $line"
            done
        else
            print_warning "No Camera Companion Docker images found"
        fi
    fi
    
    print_status "Docker verification completed"
}

# Verify environment configuration
verify_environment() {
    print_info "Verifying environment configuration..."
    
    # Check .env file
    if [[ -f ".env" ]]; then
        print_status ".env file found"
        
        # Check required variables
        required_vars=("NODE_ENV" "MONGODB_URI" "JWT_SECRET")
        for var in "${required_vars[@]}"; do
            if grep -q "^$var=" .env; then
                print_status "$var configured"
            else
                print_warning "$var not configured in .env"
            fi
        done
    else
        print_warning ".env file not found (copy from .env.example)"
    fi
    
    # Check .env.example
    if [[ -f ".env.example" ]]; then
        print_status ".env.example found"
    else
        print_warning ".env.example not found"
    fi
    
    print_status "Environment verification completed"
}

# Verify project structure
verify_structure() {
    print_info "Verifying project structure..."
    
    # Check main directories
    required_dirs=("backend" "mobile" "ai" "docs" "scripts")
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            print_status "$dir directory found"
        else
            print_warning "$dir directory not found"
        fi
    done
    
    # Check main files
    required_files=("README.md" "Makefile" "docker-compose.yml")
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            print_status "$file found"
        else
            print_warning "$file not found"
        fi
    done
    
    print_status "Project structure verification completed"
}

# Test API endpoints (if services are running)
test_endpoints() {
    print_info "Testing API endpoints (if services are running)..."
    
    # Test backend API
    if curl -s http://localhost:3000/health >/dev/null 2>&1; then
        print_status "Backend API responding at http://localhost:3000"
    else
        print_warning "Backend API not responding (service may not be running)"
    fi
    
    # Test AI service
    if curl -s http://localhost:8000/health >/dev/null 2>&1; then
        print_status "AI service responding at http://localhost:8000"
    else
        print_warning "AI service not responding (service may not be running)"
    fi
    
    # Test NeRF service
    if curl -s http://localhost:8001/health >/dev/null 2>&1; then
        print_status "NeRF service responding at http://localhost:8001"
    else
        print_warning "NeRF service not responding (service may not be running)"
    fi
    
    print_status "Endpoint testing completed"
}

# Main verification function
main() {
    verify_prerequisites
    echo ""
    verify_structure
    echo ""
    verify_environment
    echo ""
    verify_backend
    echo ""
    verify_mobile
    echo ""
    verify_ai
    echo ""
    verify_docker
    echo ""
    test_endpoints
    echo ""
    
    print_status "Build verification completed! 🎉"
    
    # Summary
    echo ""
    print_info "Next steps:"
    echo "  1. If any components show warnings, follow the suggested actions"
    echo "  2. Run 'make dev' to start the development environment"
    echo "  3. Run './scripts/build.sh all' to build all components"
    echo "  4. Check the build documentation in docs/development/BUILD_INSTRUCTIONS.md"
}

# Run main function
main