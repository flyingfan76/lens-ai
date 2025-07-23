#!/bin/bash

# Start NeRF Service for Camera Companion
# This script starts the NeRF-based 3D scene analysis service

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AI_DIR="$PROJECT_ROOT/ai"
NERF_SERVICE_SCRIPT="$AI_DIR/nerf/nerf_service.py"
LOG_DIR="$PROJECT_ROOT/logs"
PID_FILE="$PROJECT_ROOT/tmp/nerf_service.pid"

# Default configuration
HOST=${NERF_HOST:-"0.0.0.0"}
PORT=${NERF_PORT:-8001}
MODE=${NERF_MODE:-"serve"}
CONFIG_FILE=${NERF_CONFIG:-""}
LOG_LEVEL=${LOG_LEVEL:-"INFO"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Check if service is already running
check_service_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null; then
            return 0  # Service is running
        else
            rm -f "$PID_FILE"  # Remove stale PID file
            return 1  # Service is not running
        fi
    fi
    return 1  # PID file doesn't exist
}

# Stop existing service
stop_service() {
    if check_service_running; then
        local pid=$(cat "$PID_FILE")
        log "Stopping existing NeRF service (PID: $pid)..."
        
        kill -TERM "$pid" 2>/dev/null || true
        
        # Wait for graceful shutdown
        local count=0
        while ps -p "$pid" > /dev/null && [ $count -lt 10 ]; do
            sleep 1
            count=$((count + 1))
        done
        
        # Force kill if still running
        if ps -p "$pid" > /dev/null; then
            warning "Force killing NeRF service..."
            kill -KILL "$pid" 2>/dev/null || true
        fi
        
        rm -f "$PID_FILE"
        success "NeRF service stopped"
    fi
}

# Setup environment
setup_environment() {
    log "Setting up environment..."
    
    # Create necessary directories
    mkdir -p "$LOG_DIR"
    mkdir -p "$(dirname "$PID_FILE")"
    mkdir -p "$AI_DIR/data/training"
    mkdir -p "$AI_DIR/models/nerf"
    mkdir -p "$AI_DIR/checkpoints"
    mkdir -p "$AI_DIR/outputs"
    
    # Check Python environment
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is not installed or not in PATH"
        exit 1
    fi
    
    # Check if NeRF service script exists
    if [ ! -f "$NERF_SERVICE_SCRIPT" ]; then
        error "NeRF service script not found: $NERF_SERVICE_SCRIPT"
        exit 1
    fi
    
    # Set PYTHONPATH
    export PYTHONPATH="$AI_DIR:$PYTHONPATH"
    
    log "Environment setup complete"
}

# Install/check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    # Check if requirements.txt exists
    local requirements_file="$AI_DIR/requirements.txt"
    if [ -f "$requirements_file" ]; then
        log "Installing/updating Python dependencies..."
        python3 -m pip install -r "$requirements_file" --quiet || {
            warning "Failed to install some dependencies. Service may not work properly."
        }
    else
        warning "Requirements file not found: $requirements_file"
    fi
    
    # Check for CUDA availability
    if python3 -c "import torch; print(torch.cuda.is_available())" 2>/dev/null | grep -q "True"; then
        success "CUDA is available for GPU acceleration"
    else
        warning "CUDA not available, using CPU mode (slower)"
    fi
}

# Start the service
start_service() {
    log "Starting NeRF service..."
    
    # Build command
    local cmd="python3 $NERF_SERVICE_SCRIPT --mode $MODE --host $HOST --port $PORT"
    
    if [ -n "$CONFIG_FILE" ]; then
        cmd="$cmd --config $CONFIG_FILE"
    fi
    
    # Start service in background
    local log_file="$LOG_DIR/nerf_service.log"
    log "Command: $cmd"
    log "Logs will be written to: $log_file"
    
    nohup $cmd > "$log_file" 2>&1 &
    local pid=$!
    
    # Save PID
    echo $pid > "$PID_FILE"
    
    # Wait a moment and check if service started successfully
    sleep 3
    
    if ps -p "$pid" > /dev/null; then
        success "NeRF service started successfully (PID: $pid)"
        log "Service is listening on http://$HOST:$PORT"
        log "Health check: curl http://$HOST:$PORT/health"
        
        # Test service health
        local count=0
        while [ $count -lt 30 ]; do
            if curl -s "http://$HOST:$PORT/health" > /dev/null 2>&1; then
                success "NeRF service is responding to health checks"
                return 0
            fi
            sleep 1
            count=$((count + 1))
        done
        
        warning "Service started but not responding to health checks yet"
        warning "Check logs at: $log_file"
    else
        error "Failed to start NeRF service"
        error "Check logs at: $log_file"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Show service status
show_status() {
    if check_service_running; then
        local pid=$(cat "$PID_FILE")
        success "NeRF service is running (PID: $pid)"
        
        # Try to get service info
        if curl -s "http://$HOST:$PORT/health" > /dev/null 2>&1; then
            log "Service health: OK"
            log "Service URL: http://$HOST:$PORT"
        else
            warning "Service process is running but not responding"
        fi
    else
        warning "NeRF service is not running"
    fi
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo
    echo "Commands:"
    echo "  start     Start the NeRF service"
    echo "  stop      Stop the NeRF service"
    echo "  restart   Restart the NeRF service"
    echo "  status    Show service status"
    echo
    echo "Options:"
    echo "  --host HOST       Host to bind to (default: 0.0.0.0)"
    echo "  --port PORT       Port to listen on (default: 8001)"
    echo "  --config FILE     Configuration file path"
    echo "  --log-level LEVEL Log level (default: INFO)"
    echo
    echo "Environment variables:"
    echo "  NERF_HOST         Service host"
    echo "  NERF_PORT         Service port"
    echo "  NERF_CONFIG       Configuration file"
    echo "  LOG_LEVEL         Logging level"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --host)
            HOST="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --log-level)
            LOG_LEVEL="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        start|stop|restart|status)
            COMMAND="$1"
            shift
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check if command is provided
if [ -z "${COMMAND:-}" ]; then
    error "Command is required"
    usage
    exit 1
fi

# Main execution
case "$COMMAND" in
    start)
        if check_service_running; then
            warning "NeRF service is already running"
            show_status
        else
            setup_environment
            check_dependencies
            start_service
        fi
        ;;
    stop)
        stop_service
        ;;
    restart)
        stop_service
        sleep 2
        setup_environment
        check_dependencies
        start_service
        ;;
    status)
        show_status
        ;;
    *)
        error "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac