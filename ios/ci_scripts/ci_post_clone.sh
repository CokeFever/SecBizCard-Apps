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

# Optimization: Exit early if tag contains "test" or "debug" (handled by GCP)
if [ -n "$CI_TAG" ]; then
    case "$CI_TAG" in
        *test*|*debug*)
            echo "Detected test/debug tag ($CI_TAG). Skipping iOS build to save resources."
            exit 0
            ;;
    esac
fi

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

# Configure SSH for fetching private dependencies from SecBizCard
echo "Injecting Secure OCR Deploy Key..."
mkdir -p ~/.ssh
echo "$OCR_DEPLOY_KEY" | base64 --decode > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
ssh-keyscan github.com >> ~/.ssh/known_hosts

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
