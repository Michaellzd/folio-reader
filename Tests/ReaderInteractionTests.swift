import AppKit
import SwiftUI
@preconcurrency import WebKit

@main
@MainActor
struct ReaderInteractionTests {
    static func waitFor(_ label: String, _ predicate: () async throws -> Bool) async throws {
        for _ in 0..<100 {
            if try await predicate() { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw NSError(domain: "ReaderInteractionTests", code: 1, userInfo: [NSLocalizedDescriptionKey: label])
    }

    static func evaluate(_ script: String, in web: WKWebView) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            web.evaluateJavaScript(script) { value, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: value) }
            }
        }
    }

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Folio-interaction-\(UUID())")
        let state = ReaderState(store: ReadingStore(directory: directory))
        let host = NSHostingView(rootView: BookWebView(state: state))
        let window = NSWindow(contentRect: NSRect(x: -2000, y: -2000, width: 800, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        Task { @MainActor in
            do {
                state.open(URL(fileURLWithPath: CommandLine.arguments[1]))
                try await waitFor("Initial page never became ready") { state.pageReady }
                guard let book = state.book, let web = state.webView,
                      let section = book.chapters.first(where: { $0.url.fragment != nil }) else { fatalError("Missing fixture") }
                state.navigate(section.url)
                try await waitFor("Anchor navigation left reading actions disabled") { state.pageReady }
                let target = section.url.fragment ?? ""
                let targetJSON = String(data: try JSONSerialization.data(withJSONObject: [target]), encoding: .utf8)!
                let atTarget = try await evaluate("Math.abs(document.getElementById(\(targetJSON)[0]).getBoundingClientRect().top)<2 || scrollY+innerHeight>=document.documentElement.scrollHeight-2", in: web)
                guard atTarget as? Bool == true else { fatalError("Anchor target not restored") }
                let token = try await evaluate("window.folioRequest", in: web)
                guard token as? String == state.request.uuidString else { fatalError("Stale selection bridge token") }
                _ = try await evaluate("const r=document.createRange();r.selectNodeContents(document.querySelector('p'));getSelection().removeAllRanges();getSelection().addRange(r);", in: web)
                try await waitFor("Selection bridge stopped after anchor navigation") { state.selection != nil }
                state.highlight(.blue)
                try await waitFor("Highlight did not save or offer a note") { state.highlightedMark != nil }
                guard let mark = state.highlightedMark else { fatalError("Missing highlight") }
                try await waitFor("Saved highlight did not render in the actual document") {
                    try await evaluate("Array.from(document.querySelectorAll('mark.folio-mark')).map(x=>x.textContent).join('')", in: web) as? String == mark.quote
                }
                state.editNote(mark)
                state.draftText = "Test note メモ 笔记"
                state.saveNote()
                guard state.marks.count == 1, state.marks[0].id == mark.id, state.marks[0].kind == .note else { fatalError("Note duplicated highlight") }
                state.navigate(section.url)
                try await waitFor("Repeated anchor navigation left actions disabled") { state.pageReady }
                state.navigate(book.spine[0])
                try await waitFor("Returning to chapter start left actions disabled") { state.pageReady }
                state.navigate(book.spine[1])
                try await waitFor("Next chapter never became ready") { state.pageReady }
                state.jump(to: state.marks[0])
                try await waitFor("Jump to note never became ready") { state.pageReady }
                state.saveBookmark()
                try await waitFor("Bookmark action did not recover after navigation") { state.marks.count == 2 }
                let saved = try ReadingStore(directory: directory).load(book.identifier)
                guard saved.marks.contains(where: { $0.id == mark.id && $0.text == "Test note メモ 笔记" && $0.color == .blue }) else { fatalError("Attached note did not persist") }
                print("PASS reader interaction: anchor target, selection bridge, visible highlight, attached note, repeated navigation, chapter change, saved-note jump, bookmark, persistence")
                if let root = state.book?.root { try? FileManager.default.removeItem(at: root) }
                try? FileManager.default.removeItem(at: directory)
                exit(0)
            } catch { fputs("FAIL \(error.localizedDescription)\n", stderr); exit(1) }
        }
        withExtendedLifetime(window) { app.run() }
    }
}
