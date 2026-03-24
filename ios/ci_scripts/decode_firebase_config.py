import base64
import os
import re
import sys

def decode_and_save(env_name, file_path):
    print(f"Checking environment variable: {env_name}")
    data = os.environ.get(env_name, "")
    if not data:
        print(f"Warning: {env_name} is empty or not set. Skipping.")
        return

    # 1. Remove all characters that are not valid Base64 (A-Z, a-z, 0-9, +, /, =)
    # This handles internal and external whitespace, newlines, etc.
    clean_data = re.sub(r'[^a-zA-Z0-9+/=]', '', data)
    
    # 2. Add padding if missing
    missing_padding = len(clean_data) % 4
    if missing_padding:
        clean_data += "=" * (4 - missing_padding)
    
    print(f"Writing {len(clean_data)} characters of decoded data to {file_path}...")
    
    try:
        binary_data = base64.b64decode(clean_data)
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        with open(file_path, "wb") as f:
            f.write(binary_data)
        print(f"Successfully created {file_path}")
    except Exception as e:
        print(f"Error decoding {env_name}: {e}")
        sys.exit(1)

if __name__ == "__main__":
    # The script is run from project root
    # iOS Configuration
    decode_and_save("GOOGLE_SERVICE_INFO_PLIST", "ios/Runner/GoogleService-Info.plist")
    
    # Android Configuration
    decode_and_save("GOOGLE_SERVICES_JSON", "android/app/google-services.json")
    
    # Shared Configuration
    decode_and_save("FIREBASE_OPTIONS_DART", "lib/firebase_options.dart")
