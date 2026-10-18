#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
command -v gh >/dev/null || { print -u2 "Install GitHub CLI and run gh auth login first."; exit 1; }
gh auth status
REPO="Michaellzd/folio-reader"
if gh repo view "$REPO" >/dev/null 2>&1; then
  print -u2 "$REPO already exists. Refusing to overwrite it; use the tag workflow for an existing repository."
  exit 1
fi
git rev-parse --is-inside-work-tree >/dev/null
[[ -z "$(git status --porcelain)" ]] || { print -u2 "Commit source changes before publishing."; exit 1; }
./test.sh
./package.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
gh repo create "$REPO" --public --source . --remote origin --push \
  --description 'A small, local EPUB reader for macOS. Native SwiftUI, four interface languages, no account.'
gh release create "v$VERSION" --repo "$REPO" --target main --title "Folio $VERSION" \
  --notes-file RELEASE-NOTES.md dist/*.zip dist/SHA256SUMS
print "Published: https://github.com/$REPO/releases/tag/v$VERSION"
