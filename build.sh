#!/bin/bash

# JDGold Build Script

set -e

echo "🔨 Building JDGold..."

# Create app bundle structure
mkdir -p JDGold.app/Contents/MacOS
mkdir -p JDGold.app/Contents/Resources

# Compile
swiftc -O \
    -o JDGold.app/Contents/MacOS/JDGold \
    Sources/main.swift \
    -framework Cocoa \
    2>&1

# Copy Info.plist
cp Info.plist JDGold.app/Contents/Info.plist

# Copy icon
cp Resources/AppIcon.icns JDGold.app/Contents/Resources/AppIcon.icns

# Create PkgInfo
echo -n "APPL????" > JDGold.app/Contents/PkgInfo

echo "✅ Build complete: JDGold.app"
echo ""
echo "To run:"
echo "  open JDGold.app"
echo ""
echo "To install:"
echo "  cp -r JDGold.app /Applications/"
