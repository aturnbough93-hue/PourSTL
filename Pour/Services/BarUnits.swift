import Foundation

enum UnitPreference: String, CaseIterable, Codable {
    case oz
    case ml

    var displayName: String { rawValue }
}

/// A bar measure unit. "Primary" volume units convert cleanly to oz/ml for display;
/// small bar measures (dash, barspoon, rinse…) and countables stay in their native
/// unit because that is how they are actually used at the bar.
enum BarUnit: String, CaseIterable, Codable {
    case ounce, milliliter, part
    case dash, barspoon, teaspoon, tablespoon, splash, drop, rinse, pinch
    case pony, jigger, shot, cup
    case each, cube, slice, wedge, wheel, sprig, twist, leaf, piece, scoop, topUp

    /// Fluid ounces per unit, when the unit converts cleanly. `nil` means the unit is
    /// non-volume (parts, countables, freeform) and is always displayed natively.
    var ouncesPerUnit: Double? {
        switch self {
        case .ounce: return 1
        case .milliliter: return 1.0 / 29.5735
        case .cup: return 8
        case .jigger, .shot: return 1.5
        case .pony: return 1
        case .tablespoon: return 0.5
        case .teaspoon: return 4.92892 / 29.5735
        case .barspoon: return 5.0 / 29.5735
        case .dash: return 1.0 / 32
        case .splash: return 0.25
        case .drop: return 0.05 / 29.5735
        case .part, .rinse, .pinch,
             .each, .cube, .slice, .wedge, .wheel, .sprig, .twist, .leaf, .piece, .scoop, .topUp:
            return nil
        }
    }

    /// Units that follow the user's preferred oz/ml display unit.
    static let primaryVolumeUnits: Set<BarUnit> = [.ounce, .milliliter, .cup, .jigger, .pony, .shot, .tablespoon]

    /// Small bar measures that convert arithmetically but display natively.
    static let nativeBarUnits: Set<BarUnit> = [.dash, .barspoon, .teaspoon, .splash, .drop]

    var isConvertible: Bool { ouncesPerUnit != nil }
    var isPart: Bool { self == .part }
    var isCountable: Bool {
        switch self {
        case .each, .cube, .slice, .wedge, .wheel, .sprig, .twist, .leaf, .piece, .scoop:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .ounce: return "oz"
        case .milliliter: return "ml"
        case .part: return "part"
        case .dash: return "dash"
        case .barspoon: return "barspoon"
        case .teaspoon: return "tsp"
        case .tablespoon: return "tbsp"
        case .splash: return "splash"
        case .drop: return "drop"
        case .rinse: return "rinse"
        case .pinch: return "pinch"
        case .pony: return "pony"
        case .jigger: return "jigger"
        case .shot: return "shot"
        case .cup: return "cup"
        case .each: return ""
        case .cube: return "cube"
        case .slice: return "slice"
        case .wedge: return "wedge"
        case .wheel: return "wheel"
        case .sprig: return "sprig"
        case .twist: return "twist"
        case .leaf: return "leaf"
        case .piece: return "piece"
        case .scoop: return "scoop"
        case .topUp: return "to top"
        }
    }

    /// Parse a freeform unit string (as found in recipe text) into a BarUnit.
    static func parse(_ raw: String) -> BarUnit {
        switch IngredientNormalizer.normalize(raw) {
        case "oz", "ounce", "ounces", "fl oz", "fluid ounce", "fluid ounces": return .ounce
        case "ml", "milliliter", "milliliters", "millilitre", "millilitres": return .milliliter
        case "part", "parts": return .part
        case "dash", "dashes": return .dash
        case "barspoon", "barspoons", "bar spoon", "bar spoons", "bsp": return .barspoon
        case "tsp", "teaspoon", "teaspoons": return .teaspoon
        case "tbsp", "tablespoon", "tablespoons": return .tablespoon
        case "splash", "splashes": return .splash
        case "drop", "drops": return .drop
        case "rinse", "rinses", "rinse of": return .rinse
        case "pinch", "pinches": return .pinch
        case "pony", "ponies": return .pony
        case "jigger", "jiggers": return .jigger
        case "shot", "shots": return .shot
        case "cup", "cups": return .cup
        case "each": return .each
        case "cube", "cubes", "sugar cube", "sugar cubes", "lump", "lumps": return .cube
        case "slice", "slices": return .slice
        case "wedge", "wedges": return .wedge
        case "wheel", "wheels": return .wheel
        case "sprig", "sprigs": return .sprig
        case "twist", "twists", "peel", "peels": return .twist
        case "leaf", "leaves": return .leaf
        case "piece", "pieces": return .piece
        case "scoop", "scoops": return .scoop
        case "top", "top up", "to top", "topup", "fill", "to fill", "float": return .topUp
        default: return .each
        }
    }
}

