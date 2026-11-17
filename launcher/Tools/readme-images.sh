#!/bin/zsh
# Re-renders the README images in docs/images/. Run after changing the library's look.
#   before.png  playing MAME from Terminal (launcher/Tools/ReadmeArt.swift)
#   after.png   the Coinless library (Coinless --preview dino; needs Cadillacs installed)
set -eu
ROOT="${0:A:h:h:h}"
BUILD="$ROOT/launcher/.build"
OUT="$ROOT/docs/images"
mkdir -p "$OUT" "$BUILD/module-cache"
/usr/bin/xcrun swiftc -module-cache-path "$BUILD/module-cache" \
  "$ROOT/launcher/Tools/ReadmeArt.swift" -o "$BUILD/readme-art"
"$BUILD/readme-art" "$OUT/before.png"
"$ROOT/Coinless.app/Contents/MacOS/Coinless" --preview dino >/dev/null
cp "$BUILD/preview.png" "$OUT/after.png"
# Keep the repository light: 1600 px wide is plenty for a README.
/usr/bin/sips -Z 1600 "$OUT/before.png" "$OUT/after.png" >/dev/null
ls -lh "$OUT"
