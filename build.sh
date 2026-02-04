#!/bin/bash

# Exit on error
set -e

# 1. Install Flutter SDK
echo "Cloning Flutter repository..."
git clone https://github.com/flutter/flutter.git --depth 1 --branch 3.22.2 /tmp/flutter

# 2. Add Flutter to PATH
export PATH="/tmp/flutter/bin:$PATH"

# 3. Run flutter doctor
echo "Running flutter doctor..."
flutter doctor -v

# 4. Get dependencies
echo "Running flutter pub get..."
flutter pub get

# 5. Build the web app
echo "Building Flutter web app..."
flutter build web --release
