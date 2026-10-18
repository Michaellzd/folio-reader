# Working on Folio

## Product

Folio (书页) is a small native macOS EPUB reader. The primary task is opening a local EPUB and reading it immediately. Keep reading central. New accounts, cloud services, libraries, AI features, and dependencies need a concrete product reason.

Read PRODUCT.md and DESIGN.md before changing the UI. The initial design used Taste and Impeccable; preserve its restrained native Mac controls, warm paper, legible serif text, and collapsible contents.

## Layout

- `Sources/EPUB.swift`: ZIP extraction, XML parsing, EPUB2 NCX / EPUB3 navigation, spine, metadata.
- `Sources/ReaderState.swift`: opening, navigation, saved position, preferences.
- `Sources/BookWebView.swift`: local WebKit rendering and reading CSS.
- `Sources/FolioApp.swift`: SwiftUI window, native application delegate, menus, contents, appearance.
- `Sources/Localization.swift`: Chinese, English, Japanese, Spanish UI strings and system-language detection.
- `Resources/`: app metadata and icon. `Tools/`: reproducible icon generation.
- `Tests/`: original generated EPUB fixtures and parser/localization checks.

## Build and check

Requires macOS 14+, Apple's Command Line Tools with Swift 6+, and Python 3 for test fixture generation. No third-party packages or full Xcode required.

```sh
./test.sh
./build.sh
./package.sh
```

Pass explicit local EPUB paths to `./test.sh /path/to/book.epub` for additional compatibility checks. Test data remains outside version control. Confirm actual reading, TOC links and anchors, font size, all four languages, day/night themes, file-picker opening, Finder opening, and saved position after relaunch for changes to reading behavior. Check rendered layout at the minimum window size and normal desktop size. Check the packaged app after extraction before release.

## Constraints

- Keep book content local. JavaScript from books is disabled; remote subresources are blocked before loading a page.
- Restrict reading and navigation to the extracted book directory. Preserve ZIP traversal, symlink, encryption, CRC, and size checks.
- Use callback-based `evaluateJavaScript` for scripts that return `undefined`: some macOS async overlays force-unwrap the result and crash.
- Preserve EPUB content and structure; avoid book-specific markup rewrites.
- Add every new UI string to all four languages; preserve localization placeholders.
- Save settings locally and avoid telemetry. App UI language never translates or edits book content.
- Exclude real books, personal paths, credentials, generated archives, caches, crash logs, and private user data from commits and release assets.

## Releases

`./package.sh` creates a universal arm64/x86_64 `.app` ZIP, a versioned copy, and SHA256SUMS in `dist/`. `v*` tags trigger `.github/workflows/release.yml`, which tests, builds, and uploads real application assets to GitHub Releases. Use the existing version in Info.plist and update release notes with user-visible changes. Do not claim Apple notarization without Developer ID signing and a successful notarization ticket. The default build uses an ad hoc signature.
