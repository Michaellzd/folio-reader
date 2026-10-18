import AppKit
import SwiftUI
import UniformTypeIdentifiers
@preconcurrency import WebKit

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
    @Published var pageReady = false
    @Published var showAnnotations = false
    @Published var marks: [ReadingMark] = []
    @Published var saveFeedback = false
    @Published var noteEditor = false
    @Published var draftText = ""
    @Published var draftQuote = ""
    @Published var storageError: String?
    @Published var lastSavedAt: Date?
    @Published var selection: TextSelection? {
        didSet { if selection != nil { highlightedMarkID = nil } }
    }
    @Published var highlightedMarkID: UUID?
    var highlightedMark: ReadingMark? { marks.first { $0.id == highlightedMarkID } }
    @Published var draftColor = HighlightColor.yellow
    weak var webView: WKWebView?
    private let store: ReadingStore
    private var record = ReadingRecord()
    private var storageAvailable = true
    private var saveTask: Task<Void, Never>?
    private var draftPoint: ReadingPoint?
    private var draftSection = ""
    private var editingID: UUID?
    private var draftSelection: TextSelection?
    var restorePoint: ReadingPoint?
    var restoreMark: UUID?
    private var anchor: Int?
    private var anchorOffset: Double?
    init(store: ReadingStore = ReadingStore()) { self.store = store }
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
        let previouslyReady = pageReady
        let token = UUID()
        opening = token
        isLoading = true
        pageReady = false
        selection = nil
        highlightedMarkID = nil
        restoreMark = nil
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
                storageError = nil
                lastSavedAt = nil
                storageAvailable = true
                do { record = try store.load(newBook.identifier) }
                catch {
                    record = ReadingRecord()
                    storageAvailable = false
                    storageError = "已保存的数据无法读取，为避免覆盖，请先备份本机阅读数据。"
                }
                marks = record.marks
                if record.position == nil {
                    let legacy = UserDefaults.standard.dictionary(forKey: positionKey(newBook))
                    if let path = legacy?["path"] as? String {
                        record.position = ReadingPoint(path: path, scroll: legacy?["scroll"] as? Double ?? 0)
                    }
                }
                let saved = UserDefaults.standard.dictionary(forKey: positionKey(newBook))
                let savedPath = record.position?.path ?? saved?["path"] as? String
                let restored = savedPath.flatMap { localURL($0, relativeTo: newBook.root, root: newBook.root) }
                    .flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
                location = restored ?? newBook.spine[0]
                restorePoint = restored == nil ? nil : record.position
                restoreScroll = min(1, max(0, restorePoint?.scroll ?? 0))
                scroll = restoreScroll
                anchor = restorePoint?.anchor
                anchorOffset = restorePoint?.offset
                request = UUID()
                UserDefaults.standard.set(url.path, forKey: "lastBook")
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
                if let oldRoot, oldRoot != newBook.root { try? FileManager.default.removeItem(at: oldRoot) }
            case .failure(let failure):
                error = failure.localizedDescription
                pageReady = previouslyReady
            }
        }
    }

    func navigate(_ url: URL, point: ReadingPoint? = nil) {
        guard let book, book.contains(url) else { return }
        savePosition()
        webError = nil
        pageReady = false
        selection = nil
        highlightedMarkID = nil
        restoreMark = nil
        location = url
        restorePoint = point
        restoreScroll = point?.scroll ?? 0
        scroll = restoreScroll
        anchor = point?.anchor
        anchorOffset = point?.offset
        request = UUID()
        savePosition()
    }

    func turn(_ delta: Int) {
        guard let book else { return }
        let next = chapterIndex + delta
        if book.spine.indices.contains(next) { navigate(book.spine[next]) }
    }

    func receivePosition(_ fraction: Double, anchor: Int? = nil, offset: Double? = nil) {
        guard fraction.isFinite else { return }
        scroll = min(1, max(0, fraction))
        self.anchor = anchor
        anchorOffset = offset
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            self?.savePosition()
        }
    }

    private func positionKey(_ book: EPUBBook) -> String { "position:" + book.source.standardizedFileURL.path }
    func savePosition() {
        saveTask?.cancel()
        guard let book, let location else { return }
        let escaped = relativePath(location, in: book)
        UserDefaults.standard.set(["path": escaped, "scroll": scroll], forKey: positionKey(book))
        record.position = ReadingPoint(path: escaped, scroll: scroll, anchor: anchor, offset: anchorOffset)
        _ = persist()
    }

    @discardableResult private func persist() -> Bool {
        guard let book, storageAvailable else { return false }
        do {
            try store.save(record, for: book.identifier)
            storageError = nil
            lastSavedAt = Date()
            return true
        } catch {
            storageError = "无法保存阅读数据，请重试。"
            return false
        }
    }

    private var sectionTitle: String {
        guard let book else { return "" }
        return selectedChapter.flatMap { id in book.chapters.first(where: { $0.id == id })?.title } ?? book.title
    }

    private func capture(_ completion: @escaping (ReadingPoint, String, TextSelection?) -> Void) {
        guard pageReady, let book, let location, let webView else { return }
        let identifier = book.identifier, expectedRequest = request
        let titlePath = ReadingPoint(path: relativePath(location, in: book), scroll: scroll, anchor: anchor, offset: anchorOffset)
        webView.evaluateJavaScript("window.folioSnapshot ? window.folioSnapshot() : null") { [weak self] result, _ in
            guard let self, self.book?.identifier == identifier, self.request == expectedRequest else { return }
            let snapshot = result as? [String: Any]
            let point = ReadingPoint(path: titlePath.path, scroll: snapshot?["scroll"] as? Double ?? titlePath.scroll,
                                     anchor: snapshot?["anchor"] as? Int ?? titlePath.anchor,
                                     offset: snapshot?["offset"] as? Double ?? titlePath.offset)
            self.scroll = point.scroll; self.anchor = point.anchor; self.anchorOffset = point.offset
            self.savePosition()
            let selected = Self.decodeSelection(snapshot?["selection"]) ?? self.selection
            completion(point, snapshot?["quote"] as? String ?? "", selected)
        }
    }

    private func relativePath(_ url: URL, in book: EPUBBook) -> String {
        let path = String(url.path.dropFirst(book.root.path.count + 1))
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "#?%"))
        return path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
    }

    func saveBookmark() {
        capture { [weak self] point, quote, _ in
            guard let self, self.storageAvailable else { return }
            let oldRecord = self.record
            let mark = ReadingMark(kind: .bookmark, point: point, section: self.sectionTitle, quote: quote)
            self.record.marks.insert(mark, at: 0)
            guard self.persist() else { self.record = oldRecord; return }
            self.marks = self.record.marks
            self.saveFeedback = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self?.saveFeedback = false
            }
        }
    }

    func newNote() {
        capture { [weak self] point, quote, selected in
            guard let self, self.storageAvailable else { return }
            self.highlightedMarkID = nil
            self.draftPoint = point; self.draftQuote = selected?.quote ?? quote; self.draftText = ""
            self.draftSelection = selected; self.draftColor = .yellow
            self.draftSection = self.sectionTitle; self.editingID = nil; self.noteEditor = true
        }
    }

    func editNote(_ mark: ReadingMark) {
        highlightedMarkID = nil
        draftPoint = mark.point; draftSection = mark.section; draftQuote = mark.quote
        draftText = mark.text; editingID = mark.id; noteEditor = true
        draftSelection = mark.selection; draftColor = mark.color ?? .yellow
    }

    func saveNote() {
        guard let point = draftPoint, !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let oldRecord = record
        if let id = editingID, let index = record.marks.firstIndex(where: { $0.id == id }) {
            record.marks[index].text = draftText
            record.marks[index].kind = .note
            record.marks[index].color = draftSelection == nil ? nil : draftColor
        } else {
            record.marks.insert(ReadingMark(kind: .note, point: point, section: draftSection, quote: draftQuote, text: draftText,
                                           selection: draftSelection, color: draftSelection == nil ? nil : draftColor), at: 0)
        }
        guard persist() else { record = oldRecord; return }
        marks = record.marks; noteEditor = false; sidebar = true; showAnnotations = true
        selection = nil
    }

    func removeMark(_ mark: ReadingMark) {
        let oldRecord = record
        record.marks.removeAll { $0.id == mark.id }
        guard persist() else { record = oldRecord; return }
        marks = record.marks
        if highlightedMarkID == mark.id { highlightedMarkID = nil }
    }

    func jump(to mark: ReadingMark) {
        guard let book, let url = localURL(mark.point.path, relativeTo: book.root, root: book.root) else { return }
        navigate(url, point: mark.point)
        restoreMark = mark.selection == nil ? nil : mark.id
    }

    static func decodeSelection(_ value: Any?) -> TextSelection? {
        guard let value, JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value),
              let selection = try? JSONDecoder().decode(TextSelection.self, from: data),
              selection.start >= 0, selection.end > selection.start, !selection.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return selection
    }

    func highlight(_ color: HighlightColor) {
        capture { [weak self] point, _, selected in
            guard let self, self.storageAvailable, let selected else { return }
            let oldRecord = self.record
            let mark = ReadingMark(kind: .highlight, point: point, section: self.sectionTitle, quote: selected.quote,
                                   selection: selected, color: color)
            self.record.marks.insert(mark, at: 0)
            guard self.persist() else { self.record = oldRecord; return }
            self.marks = self.record.marks; self.selection = nil
            self.highlightedMarkID = mark.id
            self.webView?.evaluateJavaScript("window.getSelection().removeAllRanges()", completionHandler: nil)
        }
    }

    var highlightsJSON: String {
        guard let book, let location else { return "[]" }
        let path = relativePath(location, in: book)
        let data: [[String: Any]] = marks.filter { $0.point.path == path && $0.selection != nil }.map { mark in
            let selection = mark.selection!
            return ["id": mark.id.uuidString, "start": selection.start, "end": selection.end, "quote": selection.quote,
                    "prefix": selection.prefix, "suffix": selection.suffix,
                    "color": String(format: "#%06X", (mark.color ?? .yellow).hex),
                    "note": mark.text, "label": t("添加笔记")]
        }
        return String(data: (try? JSONSerialization.data(withJSONObject: data)) ?? Data("[]".utf8), encoding: .utf8) ?? "[]"
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}
