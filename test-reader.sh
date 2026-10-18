#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build/fixtures
python3 Tests/make_fixtures.py build/fixtures
xcrun swiftc -parse-as-library -module-cache-path "${TMPDIR:-/private/tmp}/folio-swift-cache" \
  -framework SwiftUI -framework AppKit -framework WebKit -lz \
  Sources/EPUB.swift Sources/Localization.swift Sources/ReadingStore.swift Sources/ReaderState.swift \
  Sources/AnnotationScript.swift Sources/BookWebView.swift Tests/ReaderInteractionTests.swift -o build/reader-interaction-tests
build/reader-interaction-tests "${1:-$PWD/build/fixtures/reader.epub}"
