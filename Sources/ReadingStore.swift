import Foundation

enum HighlightColor: String, Codable, CaseIterable, Identifiable {
    case yellow, green, blue, pink
    var id: String { rawValue }
    var hex: UInt32 {
        switch self {
        case .yellow: return 0xE9C96A
        case .green: return 0x9DC99A
        case .blue: return 0x9CC4DF
        case .pink: return 0xDFA9B6
        }
    }
    var label: String {
        switch self {
        case .yellow: return "黄色"
        case .green: return "绿色"
        case .blue: return "蓝色"
        case .pink: return "粉色"
        }
    }
}

struct TextSelection: Codable, Equatable {
    let start: Int
    let end: Int
    let quote: String
    let prefix: String
    let suffix: String
}

struct ReadingPoint: Codable, Equatable {
    let path: String
    var scroll: Double
    var anchor: Int?
    var offset: Double?

    init(path: String, scroll: Double, anchor: Int? = nil, offset: Double? = nil) {
        self.path = path
        self.scroll = scroll.isFinite ? min(1, max(0, scroll)) : 0
        self.anchor = anchor.flatMap { $0 >= 0 ? $0 : nil }
        self.offset = offset.flatMap { $0.isFinite ? $0 : nil }
    }
}

struct ReadingMark: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case bookmark, note, highlight }
    let id: UUID
    var kind: Kind
    let point: ReadingPoint
    let section: String
    let quote: String
    var text: String
    var selection: TextSelection?
    var color: HighlightColor?
    let createdAt: Date

    init(id: UUID = UUID(), kind: Kind, point: ReadingPoint, section: String, quote: String = "", text: String = "", selection: TextSelection? = nil, color: HighlightColor? = nil, createdAt: Date = Date()) {
        self.id = id; self.kind = kind; self.point = point; self.section = section
        self.quote = quote; self.text = text; self.createdAt = createdAt
        self.selection = selection; self.color = color
    }
}

struct ReadingRecord: Codable, Equatable {
    var position: ReadingPoint?
    var marks: [ReadingMark] = []
}

struct ReadingStore {
    let directory: URL

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Folio", isDirectory: true)) {
        self.directory = directory
    }

    private func file(_ identifier: String) throws -> URL {
        guard identifier.count == 64, identifier.allSatisfy({ $0.isHexDigit && $0.isASCII }) else {
            throw BookError.invalid("无法保存阅读数据，请重试。")
        }
        return directory.appendingPathComponent(identifier + ".json")
    }

    func load(_ identifier: String) throws -> ReadingRecord {
        let url = try file(identifier)
        guard FileManager.default.fileExists(atPath: url.path) else { return ReadingRecord() }
        return try JSONDecoder().decode(ReadingRecord.self, from: Data(contentsOf: url))
    }

    func save(_ record: ReadingRecord, for identifier: String) throws {
        let url = try file(identifier)
        let data = try JSONEncoder().encode(record)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
