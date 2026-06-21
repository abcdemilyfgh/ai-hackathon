import Foundation
import AVFoundation

@MainActor
enum IndexingService {
    static let transcribeURL = "https://clicky-proxy.emjesscleo.workers.dev/transcribe?model=nova-2&smart_format=true&punctuate=true&filler_words=true"
    static let chatURL = URL(string: "https://clicky-proxy.emjesscleo.workers.dev/chat")!
    static let model = "claude-sonnet-4-6"

    // MARK: Audio extraction via ffmpeg (video → temp .m4a Deepgram can read)
    static func extractAudio(from videoURL: URL) async throws -> URL {
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        process.arguments = [
            "-i", videoURL.path,
            "-vn",            // drop video
            "-ac", "1",       // mono
            "-ar", "16000",   // 16 kHz (plenty for speech, smaller upload)
            "-c:a", "aac",
            "-y",             // overwrite
            outURL.path
        ]
        // Capture stderr so we can surface ffmpeg errors if it fails.
        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: outURL.path) else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: errData, encoding: .utf8) ?? "unknown ffmpeg error"
            throw NSError(domain: "Indexing", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "ffmpeg failed: \(msg)"])
        }
        return outURL
    }


    // MARK: Deepgram transcription
    static func transcribe(_ audioURL: URL) async throws -> (transcript: String, duration: Double) {
        let data = try Data(contentsOf: audioURL)
        var req = URLRequest(url: URL(string: transcribeURL)!)
        req.httpMethod = "POST"
        req.setValue("audio/mp4", forHTTPHeaderField: "content-type")
        req.httpBody = data

        let (respData, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any]
        else { throw NSError(domain: "Indexing", code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Bad Deepgram response"]) }

        let results = json["results"] as? [String: Any]
        let channels = results?["channels"] as? [[String: Any]]
        let alts = channels?.first?["alternatives"] as? [[String: Any]]
        let transcript = (alts?.first?["transcript"] as? String) ?? ""

        let meta = json["metadata"] as? [String: Any]
        let duration = (meta?["duration"] as? Double) ?? 0

        return (transcript, duration)
    }

    // MARK: Local analysis — filler words
    static func analyzeFillers(_ transcript: String) -> Int {
        let fillers = ["um", "uh", "er", "ah", "hmm", "like", "you know", "i mean"]
        let lower = " " + transcript.lowercased() + " "
        var count = 0
        for f in fillers {
            count += lower.components(separatedBy: " \(f) ").count - 1
        }
        return count
    }

    // MARK: Local analysis — repeated phrases (4-word sequences appearing >1x)
    static func duplicatePhrases(_ transcript: String) -> [String] {
        let words = transcript.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard words.count >= 4 else { return [] }
        var counts: [String: Int] = [:]
        for i in 0...(words.count - 4) {
            let phrase = words[i..<(i+4)].joined(separator: " ")
            counts[phrase, default: 0] += 1
        }
        return counts.filter { $0.value > 1 }.map { $0.key }
    }

    // MARK: Claude — tags + summary from transcript
    static func tagsAndSummary(transcript: String) async -> (tags: [String], summary: String) {
        if transcript.trimmingCharacters(in: .whitespaces).isEmpty {
            return ([], "No speech detected.")
        }
        let system = """
        You tag video clips for a creator. Given a transcript, respond with ONLY a JSON \
        object: {"tags": ["t1","t2","t3"], "summary": "one sentence"}. \
        3-5 short lowercase tags. No prose, no code fences.
        """
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "system": system,
            "messages": [["role": "user", "content": "Transcript:\n\(transcript)"]]
        ]
        do {
            var req = URLRequest(url: chatURL)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let content = json?["content"] as? [[String: Any]]
            var text = (content?.first?["text"] as? String) ?? "{}"

            // Extract the JSON object even if Claude added stray text.
            if let s = text.firstIndex(of: "{"), let e = text.lastIndex(of: "}") {
                text = String(text[s...e])
            }
            let parsed = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
            let tags = (parsed?["tags"] as? [String]) ?? []
            let summary = (parsed?["summary"] as? String) ?? ""
            return (tags, summary)
        } catch {
            return ([], "⚠️ tagging failed")
        }
    }
}

