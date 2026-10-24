#!/usr/bin/env python3
"""Writes app/lib/firebase_options.dart from a google-services.json file.

Usage: python3 tool/gen_firebase_options.py google-services.json app/lib/firebase_options.dart [package_name]
If package_name is given, the matching Android app in the file is used.
Prints the package name that was used.
"""
import json
import sys


def main():
    src, dest = sys.argv[1], sys.argv[2]
    wanted = sys.argv[3] if len(sys.argv) > 3 else None
    data = json.load(open(src, encoding="utf-8"))
    info = data["project_info"]
    clients = data.get("client", [])
    if not clients:
        sys.exit("google-services.json has no Android app in it")

    client = clients[0]
    if wanted:
        for c in clients:
            if c["client_info"]["android_client_info"]["package_name"] == wanted:
                client = c
                break

    api_key = client["api_key"][0]["current_key"]
    app_id = client["client_info"]["mobilesdk_app_id"]
    package = client["client_info"]["android_client_info"]["package_name"]

    def q(s):
        return "'" + str(s).replace("\\", "\\\\").replace("'", "\\'") + "'"

    dart = f"""// GENERATED from google-services.json by tool/gen_firebase_options.py — do not edit.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {{
  static const bool isConfigured = true;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: {q(api_key)},
    appId: {q(app_id)},
    messagingSenderId: {q(info["project_number"])},
    projectId: {q(info["project_id"])},
    storageBucket: {q(info.get("storage_bucket", ""))},
  );
}}
"""
    open(dest, "w", encoding="utf-8").write(dart)
    print(package)


if __name__ == "__main__":
    main()
