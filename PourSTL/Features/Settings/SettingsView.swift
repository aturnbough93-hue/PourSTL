import SwiftUI
import SwiftData

enum SiteLinks {
    static let home = URL(string: "https://barpour.pages.dev")!
    static let privacy = URL(string: "https://barpour.pages.dev/privacy")!
    static let support = URL(string: "https://barpour.pages.dev/support")!
}

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ProEntitlementStore.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showVenue = false
    @State private var showAssistant = false
    @State private var showPro = false
    @State private var showResetConfirm = false

    private var proStatus: String {
        guard pro.hasResolvedEntitlements else { return "Checking" }
        return pro.isPro ? "Active" : "Upgrade"
    }

    private var proAccessibilityLabel: String {
        guard pro.hasResolvedEntitlements else { return "PourSTL Pro, checking subscription" }
        return pro.isPro ? "PourSTL Pro, active" : "PourSTL Pro upgrade"
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func siteLink(_ title: String, systemImage: String, url: URL) -> some View {
        Link(destination: url) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(PourColor.textPrimary)
        }
        .accessibilityLabel(title)
        .accessibilityHint("Opens \(url.host() ?? "the website") in your browser")
        .accessibilityIdentifier(url.absoluteString)
    }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Appearance") {
                    AdaptiveSegmentedPicker(
                        title: "Appearance",
                        selection: $settings.appearance,
                        options: AppAppearance.allCases,
                        optionTitle: { $0.displayName }
                    )
                }

                Section("Measurement") {
                    AdaptiveSegmentedPicker(
                        title: "Preferred units",
                        selection: $settings.unit,
                        options: UnitPreference.allCases,
                        optionTitle: { $0.rawValue }
                    )
                }

                Section("Assistant") {
                    Button {
                        showAssistant = true
                    } label: {
                        Label("Bar Assistant", systemImage: "sparkles")
                            .foregroundStyle(PourColor.textPrimary)
                    }
                    .accessibilityLabel("Bar Assistant")
                    .accessibilityHint("Offline recipe helper using recipes and My Bar on this device")
                    .accessibilityAddTraits(.isButton)
                }

                Section("Pro") {
                    Button {
                        showVenue = true
                    } label: {
                        Label("Venue check-in", systemImage: "mappin.and.ellipse")
                            .foregroundStyle(PourColor.textPrimary)
                    }
                    .accessibilityLabel("Check in to venue")
                    .accessibilityAddTraits(.isButton)
                    Button {
                        showPro = true
                    } label: {
                        HStack {
                            Label("PourSTL Pro", systemImage: "crown")
                                .foregroundStyle(PourColor.gold)
                            Spacer()
                            Text(proStatus)
                                .font(.subheadline)
                                .foregroundStyle(pro.isPro ? PourColor.canMake : PourColor.textSecondary)
                        }
                    }
                    .accessibilityLabel(proAccessibilityLabel)
                    .accessibilityAddTraits(.isButton)
                }

                Section("Support") {
                    siteLink("Get support", systemImage: "questionmark.bubble", url: SiteLinks.support)
                    siteLink("Privacy policy", systemImage: "hand.raised", url: SiteLinks.privacy)
                    siteLink("PourSTL website", systemImage: "safari", url: SiteLinks.home)
                    Button {
                        showResetConfirm = true
                    } label: {
                        Label("Replay onboarding", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(PourColor.textPrimary)
                    }
                    .accessibilityLabel("Replay onboarding")
                    .accessibilityAddTraits(.isButton)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion).foregroundStyle(PourColor.textSecondary)
                    }
                    .accessibilityLabel("Version \(appVersion)")
                    Text("Your recipes and bar inventory are stored on this device. PourSTL works offline. Sharing a recipe or contacting support sends only what you choose to share.")
                        .font(.caption)
                        .foregroundStyle(PourColor.textTertiary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PourColor.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done")
                        .accessibilityAddTraits(.isButton)
                }
            }
            .sheet(isPresented: $showVenue) { VenueSheet() }
            .sheet(isPresented: $showAssistant) { AssistantSheet() }
            .sheet(isPresented: $showPro) { ProUpsellView() }
            .confirmationDialog("Replay onboarding on next launch?", isPresented: $showResetConfirm) {
                Button("Replay onboarding") {
                    settings.hasCompletedOnboarding = false
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .preferredColorScheme(settings.appearance.colorScheme)
    }
}
