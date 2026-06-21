import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String   // "user" or "assistant"
    var text: String
}

struct ChatView: View {
    @ObservedObject var store: ClipStore
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var sending = false

    private let chatURL = URL(string: "https://clicky-proxy.emjesscleo.workers.dev/chat")!
    private let model = "claude-sonnet-4-6"

    private let suggestions = [
        "Which clips have the most filler words?",
        "Find my b-roll clips",
        "Which clips have repeated phrases?",
        "Give me a quick overview of all my clips"
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    if messages.isEmpty {
                        emptyChat
                    } else {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(messages) { m in bubble(m).id(m.id) }
                            if sending {
                                HStack { ProgressView().controlSize(.small); Spacer() }
                                    .padding(.horizontal, 12)
                            }
                        }
                        .padding(12)
                    }
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id) }
                    }
                }
            }
            Divider()
            HStack {
                TextField("Ask about your clips…", text: $input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { sendText(input) }
                Button { sendText(input) } label: { Image(systemName: "paperplane.fill") }
                    .disabled(sending || input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
        }
        .frame(minWidth: 360)
    }

    private var emptyChat: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("💬 Ask chris about your footage")
                    .font(.headline)
                Text("Try one of these:")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(suggestions, id: \.self) { s in
                Button { sendText(s) } label: {
                    HStack {
                        Text(s).multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .disabled(store.clips.isEmpty)
            }
            if store.clips.isEmpty {
                Text("Choose a folder first to start chatting.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func bubble(_ m: ChatMessage) -> some View {
        HStack {
            if m.role == "user" { Spacer() }
            Text(m.text)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(m.role == "user" ? Color.accentColor.opacity(0.2)
                                                : Color.gray.opacity(0.15))
                )
            if m.role == "assistant" { Spacer() }
        }
    }

    private func sendText(_ raw: String) {
        let q = raw.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !sending else { return }
        messages.append(.init(role: "user", text: q))
        input = ""
        sending = true

        let history = messages.map { ["role": $0.role, "content": $0.text] }
        let systemPrompt = """
        You are an assistant for a video creator. You help them find and reason about \
        their video clips. Here is the current clip index (filename | duration | tags | \
        summary | issues):

        \(store.contextForChat())

        Answer concisely. If asked to find clips, reference them by filename.
        """

        Task {
            let reply = await callClaude(system: systemPrompt, history: history)
            await MainActor.run {
                messages.append(.init(role: "assistant", text: reply))
                sending = false
            }
        }
    }

    private func callClaude(system: String,
                            history: [[String: String]]) async -> String {
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": system,
            "messages": history
        ]
        do {
            var req = URLRequest(url: chatURL)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, _) = try await URLSession.shared.data(for: req)
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let content = json["content"] as? [[String: Any]],
                let text = content.first?["text"] as? String
            else {
                let raw = String(data: data, encoding: .utf8) ?? "no response"
                return "⚠️ Unexpected response:\n\(raw)"
            }
            return text
        } catch {
            return "⚠️ Network error: \(error.localizedDescription)"
        }
    }
}

