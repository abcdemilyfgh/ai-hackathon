import Foundation

struct CachedClip: Codable {
    let mtime: Double      // file modification time, to detect changes
    let clip: Clip
}

enum ClipCache {
    private static var dir: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipAssistant", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func fileURL(for folder: URL) -> URL {
        return dir.appendingPathComponent("cache-\(stableKey(folder.path)).json")
    }

    // Deterministic FNV-1a hash (stable across launches, unlike String.hashValue).
    private static func stableKey(_ s: String) -> String {
        var h: UInt64 = 1469598103934665603
        for b in s.utf8 {
            h = (h ^ UInt64(b)) &* 1099511628211
        }
        return String(h, radix: 16)
    }

    static func load(folder: URL) -> [String: CachedClip] {
        guard let data = try? Data(contentsOf: fileURL(for: folder)),
              let dict = try? JSONDecoder().decode([String: CachedClip].self, from: data)
        else { return [:] }
        return dict
    }

    static func save(_ dict: [String: CachedClip], folder: URL) {
        if let data = try? JSONEncoder().encode(dict) {
            try? data.write(to: fileURL(for: folder))
        }
    }

    static func mtime(of path: String) -> Double {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
    }
}

