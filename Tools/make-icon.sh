#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p build
xcrun swiftc -module-cache-path "${TMPDIR:-/private/tmp}/folio-swift-cache" Tools/MakeIcon.swift -o build/make-icon
build/make-icon build/AppIcon.iconset
python3 - <<'PY'
import struct
from pathlib import Path
root = Path('build/AppIcon.iconset')
parts = []
for tag, name in [('icp4', 'icon_16x16.png'), ('icp5', 'icon_32x32.png'), ('icp6', 'icon_32x32@2x.png'), ('ic07', 'icon_128x128.png'), ('ic08', 'icon_256x256.png'), ('ic09', 'icon_512x512.png'), ('ic10', 'icon_512x512@2x.png')]:
    data = (root / name).read_bytes()
    parts.append(tag.encode() + struct.pack('>I', len(data) + 8) + data)
data = b''.join(parts)
Path('Resources/AppIcon.icns').write_bytes(b'icns' + struct.pack('>I', len(data) + 8) + data)
PY
