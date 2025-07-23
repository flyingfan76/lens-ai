# Lens AI Development Makefile

.PHONY: help install dev build test clean docker-up docker-down mobile-dev backend-dev ai-dev lint format

# Default target
help:
	@echo "Lens AI Development Commands:"
	@echo ""
	@echo "Setup & Installation:"
	@echo "  make install     - Install all dependencies"
	@echo "  make setup       - Complete project setup"
	@echo ""
	@echo "Development:"
	@echo "  make dev         - Start full development environment"
	@echo "  make mobile-dev  - Start mobile app development"
	@echo "  make backend-dev - Start backend API server"
	@echo "  make ai-dev      - Start AI service"
	@echo ""
	@echo "Building:"
	@echo "  make build         - Build all components"
	@echo "  make build-all     - Build all with optimizations"
	@echo "  make build-production - Build for production"
	@echo "  make build-dev     - Build for development"
	@echo "  make build-mobile  - Build mobile apps"
	@echo "  make build-backend - Build backend service"
	@echo "  make build-ai      - Build AI service"
	@echo "  make verify-build  - Verify build setup"
	@echo ""
	@echo "Testing:"
	@echo "  make test        - Run all tests"
	@echo "  make test-mobile - Run mobile tests"
	@echo "  make test-backend- Run backend tests"
	@echo "  make test-ai     - Run AI tests"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint        - Run linting on all code"
	@echo "  make format      - Format all code"
	@echo ""
	@echo "Docker:"
	@echo "  make docker-up   - Start Docker services"
	@echo "  make docker-down - Stop Docker services"
	@echo "  make docker-logs - View Docker logs"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make reset       - Reset development environment"

# Installation and Setup
install:
	@echo "Installing dependencies..."
	cd backend && npm install
	cd mobile && flutter pub get
	cd ai && pip install -r requirements.txt

setup: install
	@echo "Setting up development environment..."
	cp .env.example .env
	mkdir -p logs
	mkdir -p mobile/assets/{images,icons,models,animations,fonts}
	mkdir -p ai/models
	@echo "Setup complete! Edit .env file with your configuration."

# Development
dev: docker-up
	@echo "Starting full development environment..."
	make backend-dev & make mobile-dev

mobile-dev:
	@echo "Starting Flutter mobile development..."
	cd mobile && flutter run --hot

backend-dev:
	@echo "Starting backend development server..."
	cd backend && npm run dev

ai-dev:
	@echo "Starting AI service..."
	cd ai && python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Building
build: build-backend build-mobile

build-all:
	@echo "Building all components with optimizations..."
	./scripts/build.sh all

build-production:
	@echo "Building for production environment..."
	./scripts/build.sh all production

build-mobile:
	@echo "Building mobile applications..."
	cd mobile && flutter build apk --release
	cd mobile && flutter build ios --release

build-backend:
	@echo "Building backend service..."
	cd backend && npm run build

build-ai:
	@echo "Building AI service..."
	./scripts/build.sh ai

# Build verification
verify-build:
	@echo "Verifying build setup and outputs..."
	./scripts/verify-build.sh

# Quick build for development
build-dev:
	@echo "Building for development..."
	./scripts/build.sh all development

# Testing
test: test-backend test-mobile test-ai

test-mobile:
	@echo "Running mobile tests..."
	cd mobile && flutter test

test-backend:
	@echo "Running backend tests..."
	cd backend && npm test

test-ai:
	@echo "Running AI tests..."
	cd ai && python -m pytest tests/

# Code Quality
lint:
	@echo "Running linters..."
	cd backend && npm run lint
	cd mobile && flutter analyze
	cd ai && flake8 .

format:
	@echo "Formatting code..."
	cd backend && npm run format
	cd mobile && dart format lib/ test/
	cd ai && black . && isort .

# Docker Operations
docker-up:
	@echo "Starting Docker services..."
	docker-compose up -d
	@echo "Services started. Backend: http://localhost:3000, AI: http://localhost:8000"

docker-down:
	@echo "Stopping Docker services..."
	docker-compose down

docker-logs:
	docker-compose logs -f

docker-build:
	docker-compose build

# Utilities
clean:
	@echo "Cleaning build artifacts..."
	cd backend && rm -rf node_modules dist
	cd mobile && flutter clean
	cd ai && rm -rf __pycache__ .pytest_cache
	rm -rf logs/*

reset: clean docker-down
	@echo "Resetting development environment..."
	docker system prune -f
	make setup

# Database operations
db-seed:
	@echo "Seeding database with sample data..."
	cd scripts && node seed-database.js

db-reset:
	@echo "Resetting database..."
	docker-compose exec mongodb mongo lens_ai --eval "db.dropDatabase()"
	make db-seed

# Deployment helpers
deploy-staging:
	@echo "Deploying to staging environment..."
	# Add staging deployment commands

deploy-prod:
	@echo "Deploying to production environment..."
	# Add production deployment commands

# Development utilities
tunnel:
	@echo "Starting ngrok tunnel for mobile testing..."
	ngrok http 3000

generate-docs:
	@echo "Generating API documentation..."
	cd backend && npm run docs:generate
	cd mobile && dartdoc
	cd docs && mkdocs build

serve-docs:
	@echo "Serving documentation..."
	cd docs && mkdocs serve