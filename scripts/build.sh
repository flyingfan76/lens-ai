#!/bin/bash

# Camera Companion Build Script
# Usage: ./scripts/build.sh [target] [environment]
# Example: ./scripts/build.sh all production

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TARGET="${1:-all}"
ENVIRONMENT="${2:-development}"
PARALLEL_JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

echo -e "${BLUE}🏗️  Camera Companion Build Script${NC}"
echo -e "${BLUE}Target: ${TARGET}${NC}"
echo -e "${BLUE}Environment: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}Parallel Jobs: ${PARALLEL_JOBS}${NC}"
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
    exit 1
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verify prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command_exists node; then
        print_error "Node.js not found. Please install Node.js 18+"
    fi
    
    if ! command_exists flutter && [[ "$TARGET" == "all" || "$TARGET" == "mobile" ]]; then
        print_error "Flutter not found. Please install Flutter 3.16+"
    fi
    
    if ! command_exists python3 && [[ "$TARGET" == "all" || "$TARGET" == "ai" ]]; then
        print_error "Python 3 not found. Please install Python 3.9+"
    fi
    
    print_status "Prerequisites check passed"
}

# Build backend
build_backend() {
    print_info "Building backend..."
    
    cd backend
    
    # Install dependencies
    if [[ "$ENVIRONMENT" == "production" ]]; then
        npm ci --only=production
    else
        npm install
    fi
    
    # Build native modules
    print_info "Building native camera SDK modules..."
    
    if [[ -d "native/canon" ]]; then
        cd native/canon
        npm install
        npm run build
        cd ../..
    fi
    
    if [[ -d "native/sony" ]]; then
        cd native/sony  
        npm install
        npm run build
        cd ../..
    fi
    
    if [[ -d "native/nikon" ]]; then
        cd native/nikon
        npm install  
        npm run build
        cd ../..
    fi
    
    # Initialize content
    if [[ "$ENVIRONMENT" == "development" ]]; then
        npm run init-presets || print_warning "Failed to initialize presets"
        npm run init-education || print_warning "Failed to initialize education content"
    fi
    
    # Build application
    if command_exists npm && [[ -f "package.json" ]] && grep -q '"build"' package.json; then
        npm run build
    fi
    
    cd ..
    print_status "Backend build completed"
}

# Build mobile
build_mobile() {
    print_info "Building mobile application..."
    
    cd mobile
    
    # Get dependencies
    flutter pub get
    
    # Generate code if needed
    if [[ -f "pubspec.yaml" ]] && grep -q "build_runner" pubspec.yaml; then
        flutter packages pub run build_runner build
    fi
    
    # Build based on environment
    case "$ENVIRONMENT" in
        "production")
            print_info "Building production mobile apps..."
            
            # Build Android release
            if command_exists flutter; then
                flutter build apk --release
                print_status "Android APK built successfully"
                
                # Build App Bundle for Play Store
                flutter build appbundle --release
                print_status "Android App Bundle built successfully"
            fi
            
            # Build iOS release (if on macOS)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                flutter build ios --release --no-codesign
                print_status "iOS build completed"
            else
                print_warning "iOS build skipped (not on macOS)"
            fi
            ;;
        *)
            print_info "Building debug mobile apps..."
            
            # Build Android debug
            flutter build apk --debug
            print_status "Android debug APK built"
            
            # Build iOS debug (if on macOS)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                flutter build ios --debug --simulator
                print_status "iOS debug build completed"
            fi
            ;;
    esac
    
    cd ..
    print_status "Mobile build completed"
}

# Build AI service
build_ai() {
    print_info "Building AI service..."
    
    cd ai
    
    # Create virtual environment if it doesn't exist
    if [[ ! -d "venv" ]]; then
        python3 -m venv venv
        print_status "Created Python virtual environment"
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install dependencies
    if [[ "$ENVIRONMENT" == "production" ]]; then
        pip install --no-dev -r requirements.txt
    else
        pip install -r requirements.txt
    fi
    
    # Validate setup
    if [[ -f "../scripts/validate_nerf_setup.py" ]]; then
        python ../scripts/validate_nerf_setup.py || print_warning "NeRF setup validation failed"
    fi
    
    # Build Docker image
    if command_exists docker; then
        if [[ "$ENVIRONMENT" == "production" ]]; then
            docker build -t camera-companion-ai:production .
            print_status "Production AI Docker image built"
        else
            docker build -t camera-companion-ai:development .
            print_status "Development AI Docker image built"
        fi
    else
        print_warning "Docker not available, skipping container build"
    fi
    
    cd ..
    print_status "AI service build completed"
}

