Folio 1.1.1 uses the English product name **Folio** everywhere.

- The macOS application is now **Folio.app**.
- App display names, window titles, and in-app branding use Folio in every interface language.
- README, installation instructions, and release assets use the same name.
- The existing app identifier and reading-data locations are retained, so reading progress, bookmarks, highlights, notes, and preferences carry over.

Download **Folio-macOS-universal.zip**, unzip it, and move **Folio.app** to Applications. Requires macOS 14 or later. The universal app contains Apple Silicon and Intel builds; Apple Silicon is tested locally and Intel is cross-compiled.

The app includes automatic reading-position saves, manual bookmarks, four highlight colors, and passage notes, with Chinese, English, Japanese, and Spanish interfaces.

This build is ad hoc signed and not Apple-notarized. macOS may require **System Settings → Privacy & Security → Open Anyway** after the first launch attempt.

Reading data remains local in ~/Library/Application Support/Folio/. No books or personal notes are bundled.
