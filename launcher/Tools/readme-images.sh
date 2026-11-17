#!/bin/zsh
# Re-renders the images in site/images/, shared by the README and the public site.
# Run after changing the library's look, the icon, or ReadmeArt.swift.
#   arcade.png  the arcade: one cabinet, one game, empty pockets (pixel art)
#   terminal.png  playing MAME from Terminal (launcher/Tools/ReadmeArt.swift)
#   coinless.png  the Coinless library (Coinless --preview dino; needs Cadillacs installed)
set -eu
ROOT="${0:A:h:h:h}"
BUILD="$ROOT/launcher/.build"
OUT="$ROOT/site/images"
mkdir -p "$OUT" "$BUILD/module-cache"
/usr/bin/xcrun swiftc -module-cache-path "$BUILD/module-cache" \
  "$ROOT/launcher/Tools/ReadmeArt.swift" -o "$BUILD/readme-art"
"$BUILD/readme-art" "$OUT/arcade.png" "$OUT/terminal.png"
"$ROOT/Coinless.app/Contents/MacOS/Coinless" --preview dino >/dev/null
cp "$BUILD/preview.png" "$OUT/coinless.png"
# Keep the repository light: 1600 px wide is plenty for a README.
/usr/bin/sips -Z 1600 "$OUT/arcade.png" "$OUT/terminal.png" "$OUT/coinless.png" >/dev/null
# The site's link preview (1200×630, from the arcade scene) and icons (from the app icon).
/usr/bin/sips -Z 1200 "$OUT/arcade.png" --out "$OUT/og.png" >/dev/null
/usr/bin/sips -c 630 1200 "$OUT/og.png" >/dev/null
for size in 180 512; do
  /usr/bin/sips -s format png -Z $size "$ROOT/Coinless.app/Contents/Resources/Coinless.icns" --out "$OUT/icon-$size.png" >/dev/null
done
ls -lh "$OUT"
