import Foundation
import zlib

enum BookError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

struct Chapter: Identifiable, Sendable {
    let id: Int
    let title: String
    let url: URL
    let depth: Int
}

struct EPUBBook: Sendable {
    let title: String
    let author: String
    let root: URL
    let source: URL
    let spine: [URL]
    let chapters: [Chapter]
    let cover: URL?

    func contains(_ url: URL) -> Bool {
        url.isFileURL && url.standardizedFileURL.path.hasPrefix(root.path + "/")
    }

    func spineIndex(for url: URL) -> Int? {
        spine.firstIndex { $0.standardizedFileURL.path == url.standardizedFileURL.path }
    }

    static func load(_ source: URL) throws -> EPUBBook {
        guard source.pathExtension.lowercased() == "epub" else {
            throw BookError.invalid("请选择 .epub 格式的电子书。")
        }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Folio-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        do {
            try ZIPArchive.extract(source, to: root)
            let container = try XMLTree.read(root.appendingPathComponent("META-INF/container.xml"))
            guard let packagePath = container.descendants("rootfile").first?.attributes["full-path"],
                  let packageURL = localURL(packagePath, relativeTo: root, root: root) else {
                throw BookError.invalid("这本书缺少 EPUB 目录信息，请尝试其他 EPUB 文件。")
            }
            let package = try XMLTree.read(packageURL)
            let base = packageURL.deletingLastPathComponent()
            let title = package.descendants("title").first?.text.nonempty ?? source.deletingPathExtension().lastPathComponent
            let author = package.descendants("creator").map(\.text).filter { !$0.isEmpty }.joined(separator: " · ")
            struct Item {
                let url: URL
                let media: String
                let properties: [String]
            }
            var manifest: [String: Item] = [:]
            for node in package.descendants("item") {
                guard let id = node.attributes["id"], let href = node.attributes["href"],
                      let url = localURL(href, relativeTo: base, root: root) else { continue }
                manifest[id] = Item(url: url, media: node.attributes["media-type"] ?? "",
                                    properties: (node.attributes["properties"] ?? "").components(separatedBy: " "))
            }
            let spineNode = package.descendants("spine").first
            let spineItems = spineNode?.children.filter { $0.name == "itemref" } ?? []
            let spine = spineItems.filter { $0.attributes["linear"] != "no" }.compactMap { node -> URL? in
                guard let id = node.attributes["idref"], let item = manifest[id],
                      ["application/xhtml+xml", "text/html"].contains(item.media),
                      FileManager.default.fileExists(atPath: item.url.path) else { return nil }
                return item.url
            }
            guard !spine.isEmpty else { throw BookError.invalid("这本 EPUB 没有可阅读的正文，或使用了不支持的格式。") }
            if let encryption = try? XMLTree.read(root.appendingPathComponent("META-INF/encryption.xml")),
               encryption.descendants("EncryptedData").contains(where: { data in
                   data.descendants("EncryptionMethod").contains {
                       let algorithm = $0.attributes["Algorithm"] ?? ""
                       return !algorithm.contains("embedding") && !algorithm.contains("obfuscation")
                   }
               }) {
                throw BookError.invalid("这本书带有 DRM 加密。请打开未加密的 EPUB 文件。")
            }
            var chapters: [Chapter] = []
            if let nav = manifest.values.first(where: { $0.properties.contains("nav") }),
               let tree = try? XMLTree.read(nav.url),
               let contents = tree.descendants("nav").first(where: { ($0.attributes["type"] ?? "").components(separatedBy: " ").contains("toc") }) {
                func walk(_ node: XMLTree, depth: Int) {
                    for child in node.children {
                        if child.name == "a", let href = child.attributes["href"],
                           let url = localURL(href, relativeTo: nav.url.deletingLastPathComponent(), root: root),
                           !child.text.isEmpty {
                            chapters.append(Chapter(id: chapters.count, title: child.text, url: url, depth: max(0, depth - 1)))
                        } else {
                            walk(child, depth: depth + (child.name == "ol" ? 1 : 0))
                        }
                    }
                }
                walk(contents, depth: 0)
            }
            if chapters.isEmpty,
               let ncx = spineNode?.attributes["toc"].flatMap({ manifest[$0] }) ?? manifest.values.first(where: { $0.media == "application/x-dtbncx+xml" }),
               let tree = try? XMLTree.read(ncx.url) {
                func walk(_ node: XMLTree, depth: Int) {
                    for child in node.children {
                        if child.name == "navPoint" {
                            let label = child.children.first(where: { $0.name == "navLabel" })?.text ?? "章节"
                            if let href = child.children.first(where: { $0.name == "content" })?.attributes["src"],
                               let url = localURL(href, relativeTo: ncx.url.deletingLastPathComponent(), root: root) {
                                chapters.append(Chapter(id: chapters.count, title: label, url: url, depth: depth))
                            }
                            walk(child, depth: depth + 1)
                        } else { walk(child, depth: depth) }
                    }
                }
                walk(tree, depth: 0)
            }
            if chapters.isEmpty {
                chapters = spine.enumerated().map { index, url in
                    let tree = try? XMLTree.read(url)
                    let label = tree?.descendants("h1").first?.text.nonempty
                        ?? tree?.descendants("title").first?.text.nonempty ?? "第 \(index + 1) 节"
                    return Chapter(id: index, title: label, url: url, depth: 0)
                }
            }
            let coverID = package.descendants("meta").first(where: { $0.attributes["name"] == "cover" })?.attributes["content"]
            let cover = manifest.values.first(where: { $0.properties.contains("cover-image") })?.url
                ?? coverID.flatMap { manifest[$0]?.url }
            return EPUBBook(title: title, author: author, root: root, source: source,
                            spine: spine, chapters: chapters, cover: cover)
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }
}

func localURL(_ href: String, relativeTo base: URL, root: URL) -> URL? {
    // Resolve URI escaping before containment checks; fragments remain available for TOC links.
    let allowed = CharacterSet.urlFragmentAllowed.union(CharacterSet(charactersIn: "%#"))
    guard let escaped = href.addingPercentEncoding(withAllowedCharacters: allowed),
          let url = URL(string: escaped, relativeTo: URL(fileURLWithPath: base.path, isDirectory: true))?.absoluteURL,
          url.isFileURL else { return nil }
    let path = url.standardizedFileURL.path
    guard path.hasPrefix(root.standardizedFileURL.path + "/") else { return nil }
    return url
}

extension String {
    var nonempty: String? { isEmpty ? nil : self }
}

final class XMLTree: NSObject, XMLParserDelegate {
    var name = ""
    var attributes: [String: String] = [:]
    var children: [XMLTree] = []
    private var chunks: [String] = []
    private var stack: [XMLTree] = []
    var text: String { chunks.joined().split(whereSeparator: \.isWhitespace).joined(separator: " ") }

