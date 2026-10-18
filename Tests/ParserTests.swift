import Foundation

@main
struct ParserTests {
    static func main() throws {
        setbuf(stdout, nil)
        let args = Array(CommandLine.arguments.dropFirst())
        let fixtureRoot = URL(fileURLWithPath: args[0])
        var checks = 0
        func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
            guard try condition() else { throw BookError.invalid("FAIL: " + message) }
            checks += 1
        }
        for (key, row) in L10n.translations {
            try expect(row.count == 3 && row.allSatisfy { !$0.isEmpty }, "Complete translations: " + key)
            for language in AppLanguage.allCases {
                let translated = L10n.text(key, language: language)
                for token in ["{current}", "{total}"] {
                    try expect(translated.contains(token) == key.contains(token), "Localized placeholders: " + key)
                }
            }
        }
        for path in args.dropFirst() {
            let book = try EPUBBook.load(URL(fileURLWithPath: path))
            defer { try? FileManager.default.removeItem(at: book.root) }
            try expect(!book.title.isEmpty && !book.spine.isEmpty && !book.chapters.isEmpty, "Real book metadata, spine, and TOC")
            try expect(book.spine.allSatisfy { book.contains($0) && FileManager.default.fileExists(atPath: $0.path) }, "All real spine pages exist")
            try expect(book.chapters.allSatisfy { book.contains($0.url) && FileManager.default.fileExists(atPath: $0.url.path) }, "All real TOC links exist")
            print("PASS \(book.title): \(book.spine.count) spine pages, \(book.chapters.count) TOC entries")
        }
        let book = try EPUBBook.load(fixtureRoot.appendingPathComponent("中文 空格.epub"))
        defer { try? FileManager.default.removeItem(at: book.root) }
        try expect(book.title == "测试书 & 阅读", "Decoded XML metadata")
        try expect(book.author == "作者", "Author metadata")
        try expect(book.spine.count == 2, "Nonlinear pages excluded")
        try expect(book.chapters.count == 3, "EPUB3 navigation")
        try expect(book.chapters[1].depth == 1, "Nested navigation depth")
        try expect(book.chapters[0].url.lastPathComponent == "第一 章.xhtml", "Escaped Unicode resource path")
        try expect(book.chapters[1].url.fragment == "section2", "Anchor navigation")
        try expect(book.cover != nil, "EPUB3 cover metadata")
        let movedSource = fixtureRoot.appendingPathComponent("moved.epub")
        try? FileManager.default.removeItem(at: movedSource)
        try FileManager.default.copyItem(at: fixtureRoot.appendingPathComponent("中文 空格.epub"), to: movedSource)
        let moved = try EPUBBook.load(movedSource)
        defer { try? FileManager.default.removeItem(at: moved.root) }
        try expect(book.identifier == moved.identifier && book.identifier.count == 64, "Moving a book preserves its data identity")
        try expect(book.spineIndex(for: book.chapters[1].url) == 0, "Anchor maps to spine page")
        try expect(localURL("../escape", relativeTo: book.root, root: book.root) == nil, "Traversal rejected")
        try expect(localURL("https://example.com", relativeTo: book.root, root: book.root) == nil, "Remote URL rejected")
        let fallback = try EPUBBook.load(fixtureRoot.appendingPathComponent("fallback.epub"))
        defer { try? FileManager.default.removeItem(at: fallback.root) }
        try expect(fallback.chapters[0].title == "第一章", "Missing TOC uses chapter title")
        for filename in ["traversal.epub", "symlink.epub", "corrupt.epub", "truncated.epub", "drm.epub", "empty.epub"] {
            do {
                let unsafe = try EPUBBook.load(fixtureRoot.appendingPathComponent(filename))
                try? FileManager.default.removeItem(at: unsafe.root)
                throw BookError.invalid("FAIL: accepted " + filename)
            } catch let error as BookError {
                if error.localizedDescription.hasPrefix("FAIL:") { throw error }
                checks += 1
            }
        }
        let store = ReadingStore(directory: fixtureRoot.appendingPathComponent("reading-data-" + UUID().uuidString))
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try expect(try store.load(book.identifier) == ReadingRecord(), "New book has empty saved data")
        let point = ReadingPoint(path: "OPS/%E7%AC%AC%E4%B8%80%20%E7%AB%A0.xhtml", scroll: 0.61, anchor: 7, offset: 0.35)
        let bookmark = ReadingMark(kind: .bookmark, point: point, section: "第一章")
        var note = ReadingMark(kind: .note, point: point, section: "第一章", quote: "Original excerpt 日本語", text: "中文 · English · 日本語 · Español\nSecond line")
        var record = ReadingRecord(position: point, marks: [bookmark, note])
        let selected = TextSelection(start: 6, end: 12, quote: "世界🙂", prefix: "Alpha ", suffix: " repeated")
        let highlight = ReadingMark(kind: .highlight, point: point, section: "第一章", quote: selected.quote, selection: selected, color: .pink)
        record.marks.append(highlight)
        try store.save(record, for: book.identifier)
        let reloadedStore = ReadingStore(directory: store.directory)
        try expect(try reloadedStore.load(moved.identifier) == record, "Progress, bookmarks, quotes, and multilingual notes survive restart and file moves")
        note.text = "Edited note"
        record.marks = [note]
        try store.save(record, for: book.identifier)
        try expect(try store.load(book.identifier).marks == [note], "Note edits and bookmark deletion persist without changing note identity")
        try expect(try store.load(fallback.identifier).marks.isEmpty, "Different books do not share notes")
        let malformedPoint = ReadingPoint(path: "chapter.xhtml", scroll: .infinity, anchor: -2, offset: .nan)
        try expect(malformedPoint.scroll == 0 && malformedPoint.anchor == nil && malformedPoint.offset == nil, "Invalid scroll values are normalized")
        let dataURL = store.directory.appendingPathComponent(book.identifier + ".json")
        try Data("broken data".utf8).write(to: dataURL)
        do { _ = try store.load(book.identifier); throw BookError.invalid("FAIL: silently discarded damaged notes") }
        catch let error as BookError { if error.localizedDescription.hasPrefix("FAIL:") { throw error } }
        catch { checks += 1 }
        do { _ = try store.load("../escape"); throw BookError.invalid("FAIL: unsafe store identifier") }
        catch let error as BookError { if error.localizedDescription.hasPrefix("FAIL:") { throw error }; checks += 1 }
        let blocked = fixtureRoot.appendingPathComponent("blocked-store-" + UUID().uuidString)
        try Data().write(to: blocked)
        defer { try? FileManager.default.removeItem(at: blocked) }
        do { try ReadingStore(directory: blocked).save(record, for: book.identifier); throw BookError.invalid("FAIL: ignored save error") }
        catch let error as BookError { if error.localizedDescription.hasPrefix("FAIL:") { throw error } }
        catch { checks += 1 }
        print("PASS \(checks) checks")
    }
}
