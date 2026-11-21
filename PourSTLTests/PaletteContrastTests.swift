import XCTest
import SwiftUI
@testable import PourSTL

@MainActor
final class PaletteContrastTests: XCTestCase {
    func testLightPaletteSmallTextContrast() {
        assertSmallTextContrast(style: .light)
    }

    func testDarkPaletteSmallTextContrast() {
        assertSmallTextContrast(style: .dark)
    }

    private func assertSmallTextContrast(style: UIUserInterfaceStyle) {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let surfaces: [(String, Color)] = [
            ("background", PourColor.background),
            ("card", PourColor.card),
            ("surface", PourColor.surface)
        ]
        let plainText: [(String, Color)] = [
            ("primary", PourColor.textPrimary),
            ("secondary", PourColor.textSecondary),
            ("tertiary", PourColor.textTertiary),
            ("gold", PourColor.gold)
        ]
        let badges: [(String, Color)] = [
            ("canMake", PourColor.canMake),
            ("almost", PourColor.almost),
            ("accent", PourColor.accent)
        ]
        for (surfaceName, surface) in surfaces {
            let base = rgb(surface, traits: traits)
            for (name, text) in plainText {
                XCTAssertGreaterThanOrEqual(
                    contrast(rgb(text, traits: traits), base), 4.5,
                    "\(style): \(name) on \(surfaceName)"
                )
            }
            for (name, text) in badges {
                let foreground = rgb(text, traits: traits)
                for alpha in [0.0, 0.12, 0.14] {
                    let background = zip(foreground, base).map { fg, bg in
                        fg * alpha + bg * (1 - alpha)
                    }
                    XCTAssertGreaterThanOrEqual(
                        contrast(foreground, background), 4.5,
                        "\(style): \(name) on \(surfaceName) with \(alpha) tint"
                    )
                }
            }
        }
    }

    private func rgb(_ color: Color, traits: UITraitCollection) -> [Double] {
        let resolved = UIColor(color).resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual(alpha, 1)
        return [Double(red), Double(green), Double(blue)]
    }

    private func contrast(_ foreground: [Double], _ background: [Double]) -> Double {
        func luminance(_ color: [Double]) -> Double {
            zip(color, [0.2126, 0.7152, 0.0722]).reduce(0) { sum, component in
                let (value, weight) = component
                let linear = value <= 0.04045
                    ? value / 12.92
                    : pow((value + 0.055) / 1.055, 2.4)
                return sum + linear * weight
            }
        }
        let a = luminance(foreground)
        let b = luminance(background)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
