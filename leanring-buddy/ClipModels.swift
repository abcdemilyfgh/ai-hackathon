import Foundation

struct Clip: Identifiable, Codable {
    var id: String { path }
    let path: String
    var filename: String { (path as NSString).lastPathComponent }
    var durationSeconds: Double?
    var tags: [String]
    var summary: String?
    var fillerWordCount: Int
    var duplicatePhrases: [String]
    var transcript: String?
    var indexed: Bool

    var hasIssues: Bool { fillerWordCount > 5 || !duplicatePhrases.isEmpty }
    var durationLabel: String {
        guard let d = durationSeconds else { return "—" }
        let m = Int(d) / 60, s = Int(d) % 60
        return String(format: "%d:%02d", m, s)
    }

    static func mock() -> [Clip] {
        [
            Clip(path: "/Users/you/clips/clip_01.mov", durationSeconds: 92,
                 tags: ["intro", "monte-carlo"],
                 summary: "Opening segment introducing the book and Monte Carlo concepts.",
                 fillerWordCount: 9, duplicatePhrases: ["so basically what happens is"],
                 transcript: nil, indexed: true),
            Clip(path: "/Users/you/clips/clip_02.mov", durationSeconds: 47,
                 tags: ["b-roll"],
                 summary: "City street b-roll, no dialogue.",
                 fillerWordCount: 0, duplicatePhrases: [],
                 transcript: nil, indexed: true),
            Clip(path: "/Users/you/clips/clip_14.mov", durationSeconds: 168,
                 tags: [],
                 summary: nil, fillerWordCount: 0, duplicatePhrases: [],
                 transcript: nil, indexed: false)
        ]
    }
}

