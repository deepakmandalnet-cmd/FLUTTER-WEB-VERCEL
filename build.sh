#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# 1. Clone the Flutter repository
echo "Cloning Flutter repository..."
git clone https://github.com/flutter/flutter.git --depth 1 -b stable /flutter
export PATH="/flutter/bin:$PATH"

# 2. Run flutter doctor to verify setup
echo "Running flutter doctor..."
flutter doctor

# 3. Get dependencies
echo "Running flutter pub get..."
flutter pub get

# 4. Build the Flutter web app
echo "Building Flutter web app..."
flutter build web --release
