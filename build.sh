#!/bin/bash
# Build ZedgeHost Expenses Tracker APK without Gradle (aapt2 + d8 + apksigner)
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
SDK="$HOME/workspace/android-sdk"
BT="$SDK/build-tools/34.0.0"
ANDROID_JAR="$SDK/platforms/android-34/android.jar"
BUILD="$SRC/build"
APK_OUT="$HOME/workspace/expenses-tracker-apk/ZedgeHost-Expenses-Tracker.apk"

rm -rf "$BUILD"
mkdir -p "$BUILD/compiled" "$BUILD/classes"

# 1. Compile resources
"$BT/aapt2" compile --dir "$SRC/res" -o "$BUILD/compiled.zip"

# 2. Link (creates unsigned APK shell)
"$BT/aapt2" link -o "$BUILD/base.apk" \
  -I "$ANDROID_JAR" \
  --manifest "$SRC/AndroidManifest.xml" \
  --java "$BUILD/gen" \
  "$BUILD/compiled.zip" \
  --auto-add-overlay

# 3. Compile Java
mkdir -p "$BUILD/gen"
find "$BUILD/gen" -name "*.java" > "$BUILD/sources.txt" 2>/dev/null || true
echo "$SRC/java/com/zedgehost/expenses/MainActivity.java" >> "$BUILD/sources.txt"
javac -source 8 -target 8 -bootclasspath "$ANDROID_JAR" -d "$BUILD/classes" @"$BUILD/sources.txt"

# 4. DEX
"$BT/d8" --output "$BUILD" --lib "$ANDROID_JAR" "$BUILD/classes/com/zedgehost/expenses/MainActivity.class" "$BUILD/classes/com/zedgehost/expenses/"*.class 2>/dev/null || \
"$BT/d8" --output "$BUILD" --lib "$ANDROID_JAR" $(find "$BUILD/classes" -name "*.class")

# 5. Add dex + assets to APK
cp "$BUILD/base.apk" "$BUILD/app.apk"
cd "$BUILD" && zip -q app.apk classes.dex
cd "$SRC" && zip -q -r "$BUILD/app.apk" assets -x ".*"
cd "$BUILD"

# 6. Align + sign (debug keystore, created once)
KEYSTORE="$SRC/debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair -keystore "$KEYSTORE" -storepass android -keypass android \
    -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=ZedgeHost, OU=ZedgeHost, O=ZedgeHost, L=Lahore, ST=Punjab, C=PK" >/dev/null 2>&1
fi
"$BT/zipalign" -f -p 4 app.apk app-aligned.apk
"$BT/apksigner" sign --ks "$KEYSTORE" --ks-pass pass:android --key-pass pass:android \
  --out "$APK_OUT" app-aligned.apk

"$BT/apksigner" verify -v "$APK_OUT"
echo "APK BUILT: $APK_OUT"
ls -la "$APK_OUT"
file "$APK_OUT"
