import SwiftUI

// MARK: - Palette

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

enum PourColor {
    private static func adaptive(dark: UInt32, light: UInt32, darkAlpha: CGFloat = 1, lightAlpha: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }

    static let background = adaptive(dark: 0x0A0A0C, light: 0xF4F4F6)
    static let elevated = adaptive(dark: 0x121214, light: 0xFFFFFF)
    static let card = adaptive(dark: 0x1A1A1D, light: 0xFFFFFF)
    static let surface = adaptive(dark: 0x222226, light: 0xEAEAEC)
    static let border = adaptive(dark: 0xFFFFFF, light: 0x000000, darkAlpha: 0.10, lightAlpha: 0.08)

    /// Warm copper — primary accent.
    static let accent = adaptive(dark: 0xE8A87C, light: 0xA8602C)
    /// Copper for fills (paired with dark text).
    static let accentFill = adaptive(dark: 0xE8A87C, light: 0xD98A5A)
    /// Soft gold, used sparingly.
    static let gold = adaptive(dark: 0xD4AF37, light: 0x9A7A1F)

    static let textPrimary = adaptive(dark: 0xF7F7F8, light: 0x1A1A1D)
    static let textSecondary = adaptive(dark: 0xAEAEB2, light: 0x54545A)
    static let textTertiary = adaptive(dark: 0x8E8E93, light: 0x77777D)

    static let canMake = adaptive(dark: 0x32D74B, light: 0x21853A)
    static let almost = adaptive(dark: 0xFF9F0A, light: 0xB2500A)
    static let destructive = adaptive(dark: 0xFF453A, light: 0xD70015)
}

// MARK: - Typography

extension Font {
    static let pourLargeTitle = Font.system(size: 34, weight: .bold)
    static let pourTitle = Font.system(size: 28, weight: .semibold)
    static let pourTitle2 = Font.system(size: 22, weight: .semibold)
    /// Ingredient measures: medium weight, tabular figures, right-aligned by callers.
    static let pourMeasure = Font.system(size: 17, weight: .medium).monospacedDigit()
}

// MARK: - Glass → SF Symbol mapping (per spec)

enum GlassIcon {
    /// Coupe, Martini, Nick & Nora, Wine, Flute → wineglass; Rocks, Old Fashioned,
    /// Highball, Collins, Pint, mugs → mug; Shot, Cordial → flask; Irish Coffee → cup.
    static func symbol(for glassType: String) -> String {
        switch IngredientNormalizer.normalize(glassType) {
        case "coupe", "martini", "nick nora", "nick and nora", "wine", "flute",
             "cocktail", "cocktail glass", "champagne coupe", "sour glass", "margarita glass":
            return "wineglass"
        case "rocks", "old fashioned", "double rocks", "highball", "collins", "pint",
             "mug", "copper mug", "mule mug", "julep cup", "beer mug", "tiki mug":
            return "mug"
        case "shot", "cordial", "shot glass", "pony glass":
            return "flask"
        case "irish coffee", "coffee mug", "toddy":
            return "cup.and.saucer"
        default:
            return "wineglass"
        }
    }

    static func fillSymbol(for glassType: String) -> String {
        let base = symbol(for: glassType)
        switch base {
        case "wineglass": return "wineglass.fill"
        case "mug": return "mug.fill"
        case "flask": return "flask.fill"
        case "cup.and.saucer": return "cup.and.saucer.fill"
        default: return base
        }
    }

    /// Glass names offered by the custom recipe editor, in display order.
    static let pickerGlasses: [String] = [
        "Coupe", "Martini", "Nick & Nora", "Wine", "Flute",
        "Rocks", "Old Fashioned", "Double Rocks", "Highball", "Collins", "Pint",
        "Copper Mug", "Julep Cup",
        "Shot", "Cordial", "Irish Coffee",
    ]
}

// MARK: - Shared components

struct PourSectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.pourTitle2)
                .foregroundStyle(PourColor.textPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.subheadline)
                    .foregroundStyle(PourColor.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct StatusPill: View {
    enum Kind { case canMake, almost, missing, lowStock, custom }
    let kind: Kind

    var body: some View {
        let config: (String, String, Color) = {
            switch kind {
            case .canMake: return ("Can make", "checkmark.circle.fill", PourColor.canMake)
            case .almost: return ("Almost", "exclamationmark.triangle", PourColor.almost)
            case .missing: return ("Missing", "exclamationmark.triangle", PourColor.almost)
            case .lowStock: return ("Low stock", "exclamationmark.triangle.fill", PourColor.almost)
            case .custom: return ("Custom", "pencil", PourColor.accent)
            }
        }()
        Label(config.0, systemImage: config.1)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(config.2)
            .background(config.2.opacity(0.14), in: Capsule())
            .accessibilityElement(children: .combine)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(PourColor.textTertiary)
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PourColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.body)
                    .foregroundStyle(PourColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(minHeight: 52)
                        .padding(.horizontal, 28)
                        .background(PourColor.accentFill, in: RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityLabel(actionTitle)
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

struct PourPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(PourColor.accentFill.opacity(configuration.isPressed ? 0.85 : 1), in: RoundedRectangle(cornerRadius: 14))
    }
}
