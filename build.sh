#!/bin/bash

# JDGold Build Script

set -e

echo "🔨 Building JDGold..."

# Create app bundle structure
mkdir -p JDGold.app/Contents/MacOS
mkdir -p JDGold.app/Contents/Resources

# Compile arm64
echo "  Compiling arm64..."
swiftc -O \
    -target arm64-apple-macosx12.0 \
    -o JDGold.app/Contents/MacOS/JDGold-arm64 \
    Sources/main.swift \
    -framework Cocoa \
    2>&1

# Compile x86_64
echo "  Compiling x86_64..."
swiftc -O \
    -target x86_64-apple-macosx12.0 \
    -o JDGold.app/Contents/MacOS/JDGold-x86_64 \
    Sources/main.swift \
    -framework Cocoa \
    2>&1

# Create Universal Binary
echo "  Creating Universal Binary..."
lipo -create \
    JDGold.app/Contents/MacOS/JDGold-arm64 \
    JDGold.app/Contents/MacOS/JDGold-x86_64 \
    -output JDGold.app/Contents/MacOS/JDGold

# Clean up temporary architecture-specific binaries
rm JDGold.app/Contents/MacOS/JDGold-arm64
rm JDGold.app/Contents/MacOS/JDGold-x86_64

# Copy Info.plist
cp Info.plist JDGold.app/Contents/Info.plist

# Copy icon
cp Resources/AppIcon.icns JDGold.app/Contents/Resources/AppIcon.icns

# Create PkgInfo
echo -n "APPL????" > JDGold.app/Contents/PkgInfo

# Ad-hoc code signing
echo "  Signing..."
codesign --force --deep --sign - JDGold.app

echo "✅ Build complete: JDGold.app"
echo ""
echo "To run:"
echo "  open JDGold.app"
echo ""
echo "To install:"
echo "  cp -r JDGold.app /Applications/"
