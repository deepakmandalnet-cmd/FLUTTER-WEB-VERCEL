#!/bin/bash

# Print each command before executing it
set -x
# Exit immediately if a command exits with a non-zero status.
set -e

echo "--- Starting Build Script ---"

echo "--- Installing Flutter ---"
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable
fi

echo "--- Setting Flutter Path ---"
export PATH="$PATH:`pwd`/flutter/bin"

echo "--- Running flutter doctor -v ---"
flutter doctor -v

echo "--- Enabling Flutter web ---"
flutter config --enable-web

echo "--- Getting dependencies ---"
flutter pub get

echo "--- Building Flutter web app ---"
flutter build web --release

echo "--- Build finished successfully. Output is in build/web ---"
ls -la build/web
