import SwiftUI
import SwiftData

/// Short, skippable first-run flow: welcome → preferred units → starter bar → done.
struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query private var inventory: [InventoryItem]
    @State private var page = 0
    @State private var starterBarAdded = false

    private let starterBar: [(String, InventoryCategory)] = [
        ("London Dry Gin", .spirits),
        ("Bourbon", .spirits),
        ("Sweet Vermouth", .vermouthWine),
        ("Dry Vermouth", .vermouthWine),
        ("Campari", .liqueurs),
        ("Orange Liqueur", .liqueurs),
        ("Angostura Bitters", .bitters),
        ("Simple Syrup", .syrups),
        ("Lime Juice", .juices),
        ("Lemon Juice", .juices),
        ("Soda Water", .mixers),
        ("Mint", .produce),
    ]

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                switch page {
                case 0:
                    VStack(spacing: 16) {
                        Image(systemName: "wineglass.fill")
                            .font(.system(size: 64, weight: .regular))
                            .foregroundStyle(PourColor.accent)
                            .accessibilityHidden(true)
                        Text("Welcome to Pour")
                            .font(.pourTitle)
                            .foregroundStyle(PourColor.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("A calm, precise bartender's assistant. Recipes, inventory, scaling and shopping — fully offline.")
                            .font(.body)
                            .foregroundStyle(PourColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                case 1:
                    VStack(spacing: 16) {
                        Text("How do you measure?")
                            .font(.pourTitle2)
                            .foregroundStyle(PourColor.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("You can change this any time in Settings.")
                            .font(.subheadline)
                            .foregroundStyle(PourColor.textSecondary)
                        Picker("Preferred units", selection: $settings.unit) {
                            ForEach(UnitPreference.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Preferred units, \(settings.unit.rawValue)")
                    }
                default:
                    VStack(spacing: 16) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 48, weight: .regular))
                            .foregroundStyle(PourColor.accent)
                            .accessibilityHidden(true)
                        Text("Start with a stocked bar?")
                            .font(.pourTitle2)
                            .foregroundStyle(PourColor.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("Add 12 common bottles to My Bar so “What can I make” works right away.")
                            .font(.body)
                            .foregroundStyle(PourColor.textSecondary)
                            .multilineTextAlignment(.center)
                        Button {
                            seedStarterBar()
                        } label: {
                            Text(starterBarAdded ? "Added to My Bar" : "Add starter bar")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.black)
                                .frame(minHeight: 52)
                                .padding(.horizontal, 28)
                                .background(PourColor.accentFill, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(starterBarAdded)
                        .accessibilityLabel(starterBarAdded ? "Starter bar added" : "Add starter bar")
                        .accessibilityAddTraits(.isButton)
                    }
                }

                Spacer()

                HStack {
                    Button("Skip") { finish() }
                        .foregroundStyle(PourColor.textSecondary)
                        .accessibilityLabel("Skip")
                        .accessibilityAddTraits(.isButton)
                    Spacer()
                    Button(page < 2 ? "Next" : "Get started") {
                        if page < 2 { page += 1 } else { finish() }
                        Haptics.selection()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(minHeight: 52)
                    .padding(.horizontal, 28)
                    .background(PourColor.accentFill, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityLabel(page < 2 ? "Next" : "Get started")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .padding(24)
            .background(PourColor.background)
        }
    }

    private func seedStarterBar() {
        let existing = Set(inventory.map(\.canonicalName))
        for (name, category) in starterBar
        where !existing.contains(IngredientNormalizer.canonicalName(for: name)) {
            modelContext.insert(InventoryItem(name: name, category: category, isInStock: true))
        }
        try? modelContext.save()
        starterBarAdded = true
        Haptics.success()
    }

    private func finish() {
        settings.hasCompletedOnboarding = true
    }
}
