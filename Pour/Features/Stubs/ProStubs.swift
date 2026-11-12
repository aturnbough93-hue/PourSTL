import SwiftUI
import SwiftData

/// Clean seams for out-of-scope Pro features. Each stub matches where the spec
/// places the entry point and shows an honest, styled placeholder.

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
                Text("Voice search is coming soon. For now, type a drink, ingredient, or brand into search on Home.")
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

struct ProUpsellView: View {
    @Environment(ProEntitlementStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    featureList
                    purchaseSection
                    statusMessages
                    legalLinks
                    Button("Not now", action: { dismiss() })
                        .buttonStyle(PourSecondaryButtonStyle())
                        .accessibilityLabel("Not now")
                        .accessibilityAddTraits(.isButton)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PourColor.background)
            .navigationTitle("Pour Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done")
                        .accessibilityAddTraits(.isButton)
                }
            }
            .task { await store.loadProducts() }
            .onChange(of: store.purchaseStatus.announcement) { _, message in
                announce(message)
            }
            .onChange(of: store.restoreStatus.announcement) { _, message in
                announce(message)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(PourColor.gold)
                .accessibilityHidden(true)
            Text("Pour Pro")
                .font(.pourTitle)
                .foregroundStyle(PourColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("A subscription is optional. Everything available today is free and works offline.")
                .font(.body)
                .foregroundStyle(PourColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(ProGate.plannedFeatures) { feature in
                Label {
                    Text(feature.text)
                } icon: {
                    Image(systemName: feature.symbol)
                        .accessibilityHidden(true)
                }
                .font(.subheadline)
                .foregroundStyle(PourColor.textSecondary)
                .accessibilityLabel(feature.text)
            }
            Text("These features are planned. Everything available today is free and works offline.")
                .font(.caption)
                .foregroundStyle(PourColor.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var purchaseSection: some View {
        VStack(spacing: 12) {
            if store.isPro {
                Label(ProStoreCopy.proActive, systemImage: "checkmark.circle.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PourColor.canMake)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityLabel(ProStoreCopy.proActive)
                Button("Manage subscription") {
                    Task { await store.manageSubscriptions() }
                }
                .buttonStyle(PourSecondaryButtonStyle())
                .accessibilityLabel("Manage subscription")
                .accessibilityAddTraits(.isButton)
            } else if store.productsState == .loaded {
                ForEach(store.offers) { offer in
                    Button {
                        Task { await store.purchase(productID: offer.id) }
                    } label: {
                        Text(offer.title)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(PourPrimaryButtonStyle())
                    .disabled(controlsDisabled)
                    .opacity(controlsDisabled ? 0.6 : 1)
                    .accessibilityLabel(offer.title)
                    .accessibilityHint("Starts an App Store subscription. Today’s features stay free.")
                    .accessibilityAddTraits(.isButton)
                }
            } else if store.productsState == .unavailable {
                Text("Subscriptions aren’t available right now. Pour still works offline. Try again when you can reach the App Store.")
                    .font(.body)
                    .foregroundStyle(PourColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Subscriptions aren’t available right now. Pour still works offline.")
                Button("Try again") {
                    Task { await store.loadProducts() }
                }
                .buttonStyle(PourPrimaryButtonStyle())
                .disabled(controlsDisabled)
                .accessibilityLabel("Try again")
                .accessibilityAddTraits(.isButton)
            } else {
                ProgressView("Loading subscriptions")
                    .tint(PourColor.accent)
                    .foregroundStyle(PourColor.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .accessibilityLabel("Loading subscriptions")
            }

            Button {
                Task { await store.restore() }
            } label: {
                if store.restoreStatus == .inProgress {
                    ProgressView()
                        .tint(PourColor.accent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text("Restore purchases")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(PourColor.accent)
            .disabled(controlsDisabled)
            .opacity(controlsDisabled ? 0.6 : 1)
            .accessibilityLabel(store.restoreStatus == .inProgress ? "Restoring purchases" : "Restore purchases")
            .accessibilityAddTraits(.isButton)
        }
    }

    @ViewBuilder
    private var statusMessages: some View {
        VStack(spacing: 8) {
            if let message = store.purchaseStatus.message {
                statusText(message, isFailure: store.purchaseStatus.isFailure)
            }
            if let message = store.restoreStatus.message {
                statusText(message, isFailure: store.restoreStatus.isFailure)
            }
            if let notice = store.notice {
                statusText(notice, isFailure: true)
            }
        }
    }

    private func statusText(_ message: String, isFailure: Bool) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(isFailure ? PourColor.destructive : PourColor.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(message)
    }

    private var legalLinks: some View {
        VStack(spacing: 8) {
            Text("Payment is processed by the App Store. A subscription renews until you cancel it there.")
                .font(.caption)
                .foregroundStyle(PourColor.textTertiary)
                .multilineTextAlignment(.center)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) {
                    privacyLink
                    termsOfUseLink
                }
                VStack(spacing: 4) {
                    privacyLink
                    termsOfUseLink
                }
            }
        }
    }

    private var privacyLink: some View {
        Link(destination: ProProductID.privacyPolicyURL) {
            Text("Privacy")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .accessibilityLabel("Privacy")
    }

    private var termsOfUseLink: some View {
        Link(destination: ProProductID.termsOfUseURL) {
            Text("Terms of Use")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .accessibilityLabel("Terms of Use")
    }

    private var controlsDisabled: Bool {
        store.purchaseStatus == .inProgress || store.restoreStatus == .inProgress
    }

    private func announce(_ message: String?) {
        guard let message else { return }
        AccessibilityNotification.Announcement(message).post()
    }
}

private struct PourSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(PourColor.accent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                PourColor.surface.opacity(configuration.isPressed ? 0.7 : 1),
                in: RoundedRectangle(cornerRadius: 14)
            )
    }
}

/// Minimal local venue check-in (no cloud): create a venue, check in, check out.
/// House specs and team features are Pro seams.
struct VenueSheet: View {
    @Query private var venues: [Venue]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var newVenueName = ""
    @State private var showSaveError = false

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
                            saveChanges()
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
                            if saveChanges() {
                                newVenueName = ""
                                Haptics.success()
                            }
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
            .alert("Venue wasn’t saved", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check available device storage and try again.")
            }
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

    @discardableResult
    private func saveChanges() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            showSaveError = true
            return false
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
        saveChanges()
    }
}