# Build Docker services
build_docker() {
    print_info "Building Docker services..."
    
    if ! command_exists docker; then
        print_error "Docker not found. Please install Docker."
    fi
    
    if ! command_exists docker-compose; then
        print_error "Docker Compose not found. Please install Docker Compose."
    fi
    
    case "$ENVIRONMENT" in
        "production")
            if [[ -f "docker-compose.prod.yml" ]]; then
                docker-compose -f docker-compose.prod.yml build
                print_status "Production Docker services built"
            else
                docker-compose build
                print_warning "Production compose file not found, using default"
            fi
            ;;
        *)
            docker-compose build
            print_status "Development Docker services built"
            ;;
    esac
}

# Run tests
run_tests() {
    print_info "Running tests..."
    
    # Backend tests
    if [[ "$TARGET" == "all" || "$TARGET" == "backend" ]]; then
        cd backend
        if [[ -f "package.json" ]] && grep -q '"test"' package.json; then
            npm test || print_warning "Backend tests failed"
        fi
        cd ..
    fi
    
    # Mobile tests
    if [[ "$TARGET" == "all" || "$TARGET" == "mobile" ]]; then
        cd mobile
        flutter test || print_warning "Mobile tests failed"
        cd ..
    fi
    
    # AI tests
    if [[ "$TARGET" == "all" || "$TARGET" == "ai" ]]; then
        cd ai
        if [[ -d "venv" ]]; then
            source venv/bin/activate
        fi
        if [[ -d "tests" ]]; then
            python -m pytest tests/ || print_warning "AI tests failed"
        fi
        cd ..
    fi
    
    print_status "Tests completed"
}

# Cleanup function
cleanup() {
    print_info "Cleaning up build artifacts..."
    
    # Backend cleanup
    if [[ -d "backend/node_modules" && "$ENVIRONMENT" == "production" ]]; then
        cd backend
        npm prune --production
        cd ..
    fi
    
    # Mobile cleanup
    if [[ -d "mobile/build" ]]; then
        cd mobile
        flutter clean
        cd ..
    fi
    
    # AI cleanup
    if [[ -d "ai/__pycache__" ]]; then
        find ai -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
        find ai -name "*.pyc" -delete 2>/dev/null || true
    fi
    
    print_status "Cleanup completed"
}

# Verify build
verify_build() {
    print_info "Verifying build..."
    
    # Check backend build
    if [[ "$TARGET" == "all" || "$TARGET" == "backend" ]]; then
        if [[ -f "backend/dist/app.js" || -f "backend/src/app.js" ]]; then
            print_status "Backend build verified"
        else
            print_warning "Backend build verification failed"
        fi
    fi
    
    # Check mobile build
    if [[ "$TARGET" == "all" || "$TARGET" == "mobile" ]]; then
        if [[ -f "mobile/build/app/outputs/flutter-apk/app-release.apk" || 
              -f "mobile/build/app/outputs/flutter-apk/app-debug.apk" ]]; then
            print_status "Mobile build verified"
        else
            print_warning "Mobile build verification failed"
        fi
    fi
    
    # Check AI build
    if [[ "$TARGET" == "all" || "$TARGET" == "ai" ]]; then
        if docker images | grep -q camera-companion-ai; then
            print_status "AI service build verified"
        else
            print_warning "AI service build verification failed"
        fi
    fi
}

# Main build function
build_all() {
    check_prerequisites
    
    case "$TARGET" in
        "backend")
            build_backend
            ;;
        "mobile")
            build_mobile
            ;;
        "ai")
            build_ai
            ;;
        "docker")
            build_docker
            ;;
        "all")
            build_backend &
            BACKEND_PID=$!
            
            build_mobile &
            MOBILE_PID=$!
            
            build_ai &
            AI_PID=$!
            
            # Wait for all background jobs
            wait $BACKEND_PID
            wait $MOBILE_PID  
            wait $AI_PID
            
            build_docker
            ;;
        *)
            print_error "Unknown target: $TARGET. Use: all, backend, mobile, ai, or docker"
            ;;
    esac
    
    if [[ "$ENVIRONMENT" == "development" ]]; then
        run_tests
    fi
    
    verify_build
    
    print_status "Build process completed successfully! 🎉"
}

# Handle script interruption
trap 'print_error "Build interrupted"' INT TERM

# Run main function
build_all

# Optional cleanup
if [[ "${CLEANUP:-false}" == "true" ]]; then
    cleanup
fi

print_status "All done! 🚀"