import SwiftUI

struct FileBrowserView: View {
    @ObservedObject var store: ClipStore
    @State private var search = ""
    @State private var selected: Clip?

    var filtered: [Clip] {
        guard !search.isEmpty else { return store.clips }
        let q = search.lowercased()
        return store.clips.filter {
            $0.filename.lowercased().contains(q)
            || $0.tags.contains { $0.lowercased().contains(q) }
            || ($0.summary?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(action: store.pickFolder) {
                        Label(store.folderURL?.lastPathComponent ?? "Choose folder…",
                              systemImage: "folder")
                    }
                    Spacer()
                    Text("\(store.clips.count) clips")
                        .foregroundStyle(.secondary).font(.caption)
                }
                TextField("Search clips, tags, summaries…", text: $search)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(12)
            Divider()
            List(filtered) { clip in
                Button { selected = clip } label: {
                    ClipRow(clip: clip)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
        .frame(minWidth: 360)
        .sheet(item: $selected) { clip in
            ClipDetailView(clip: clip)
        }
    }
}

struct ClipRow: View {
    let clip: Clip

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "film")
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(clip.filename).fontWeight(.medium)
                    if !clip.indexed {
                        ProgressView().controlSize(.small)
                    }
                    if clip.hasIssues {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .help(issueText)
                    }
                    Spacer()
                    Text(clip.durationLabel)
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let s = clip.summary {
                    Text(s).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                if !clip.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(clip.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())   // makes the whole row clickable
    }

    private var issueText: String {
        var parts: [String] = []
        if clip.fillerWordCount > 5 { parts.append("\(clip.fillerWordCount) filler words") }
        if !clip.duplicatePhrases.isEmpty { parts.append("\(clip.duplicatePhrases.count) repeated phrases") }
        return parts.joined(separator: " • ")
    }
}

