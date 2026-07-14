import SwiftUI

/// Conversational plan pivoting: "more chest", "train 5 days", "my knee hurts",
/// "make it easier" — or free-form coaching with an API key configured.
struct CoachChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var input = ""
    @State private var sending = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if appState.chat.isEmpty { welcome }
                            ForEach(appState.chat) { msg in
                                bubble(msg)
                            }
                            if sending {
                                HStack { ProgressView(); Text("Coach is thinking…").font(.footnote).foregroundStyle(.secondary) }
                                    .id("thinking")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: appState.chat.count) { _, _ in
                        if let last = appState.chat.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                HStack(spacing: 8) {
                    TextField("Ask or adjust: “more arms”, “only 45 min”…", text: $input, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                    Button {
                        send()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.title)
                    }
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || sending)
                }
                .padding()
                .background(.thinMaterial)
            }
            .navigationTitle("Coach")
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("👋 I'm your coach. I built your plan and I can change it on the spot:")
            Text("""
            • “Give me more chest volume”
            • “I can only train 3 days now”
            • “Sessions need to be 45 minutes”
            • “My shoulder hurts”
            • “Make it harder” / “I need a deload”
            • “Switch my goal to fat loss”
            """)
            .font(.footnote)
            Text("Every change rebuilds your mesocycle and recalculates nutrition — nothing drifts out of sync.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func bubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.role == "user" { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                Text(msg.text)
                if msg.planChanged {
                    Label("Plan updated", systemImage: "checkmark.seal.fill")
                        .font(.caption2).foregroundStyle(.green)
                }
            }
            .padding(10)
            .background(msg.role == "user" ? Color.accentColor.opacity(0.9) : Color(.secondarySystemBackground))
            .foregroundStyle(msg.role == "user" ? Color.white : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            if msg.role == "coach" { Spacer(minLength: 40) }
        }
        .id(msg.id)
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        sending = true
        Task {
            await appState.sendToCoach(text)
            sending = false
        }
    }
}
