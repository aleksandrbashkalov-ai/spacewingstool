import Foundation

public actor PersistenceService {
    public static let shared = PersistenceService()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()
    private let decoder = JSONDecoder()

    private var baseURL: URL {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            let fallback = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(Constants.appBundleID)
            try? fileManager.createDirectory(at: fallback, withIntermediateDirectories: true)
            return fallback
        }
        let dir = appSupport.appendingPathComponent(Constants.appBundleID)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {}

    public func save<T: Codable>(_ value: T, key: String) {
        do {
            let data = try encoder.encode(value)
            let url = baseURL.appendingPathComponent("\(key).json")
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            Log.error("Failed to save \(key): \(error.localizedDescription)")
        }
    }

    public func load<T: Codable>(_ type: T.Type, key: String) -> T? {
        let url = baseURL.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    public func delete(key: String) {
        let url = baseURL.appendingPathComponent("\(key).json")
        try? FileManager.default.removeItem(at: url)
    }
}
