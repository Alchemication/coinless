#!/bin/zsh
# Builds Coinless.app in the project root, signs it for this Mac, and runs its self-check.
set -eu
PROJECT_ROOT="${0:A:h:h}"
LAUNCHER="$PROJECT_ROOT/launcher"
BUILD="$LAUNCHER/.build"
CACHE="$BUILD/module-cache"
APP="$PROJECT_ROOT/Coinless.app"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$CACHE"
/usr/bin/plutil -lint -s "$LAUNCHER/Info.plist"
/usr/bin/xcrun swiftc -parse-as-library -O -module-cache-path "$CACHE" \
  -framework SwiftUI -framework AppKit -framework GameController \
  "$LAUNCHER"/Sources/*.swift -o "$APP/Contents/MacOS/Coinless"
cp "$LAUNCHER/Info.plist" "$APP/Contents/Info.plist"
# The app reads launcher/games.json at runtime; this copy is only a fallback.
cp "$LAUNCHER/games.json" "$APP/Contents/Resources/games.json"
# Used only if Coinless.app is moved out of the project folder.
printf '%s' "$PROJECT_ROOT" > "$APP/Contents/Resources/project-path.txt"
/usr/bin/xcrun swiftc -module-cache-path "$CACHE" "$LAUNCHER/Tools/Icon.swift" -o "$BUILD/make-icon"
"$BUILD/make-icon" "$APP/Contents/Resources/Coinless.icns"
/usr/bin/codesign --force --sign - "$APP"
printf 'Built %s\n\n' "$APP"

if ! "$APP/Contents/MacOS/Coinless" --check; then
  printf '\nThe app was built, but the check above needs attention before games can start.\n' >&2
fi