    func descendants(_ name: String) -> [XMLTree] {
        children.flatMap { ($0.name == name ? [$0] : []) + $0.descendants(name) }
    }
    static func read(_ url: URL) throws -> XMLTree {
        let data = try Data(contentsOf: url)
        guard data.count < 32 * 1024 * 1024 else { throw BookError.invalid("EPUB 章节过大，无法打开。") }
        let tree = XMLTree()
        tree.stack = [tree]
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = tree
        guard parser.parse() else { throw BookError.invalid("EPUB 文件结构不完整或已损坏。") }
        tree.stack = []
        return tree
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        let node = XMLTree()
        node.name = elementName.components(separatedBy: ":").last ?? elementName
        node.attributes = Dictionary(attributeDict.map { ($0.key.components(separatedBy: ":").last ?? $0.key, $0.value) }, uniquingKeysWith: { first, _ in first })
        stack.last?.children.append(node)
        stack.append(node)
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        for node in stack { node.chunks.append(string) }
    }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let value = String(data: CDATABlock, encoding: .utf8) { for node in stack { node.chunks.append(value) } }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        _ = stack.popLast()
    }
}

enum ZIPArchive {
    static func extract(_ source: URL, to root: URL) throws {
        let data = try Data(contentsOf: source, options: .mappedIfSafe)
        func invalid() -> BookError { .invalid("EPUB 压缩包已损坏、被加密，或超出大小限制。请尝试其他文件。") }
        guard data.count >= 22, data.count <= 512 * 1024 * 1024 else { throw invalid() }
        func u16(_ i: Int) throws -> Int {
            guard i >= 0, i + 2 <= data.count else { throw invalid() }
            return Int(data[i]) | Int(data[i + 1]) << 8
        }
        func u32(_ i: Int) throws -> Int {
            guard i >= 0, i + 4 <= data.count else { throw invalid() }
            return Int(data[i]) | Int(data[i + 1]) << 8 | Int(data[i + 2]) << 16 | Int(data[i + 3]) << 24
        }
        var end: Int?
        for i in stride(from: data.count - 22, through: max(0, data.count - 65557), by: -1) {
            if try u32(i) == 0x06054b50, try i + 22 + u16(i + 20) == data.count { end = i; break }
        }
        guard let end, try u16(end + 4) == 0, try u16(end + 6) == 0 else { throw invalid() }
        let count = try u16(end + 10)
        var cursor = try u32(end + 16)
        guard count > 0, count <= 20000, try u16(end + 8) == count else { throw invalid() }
        var total = 0
        var seen = Set<String>()
        for _ in 0..<count {
            guard try u32(cursor) == 0x02014b50 else { throw invalid() }
            let flags = try u16(cursor + 8)
            let method = try u16(cursor + 10)
            let crc = try u32(cursor + 16)
            let compressed = try u32(cursor + 20)
            let size = try u32(cursor + 24)
            let nameSize = try u16(cursor + 28)
            let extra = try u16(cursor + 30)
            let comment = try u16(cursor + 32)
            let external = try u32(cursor + 38)
            let offset = try u32(cursor + 42)
            let next = cursor + 46 + nameSize + extra + comment
            guard next <= data.count, nameSize > 0, flags & 1 == 0,
                  method == 0 || method == 8, (external >> 16) & 0xF000 != 0xA000,
                  let name = String(data: data[(cursor + 46)..<(cursor + 46 + nameSize)], encoding: .utf8),
                  !name.hasPrefix("/"), !name.contains("\\"), !name.contains("\0"),
                  !name.components(separatedBy: "/").contains("..") else { throw invalid() }
            cursor = next
            let target = root.appendingPathComponent(name).standardizedFileURL
            guard target.path.hasPrefix(root.path + "/"), seen.insert(target.path).inserted else { throw invalid() }
            total += size
            guard total <= 512 * 1024 * 1024, size <= 64 * 1024 * 1024 else { throw invalid() }
            if name.hasSuffix("/") {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                continue
            }
            guard try u32(offset) == 0x04034b50 else { throw invalid() }
            let start = try offset + 30 + u16(offset + 26) + u16(offset + 28)
            guard start >= 0, start + compressed <= data.count else { throw invalid() }
            let input = Data(data[start..<(start + compressed)])
            var output: Data
            if method == 0 {
                guard size == compressed else { throw invalid() }
                output = input
            } else {
                output = Data(count: max(size, 1))
                var stream = z_stream()
                guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { throw invalid() }
                defer { inflateEnd(&stream) }
                let status: Int32 = input.withUnsafeBytes { src in
                    output.withUnsafeMutableBytes { dst in
                        stream.next_in = UnsafeMutablePointer(mutating: src.bindMemory(to: Bytef.self).baseAddress)
                        stream.avail_in = uInt(compressed)
                        stream.next_out = dst.bindMemory(to: Bytef.self).baseAddress
                        stream.avail_out = uInt(max(size, 1))
                        return inflate(&stream, Z_FINISH)
                    }
                }
                guard status == Z_STREAM_END, stream.total_out == size else { throw invalid() }
                output.count = size
            }
            let checksum = output.withUnsafeBytes { bytes in
                crc32(0, bytes.bindMemory(to: Bytef.self).baseAddress, uInt(output.count))
            }
            guard checksum == crc else { throw invalid() }
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try output.write(to: target)
        }
    }
}
