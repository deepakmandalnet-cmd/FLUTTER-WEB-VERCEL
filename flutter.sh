#!/bin/bash

# Vercel's build environment has a specific directory structure.
# We need to make sure we are in the right place.
cd /vercel/work

# 1. Install Flutter

# Clone the Flutter repository from the stable channel.
# The --depth 1 flag is used to only fetch the latest commit, which saves time.

git clone https://github.com/flutter/flutter.git --depth 1 -b stable

# Add the Flutter tool to the path.
export PATH="$PATH:`pwd`/flutter/bin"

# 2. Run Flutter Doctor

# This command checks the Flutter installation and shows any potential issues.
# The output can be helpful for debugging if the build fails.
flutter doctor

# 3. Enable Web Support

# This ensures that Flutter's web support is enabled before building.
flutter config --enable-web

# 4. Get Dependencies

# This command downloads all the packages your project depends on (from pubspec.yaml).
flutter pub get

# 5. Build the Web App

# This is the final step where Flutter compiles your Dart code into a web-ready format.
# The output will be placed in the build/web directory, which Vercel will then deploy.
flutter build web
