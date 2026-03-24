import base64
import os
import re
import sys

def decode_and_save(env_names, file_path):
    if isinstance(env_names, str):
        env_names = [env_names]
    
    data = ""
    found_env = ""
    for env_name in env_names:
        print(f"Checking environment variable: {env_name}")
        data = os.environ.get(env_name, "")
        if data:
            found_env = env_name
            break

    if not data:
        print(f"Warning: None of {env_names} are set. Skipping {file_path}.")
        return

    print(f"Found {found_env}. Processing...")
    # 1. Remove all characters that are not valid Base64 (A-Z, a-z, 0-9, +, /, =)
    # This handles internal and external whitespace, newlines, etc.
    clean_data = re.sub(r'[^a-zA-Z0-9+/=]', '', data)
    
    # 2. Add padding if missing
    missing_padding = len(clean_data) % 4
    if missing_padding:
        clean_data += "=" * (4 - missing_padding)
    
    print(f"Writing {len(clean_data)} characters of decoded data (Base64) to {file_path}...")
    
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
    decode_and_save(["GOOGLE_SERVICE_INFO_PLIST", "GOOGLE_SERVICES_INFO_PLIST", "IOS_GOOGLE_SERVICES_JSON"], "ios/Runner/GoogleService-Info.plist")
    
    # Android Configuration
    decode_and_save(["GOOGLE_SERVICES_JSON", "ANDROID_GOOGLE_SERVICES_JSON"], "android/app/google-services.json")
    
    # Shared Configuration
    decode_and_save(["FIREBASE_OPTIONS_DART"], "lib/firebase_options.dart")
