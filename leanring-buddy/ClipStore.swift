import SwiftUI
import AppKit
import Combine

@MainActor
final class ClipStore: ObservableObject {
    @Published var clips: [Clip] = Clip.mock()
    @Published var folderURL: URL?

    private var cache: [String: CachedClip] = [:]

    func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { loadFolder(url) }
    }

    func loadFolder(_ url: URL) {
        folderURL = url
        cache = ClipCache.load(folder: url)

        let exts = ["mov", "mp4", "m4v", "mkv", "webm", "avi"]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil)) ?? []

        clips = files
            .filter { exts.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { fileURL -> Clip in
                let path = fileURL.path
                // Cache hit (and file unchanged) → reuse instantly.
                if let cached = cache[path], cached.mtime == ClipCache.mtime(of: path) {
                    return cached.clip
                }
                return Clip(path: path, durationSeconds: nil, tags: [],
                            summary: nil, fillerWordCount: 0, duplicatePhrases: [],
                            transcript: nil, indexed: false)
            }

        Task { await indexAll() }
    }

    func indexAll() async {
        for clip in clips where !clip.indexed {
            await index(clip)
        }
    }

    private func index(_ clip: Clip) async {
        let videoURL = URL(fileURLWithPath: clip.path)
        var result = clip
        do {
            let audioURL = try await IndexingService.extractAudio(from: videoURL)
            defer { try? FileManager.default.removeItem(at: audioURL) }

            let (transcript, duration) = try await IndexingService.transcribe(audioURL)
            result.durationSeconds   = duration
            result.transcript        = transcript
            result.fillerWordCount   = IndexingService.analyzeFillers(transcript)
            result.duplicatePhrases  = IndexingService.duplicatePhrases(transcript)
            let meta = await IndexingService.tagsAndSummary(transcript: transcript)
            result.tags    = meta.tags
            result.summary = meta.summary
            result.indexed = true
        } catch {
            let msg = error.localizedDescription
            let noAudio = msg.contains("does not contain any stream")
                       || msg.contains("Output file does not contain any stream")
                       || msg.contains("No audio")
            if noAudio {
                result.tags = ["b-roll", "no-audio"]
                result.summary = "No audio — likely b-roll."
            } else {
                result.summary = "⚠️ \(msg)"
            }
            result.indexed = true
        }
        apply(result)
    }

    /// Update the UI row AND persist to cache.
    private func apply(_ clip: Clip) {
        if let i = clips.firstIndex(where: { $0.id == clip.id }) {
            clips[i] = clip
        }
        cache[clip.path] = CachedClip(mtime: ClipCache.mtime(of: clip.path), clip: clip)
        if let folder = folderURL { ClipCache.save(cache, folder: folder) }
    }

    func contextForChat() -> String {
        clips.map { c in
            "\(c.filename) | \(c.durationLabel) | tags: \(c.tags.joined(separator: ", "))"
            + " | summary: \(c.summary ?? "n/a")"
            + (c.hasIssues ? " | ⚠ \(c.fillerWordCount) fillers, \(c.duplicatePhrases.count) repeats" : "")
        }.joined(separator: "\n")
    }
}

