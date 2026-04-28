#!/bin/bash

# ULX3S FPGA Development Container Script

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🐳 ULX3S FPGA Development Container"
echo "=================================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if docker-compose is available
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "❌ docker-compose is not available. Please install docker-compose."
    exit 1
fi

case "${1:-help}" in
    "build")
        echo "🔨 Building FPGA development container..."
        $DOCKER_COMPOSE build
        echo "✅ Container built successfully!"
        ;;

    "shell")
        echo "🐚 Starting FPGA development shell..."
        $DOCKER_COMPOSE run --rm fpga-dev
        ;;

    "make")
        shift
        echo "🔨 Running make $@ in container..."
        $DOCKER_COMPOSE run --rm fpga-dev make "$@"
        ;;

    "program")
        echo "📡 Programming FPGA..."
        if [ ! -f "ulx3s.bit" ]; then
            echo "❌ ulx3s.bit not found. Run 'make ulx3s.bit' first."
            exit 1
        fi
        $DOCKER_COMPOSE run --rm fpga-dev openFPGALoader -b ulx3s ulx3s.bit
        ;;

    "clean")
        echo "🧹 Cleaning up..."
        $DOCKER_COMPOSE down -v --rmi local
        docker system prune -f
        ;;

    "help"|*)
        echo "Usage: $0 {build|shell|make|program|clean}"
        echo ""
        echo "Commands:"
        echo "  build    - Build the FPGA development container"
        echo "  shell    - Start an interactive shell in the container"
        echo "  make     - Run make commands in the container (e.g., '$0 make ulx3s.bit')"
        echo "  program  - Program the FPGA with ulx3s.bit"
        echo "  clean    - Remove containers and clean up"
        echo ""
        echo "Examples:"
        echo "  $0 build                    # Build the container"
        echo "  $0 shell                    # Start development shell"
        echo "  $0 make ulx3s.bit          # Build bitstream"
        echo "  $0 program                  # Program FPGA"
        ;;
esac