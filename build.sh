#!/usr/bin/env bash
set -e

GAME_NAME="stellar-assault"
APP_NAME="StellarAssault"
BUILD_DIR="build"
DIST_DIR="dist"

mkdir -p "$BUILD_DIR"

# Create .love archive
zip -9 -r "$BUILD_DIR/$GAME_NAME.love" \
    main.lua assets src states \
    -x "*/.DS_Store" > /dev/null

# If running on macOS, package into an app bundle
if [ "$(uname)" = "Darwin" ]; then
    mkdir -p "$DIST_DIR"
    APP_PATH="$DIST_DIR/$APP_NAME.app"
    cp -R /Applications/love.app "$APP_PATH"
    cp "$BUILD_DIR/$GAME_NAME.love" "$APP_PATH/Contents/Resources/game.love"
    if [ -f "$APP_PATH/Contents/MacOS/love" ]; then
        mv "$APP_PATH/Contents/MacOS/love" "$APP_PATH/Contents/MacOS/$APP_NAME"
    fi
fi
