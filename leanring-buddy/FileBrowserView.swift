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
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(action: store.pickFolder) {
                        Label(store.folderURL?.lastPathComponent ?? "Choose folder…",
                              systemImage: "folder")
                    }
                    Spacer()
                    if !store.clips.isEmpty {
                        Text("\(store.clips.count) clips")
                            .foregroundStyle(.secondary).font(.caption)
                    }
                }
                if store.folderURL != nil {
                    TextField("Search clips, tags, summaries…", text: $search)
                        .textFieldStyle(.roundedBorder)
                }
                // Progress bar while indexing
                if store.isIndexing {
                    VStack(alignment: .leading, spacing: 3) {
                        ProgressView(value: Double(store.indexProgress),
                                     total: Double(max(store.indexTotal, 1)))
                        Text("Indexing \(store.indexProgress) / \(store.indexTotal)…")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            Divider()

            // Body: empty state OR list
            if store.folderURL == nil {
                emptyState
            } else {
                List(filtered) { clip in
                    Button { selected = clip } label: { ClipRow(clip: clip) }
                        .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 360)
        .sheet(item: $selected) { clip in ClipDetailView(clip: clip) }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No folder selected")
                .font(.headline)
            Text("Choose a folder of clips and chris will\ntranscribe, tag, and flag them automatically.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: store.pickFolder) {
                Label("Choose folder…", systemImage: "folder")
            }
            .controlSize(.large)
            .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
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
        .contentShape(Rectangle())
    }

    private var issueText: String {
        var parts: [String] = []
        if clip.fillerWordCount > 5 { parts.append("\(clip.fillerWordCount) filler words") }
        if !clip.duplicatePhrases.isEmpty { parts.append("\(clip.duplicatePhrases.count) repeated phrases") }
        return parts.joined(separator: " • ")
    }
}

