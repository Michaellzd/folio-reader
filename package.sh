#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
if [[ "${SKIP_BUILD:-0}" != 1 ]]; then ./build.sh; fi
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
STAGE="$PWD/build/package-$VERSION"
mkdir -p "$STAGE" dist
if [[ -d "$STAGE/Folio.app" ]]; then rm -rf "$STAGE/Folio.app"; fi
ditto "build/Folio.app" "$STAGE/Folio.app"
cp START-HERE.txt LICENSE "$STAGE/"
codesign --verify --deep --strict "$STAGE/Folio.app"
xcrun lipo "$STAGE/Folio.app/Contents/MacOS/Folio" -verify_arch arm64 x86_64
ditto -c -k --sequesterRsrc "$STAGE" "dist/Folio-$VERSION-macOS-universal.zip"
cp "dist/Folio-$VERSION-macOS-universal.zip" dist/Folio-macOS-universal.zip
(cd dist && shasum -a 256 "Folio-$VERSION-macOS-universal.zip" Folio-macOS-universal.zip > SHA256SUMS)
print "发行包：$PWD/dist/Folio-$VERSION-macOS-universal.zip"
