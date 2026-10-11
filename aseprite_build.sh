#!/bin/bash
set -e

# =================================================================
# Aseprite Builder - Linux/macOS Build Script
# Automated build script for Aseprite (CI/CD compatible)
# =================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[+]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# =================================================================
# 1. CONFIGURATION
# =================================================================
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="${SCRIPT_DIR}/workspace"
ASEPRITE_DIR="${ROOT_DIR}/aseprite"
BUILD_DIR="${ROOT_DIR}/build"
SKIA_DIR="${ROOT_DIR}/skia"
OUTPUT_DIR="${ROOT_DIR}/output"

echo "================================================================="
echo "Aseprite Builder - Automated Build Process"
echo "================================================================="
echo ""

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="Linux"
    SKIA_RELEASE="Skia-Linux-Release-x64-libstdc++.zip"
    SKIA_ARCH="x64"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macOS"
    # Detect architecture
    if [[ $(uname -m) == "arm64" ]]; then
        SKIA_RELEASE="Skia-macOS-Release-arm64.zip"
        SKIA_ARCH="arm64"
        log_info "Detected Apple Silicon (ARM64)"
    else
        SKIA_RELEASE="Skia-macOS-Release-x64.zip"
        SKIA_ARCH="x64"
        log_info "Detected Intel Mac (x64)"
    fi
else
    log_error "Unsupported operating system: $OSTYPE"
    exit 1
fi

log_info "Building for: $OS_TYPE"

# =================================================================
# 2. PRE-FLIGHT CHECKS
# =================================================================
echo ""
log_info "[1/6] Running pre-flight checks..."

# Check for required tools
if ! command -v cmake &> /dev/null; then
    log_error "CMake not found. Please install CMake."
    exit 1
fi

if ! command -v ninja &> /dev/null; then
    log_warn "Ninja not found. Attempting to install..."
    if [[ "$OS_TYPE" == "Linux" ]]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update -qq
            sudo apt-get install -y ninja-build
        elif command -v yum &> /dev/null; then
            sudo yum install -y ninja-build
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm ninja
        else
            log_error "Could not install Ninja. Please install it manually."
            exit 1
        fi
    elif [[ "$OS_TYPE" == "macOS" ]]; then
        if command -v brew &> /dev/null; then
            brew install ninja
        else
            log_error "Homebrew not found. Please install Ninja manually or install Homebrew."
            exit 1
        fi
    fi
fi

if ! command -v git &> /dev/null; then
    log_error "Git not found. Please install Git."
    exit 1
fi

# Install Linux dependencies
if [[ "$OS_TYPE" == "Linux" ]]; then
    log_info "Installing Linux dependencies..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y \
            g++ clang cmake ninja-build libx11-dev libxcursor-dev \
            libxi-dev libxrandr-dev libgl1-mesa-dev libfontconfig1-dev \
            libfreetype6-dev libharfbuzz-dev libpixman-1-dev zlib1g-dev \
            wget unzip
    elif command -v yum &> /dev/null; then
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y cmake ninja-build libX11-devel libXcursor-devel \
            libXi-devel libXrandr-devel mesa-libGL-devel fontconfig-devel \
            freetype-devel harfbuzz-devel pixman-devel zlib-devel wget unzip
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm base-devel cmake ninja libx11 libxcursor \
            libxi libxrandr mesa fontconfig freetype2 harfbuzz pixman zlib wget unzip
    else
        log_warn "Unknown package manager. Please install dependencies manually."
    fi
fi

log_info "Pre-flight checks complete"

# =================================================================
# 3. FETCH VERSION & DOWNLOAD SOURCE
# =================================================================
echo ""
log_info "[2/6] Fetching Aseprite version and source..."

# Detect if running in CI
if [[ -n "${GITHUB_ACTIONS}" ]]; then
    log_info "GitHub Actions detected"
    if [[ -n "${ASEPRITE_VERSION}" ]]; then
        ASE_VER="${ASEPRITE_VERSION}"
        log_info "Using environment variable version: $ASE_VER"
    fi
else
    log_info "Local build detected"
fi

