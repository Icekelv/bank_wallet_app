#!/usr/bin/env python3
"""Adjusts the Android project that `flutter create` generates.

Run from the app/ folder after `flutter create`. Reads environment variables:
  APP_NAME      launcher label (default "mono")
  APP_ID        Android applicationId; must match the package registered in Firebase
  API_BASE_URL  if it starts with http:// cleartext traffic is allowed
"""
import os
import re
import sys

app_name = os.environ.get("APP_NAME") or "mono"
app_id = os.environ.get("APP_ID") or ""
api = os.environ.get("API_BASE_URL") or ""

manifest_path = "android/app/src/main/AndroidManifest.xml"
m = open(manifest_path, encoding="utf-8").read()

perms = [
    "android.permission.INTERNET",
    "android.permission.POST_NOTIFICATIONS",
]
for perm in perms:
    if perm not in m:
        m = m.replace("<application", f'<uses-permission android:name="{perm}"/>\n    <application', 1)

label = app_name.replace("&", "&amp;").replace('"', "&quot;")
m = re.sub(r'android:label="[^"]*"', f'android:label="{label}"', m, count=1)

if api.startswith("http://") and "usesCleartextTraffic" not in m:
    m = m.replace("<application", '<application android:usesCleartextTraffic="true"', 1)

open(manifest_path, "w", encoding="utf-8").write(m)
print("Patched", manifest_path)

gradle = None
for name in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    if os.path.exists(name):
        gradle = name
        break
if gradle is None:
    sys.exit("No android/app/build.gradle(.kts) found — did flutter create run?")

g = open(gradle, encoding="utf-8").read()
# Firebase Messaging needs Android 7.0+ (API 24).
g = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24", g)
g = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 24", g)
g = re.sub(r"minSdk\s*=\s*(\d+)", lambda mm: "minSdk = " + str(max(24, int(mm.group(1)))), g)
g = re.sub(r"minSdkVersion\s+(\d+)", lambda mm: "minSdkVersion " + str(max(24, int(mm.group(1)))), g)
if app_id:
    g = re.sub(r'applicationId\s*=\s*"[^"]*"', f'applicationId = "{app_id}"', g)
    g = re.sub(r'applicationId\s+"[^"]*"', f'applicationId "{app_id}"', g)
open(gradle, "w", encoding="utf-8").write(g)
print("Patched", gradle, "applicationId:", app_id or "(unchanged)")
