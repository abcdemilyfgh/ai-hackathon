import SwiftUI

struct ClipDetailView: View {
    let clip: Clip
    @Environment(\.dismiss) private var dismiss

    private let fillerWords = ["um", "uh", "er", "ah", "hmm", "like", "you know", "i mean"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(clip.filename).font(.headline)
                    Text(clip.durationLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let s = clip.summary, !s.isEmpty {
                        section("Summary") { Text(s) }
                    }

                    if !clip.tags.isEmpty {
                        section("Tags") { FlowTags(tags: clip.tags) }
                    }

                    if clip.hasIssues {
                        section("⚠️ Flags") {
                            VStack(alignment: .leading, spacing: 6) {
                                if clip.fillerWordCount > 5 {
                                    Label("\(clip.fillerWordCount) filler words",
                                          systemImage: "waveform").foregroundStyle(.orange)
                                }
                                if !clip.duplicatePhrases.isEmpty {
                                    Label("\(clip.duplicatePhrases.count) repeated phrases",
                                          systemImage: "repeat").foregroundStyle(.orange)
                                }
                            }
                        }
                    }

                    section("Transcript") {
                        if let t = clip.transcript, !t.isEmpty {
                            Text(highlighted(t))
                                .font(.callout)
                                .textSelection(.enabled)
                            // Legend
                            HStack(spacing: 14) {
                                legend("repeated phrase", .orange)
                                legend("filler word", .yellow)
                            }
                            .padding(.top, 6)
                        } else {
                            Text("No transcript (no speech detected).")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 520, height: 560)
    }

    // Build a transcript with repeated phrases + filler words highlighted.
    private func highlighted(_ text: String) -> AttributedString {
        var attr = AttributedString(text)
        let ns = text as NSString

        // Highlight by regex so phrases match across punctuation/whitespace/case.
        func markRegex(_ pattern: String, _ color: Color) {
            guard let re = try? NSRegularExpression(pattern: pattern,
                                                    options: [.caseInsensitive]) else { return }
            let matches = re.matches(in: text,
                                     range: NSRange(location: 0, length: ns.length))
            for m in matches {
                if let sr = Range(m.range, in: text),
                   let lo = AttributedString.Index(sr.lowerBound, within: attr),
                   let hi = AttributedString.Index(sr.upperBound, within: attr) {
                    attr[lo..<hi].backgroundColor = color.opacity(0.35)
                }
            }
        }

        // Repeated phrases: allow non-word chars between words (commas, etc.)
        for phrase in clip.duplicatePhrases {
            let words = phrase.split(separator: " ").map {
                NSRegularExpression.escapedPattern(for: String($0))
            }
            guard !words.isEmpty else { continue }
            markRegex(words.joined(separator: "\\W+"), .orange)
        }

        // Filler words: whole-word match.
        for f in fillerWords {
            markRegex("\\b" + NSRegularExpression.escapedPattern(for: f) + "\\b", .yellow)
        }

        return attr
    }

    @ViewBuilder private func legend(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.35))
                .frame(width: 14, height: 14)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func section<Content: View>(
        _ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

struct FlowTags: View {
    let tags: [String]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 6)],
                  alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag).font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            }
        }
    }
}

