#!/bin/zsh
set -eu
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_ROOT/Arcade.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$PROJECT_ROOT/launcher/.build/module-cache"
/usr/bin/plutil -lint "$PROJECT_ROOT/launcher/Info.plist"
/usr/bin/xcrun swiftc -parse-as-library -O \
  -module-cache-path "$PROJECT_ROOT/launcher/.build/module-cache" \
  -framework SwiftUI -framework AppKit -framework GameController \
  "$PROJECT_ROOT/launcher/Arcade.swift" -o "$APP_PATH/Contents/MacOS/Arcade"
cp "$PROJECT_ROOT/launcher/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$PROJECT_ROOT/launcher/games.json" "$APP_PATH/Contents/Resources/games.json"
printf '%s' "$PROJECT_ROOT" > "$APP_PATH/Contents/Resources/project-path.txt"
/usr/bin/xcrun swiftc -module-cache-path "$PROJECT_ROOT/launcher/.build/module-cache" \
  "$PROJECT_ROOT/launcher/Icon.swift" -o "$PROJECT_ROOT/launcher/.build/make-icon"
"$PROJECT_ROOT/launcher/.build/make-icon" "$APP_PATH/Contents/Resources/Arcade.icns"
/usr/bin/codesign --force --sign - "$APP_PATH"
"$APP_PATH/Contents/MacOS/Arcade" --check
printf '\nBuilt %s\n' "$APP_PATH"
