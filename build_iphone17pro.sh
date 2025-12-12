#!/bin/bash

# Quick Build & Run Script for iPhone 17 Pro
# Always uses iPhone 17 Pro simulator

PROJECT_DIR="/Users/raamasrivatsan/Desktop/coding projects/GarageValueTracker"
PROJECT_NAME="GarageValueTracker"
SCHEME="GarageValueTracker"
SIMULATOR_ID="0BEB9DC8-97A8-4F47-801B-5526C47767B3" # iPhone 17 Pro

cd "$PROJECT_DIR"

echo "🏗️  Building for iPhone 17 Pro..."
echo ""

xcodebuild \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  build \
  2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:|warning:)" | tail -20

if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    echo ""
    echo "✅ BUILD SUCCEEDED on iPhone 17 Pro"
    echo ""
    echo "📱 To run in Xcode:"
    echo "   1. Open GarageValueTracker.xcodeproj"
    echo "   2. Select iPhone 17 Pro as destination"
    echo "   3. Press ⌘R to run"
else
    echo ""
    echo "❌ BUILD FAILED"
    echo ""
    echo "Check errors above"
fi

