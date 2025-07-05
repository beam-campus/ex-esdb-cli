#!/bin/bash

# ExESDB TUI Startup Script
# This script starts the ExESDB CLI with TUI interface

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting ExESDB Terminal User Interface (TUI)...${NC}"

# Check if we're in the right directory
if [ ! -f "mix.exs" ]; then
    echo -e "${RED}❌ Error: mix.exs not found. Please run this script from the CLI system directory.${NC}"
    exit 1
fi

# Check if dependencies are installed
if [ ! -d "deps" ]; then
    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    mix deps.get
fi

# Compile the application
echo -e "${BLUE}🔨 Compiling application...${NC}"
mix compile

# Set default environment variables if not already set
export EX_ESDB_STORE_ID=${EX_ESDB_STORE_ID:-"reg_gh"}
export EX_ESDB_TIMEOUT=${EX_ESDB_TIMEOUT:-"10000"}
export EX_ESDB_PUB_SUB=${EX_ESDB_PUB_SUB:-"native"}

echo -e "${GREEN}⚙️  Configuration:${NC}"
echo -e "  • Store ID: ${EX_ESDB_STORE_ID}"
echo -e "  • Timeout: ${EX_ESDB_TIMEOUT}ms"
echo -e "  • Pub/Sub: ${EX_ESDB_PUB_SUB}"

# Start the application
# Choose TUI mode (enhanced by default)
TUI_MODE=${TUI_MODE:-"enhanced"}
export TUI_MODE

echo -e "${GREEN}🎯 Starting ExESDB TUI application (${TUI_MODE} mode)...${NC}"
echo -e "${YELLOW}📡 SSH daemon will start on 127.0.0.1:2222${NC}"
echo -e "${YELLOW}🔗 Connect with: ssh -p 2222 username@127.0.0.1${NC}"

if [ "$TUI_MODE" = "enhanced" ]; then
    echo -e "${YELLOW}🚀 Enhanced Features Available:${NC}"
    echo -e "  • Real-time event monitoring ('m' key)"
    echo -e "  • Advanced search ('/' key)
    echo -e "  • Smart filtering ('f' key)"
    echo -e "  • Event analytics and metrics"
    echo -e "  • Multi-store support"
    echo -e "  • Auto-refresh with configurable intervals"
fi

echo -e "${YELLOW}⌨️  Quick Start:${NC}"
echo -e "  • Navigation: ↑/↓ arrows, Enter to select"
echo -e "  • Help: 'h' key for detailed help"
echo -e "  • Quit: 'q' key or Ctrl+C"
echo -e "  • Main menu: ESC key"
echo -e ""
echo -e "${BLUE}Starting application... Press Ctrl+C to stop.${NC}"
echo -e ""

# Run the application
mix run --no-halt
