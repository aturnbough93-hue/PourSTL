import SwiftUI

/// Cocktail timer with a large circular progress ring and calibrated haptics
/// at the 10s, 5s and completion milestones. Respects Reduce Motion.
struct TimerSheet: View {
    var recipeName: String? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedSeconds: TimeInterval = 30
    @State private var endsAt: Date? = nil
    @State private var lastWholeSecond: Int? = nil
    @State private var didComplete = false

    private let presets: [TimeInterval] = [15, 30, 45, 60, 90, 120]

    private var isRunning: Bool { endsAt != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                presetChips
                ring
                controls
                Spacer()
            }
            .padding()
            .background(PourColor.background)
            .navigationTitle(recipeName ?? "Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done")
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    private var presetChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { seconds in
                    let selected = selectedSeconds == seconds && !isRunning
                    Button {
                        selectedSeconds = seconds
                        didComplete = false
                        Haptics.selection()
                    } label: {
                        Text(formatPreset(seconds))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selected ? .black : PourColor.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .frame(minHeight: 44)
                            .background(selected ? PourColor.accentFill : PourColor.surface, in: Capsule())
                    }
                    .disabled(isRunning)
                    .accessibilityLabel("\(formatPreset(seconds)) timer\(selected ? ", selected" : "")")
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .frame(minHeight: 40)
    }

    private var ring: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { context in
            let remaining = remaining(at: context.date)
            let progress = didComplete ? 0 : (isRunning ? remaining / selectedSeconds : 1)
            ZStack {
                Circle()
                    .stroke(PourColor.surface, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(
                        PourColor.accent,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 0.05), value: progress)
                VStack(spacing: 4) {
                    Text(formatRemaining(remaining))
                        .font(.system(size: 52, weight: .semibold).monospacedDigit())
                        .foregroundStyle(PourColor.textPrimary)
                        .accessibilityAddTraits(.updatesFrequently)
                    Text(didComplete ? "Complete" : (isRunning ? "remaining" : "ready"))
                        .font(.subheadline)
                        .foregroundStyle(PourColor.textTertiary)
                }
            }
            .onChange(of: Int(remaining.rounded(.up))) { _, whole in
                fireHaptics(at: whole)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(didComplete ? "Timer complete" : "Timer, \(formatRemaining(remaining)) remaining")
        }
        .frame(width: 260, height: 260)
        .padding(.top, 8)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            if isRunning {
                Button {
                    endsAt = nil
                    lastWholeSecond = nil
                    Haptics.warning()
                } label: {
                    Text("Stop")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(PourColor.destructive)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(PourColor.destructive.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityLabel("Stop timer")
                .accessibilityAddTraits(.isButton)
            } else {
                Button {
                    endsAt = Date().addingTimeInterval(selectedSeconds)
                    lastWholeSecond = Int(selectedSeconds)
                    didComplete = false
                    Haptics.mediumTap()
                } label: {
                    Text("Start")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(PourColor.accentFill, in: RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityLabel("Start timer")
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    private func remaining(at date: Date) -> TimeInterval {
        guard let endsAt else { return didComplete ? 0 : selectedSeconds }
        return max(0, endsAt.timeIntervalSince(date))
    }

    /// Milestone haptics: medium tap at 10s, light ticks at 5s and below, success on completion.
    private func fireHaptics(at wholeSeconds: Int) {
        guard isRunning else { return }
        defer { lastWholeSecond = wholeSeconds }
        guard lastWholeSecond != wholeSeconds else { return }

        if wholeSeconds == 10 {
            Haptics.mediumTap()
        } else if wholeSeconds <= 5 && wholeSeconds > 0 {
            Haptics.lightTick()
        } else if wholeSeconds <= 0 {
            if !didComplete {
                didComplete = true
                Haptics.success()
            }
            endsAt = nil
        }
    }

    private func formatPreset(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        if total < 60 { return "\(total)s" }
        let remainder = total % 60
        return remainder == 0 ? "\(total / 60)m" : "\(total / 60)m \(remainder)s"
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
