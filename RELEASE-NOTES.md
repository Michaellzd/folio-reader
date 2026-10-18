Folio 1.1.3 fixes unresponsive highlights and notes after jumping to a section within a chapter.

- Chapter links with anchors now complete the reader loading flow and scroll to the selected section. Save bookmark, text selection, highlighting, and Add note remain available after navigation.
- Fixes the page-ready state getting stuck when WebKit treats an anchor change as same-document navigation and skips its normal loading callback.
- Retains the localized **Highlighted → Add note** prompt from 1.1.2, with the original passage and selected color.
- Adds a complete SwiftUI/WebKit regression test covering anchored navigation, selection, visible highlights, attached notes, repeated navigation, chapter changes, and returning to a saved note. Test annotations use isolated temporary storage.

Download **Folio-macOS-universal.zip**, unzip it, and move **Folio.app** to Applications. Requires macOS 14 or later. Includes Apple Silicon and Intel support. The app uses an ad hoc signature and is not Apple-notarized; see README for first-open instructions.
