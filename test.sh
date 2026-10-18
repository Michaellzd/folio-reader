#!/bin/zsh
set -euo pipefail
BOOK_PATHS=()
for BOOK_PATH in "$@"; do BOOK_PATHS+=("${BOOK_PATH:A}"); done
cd "${0:A:h}"
mkdir -p build/fixtures
python3 Tests/make_fixtures.py build/fixtures
xcrun swiftc -parse-as-library -module-cache-path /private/tmp/folio-swift-cache \
  Sources/EPUB.swift Sources/Localization.swift Tests/ParserTests.swift -lz -o build/parser-tests
build/parser-tests "$PWD/build/fixtures" "${BOOK_PATHS[@]}"
