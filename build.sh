#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="${APP_OUTPUT:-$PWD/build/书页.app}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
for ARCH in arm64 x86_64; do
  xcrun swiftc -O -parse-as-library -target "$ARCH-apple-macosx14.0" \
    -module-cache-path "${TMPDIR:-/private/tmp}/folio-swift-cache" \
    -framework SwiftUI -framework AppKit -framework WebKit -lz \
    Sources/*.swift -o "build/Folio-$ARCH"
done
xcrun lipo -create build/Folio-arm64 build/Folio-x86_64 -output "$APP/Contents/MacOS/Folio"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"; fi
codesign --force --deep --sign - "$APP"
print "已构建：$APP"
