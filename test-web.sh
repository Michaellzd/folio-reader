#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build
xcrun swiftc -parse-as-library -module-cache-path "${TMPDIR:-/private/tmp}/folio-swift-cache" \
  -framework AppKit -framework WebKit Sources/AnnotationScript.swift Tests/AnnotationTests.swift -o build/annotation-tests
build/annotation-tests
