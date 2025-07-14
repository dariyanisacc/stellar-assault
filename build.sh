#!/bin/bash

# Build script for Stellar Assault
# Supports creating .love files and platform-specific builds

VERSION="1.2.0"
GAME_NAME="stellar-assault"
BUILD_DIR="build"
DIST_DIR="dist"

echo "Building Stellar Assault v${VERSION}..."

# Create directories
mkdir -p ${BUILD_DIR}
mkdir -p ${DIST_DIR}

# Clean previous builds
rm -f ${BUILD_DIR}/${GAME_NAME}.love
rm -rf ${DIST_DIR}/*

# Create .love file
echo "Creating .love file..."
zip -r ${BUILD_DIR}/${GAME_NAME}.love \
    *.lua \
    src/*.lua \
    src/entities/*.lua \
    states/*.lua \
    assets/ \
    *.mp3 *.wav *.ogg *.flac \
    conf.lua \
    README.md \
    -x "*.git*" -x "*__pycache__*" -x "*.DS_Store"

if [ $? -eq 0 ]; then
    echo "✓ .love file created: ${BUILD_DIR}/${GAME_NAME}.love"
else
    echo "✗ Failed to create .love file"
    exit 1
fi

# Platform-specific builds
echo ""
echo "Creating platform builds..."

# macOS
if command -v love &> /dev/null; then
    echo "Building for macOS..."
    cp -r /Applications/love.app ${DIST_DIR}/StellarAssault.app 2>/dev/null || {
        echo "  Love.app not found in /Applications"
        echo "  Download from https://love2d.org"
    }
    
    if [ -d "${DIST_DIR}/StellarAssault.app" ]; then
        cp ${BUILD_DIR}/${GAME_NAME}.love ${DIST_DIR}/StellarAssault.app/Contents/Resources/
        
        # Update Info.plist
        /usr/libexec/PlistBuddy -c "Set :CFBundleName Stellar Assault" ${DIST_DIR}/StellarAssault.app/Contents/Info.plist 2>/dev/null
        /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.stellarassault.game" ${DIST_DIR}/StellarAssault.app/Contents/Info.plist 2>/dev/null
        
        echo "✓ macOS app bundle created: ${DIST_DIR}/StellarAssault.app"
    fi
fi

# Linux
echo "Building for Linux..."
mkdir -p ${DIST_DIR}/linux
cp ${BUILD_DIR}/${GAME_NAME}.love ${DIST_DIR}/linux/

# Create run script
cat > ${DIST_DIR}/linux/run.sh << 'EOF'
#!/bin/bash
if command -v love &> /dev/null; then
    love stellar-assault.love
else
    echo "LÖVE is not installed. Please install it from https://love2d.org"
    echo "Or use your package manager:"
    echo "  Ubuntu/Debian: sudo apt install love"
    echo "  Fedora: sudo dnf install love"
    echo "  Arch: sudo pacman -S love"
    exit 1
fi
EOF

chmod +x ${DIST_DIR}/linux/run.sh

# Create desktop entry
cat > ${DIST_DIR}/linux/stellar-assault.desktop << EOF
[Desktop Entry]
Name=Stellar Assault
Comment=A space shooter game
Exec=love %f
Icon=love
Terminal=false
Type=Application
Categories=Game;
MimeType=application/x-love-game;
EOF

# Create tar.gz
tar -czf ${DIST_DIR}/${GAME_NAME}-${VERSION}-linux.tar.gz -C ${DIST_DIR}/linux .
echo "✓ Linux build complete: ${DIST_DIR}/${GAME_NAME}-${VERSION}-linux.tar.gz"

# Windows (if running on Windows with WSL or Git Bash)
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    echo "Building for Windows..."
    echo "  Run build.bat for Windows builds"
fi

# Create source archive
echo "Creating source archive..."
tar -czf ${DIST_DIR}/${GAME_NAME}-${VERSION}-source.tar.gz \
    --exclude=".git" \
    --exclude="build" \
    --exclude="dist" \
    --exclude=".DS_Store" \
    --exclude="*.love" \
    .

# Summary
echo ""
echo "Build Summary:"
echo "=============="
echo "Version: ${VERSION}"
echo "Love file: ${BUILD_DIR}/${GAME_NAME}.love"
echo ""
echo "Platform builds in ${DIST_DIR}/"
ls -la ${DIST_DIR}/ 2>/dev/null || echo "No distribution files created yet"

echo ""
echo "Build complete!"
echo ""
echo "To test: love ${BUILD_DIR}/${GAME_NAME}.love"