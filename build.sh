#!/bin/bash

# GoldPrice Build Script

set -e

echo "🔨 Building GoldPrice..."

# Create app bundle structure
mkdir -p GoldPrice.app/Contents/MacOS
mkdir -p GoldPrice.app/Contents/Resources

# Compile
swiftc -O \
    -o GoldPrice.app/Contents/MacOS/GoldPrice \
    Sources/main.swift \
    -framework Cocoa \
    2>&1

# Copy Info.plist if not exists
if [ ! -f "GoldPrice.app/Contents/Info.plist" ]; then
    cp Info.plist GoldPrice.app/Contents/Info.plist 2>/dev/null || true
fi

echo "✅ Build complete: GoldPrice.app"
echo ""
echo "To run:"
echo "  open GoldPrice.app"
echo ""
echo "To install:"
echo "  cp -r GoldPrice.app /Applications/"
