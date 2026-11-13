import SwiftUI
import SwiftData

/// Ephemeral conversation with the offline recipe helper.
struct AssistantSheet: View {
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Query private var inventory: [InventoryItem]
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let assistant: any BartenderAssistant

    @State private var draft = ""
    @State private var messages: [Turn] = []
    @State private var isAnswering = false
    @State private var answerTask: Task<Void, Never>?

    init(assistant: any BartenderAssistant = LocalBartenderAssistant()) {
        self.assistant = assistant
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                conversation
                footer
            }
            .background(PourColor.background)
            .navigationTitle("Bar Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done")
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        .onDisappear {
            answerTask?.cancel()
            answerTask = nil
            messages = []
            draft = ""
        }
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if messages.isEmpty && !isAnswering {
                        emptyState
                    }
                    ForEach(messages) { turn in
                        message(turn)
                            .id(turn.id)
                    }
                    if isAnswering {
                        loadingRow
                            .id("loading")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in scrollToEnd(proxy) }
            .onChange(of: isAnswering) { _, _ in scrollToEnd(proxy) }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            EmptyStateView(
                symbol: "sparkles",
                title: "Ask your bar",
                message: "An offline recipe helper for what you can make, ingredient stand-ins, and scaled measures. It understands a fixed set of question patterns using recipes and My Bar on this device."
            )
            VStack(spacing: 8) {
                ForEach(LocalBartenderAssistant.starterQuestions, id: \.self) { question in
                    questionButton(question)
                }
            }
        }
    }

    private func message(_ turn: Turn) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(turn.text)
                    .font(.body)
                    .foregroundStyle(turn.kind == .user ? Color.black : PourColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(bubbleColor(turn.kind), in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        if turn.kind != .user {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(turn.kind == .failure ? PourColor.destructive.opacity(0.45) : PourColor.border)
                        }
                    }
                if let note = turn.sourceNote {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(PourColor.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(for: turn))
            if turn.kind == .failure, let question = turn.failedQuestion {
                Button("Try again") { retry(question) }
                    .buttonStyle(.plain)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PourColor.accent)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Try that question again")
                    .accessibilityAddTraits(.isButton)
                    .disabled(isAnswering)
            }
            if !turn.followUps.isEmpty {
                VStack(spacing: 8) {
                    ForEach(turn.followUps, id: \.self) { question in
                        questionButton(question)
                    }
                }
            }
        }
    }

    private var loadingRow: some View {
        HStack(spacing: 10) {
            if reduceMotion {
                Image(systemName: "sparkles")
                    .foregroundStyle(PourColor.accent)
                    .accessibilityHidden(true)
            } else {
                ProgressView()
                    .tint(PourColor.accent)
            }
            Text("Checking your bar…")
                .font(.subheadline)
                .foregroundStyle(PourColor.textSecondary)
        }
        .frame(minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Checking your bar")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("Questions stay on this device and clear when you close this sheet. Stock checks ingredient presence, not quantities or dietary needs.")
                .font(.caption)
                .foregroundStyle(PourColor.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask about your bar", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.body)
                    .foregroundStyle(PourColor.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(PourColor.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(PourColor.border))
                    .accessibilityLabel("Question for Bar Assistant")
                    .accessibilityHint("Ask what you can make, a substitution, or a scaled recipe. Answers stay on this device.")
                    .submitLabel(.send)
                    .onSubmit { ask(draft) }
                Button(action: { ask(draft) }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canSend ? PourColor.accent : PourColor.textTertiary)
                .disabled(!canSend)
                .accessibilityLabel("Send question")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(PourColor.background)
    }

    private var canSend: Bool {
        !isAnswering && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func questionButton(_ title: String) -> some View {
        Button {
            ask(title)
        } label: {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(PourColor.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 14)
                .background(PourColor.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(PourColor.border))
        }
        .buttonStyle(.plain)
        .disabled(isAnswering)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    private func bubbleColor(_ kind: Turn.Kind) -> Color {
        switch kind {
        case .user: return PourColor.accentFill
        case .assistant: return PourColor.card
        case .failure: return PourColor.destructive.opacity(0.14)
        }
    }

    private func accessibilityLabel(for turn: Turn) -> String {
        switch turn.kind {
        case .user:
            return "You said: \(turn.text)"
        case .assistant:
            if let note = turn.sourceNote {
                return "Assistant: \(turn.text). \(note)"
            }
            return "Assistant: \(turn.text)"
        case .failure:
            return "Could not answer. \(turn.text). Your recipes and inventory stay on this device."
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        if isAnswering {
            scroll(proxy, to: "loading")
        } else if let id = messages.last?.id {
            scroll(proxy, to: id)
        }
    }

    private func scroll<ID: Hashable>(_ proxy: ScrollViewProxy, to id: ID) {
        if reduceMotion {
            proxy.scrollTo(id, anchor: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }

    private func ask(_ raw: String) {
        let question = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isAnswering else { return }
        draft = ""
        messages.append(Turn(kind: .user, text: question))
        run(question)
    }

    private func retry(_ question: String) {
        guard !isAnswering else { return }
        run(question)
    }

    private func run(_ question: String) {
        let library = AssistantLibrary(
            recipes: recipes,
            inventory: inventory,
            preferredUnit: settings.unit
        )
        isAnswering = true
        Haptics.selection()
        answerTask?.cancel()
        answerTask = Task { @MainActor in
            defer { isAnswering = false }
            do {
                let reply = try await assistant.answer(question, in: library)
                guard !Task.isCancelled else { return }
                messages.append(Turn(
                    kind: .assistant,
                    text: reply.text,
                    followUps: reply.followUps,
                    sourceNote: reply.sourceNote
                ))
                Haptics.success()
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                messages.append(Turn(
                    kind: .failure,
                    text: "Could not answer from your bar just now. Your recipes and inventory stay on this device.",
                    failedQuestion: question
                ))
                Haptics.error()
            }
        }
    }
}

private struct Turn: Identifiable, Equatable {
    enum Kind { case user, assistant, failure }

    let id = UUID()
    var kind: Kind
    var text: String
    var followUps: [String] = []
    var sourceNote: String?
    var failedQuestion: String?
}
