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
export PATH="/Users/local/flutter/bin:$PATH"

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
    echo "Found OCR_DEPLOY_KEY environment variable (Length: ${#OCR_DEPLOY_KEY}). Configuring SSH key..."
    # Use python3 for robust base64 decoding (handles binary data and line breaks consistently)
    python3 -c "import base64, os; open(os.path.expanduser('~/.ssh/id_ed25519'), 'wb').write(base64.b64decode(os.environ['OCR_DEPLOY_KEY']))"
    chmod 600 ~/.ssh/id_ed25519
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519
else
    echo "Warning: OCR_DEPLOY_KEY environment variable is not set."
    echo "If SecBizCard_OCR is a private git dependency, `flutter pub get` will fail."
    echo "Please add OCR_DEPLOY_KEY in Xcode Cloud workflow environment variables."
fi

# Inject Firebase Configuration (iOS)
echo "Injecting Firebase configuration files using robust script..."
python3 ios/ci_scripts/decode_firebase_config.py

echo "Verifying injected files content (first 100 bytes in hex):"
[ -f "lib/firebase_options.dart" ] && head -c 100 "lib/firebase_options.dart" | xxd
[ -f "ios/Runner/GoogleService-Info.plist" ] && head -c 100 "ios/Runner/GoogleService-Info.plist" | xxd

# Upgrade dependencies (ensures newest compatible transient dependencies like analyzer)
echo "Running flutter pub upgrade..."
flutter pub upgrade

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
