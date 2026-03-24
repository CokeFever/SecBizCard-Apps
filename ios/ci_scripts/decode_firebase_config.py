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
    
    # 1. Remove ALL whitespace characters (newlines, spaces, tabs, etc.)
    # This is much more robust than simple regex.
    clean_data = "".join(data.split())
    
    # 2. Allow standard and URL-safe Base64 characters (A-Z, a-z, 0-9, +, /, -, _, =)
    clean_data = re.sub(r'[^a-zA-Z0-9+/=_ -]', '', clean_data)
    
    # 2b. Convert URL-safe characters to standard ones before decoding
    clean_data = clean_data.replace('-', '+').replace('_', '/')
    
    # 3. Strip any existing trailing padding '=' signs
    # We will re-add them correctly based on the content length.
    clean_data = clean_data.rstrip('=')
    
    # 4. Add proper padding
    # Base64 string length % 4 can be 0, 2, or 3.
    # A remainder of 1 is invalid and indicates data corruption.
    remainder = len(clean_data) % 4
    if remainder == 1:
        print(f"Error: Invalid Base64 length ({len(clean_data)}) for {found_env}.")
        print("This usually means the environment variable is truncated or corrupted.")
        print("Please re-encode your file and update the secret.")
        sys.exit(1)
    elif remainder == 2:
        clean_data += "=="
    elif remainder == 3:
        clean_data += "="
    
    print(f"Writing {len(clean_data)} characters of decoded data (Base64) to {file_path}...")
    
    try:
        # Standard Base64 decoding
        binary_data = base64.b64decode(clean_data)
        
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        with open(file_path, "wb") as f:
            f.write(binary_data)
        print(f"Successfully created {file_path}")
        
        # Verify it's not empty
        if os.path.getsize(file_path) == 0:
            print(f"Error: Resulting file {file_path} is empty!")
            sys.exit(1)
            
    except Exception as e:
        print(f"Error decoding {found_env}: {e}")
        sys.exit(1)

if __name__ == "__main__":
    # The script is run from project root
    # iOS Configuration
    decode_and_save(["GOOGLE_SERVICE_INFO_PLIST", "GOOGLE_SERVICES_INFO_PLIST", "IOS_GOOGLE_SERVICES_JSON"], "ios/Runner/GoogleService-Info.plist")
    
    # Android Configuration
    decode_and_save(["GOOGLE_SERVICES_JSON", "ANDROID_GOOGLE_SERVICES_JSON"], "android/app/google-services.json")
    
    # Shared Configuration
    decode_and_save(["FIREBASE_OPTIONS_DART"], "lib/firebase_options.dart")
