#!/bin/bash
# Exit on error
set -e

# --- Setup Flutter ---
echo "Cloning Flutter repository..."
git clone https://github.com/flutter/flutter.git --depth 1 -b stable /flutter
export PATH="/flutter/bin:$PATH"

# --- Verify Flutter --- 
echo "Verifying Flutter setup..."
flutter doctor

# --- Build Project ---
echo "Getting dependencies..."
flutter pub get

echo "Building Flutter for web..."
flutter build web --release

echo "Build successful! Output is in build/web"
