import Foundation

@main
struct ParserTests {
    static func main() throws {
        setbuf(stdout, nil)
        let args = Array(CommandLine.arguments.dropFirst())
        let fixtureRoot = URL(fileURLWithPath: args[0])
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            guard condition() else { throw BookError.invalid("FAIL: " + message) }
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
        print("PASS \(checks) checks")
    }
}
