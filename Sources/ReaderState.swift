import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ReaderState: ObservableObject {
    static let shared = ReaderState()
    @Published var book: EPUBBook?
    @Published var location: URL?
    @Published var request = UUID()
    @Published var isLoading = false
    @Published var error: String?
    @Published var sidebar = true
    @Published var appearancePanel = false
    @Published var scroll = 0.0
    @Published var webError: String?
    @Published var language = AppLanguage.initial {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }
    @Published var fontSize: Double = UserDefaults.standard.object(forKey: "fontSize") as? Double ?? 20 {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    @Published var dark = UserDefaults.standard.bool(forKey: "dark") {
        didSet { UserDefaults.standard.set(dark, forKey: "dark") }
    }
    var restoreScroll = 0.0
    private var opening: UUID?
    var chapterIndex: Int { book.flatMap { book in location.flatMap { book.spineIndex(for: $0) } } ?? 0 }
    var selectedChapter: Int? {
        guard let book, let location else { return nil }
        return book.chapters.last(where: { $0.url.path == location.path && $0.url.fragment == location.fragment })?.id
            ?? book.chapters.first(where: { $0.url.path == location.path })?.id
    }
    var paper: Color { dark ? Color(hex: 0x20221F) : Color(hex: 0xF8F5EF) }
    var ink: Color { dark ? Color(hex: 0xE6E2D8) : Color(hex: 0x302E29) }
    var muted: Color { dark ? Color(hex: 0xADAFA5) : Color(hex: 0x777267) }
    var accent: Color { dark ? Color(hex: 0xBAC5A5) : Color(hex: 0x5B6548) }
    func t(_ key: String) -> String { L10n.text(key, language: language) }
    func sectionLabel(_ total: Int) -> String {
        t("第 {current} / {total} 节").replacingOccurrences(of: "{current}", with: String(chapterIndex + 1))
            .replacingOccurrences(of: "{total}", with: String(total))
    }

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "epub") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = t("开始阅读")
        panel.message = t("选择一本 EPUB 电子书")
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }

    func open(_ url: URL) {
        savePosition()
        let token = UUID()
        opening = token
        isLoading = true
        error = nil
        let accessed = url.startAccessingSecurityScopedResource()
        Task {
            let result = await Task.detached(priority: .userInitiated) { Result { try EPUBBook.load(url) } }.value
            if accessed { url.stopAccessingSecurityScopedResource() }
            guard opening == token else {
                if case .success(let abandoned) = result { try? FileManager.default.removeItem(at: abandoned.root) }
                return
            }
            isLoading = false
            switch result {
            case .success(let newBook):
                let oldRoot = book?.root
                book = newBook
                webError = nil
                let saved = UserDefaults.standard.dictionary(forKey: positionKey(newBook))
                let savedPath = saved?["path"] as? String
                let restored = savedPath.flatMap { localURL($0, relativeTo: newBook.root, root: newBook.root) }
                location = restored.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil } ?? newBook.spine[0]
                restoreScroll = min(1, max(0, saved?["scroll"] as? Double ?? 0))
                scroll = restoreScroll
                request = UUID()
                UserDefaults.standard.set(url.path, forKey: "lastBook")
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
                if let oldRoot, oldRoot != newBook.root { try? FileManager.default.removeItem(at: oldRoot) }
            case .failure(let failure): error = failure.localizedDescription
            }
        }
    }

    func navigate(_ url: URL) {
        guard let book, book.contains(url) else { return }
        savePosition()
        webError = nil
        location = url
        restoreScroll = 0
        scroll = 0
        request = UUID()
        savePosition()
    }

    func turn(_ delta: Int) {
        guard let book else { return }
        let next = chapterIndex + delta
        if book.spine.indices.contains(next) { navigate(book.spine[next]) }
    }

    func receivePosition(_ fraction: Double) {
        scroll = min(1, max(0, fraction))
        savePosition()
    }

    private func positionKey(_ book: EPUBBook) -> String { "position:" + book.source.standardizedFileURL.path }
    func savePosition() {
        guard let book, let location else { return }
        let relative = String(location.path.dropFirst(book.root.path.count + 1))
        // Use an escaped URI so Chinese names, spaces, and literal # remain valid.
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "#?%"))
        let escaped = relative.addingPercentEncoding(withAllowedCharacters: allowed) ?? relative
        UserDefaults.standard.set(["path": escaped, "scroll": scroll], forKey: positionKey(book))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}
