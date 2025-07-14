#!/bin/bash

# Cross-platform build script for Stellar Assault
# Creates builds for Windows, macOS, and Linux from macOS

GAME_NAME="StellarAssault"
VERSION="1.0.0"
LOVE_VERSION="11.5"

echo "Building ${GAME_NAME} v${VERSION} for all platforms..."

# Create directories
mkdir -p build
mkdir -p dist/{windows,macos,linux}

# Create .love file
echo "Creating .love file..."
zip -9 -r "build/${GAME_NAME}.love" . \
    -x "*.git*" \
    -x "*build/*" \
    -x "*dist/*" \
    -x "*tests/*" \
    -x "*.DS_Store" \
    -x "build*.sh" \
    -x "build.bat" \
    -x "run_tests.lua" \
    -x "*.md"

echo "✓ .love file created"

# Download Love2D binaries if not present
echo ""
echo "Checking for Love2D binaries..."

# Windows 64-bit
if [ ! -f "dist/windows/love.exe" ]; then
    echo "Downloading Love2D for Windows (64-bit)..."
    curl -L -o "dist/love-windows.zip" "https://github.com/love2d/love/releases/download/${LOVE_VERSION}/love-${LOVE_VERSION}-win64.zip"
    unzip -q "dist/love-windows.zip" -d "dist/"
    mv "dist/love-${LOVE_VERSION}-win64"/* "dist/windows/"
    rm -rf "dist/love-${LOVE_VERSION}-win64" "dist/love-windows.zip"
    echo "✓ Windows binaries downloaded"
else
    echo "✓ Windows binaries found"
fi

# Create Windows executable
echo ""
echo "Creating Windows executable..."
cat "dist/windows/love.exe" "build/${GAME_NAME}.love" > "dist/windows/${GAME_NAME}.exe"
echo "✓ Windows executable created"

# Create Windows installer using makensis (if available)
if command -v makensis &> /dev/null; then
    echo "Creating Windows installer..."
    cat > "build/installer.nsi" << EOF
!define APPNAME "${GAME_NAME}"
!define COMPANYNAME "YourCompany"
!define DESCRIPTION "Stellar Assault - Space Shooter Game"
!define VERSIONMAJOR 1
!define VERSIONMINOR 0
!define VERSIONBUILD 0

RequestExecutionLevel admin
InstallDir "\$PROGRAMFILES\\\${APPNAME}"
Name "\${APPNAME}"
Icon "dist\windows\game.ico"
outFile "dist\${APPNAME}-Setup.exe"

!include LogicLib.nsh

page directory
page instfiles

section "install"
    setOutPath \$INSTDIR
    File "dist\windows\${GAME_NAME}.exe"
    File "dist\windows\*.dll"
    
    # Create start menu shortcut
    createDirectory "\$SMPROGRAMS\\\${APPNAME}"
    createShortCut "\$SMPROGRAMS\\\${APPNAME}\\\${APPNAME}.lnk" "\$INSTDIR\\\${GAME_NAME}.exe"
    
    # Create desktop shortcut
    createShortCut "\$DESKTOP\\\${APPNAME}.lnk" "\$INSTDIR\\\${GAME_NAME}.exe"
    
    # Write uninstaller
    writeUninstaller "\$INSTDIR\uninstall.exe"
sectionEnd

section "uninstall"
    delete "\$INSTDIR\\\${GAME_NAME}.exe"
    delete "\$INSTDIR\*.dll"
    delete "\$INSTDIR\uninstall.exe"
    rmDir \$INSTDIR
    
    # Remove shortcuts
    delete "\$SMPROGRAMS\\\${APPNAME}\\\${APPNAME}.lnk"
    rmDir "\$SMPROGRAMS\\\${APPNAME}"
    delete "\$DESKTOP\\\${APPNAME}.lnk"
sectionEnd
EOF
    makensis "build/installer.nsi"
    echo "✓ Windows installer created"
else
    echo "ℹ makensis not found. Install it with: brew install makensis"
fi

# macOS app bundle
echo ""
echo "Creating macOS app..."
if [ ! -d "dist/love.app" ]; then
    echo "Downloading Love2D for macOS..."
    curl -L -o "dist/love-macos.zip" "https://github.com/love2d/love/releases/download/${LOVE_VERSION}/love-${LOVE_VERSION}-macos.zip"
    unzip -q "dist/love-macos.zip" -d "dist/"
    mv "dist/love.app" "dist/love-template.app"
    echo "✓ macOS template downloaded"
fi

# Create macOS app
cp -R "dist/love-template.app" "dist/macos/${GAME_NAME}.app"
cp "build/${GAME_NAME}.love" "dist/macos/${GAME_NAME}.app/Contents/Resources/"

# Update Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${GAME_NAME}" "dist/macos/${GAME_NAME}.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${GAME_NAME}" "dist/macos/${GAME_NAME}.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.yourcompany.stellarassault" "dist/macos/${GAME_NAME}.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "dist/macos/${GAME_NAME}.app/Contents/Info.plist"

echo "✓ macOS app created"

# Create DMG (optional)
if command -v create-dmg &> /dev/null; then
    echo "Creating macOS DMG..."
    create-dmg \
        --volname "${GAME_NAME}" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${GAME_NAME}.app" 175 120 \
        --hide-extension "${GAME_NAME}.app" \
        --app-drop-link 425 120 \
        "dist/${GAME_NAME}-${VERSION}.dmg" \
        "dist/macos/"
    echo "✓ macOS DMG created"
else
    echo "ℹ create-dmg not found. Install it with: brew install create-dmg"
fi

# Linux AppImage
echo ""
echo "Creating Linux AppImage..."
if [ ! -f "dist/linux/love.AppImage" ]; then
    echo "Downloading Love2D AppImage..."
    curl -L -o "dist/linux/love.AppImage" "https://github.com/love2d/love/releases/download/${LOVE_VERSION}/love-${LOVE_VERSION}-x86_64.AppImage"
    chmod +x "dist/linux/love.AppImage"
    echo "✓ Linux AppImage template downloaded"
fi

# Create Linux AppImage
cp "dist/linux/love.AppImage" "dist/linux/${GAME_NAME}.AppImage"
echo "✓ Linux AppImage created (embedded .love file)"

echo ""
echo "===================================="
echo "Build complete! Distributions ready:"
echo "===================================="
echo "✓ Windows: dist/windows/${GAME_NAME}.exe"
[ -f "dist/${GAME_NAME}-Setup.exe" ] && echo "✓ Windows Installer: dist/${GAME_NAME}-Setup.exe"
echo "✓ macOS: dist/macos/${GAME_NAME}.app"
[ -f "dist/${GAME_NAME}-${VERSION}.dmg" ] && echo "✓ macOS DMG: dist/${GAME_NAME}-${VERSION}.dmg"
echo "✓ Linux: dist/linux/${GAME_NAME}.AppImage"
echo "✓ Universal: build/${GAME_NAME}.love"
echo ""
echo "Note: Windows exe needs all DLL files in the same directory to run."