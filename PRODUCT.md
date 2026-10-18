# Folio / 书页

<!-- impeccable:product-schema 1 -->

## Platform
macOS (native desktop)

## Users and purpose
The user wants a simple Mac app that directly opens and reads local EPUB files. Success is opening an EPUB and reading its actual content immediately.

## Capabilities and constraints
Open EPUB from Finder, a file picker, or drag and drop. Keep the interface small and focused. No account or server. EPUB content stays local. Encrypted DRM books are outside this implementation.

## Stack
Implementation choice under the user's full authorization: native SwiftUI/AppKit and WebKit, with Foundation XML and system zlib. Build using Command Line Tools without Xcode or third-party packages.

## Evidence
Three real EPUB files in the parent workspace are available for verification. They are test inputs, not bundled or redistributed with the app.

## Design judgment
The user requested taste and impeccable. Read the upstream instruction-only Taste skill (Hmbown/taste) and Impeccable (pbakaus/impeccable) through the web tool because neither is installed locally and shell network access is unavailable. The Impeccable launcher was unavailable; use the documented context fallback. The user's request for a simple working app and full authorization takes precedence over optional design approval rounds.

## Interface languages
The user explicitly requested Chinese, English, Japanese, and Spanish. First launch follows the system; a persistent picker allows changing the interface language. Book text stays in its original language.

## Open source
The user requested public source, AGENTS.md, README with links to their other products (using Michaellzd/ownwords as the reference), and downloadable release assets. GitHub publication requires a connected account; never describe an unpushed local repository as published.

## Saved reading and annotations
The user requested closing and reopening without losing their place, manual saves/bookmarks, colored text highlights, and notes attached to highlighted passages. All associated UI must follow the selected language. Document the workflows in README. Persist reading data locally; retain original excerpts and note text. Opening the last available book automatically is authorized by this request.
