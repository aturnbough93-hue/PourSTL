import SwiftUI
import SwiftData

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
        guard pro.hasResolvedEntitlements else { return "Pour Pro, checking subscription" }
        return pro.isPro ? "Pour Pro, active" : "Pour Pro upgrade"
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Appearance, \(settings.appearance.displayName)")
                }

                Section("Measurement") {
                    Picker("Preferred units", selection: $settings.unit) {
                        ForEach(UnitPreference.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Preferred units, \(settings.unit.rawValue)")
                }

                Section("Pro") {
                    Button {
                        showAssistant = true
                    } label: {
                        Label("AI Bartender Assistant", systemImage: "sparkles")
                            .foregroundStyle(PourColor.textPrimary)
                    }
                    .accessibilityLabel("AI Bartender Assistant")
                    .accessibilityAddTraits(.isButton)
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
                            Label("Pour Pro", systemImage: "crown")
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
                    Link(destination: URL(string: "https://github.com/aturnbough93-hue/pour/issues")!) {
                        Label("Send feedback", systemImage: "bubble.left")
                            .foregroundStyle(PourColor.textPrimary)
                    }
                    .accessibilityLabel("Send feedback")
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
                    Text("Your recipes and bar inventory are stored on this device. Pour works offline. Sharing a recipe or opening feedback sends only what you choose to share.")
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
            .sheet(isPresented: $showAssistant) { AssistantPlaceholderView() }
            .sheet(isPresented: $showPro) { ProUpsellView() }
            .confirmationDialog("Replay onboarding on next launch?", isPresented: $showResetConfirm) {
                Button("Replay onboarding") {
                    settings.hasCompletedOnboarding = false
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
