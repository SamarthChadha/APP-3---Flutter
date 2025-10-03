Import("env")
import os

# Load .env file
env_file = os.path.join(env.get("PROJECT_DIR"), ".env")

if os.path.exists(env_file):
    with open(env_file, "r") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                # Add as build flag
                env.Append(CPPDEFINES=[(key, value)])
                print(f"Loaded {key} from .env")
else:
    print("Warning: .env file not found")