# Fetch latest version if not set
if [[ -z "${ASE_VER}" ]]; then
    log_info "Fetching latest Aseprite release from GitHub API..."
    
    if command -v curl &> /dev/null; then
        RELEASE_JSON=$(curl -s https://api.github.com/repos/aseprite/aseprite/releases/latest)
    elif command -v wget &> /dev/null; then
        RELEASE_JSON=$(wget -qO- https://api.github.com/repos/aseprite/aseprite/releases/latest)
    else
        log_error "Neither curl nor wget found. Cannot fetch release info."
        exit 1
    fi
    
    ASE_VER=$(echo "$RELEASE_JSON" | grep '"tag_name":' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
    
    if [[ -z "$ASE_VER" ]]; then
        log_warn "Could not fetch latest release. Using fallback: v1.3.17"
        ASE_VER="v1.3.17"
    fi
fi

log_info "Detected Version: $ASE_VER"

# =================================================================
# 4. CLEANING & DOWNLOADING
# =================================================================
echo ""
log_info "[3/6] Cleaning and downloading..."

rm -rf "${ASEPRITE_DIR}" "${BUILD_DIR}" "${SKIA_DIR}" "${OUTPUT_DIR}"
mkdir -p "${ROOT_DIR}" "${BUILD_DIR}" "${OUTPUT_DIR}"

# Clone Aseprite source
log_info "Cloning Aseprite repository (tag: $ASE_VER)..."
cd "${ROOT_DIR}"
git clone --recursive --depth 1 --branch "${ASE_VER}" https://github.com/aseprite/aseprite.git

log_info "Aseprite source downloaded"

# Download Skia
log_info "Downloading Skia library for $OS_TYPE ($SKIA_ARCH)..."
cd "${ROOT_DIR}"
SKIA_URL="https://github.com/aseprite/skia/releases/download/m102-861e4743af/${SKIA_RELEASE}"

if command -v wget &> /dev/null; then
    wget -q --show-progress "${SKIA_URL}" -O skia.zip
elif command -v curl &> /dev/null; then
    curl -L "${SKIA_URL}" -o skia.zip
else
    log_error "Neither wget nor curl available. Cannot download Skia."
    exit 1
fi

log_info "Extracting Skia..."
unzip -q skia.zip -d skia
rm -f skia.zip

log_info "Skia extracted successfully"

# =================================================================
# 5. CMAKE CONFIGURATION
# =================================================================
echo ""
log_info "[4/6] Configuring build with CMake..."

cd "${BUILD_DIR}"

CMAKE_ARGS=(
    -G Ninja
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
    -DLAF_BACKEND=skia
    -DSKIA_DIR="${SKIA_DIR}"
    -DSKIA_LIBRARY_DIR="${SKIA_DIR}/out/Release-${SKIA_ARCH}"
    -DENABLE_UPDATER=OFF
    -DENABLE_TESTS=OFF
)

# macOS specific flags
if [[ "$OS_TYPE" == "macOS" ]]; then
    CMAKE_ARGS+=(-DCMAKE_OSX_DEPLOYMENT_TARGET=10.9)
fi

# Linux specific flags
if [[ "$OS_TYPE" == "Linux" ]]; then
    CMAKE_ARGS+=(
        -DCMAKE_CXX_FLAGS=-stdlib=libstdc++
        -DCMAKE_EXE_LINKER_FLAGS=-stdlib=libstdc++
    )
    export CC=clang
    export CXX=clang++
fi

cmake "${CMAKE_ARGS[@]}" "${ASEPRITE_DIR}"

if [[ $? -ne 0 ]]; then
    log_error "CMake configuration failed"
    exit 1
fi

log_info "CMake configuration successful"

# =================================================================
# 6. COMPILATION
# =================================================================
echo ""
log_info "[5/6] Compiling with Ninja..."

# Detect CPU cores
if [[ "$OS_TYPE" == "macOS" ]]; then
    CPU_CORES=$(sysctl -n hw.ncpu)
elif [[ "$OS_TYPE" == "Linux" ]]; then
    CPU_CORES=$(nproc)
else
    CPU_CORES=4
fi

# Use at most 8 jobs to avoid overwhelming the system
JOBS=$((CPU_CORES > 8 ? 8 : CPU_CORES))

log_info "Using $JOBS parallel compilation jobs"

ninja -j $JOBS

if [[ $? -ne 0 ]]; then
    log_error "Compilation failed"
    exit 1
fi

log_info "Compilation successful"

# =================================================================
# 7. PACKAGING
# =================================================================
echo ""
log_info "[6/6] Packaging build..."

cd "${BUILD_DIR}/bin"

# Create portable marker
echo '# This file is here so Aseprite behaves as a portable program' > aseprite.ini

# Clean up unnecessary files
if [[ "$OS_TYPE" == "Linux" ]]; then
    # Keep only aseprite binary and data folder
    find . -mindepth 1 ! \( -name 'aseprite' -o -name 'data' -prune -o -name 'aseprite.ini' \) -exec rm -rf {} + 2>/dev/null || true
    
    # Create tarball
    ARCHIVE_NAME="Aseprite-${ASE_VER}-Linux-x64.tar.gz"
    tar -czf "${OUTPUT_DIR}/${ARCHIVE_NAME}" *
    
    log_info "Created archive: ${ARCHIVE_NAME}"
    
    # Create .deb package (optional)
    if command -v dpkg-deb &> /dev/null; then
        DEB_DIR="${ROOT_DIR}/aseprite_deb"
        mkdir -p "${DEB_DIR}/opt/aseprite"
        mkdir -p "${DEB_DIR}/usr/bin"
        mkdir -p "${DEB_DIR}/usr/share/applications"
        mkdir -p "${DEB_DIR}/DEBIAN"
        
        cp -r "${BUILD_DIR}/bin"/* "${DEB_DIR}/opt/aseprite/"
        
        # Create symlink
        ln -s /opt/aseprite/aseprite "${DEB_DIR}/usr/bin/aseprite"
        
        # Create control file
        VERSION_CLEAN="${ASE_VER#v}"
        cat > "${DEB_DIR}/DEBIAN/control" <<EOF
Package: aseprite
Version: ${VERSION_CLEAN}
Section: graphics
Priority: optional
Architecture: amd64
Maintainer: Aseprite Builder
Description: Animated sprite editor & pixel art tool
 Aseprite is a pixel art tool to create 2D animations, sprites, and any kind of graphics for games.
EOF
        
        # Create desktop entry
        cat > "${DEB_DIR}/usr/share/applications/aseprite.desktop" <<EOF
[Desktop Entry]
Name=Aseprite
Comment=Animated sprite editor & pixel art tool
Exec=/opt/aseprite/aseprite
Icon=/opt/aseprite/data/icons/ase64.png
Terminal=false
Type=Application
Categories=Graphics;2DGraphics;RasterGraphics;
EOF
        
        dpkg-deb --build "${DEB_DIR}" "${OUTPUT_DIR}/Aseprite-${ASE_VER}-Linux-x64.deb"
        log_info "Created .deb package: Aseprite-${ASE_VER}-Linux-x64.deb"
    fi
    
elif [[ "$OS_TYPE" == "macOS" ]]; then
    # Keep only Aseprite.app
    find . -mindepth 1 ! \( -name 'Aseprite.app' -prune -o -name 'aseprite.ini' \) -exec rm -rf {} + 2>/dev/null || true
    
    # Create DMG or ZIP
    if command -v hdiutil &> /dev/null; then
        ARCHIVE_NAME="Aseprite-${ASE_VER}-macOS-${SKIA_ARCH}.dmg"
        hdiutil create -volname "Aseprite" -srcfolder . -ov -format UDZO "${OUTPUT_DIR}/${ARCHIVE_NAME}"
        log_info "Created DMG: ${ARCHIVE_NAME}"
    else
        ARCHIVE_NAME="Aseprite-${ASE_VER}-macOS-${SKIA_ARCH}.zip"
        zip -r "${OUTPUT_DIR}/${ARCHIVE_NAME}" * >/dev/null
        log_info "Created archive: ${ARCHIVE_NAME}"
    fi
fi

echo ""
echo "================================================================="
echo "BUILD COMPLETE!"
echo "================================================================="
echo "Aseprite ${ASE_VER} built successfully for ${OS_TYPE}"
echo "Build output: ${BUILD_DIR}/bin"
echo "Archive: ${OUTPUT_DIR}"
echo "================================================================="
