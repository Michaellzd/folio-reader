Folio 1.1.0 adds saved reading, colored highlights, and passage notes to the local macOS EPUB reader.

- Native Mac window with warm paper and a collapsible contents sidebar.
- EPUB2/EPUB3 reading, nested contents, local images, and chapter links.
- Adjustable text size, day/night appearance, and saved reading position.
- Automatic reopening of the last book, paragraph-aware position restoration, and manual bookmarks (⌘S).
- Select text to highlight in yellow, green, blue, or pink; attach a note, then click the highlight to edit it.
- Bookmarks, highlights, and notes are saved locally and remain associated when the same EPUB is moved or copied.
- All annotation controls, color names, note editors, save states, and errors follow the four-language interface setting.
- Chinese, English, Japanese, and Spanish interface with a persistent language picker.
- Universal application for Apple Silicon and Intel. Apple Silicon tested locally; Intel cross-compiled.

Download **Folio-macOS-universal.zip**, unzip, and move **书页.app** to Applications. Source-code archives are for developers. SHA256SUMS is included for verification.

This build is ad hoc signed and not Apple-notarized. macOS may require **System Settings → Privacy & Security → Open Anyway** after the first launch attempt.

Reading data uses atomic JSON files in ~/Library/Application Support/Folio/. Back up that folder to retain notes; there is no cloud sync. Existing 1.0 progress migrates on opening a book.

DRM, ZIP64, fixed-layout reproduction, vertical typesetting, and interactive EPUB scripts are not supported. No books are bundled. The README documents all annotation workflows in English, Chinese, Japanese, and Spanish.
