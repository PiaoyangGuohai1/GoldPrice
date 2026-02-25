#!/bin/bash

# JDGold Build Script

set -euo pipefail

echo "🔨 Building JDGold..."

APP_BUNDLE="JDGold.app"
APP_MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
APP_RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

# Start from a clean app bundle so stale files don't leak into releases.
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS_DIR"
mkdir -p "$APP_RESOURCES_DIR"

declare -a built_binaries=()
declare -a failed_arches=()

compile_arch() {
    local arch="$1"
    local target="${arch}-apple-macosx12.0"
    local output="$APP_MACOS_DIR/JDGold-${arch}"

    echo "  Compiling ${arch}..."
    if swiftc -O \
        -target "$target" \
        -o "$output" \
        Sources/main.swift \
        -framework Cocoa \
        2>&1; then
        built_binaries+=("$output")
    else
        echo "  Warning: failed to compile ${arch}, continuing..."
        failed_arches+=("$arch")
    fi
}

compile_arch arm64
compile_arch x86_64

if [ "${#built_binaries[@]}" -eq 0 ]; then
    echo "❌ Build failed: no architecture could be compiled."
    exit 1
fi

if [ "${#built_binaries[@]}" -eq 2 ]; then
    echo "  Creating Universal Binary..."
    lipo -create "${built_binaries[@]}" -output "$APP_MACOS_DIR/JDGold"
    rm -f "$APP_MACOS_DIR/JDGold-arm64" "$APP_MACOS_DIR/JDGold-x86_64"
else
    echo "  Creating single-arch binary..."
    mv "${built_binaries[0]}" "$APP_MACOS_DIR/JDGold"
fi

# Copy Info.plist
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"

# Copy icon
cp Resources/AppIcon.icns "$APP_RESOURCES_DIR/AppIcon.icns"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Ad-hoc code signing
echo "  Signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

if [ "${#failed_arches[@]}" -gt 0 ]; then
    echo "⚠️  Built with partial architectures (failed: ${failed_arches[*]})."
fi

echo "✅ Build complete: $APP_BUNDLE"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
echo ""
echo "To install:"
echo "  cp -r $APP_BUNDLE /Applications/"
