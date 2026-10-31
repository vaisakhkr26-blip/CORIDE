#!/usr/bin/env bash
# One-time setup. Run inside the coride_app folder, with Flutter 3.35+ installed.
set -euo pipefail

# 1. Generate the Android/iOS project files around the existing lib/ code (keeps lib/ and pubspec.yaml as they are).
cp -r lib /tmp/coride_lib_backup && cp pubspec.yaml /tmp/coride_pubspec_backup.yaml
flutter create --org in.coride --project-name coride --platforms=android,ios .
rm -rf lib && cp -r /tmp/coride_lib_backup lib && cp /tmp/coride_pubspec_backup.yaml pubspec.yaml
rm -f test/widget_test.dart

# 2. Let the app talk to the backend over plain http while you are developing.
MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q usesCleartextTraffic "$MANIFEST"; then
  sed -i 's/<application/<application android:usesCleartextTraffic="true"/' "$MANIFEST"
fi
# 3. Internet permission for release builds (debug builds already have it).
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
fi

flutter pub get
flutter test
echo
echo "Setup done. Now run the app (see README.md)."
