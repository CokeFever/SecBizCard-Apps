#!/bin/sh

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

export PATH="$PATH:$HOME/flutter/bin"

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
    echo "Found OCR_DEPLOY_KEY environment variable. Configuring SSH key..."
    # Decode base64 key or use raw key (assuming raw or base64 based on content, let's treat it as raw text like GitHub Actions)
    # App Store Connect secrets are plain text. We write it to a file.
    # To handle potential newlines, we decode it if we need to, but usually it's plain text.
    # Let's echo it directly to id_ed25519 and set permissions
    echo "$OCR_DEPLOY_KEY" > ~/.ssh/id_ed25519
    chmod 600 ~/.ssh/id_ed25519
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519
else
    echo "Warning: OCR_DEPLOY_KEY environment variable is not set."
    echo "If SecBizCard_OCR is a private git dependency, `flutter pub get` will fail."
    echo "Please add OCR_DEPLOY_KEY in Xcode Cloud workflow environment variables."
fi

# Install dependencies
echo "Running flutter pub get..."
flutter pub get

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
