#!/bin/bash

# iOS App Icon Generator Script
# Generates all required icon sizes from a 1024x1024 source image

SOURCE_IMAGE="icon.png"
OUTPUT_DIR="GarageValueTracker/Assets.xcassets/AppIcon.appiconset"

echo "🎨 Generating iOS app icons from $SOURCE_IMAGE..."

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Error: $SOURCE_IMAGE not found!"
    exit 1
fi

# Check if sips is available
if ! command -v sips &> /dev/null; then
    echo "❌ Error: sips command not found (macOS required)"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to resize and save icon
resize_icon() {
    local size=$1
    local name=$2
    echo "  Creating ${name} (${size}x${size})"
    sips -z $size $size "$SOURCE_IMAGE" --out "$OUTPUT_DIR/$name" > /dev/null 2>&1
}

# Generate all required sizes
echo "📱 Generating iPhone icons..."
resize_icon 180 "Icon-App-60x60@3x.png"      # iPhone 3x
resize_icon 120 "Icon-App-60x60@2x.png"      # iPhone 2x
resize_icon 87  "Icon-App-29x29@3x.png"      # Settings 3x
resize_icon 58  "Icon-App-29x29@2x.png"      # Settings 2x
resize_icon 80  "Icon-App-40x40@2x.png"      # Spotlight 2x
resize_icon 120 "Icon-App-40x40@3x.png"      # Spotlight 3x

echo "📱 Generating iPad icons..."
resize_icon 152 "Icon-App-76x76@2x.png"      # iPad 2x
resize_icon 76  "Icon-App-76x76@1x.png"      # iPad 1x
resize_icon 167 "Icon-App-83.5x83.5@2x.png"  # iPad Pro

echo "🏪 Copying App Store icon..."
cp "$SOURCE_IMAGE" "$OUTPUT_DIR/Icon-App-1024x1024@1x.png"

echo "✅ All icons generated successfully!"
echo ""
echo "📋 Generated icons:"
ls -lh "$OUTPUT_DIR"/*.png 2>/dev/null | wc -l | xargs echo "  Total:"
echo ""
echo "🎯 Next steps:"
echo "  1. Open Xcode"
echo "  2. Select Assets.xcassets in Project Navigator"
echo "  3. Click AppIcon"
echo "  4. The icons should already be there!"
echo ""
echo "  Or build the project - Xcode will automatically detect them."

