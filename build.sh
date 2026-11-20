#!/bin/sh
# Xcode-free build: swiftc + iconutil + codesign. Produces build/Pastry.app and installs it to /Applications/Pastry.app.
# Usage: ./build.sh            build + install
#        ./build.sh --no-install   build only
set -e
cd "$(dirname "$0")"
VERSION=1.0.0
APP=build/Pastry.app
rm -rf "$APP" build/AppIcon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos14.0" Sources/*.swift -o "$APP/Contents/MacOS/Pastry" -lsqlite3 -Xlinker -weak_framework -Xlinker FoundationModels

swiftc -O tools/make-icon.swift -o build/make-icon
build/make-icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Pastry</string>
  <key>CFBundleDisplayName</key><string>Pastry</string>
  <key>CFBundleExecutable</key><string>Pastry</string>
  <key>CFBundleIdentifier</key><string>com.manavchordia.pastry</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Manav Chordia</string>
</dict></plist>
EOF
plutil -lint "$APP/Contents/Info.plist" >/dev/null
# Stable signature so the Accessibility grant survives rebuilds: sign with the self-signed "Pastry Dev" identity if it exists
# (the designated requirement then pins the certificate, not the cdhash); otherwise ad-hoc with a fixed designated requirement.
# One-time identity setup: see README ("Signing").
if security find-identity -p codesigning | grep -q '"Pastry Dev"'; then
  codesign --force --deep --sign "Pastry Dev" "$APP"
else
  echo "note: no 'Pastry Dev' identity; ad-hoc signing (Accessibility grant may need re-granting)"
  codesign --force --deep --sign - -r='designated => identifier "com.manavchordia.pastry"' "$APP"
fi
codesign -dr - "$APP" 2>&1 | sed -n 's/^designated/designated/p'
echo "built $APP"
[ "$1" = "--no-install" ] && exit 0

# install: quit any running instance first, then replace /Applications/Pastry.app
osascript -e 'tell application id "com.manavchordia.pastry" to quit' >/dev/null 2>&1 || true
for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -x Pastry >/dev/null || break; sleep 0.3; done
pkill -x Pastry 2>/dev/null || true
rm -rf /Applications/Pastry.app
cp -R "$APP" /Applications/Pastry.app
echo "installed /Applications/Pastry.app"