/// A quantity + unit pair with conversion, scaling and display formatting.
struct Measure: Equatable {
    var amount: Double
    var unit: BarUnit

    static let millilitersPerOunce = 29.5735

    /// Total ounces, when the unit converts cleanly. `nil` for parts/countables.
    var ounces: Double? {
        unit.ouncesPerUnit.map { amount * $0 }
    }

    var milliliters: Double? {
        ounces.map { $0 * Measure.millilitersPerOunce }
    }

    var isConvertible: Bool { unit.isConvertible }

    func scaled(by factor: Double) -> Measure {
        Measure(amount: amount * factor, unit: unit)
    }

    /// Convert to the preferred display unit. Only primary volume units convert;
    /// small bar measures (dash, barspoon, splash, drop, tsp), parts and countables
    /// always display natively.
    func converted(to preference: UnitPreference) -> Measure {
        guard let oz = ounces, BarUnit.primaryVolumeUnits.contains(unit) else { return self }
        switch preference {
        case .oz: return Measure(amount: oz, unit: .ounce)
        case .ml: return Measure(amount: oz * Measure.millilitersPerOunce, unit: .milliliter)
        }
    }

    /// Display string in the preferred unit, e.g. "1.5 oz", "45 ml", "2 dashes".
    func formatted(for preference: UnitPreference) -> String {
        converted(to: preference).formattedNative()
    }

    /// Display string in the measure's own unit.
    func formattedNative() -> String {
        if unit == .topUp { return BarUnit.topUp.displayName }
        let value = Self.displayAmount(amount, for: unit)
        let label = Self.pluralized(unit, amount: value)
        return label.isEmpty ? Self.formatNumber(value) : "\(Self.formatNumber(value)) \(label)"
    }

    /// Round for display: ounces snap to quarter steps, ml to integers ≥ 10 or half-steps below.
    static func displayAmount(_ amount: Double, for unit: BarUnit) -> Double {
        switch unit {
        case .ounce: return (amount * 4).rounded() / 4
        case .milliliter: return amount >= 10 ? amount.rounded() : (amount * 2).rounded() / 2
        default: return amount
        }
    }

    static func pluralized(_ unit: BarUnit, amount: Double) -> String {
        let name = unit.displayName
        guard !name.isEmpty else { return "" }
        switch unit {
        case .dash: return amount == 1 ? "dash" : "dashes"
        case .splash: return amount == 1 ? "splash" : "splashes"
        case .drop: return amount == 1 ? "drop" : "drops"
        case .pinch: return amount == 1 ? "pinch" : "pinches"
        case .part: return amount == 1 ? "part" : "parts"
        case .leaf: return amount == 1 ? "leaf" : "leaves"
        case .cube: return amount == 1 ? "cube" : "cubes"
        case .slice: return amount == 1 ? "slice" : "slices"
        case .wedge: return amount == 1 ? "wedge" : "wedges"
        case .wheel: return amount == 1 ? "wheel" : "wheels"
        case .sprig: return amount == 1 ? "sprig" : "sprigs"
        case .twist: return amount == 1 ? "twist" : "twists"
        case .piece: return amount == 1 ? "piece" : "pieces"
        case .scoop: return amount == 1 ? "scoop" : "scoops"
        case .pony: return amount == 1 ? "pony" : "ponies"
        case .jigger: return amount == 1 ? "jigger" : "jiggers"
        default: return name
        }
    }

    static func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 { return String(Int(value)) }
        var s = String(format: "%.2f", value)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}
