#!/bin/bash

# ODAS Web GUI Installation Script
# ==============================
#
# This script sets up the ODAS Web GUI environment, including:
# - Node.js version 12 installation (if needed)
# - Python 2.7 environment setup
# - npm dependencies installation
# - Environment configuration
# - Global odas_gui command
#
# Usage:
#   ./install.sh
#
# Prerequisites:
#   - curl (for downloading files)
#   - make, gcc (for building Python)
#   - git (for submodule management)
#
# Installation Steps:
#   1. Checks for Node.js 12
#   2. Sets up Python 2.7 environment
#   3. Installs npm dependencies
#   4. Configures the environment
#   5. Creates global odas_gui command
#
# Output:
#   - Local Python 2.7 installation in .python2/
#   - Node.js 12 installation (if needed)
#   - npm dependencies in node_modules/
#   - Environment configuration
#   - Global odas_gui command in /usr/local/bin/

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}Starting ODAS Web GUI installation...${NC}"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Node.js 12 using nvm
install_nodejs() {
    echo -e "${YELLOW}Installing Node.js 12...${NC}"
    
    # Check if nvm is installed
    if ! command_exists nvm; then
        echo -e "${YELLOW}Installing nvm...${NC}"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
        
        # Load nvm
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi
    
    # Install and use Node.js 12
    nvm install 12
    nvm use 12
}

# Function to setup Python 2.7
setup_python2() {
    echo -e "${YELLOW}Setting up Python 2.7...${NC}"
    
    PYTHON_DIR="$PROJECT_ROOT/.python2"
    PYTHON_BIN="$PYTHON_DIR/bin/python2.7"
    
    if [ -f "$PYTHON_BIN" ]; then
        echo -e "${GREEN}Python 2.7 already installed at $PYTHON_BIN${NC}"
        return 0
    fi
    
    # Create directory for Python 2.7
    mkdir -p "$PYTHON_DIR"
    
    if [ "$(uname)" == "Linux" ]; then
        # Download and build Python 2.7
        cd "$PYTHON_DIR"
        curl -O https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz
        tar xzf Python-2.7.18.tgz
        cd Python-2.7.18
        ./configure --prefix="$PYTHON_DIR" --enable-optimizations
        make -j$(nproc)
        make install
    else
        # For macOS, use pyenv
        if ! command_exists pyenv; then
            echo -e "${YELLOW}Installing pyenv...${NC}"
            brew install pyenv
        fi
        
        # Install Python 2.7
        pyenv install 2.7.18
        
        # Create symlink
        mkdir -p "$(dirname "$PYTHON_BIN")"
        ln -sf "$(pyenv root)/versions/2.7.18/bin/python2.7" "$PYTHON_BIN"
    fi
    
    echo -e "${GREEN}Python 2.7 installed at $PYTHON_BIN${NC}"
}

# Function to install npm dependencies with workaround for gRPC
install_npm_deps() {
    echo -e "${YELLOW}Installing npm dependencies...${NC}"
    
    cd "$SCRIPT_DIR"
    
    # Install dependencies without rebuilding
    npm install --python="$PROJECT_ROOT/.python2/bin/python2.7" --ignore-scripts
    
    # Workaround for gRPC build error
    echo -e "${YELLOW}Applying workaround for gRPC build error...${NC}"
    
    # Remove problematic gRPC version
    npm uninstall grpc
    
    # Install specific version of gRPC that works with Electron
    npm install grpc@1.24.11 --python="$PROJECT_ROOT/.python2/bin/python2.7" --ignore-scripts
    
    # Rebuild native modules
    echo -e "${YELLOW}Rebuilding native modules...${NC}"
    npm rebuild --python="$PROJECT_ROOT/.python2/bin/python2.7"
}

# Function to create global odas_gui command
create_global_command() {
    echo -e "${YELLOW}Creating global odas_gui command...${NC}"
    
    # Get the absolute path to the odas_web directory
    ODAS_WEB_DIR="$(cd "$SCRIPT_DIR" && pwd)"
    echo -e "${YELLOW}ODAS Web directory: $ODAS_WEB_DIR${NC}"
    
    # Create the command script
    cat > "$ODAS_WEB_DIR/odas_gui" << 'EOF'
#!/bin/bash

# Get the real path of this script, resolving any symlinks
REAL_SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
ODAS_WEB_DIR="$(dirname "$REAL_SCRIPT_PATH")"
echo "Running from: $ODAS_WEB_DIR"

# Load nvm if available
if [ -f "$HOME/.nvm/nvm.sh" ]; then
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm use 12
fi

# Change to the odas_web directory and start the application
cd "$ODAS_WEB_DIR"
if [ ! -f "package.json" ]; then
    echo "Error: Could not find package.json in $ODAS_WEB_DIR"
    echo "Current directory: $(pwd)"
    exit 1
fi
npm start
EOF

    # Make the script executable
    chmod +x "$ODAS_WEB_DIR/odas_gui"
    
    # Create symlink in /usr/local/bin
    echo -e "${YELLOW}Creating symlink from $ODAS_WEB_DIR/odas_gui to /usr/local/bin/odas_gui${NC}"
    if [ "$(uname)" == "Linux" ]; then
        sudo ln -sf "$ODAS_WEB_DIR/odas_gui" /usr/local/bin/odas_gui
    else
        # For macOS, use /usr/local/bin
        sudo ln -sf "$ODAS_WEB_DIR/odas_gui" /usr/local/bin/odas_gui
    fi
    
    # Verify the symlink
    if [ -L "/usr/local/bin/odas_gui" ]; then
        echo -e "${GREEN}Symlink created successfully!${NC}"
        echo -e "${YELLOW}Symlink points to: $(readlink -f /usr/local/bin/odas_gui)${NC}"
    else
        echo -e "${RED}Failed to create symlink!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Global odas_gui command created successfully!${NC}"
    echo -e "${YELLOW}Note: You may need to restart your terminal for the command to be available.${NC}"
}

# Main installation process
main() {
    # Check for Node.js 12
    if ! command_exists node || [ "$(node -v | cut -d. -f1)" != "v12" ]; then
        install_nodejs
    fi
    
    # Setup Python 2.7
    setup_python2
    
    # Install npm dependencies
    install_npm_deps
    
    # Create global command
    create_global_command
    
    echo -e "${GREEN}ODAS Web GUI installation completed successfully!${NC}"
    echo -e "${YELLOW}You can now run the GUI from anywhere using:${NC}"
    echo -e "${YELLOW}odas_gui${NC}"
}

# Run the installation
main 