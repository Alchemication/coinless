#!/bin/zsh
# Re-renders the README images in docs/images/. Run after changing the library's look.
#   arcade.png  the arcade: one cabinet, one game, empty pockets (pixel art)
#   terminal.png  playing MAME from Terminal (launcher/Tools/ReadmeArt.swift)
#   coinless.png  the Coinless library (Coinless --preview dino; needs Cadillacs installed)
set -eu
ROOT="${0:A:h:h:h}"
BUILD="$ROOT/launcher/.build"
OUT="$ROOT/docs/images"
mkdir -p "$OUT" "$BUILD/module-cache"
/usr/bin/xcrun swiftc -module-cache-path "$BUILD/module-cache" \
  "$ROOT/launcher/Tools/ReadmeArt.swift" -o "$BUILD/readme-art"
"$BUILD/readme-art" "$OUT/arcade.png" "$OUT/terminal.png"
"$ROOT/Coinless.app/Contents/MacOS/Coinless" --preview dino >/dev/null
cp "$BUILD/preview.png" "$OUT/coinless.png"
# Keep the repository light: 1600 px wide is plenty for a README.
/usr/bin/sips -Z 1600 "$OUT/arcade.png" "$OUT/terminal.png" "$OUT/coinless.png" >/dev/null
ls -lh "$OUT"
