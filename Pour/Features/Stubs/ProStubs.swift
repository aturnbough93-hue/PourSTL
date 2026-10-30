import SwiftUI
import SwiftData

/// Clean seams for out-of-scope Pro features. Each stub matches where the spec
/// places the entry point and shows an honest, styled placeholder.

struct AssistantPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(PourColor.accent)
                    .accessibilityHidden(true)
                Text("AI Bartender Assistant")
                    .font(.pourTitle2)
                    .foregroundStyle(PourColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Ask what you can make, get ranked substitutions, and refine drinks conversationally. A Pour Pro feature — the conversational surface and hooks live here.")
                    .font(.body)
                    .foregroundStyle(PourColor.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Not now") { dismiss() }
                    .buttonStyle(PourPrimaryButtonStyle())
                    .padding(.top, 12)
                    .accessibilityLabel("Not now")
                    .accessibilityAddTraits(.isButton)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PourColor.background)
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct VoiceSearchPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "mic")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(PourColor.accent)
                    .accessibilityHidden(true)
                Text("Voice search")
                    .font(.pourTitle2)
                    .foregroundStyle(PourColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("On-device speech recognition (SFSpeechRecognizer) fills the search field with what you say. Permission prompts and the listening state are staged for a follow-up build.")
                    .font(.body)
                    .foregroundStyle(PourColor.textSecondary)
                    .multilineTextAlignment(.center)
                Button("OK") { dismiss() }
                    .buttonStyle(PourPrimaryButtonStyle())
                    .padding(.top, 12)
                    .accessibilityLabel("OK")
                    .accessibilityAddTraits(.isButton)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PourColor.background)
            .navigationTitle("Voice Search")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct BarcodeScannerPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(PourColor.accent)
                    .accessibilityHidden(true)
                Text("Barcode scanning")
                    .font(.pourTitle2)
                    .foregroundStyle(PourColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Scan a bottle to add it to My Bar instantly. Camera permission handling and the viewfinder ship in a follow-up build.")
                    .font(.body)
                    .foregroundStyle(PourColor.textSecondary)
                    .multilineTextAlignment(.center)
                Button("OK") { dismiss() }
                    .buttonStyle(PourPrimaryButtonStyle())
                    .padding(.top, 12)
                    .accessibilityLabel("OK")
                    .accessibilityAddTraits(.isButton)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PourColor.background)
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ProUpsellView: View {
    @Environment(\.dismiss) private var dismiss

    private let features: [(String, String)] = [
        ("sparkles", "AI Bartender Assistant — substitutions and suggestions"),
        ("video", "AI video generation for technique demos"),
        ("square.stack.3d.up", "Bottle-level tracking, costing and export"),
        ("person.2", "Shared inventory and venue teams"),
        ("icloud", "CloudKit sync across devices"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "crown")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(PourColor.gold)
                    .accessibilityHidden(true)
                Text("Pour Pro")
                    .font(.pourTitle)
                    .foregroundStyle(PourColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(features, id: \.0) { symbol, text in
                        Label(text, systemImage: symbol)
                            .font(.subheadline)
                            .foregroundStyle(PourColor.textSecondary)
                    }
                }
                Text("Subscriptions land with StoreKit 2 in a follow-up build. Everything you can use today is free and fully offline.")
                    .font(.caption)
                    .foregroundStyle(PourColor.textTertiary)
                    .multilineTextAlignment(.center)
                Button("Maybe later") { dismiss() }
                    .buttonStyle(PourPrimaryButtonStyle())
                    .accessibilityLabel("Maybe later")
                    .accessibilityAddTraits(.isButton)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PourColor.background)
            .navigationTitle("Pour Pro")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Minimal local venue check-in (no cloud): create a venue, check in, check out.
/// House specs and team features are Pro seams.
struct VenueSheet: View {
    @Query private var venues: [Venue]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var newVenueName = ""

    private var checkedIn: Venue? { venues.first { $0.isCheckedIn } }

    var body: some View {
        NavigationStack {
            List {
                if venues.isEmpty {
                    Section {
                        Text("No venues yet. Add your workplace to check in and surface its menu during a shift.")
                            .font(.subheadline)
                            .foregroundStyle(PourColor.textSecondary)
                            .listRowBackground(PourColor.card)
                    }
                } else {
                    Section("Venues") {
                        ForEach(venues) { venue in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(venue.name)
                                        .font(.body)
                                        .foregroundStyle(PourColor.textPrimary)
                                    if venue.isCheckedIn {
                                        Text("Checked in")
                                            .font(.caption)
                                            .foregroundStyle(PourColor.canMake)
                                    }
                                }
                                Spacer()
                                Button(venue.isCheckedIn ? "Check out" : "Check in") {
                                    toggleCheckIn(venue)
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PourColor.accent)
                                .accessibilityLabel(venue.isCheckedIn ? "Check out of \(venue.name)" : "Check in to \(venue.name)")
                                .accessibilityAddTraits(.isButton)
                            }
                            .frame(minHeight: 52)
                            .listRowBackground(PourColor.card)
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.delete(venues[index]) }
                            try? modelContext.save()
                        }
                    }
                }
                Section("Add a venue") {
                    HStack(spacing: 10) {
                        TextField("Venue name", text: $newVenueName)
                            .accessibilityLabel("Venue name")
                        Button("Add") {
                            let trimmed = newVenueName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            modelContext.insert(Venue(name: trimmed))
                            try? modelContext.save()
                            newVenueName = ""
                            Haptics.success()
                        }
                        .disabled(IngredientNormalizer.normalize(newVenueName).isEmpty)
                        .foregroundStyle(PourColor.accent)
                        .accessibilityLabel("Add venue")
                        .accessibilityAddTraits(.isButton)
                    }
                    .listRowBackground(PourColor.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PourColor.background)
            .navigationTitle("Venue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done")
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    private func toggleCheckIn(_ venue: Venue) {
        if venue.isCheckedIn {
            venue.isCheckedIn = false
            Haptics.lightTick()
        } else {
            for other in venues { other.isCheckedIn = false }
            venue.isCheckedIn = true
            Haptics.success()
        }
        try? modelContext.save()
    }
}
