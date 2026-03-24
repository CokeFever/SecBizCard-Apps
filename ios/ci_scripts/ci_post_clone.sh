#!/bin/bash

# The script runs in <project_root>/ios/ci_scripts

# Fail on error
set -e

# Find the project root
# The script is located in <project_root>/ios/ci_scripts/ci_post_clone.sh
# So we go up two levels.
echo "Resolving project root..."
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR/../.."

echo "Current directory: $(pwd)"

if [ ! -f "pubspec.yaml" ]; then
    echo "Error: Could not find pubspec.yaml in $(pwd)"
    exit 1
fi

# Install Flutter if not already present
if [ ! -d "$HOME/flutter" ]; then
    echo "Cloning Flutter..."
    # Using --depth 1 to speed up cloning
    git clone https://github.com/flutter/flutter.git -b stable $HOME/flutter --depth 1
fi

# Set Flutter path (prepend to override any pre-installed versions)
export PATH="$HOME/flutter/bin:$PATH"

echo "Diagnostic: Toolchain check"
flutter --version
which flutter
which dart
which xxd || echo "xxd NOT FOUND"

echo "Aggressively cleaning caches..."
flutter clean
rm -rf .dart_tool
rm -rf pubspec.lock
rm -rf $HOME/.pub-cache

echo "Using Flutter from: $(which flutter)"
flutter --version

# Check for missing files that might block the build
if [ ! -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo "Warning: ios/Runner/GoogleService-Info.plist is missing!"
    echo "Building without Firebase configuration might fail archive step (Error 65)."
fi

# Pre-download Flutter artifacts
echo "Pre-caching iOS artifacts..."
flutter precache --ios

# Set up SSH for private package (SecBizCard_OCR)
echo "Setting up SSH for private dependencies..."
mkdir -p ~/.ssh
ssh-keyscan github.com >> ~/.ssh/known_hosts

if [ -n "$OCR_DEPLOY_KEY" ]; then
    # Use Dart for robust base64 decoding
    dart ios/ci_scripts/inject_secrets.dart
    mv .ssh_id_ed25519 ~/.ssh/id_ed25519
    chmod 600 ~/.ssh/id_ed25519
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519
else
    echo "Warning: OCR_DEPLOY_KEY environment variable is not set."
    echo "If SecBizCard_OCR is a private git dependency, `flutter pub get` will fail."
    echo "Please add OCR_DEPLOY_KEY in Xcode Cloud workflow environment variables."
fi

# Inject Firebase Configuration (iOS/Android/Dart)
echo "Injecting Firebase configuration files using Dart script..."
# Dart script handles all injection (GoogleService-Info.plist, google-services.json, firebase_options.dart)
# It's already been called above if OCR_DEPLOY_KEY was present, but let's call it specifically to be sure.
dart ios/ci_scripts/inject_secrets.dart

echo "Verifying injected files content (first 100 bytes in hex):"
[ -f "lib/firebase_options.dart" ] && head -c 100 "lib/firebase_options.dart" | xxd
[ -f "ios/Runner/GoogleService-Info.plist" ] && head -c 100 "ios/Runner/GoogleService-Info.plist" | xxd

# Upgrade dependencies (ensures newest compatible transient dependencies like analyzer)
echo "Running flutter pub get (after cache clean)..."
flutter pub get

echo "Verifying injected files content (first 100 bytes in hex/od):"
[ -f "lib/firebase_options.dart" ] && head -c 100 "lib/firebase_options.dart" | od -t x1
[ -f "ios/Runner/GoogleService-Info.plist" ] && head -c 100 "ios/Runner/GoogleService-Info.plist" | od -t x1

# Generate localization files (required before build)
echo "Generating localization files..."
flutter gen-l10n

# Generate code (Riverpod, Freezed, JSON serialization .g.dart files)
echo "Running build_runner..."
dart run build_runner build --delete-conflicting-outputs

# Build iOS release (also runs pod install internally)
echo "Building iOS release..."
flutter build ios --release --no-codesign

echo "ci_post_clone script completed successfully."
exit 0
