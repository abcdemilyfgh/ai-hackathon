import SwiftUI

struct FileBrowserView: View {
    @ObservedObject var store: ClipStore
    @State private var search = ""
    @State private var selected: Clip?
    @State private var flaggedOnly = false
    @State private var sort: SortOrder = .name

    enum SortOrder: String, CaseIterable, Identifiable {
        case name = "Name", duration = "Duration", issues = "Issues"
        var id: String { rawValue }
    }

    var filtered: [Clip] {
        var list = store.clips

        if !search.isEmpty {
            let q = search.lowercased()
            list = list.filter {
                $0.filename.lowercased().contains(q)
                || $0.tags.contains { $0.lowercased().contains(q) }
                || ($0.summary?.lowercased().contains(q) ?? false)
            }
        }
        if flaggedOnly { list = list.filter { $0.hasIssues } }

        switch sort {
        case .name:
            list.sort { $0.filename < $1.filename }
        case .duration:
            list.sort { ($0.durationSeconds ?? 0) > ($1.durationSeconds ?? 0) }
        case .issues:
            list.sort {
                ($0.fillerWordCount + $0.duplicatePhrases.count)
                    > ($1.fillerWordCount + $1.duplicatePhrases.count)
            }
        }
        return list
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
                    if !store.clips.isEmpty {
                        Text("\(filtered.count) of \(store.clips.count)")
                            .foregroundStyle(.secondary).font(.caption)
                    }
                }

                if store.folderURL != nil {
                    TextField("Search clips, tags, summaries…", text: $search)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Toggle("Flagged only", isOn: $flaggedOnly)
                            .toggleStyle(.checkbox)
                            .font(.caption)
                        Spacer()
                        Picker("Sort", selection: $sort) {
                            ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                        .font(.caption)
                    }
                }

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
                .font(.system(size: 48)).foregroundStyle(.secondary)
            Text("No folder selected").font(.headline)
            Text("Choose a folder of clips and Snappy will\ntranscribe, tag, and flag them automatically.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: store.pickFolder) {
                Label("Choose folder…", systemImage: "folder")
            }
            .controlSize(.large).padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity).padding()
    }
}

struct ClipRow: View {
    let clip: Clip

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "film")
                .foregroundStyle(.secondary).padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(clip.filename).fontWeight(.medium)
                    if !clip.indexed { ProgressView().controlSize(.small) }
                    if clip.hasIssues {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).help(issueText)
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
                            Text(tag).font(.caption2)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4).contentShape(Rectangle())
    }

    private var issueText: String {
        var parts: [String] = []
        if clip.fillerWordCount > 5 { parts.append("\(clip.fillerWordCount) filler words") }
        if !clip.duplicatePhrases.isEmpty { parts.append("\(clip.duplicatePhrases.count) repeated phrases") }
        return parts.joined(separator: " • ")
    }
}

