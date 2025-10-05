Import("env")  # type: ignore[name-defined]
import os
from typing import Any


env: Any


def read_env(path):
    secrets = {}
    with open(path, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            secrets[key.strip()] = value.strip()
    return secrets


def escape(value):
    return value.replace("\\", "\\\\").replace("\"", "\\\"")


def write_header(path, ssid, password):
    content = f"""#pragma once

namespace wifi_credentials {{
constexpr const char SSID[] = \"{escape(ssid)}\";
constexpr const char PASSWORD[] = \"{escape(password)}\";
}} // namespace wifi_credentials
"""

    existing = None
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as current:
            existing = current.read()
    if existing == content:
        return

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as header:
        header.write(content)
    print(f"Generated secret header at {path}")


project_dir = env.subst("$PROJECT_DIR")
env_file = os.path.join(project_dir, ".env")

if not os.path.exists(env_file):
    print("Warning: .env file not found. Create one based on .env.example.")
    env.Exit(1)

secrets = read_env(env_file)

ssid = secrets.get("WIFI_SSID")
password = secrets.get("WIFI_PASSWORD")

if not ssid or not password:
    print("Error: WIFI_SSID or WIFI_PASSWORD missing from .env")
    env.Exit(1)

header_path = os.path.join(env.subst("$PROJECT_SRC_DIR"), "wifi_credentials.h")
write_header(header_path, ssid, password)
