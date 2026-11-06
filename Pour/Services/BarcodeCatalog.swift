import Foundation

/// Camera permission and hardware, reduced to values the scanner UI and tests can share.
enum CameraAuthorizationState: Equatable {
    case notDetermined
    case restricted
    case denied
    case authorized
}

enum BarcodeCameraReadiness: Equatable {
    case ready
    case needsPermission
    case denied
    case restricted
    case unavailable

    /// Title for the non-camera fallback. Nil while the camera can run.
    var fallbackTitle: String? {
        switch self {
        case .ready, .needsPermission: return nil
        case .denied: return "Camera access is off"
        case .restricted: return "Camera is restricted"
        case .unavailable: return "No camera on this device"
        }
    }

    /// Honest explanation plus the typed-code and add-by-name fallbacks.
    var fallbackMessage: String? {
        switch self {
        case .ready, .needsPermission:
            return nil
        case .denied:
            return "Pour needs the camera to scan a barcode. You can allow access in Settings, enter the numbers under the barcode, or add the bottle by name."
        case .restricted:
            return "This device doesn’t allow Pour to use the camera. Enter the numbers under the barcode, or add the bottle by name."
        case .unavailable:
            return "Pour can’t scan a barcode on this device. Enter the numbers under the barcode, or add the bottle by name."
        }
    }

    var offersSettings: Bool { self == .denied }
}

enum BarcodeCameraPolicy {
    static func readiness(hardwarePresent: Bool, authorization: CameraAuthorizationState) -> BarcodeCameraReadiness {
        guard hardwarePresent else { return .unavailable }
        switch authorization {
        case .authorized: return .ready
        case .notDetermined: return .needsPermission
        case .denied: return .denied
        case .restricted: return .restricted
        }
    }
}

enum BarcodeSymbology: String, Equatable {
    case ean13
    case ean8
    case upca
    case upce
    case itf14
    case code128
    case other
}

struct ParsedBarcode: Equatable {
    var rawPayload: String
    var normalizedCode: String
    var symbology: BarcodeSymbology
    /// Keys to try against the offline catalog, most specific first.
    var lookupKeys: [String]
}

enum BarcodeManualEntryResult: Equatable {
    case parsed(ParsedBarcode)
    case empty
    case invalid
}

enum BarcodeCheckDigit {
    static func compute(_ body: String) -> Int {
        var sum = 0
        for (index, character) in body.reversed().enumerated() {
            guard let digit = character.wholeNumberValue else { return -1 }
            sum += digit * (index % 2 == 0 ? 3 : 1)
        }
        return (10 - (sum % 10)) % 10
    }

    static func isValidGTIN(_ digits: String) -> Bool {
        guard [8, 12, 13, 14].contains(digits.count) else { return false }
        guard digits.allSatisfy(\.isNumber) else { return false }
        guard let provided = digits.last?.wholeNumberValue else { return false }
        return compute(String(digits.dropLast())) == provided
    }
}

/// GTIN parsing for bottle barcodes. Matching stays on device; unknown codes are not looked up online.
enum BarcodeParser {
    static func interpretManualEntry(_ raw: String) -> BarcodeManualEntryResult {
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .empty }
        guard let parsed = parse(payload: raw) else { return .invalid }
        return .parsed(parsed)
    }

    static func sameProductCode(_ lhs: String?, _ rhs: String) -> Bool {
        guard let lhs, let left = parse(payload: lhs)?.normalizedCode else { return false }
        guard let right = parse(payload: rhs)?.normalizedCode else { return false }
        return left == right
    }

    static func parse(payload: String, metadataType: String? = nil) -> ParsedBarcode? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let compact = compactDigits(from: trimmed) else { return nil }
        let hint = symbologyHint(metadataType)

        if hint == .upce {
            if let expanded = expandUPCE(compact) {
                return makeUPCA(raw: trimmed, upca: expanded, symbology: .upce)
            }
            if compact.count == 12 || compact.count == 13 {
                return parseFixedLength(compact, raw: trimmed, preferred: .upca)
            }
            return nil
        }

        // An unlabeled 6- or 8-digit code can be UPC-E. Prefer that when the
        // expansion check digit matches; otherwise an 8-digit code falls through to EAN-8.
        // A camera that already identified EAN-8 must not be rewritten as UPC-E.
        if hint != .ean8,
           compact.count == 6 || compact.count == 8,
           let expanded = expandUPCE(compact, allowBareSixDigits: hint == nil) {
            return makeUPCA(raw: trimmed, upca: expanded, symbology: .upce)
        }

        if compact.count == 16, compact.hasPrefix("01") {
            let gtin14 = String(compact.dropFirst(2))
            if BarcodeCheckDigit.isValidGTIN(gtin14) {
                return makeGTIN14(raw: trimmed, gtin14: gtin14, symbology: .code128)
            }
        }

        return parseFixedLength(compact, raw: trimmed, preferred: hint)
    }

    private static func parseFixedLength(_ compact: String, raw: String, preferred: BarcodeSymbology?) -> ParsedBarcode? {
        switch compact.count {
        case 8:
            guard BarcodeCheckDigit.isValidGTIN(compact) else { return nil }
            return make(raw: raw, normalized: compact, symbology: .ean8, extraKeys: [])
        case 12:
            guard BarcodeCheckDigit.isValidGTIN(compact) else { return nil }
            return makeUPCA(raw: raw, upca: compact, symbology: preferred == .code128 ? .code128 : .upca)
        case 13:
            guard BarcodeCheckDigit.isValidGTIN(compact) else { return nil }
            let symbology: BarcodeSymbology = compact.hasPrefix("0") ? .upca : .ean13
            var extras = [compact]
            if compact.hasPrefix("0") {
                extras.append(String(compact.dropFirst()))
            }
            return make(raw: raw, normalized: compact, symbology: symbology, extraKeys: extras)
        case 14:
            guard BarcodeCheckDigit.isValidGTIN(compact) else { return nil }
            let symbology: BarcodeSymbology = preferred == .code128 ? .code128 : .itf14
            return makeGTIN14(raw: raw, gtin14: compact, symbology: symbology)
        default:
            return nil
        }
    }

    private static func makeUPCA(raw: String, upca: String, symbology: BarcodeSymbology) -> ParsedBarcode? {
        guard upca.count == 12, BarcodeCheckDigit.isValidGTIN(upca) else { return nil }
        let gtin13 = "0" + upca
        return make(raw: raw, normalized: gtin13, symbology: symbology, extraKeys: [upca, gtin13])
    }

    /// ITF-14 / GTIN-14 stores a packaging indicator and its own check digit.
    /// The consumer GTIN-13 is the middle 12 digits plus a recalculated check digit.
    private static func makeGTIN14(raw: String, gtin14: String, symbology: BarcodeSymbology) -> ParsedBarcode? {
        guard gtin14.count == 14 else { return nil }
        let data12 = String(gtin14.dropFirst().dropLast())
        guard data12.count == 12 else { return nil }
        let gtin13 = data12 + String(BarcodeCheckDigit.compute(data12))
        guard BarcodeCheckDigit.isValidGTIN(gtin13) else { return nil }
        var extras = [gtin13, gtin14]
        if gtin13.hasPrefix("0") {
            extras.append(String(gtin13.dropFirst()))
        }
        return make(raw: raw, normalized: gtin13, symbology: symbology, extraKeys: extras)
    }

    private static func make(raw: String, normalized: String, symbology: BarcodeSymbology, extraKeys: [String]) -> ParsedBarcode {
        var keys: [String] = []
        for key in [normalized] + extraKeys where !key.isEmpty && !keys.contains(key) {
            keys.append(key)
        }
        return ParsedBarcode(rawPayload: raw, normalizedCode: normalized, symbology: symbology, lookupKeys: keys)
    }

    /// UPC-E number-system + 6 digits + optional check, expanded to UPC-A.
    /// `allowBareSixDigits` accepts a 6-digit body and assumes number system 0.
    private static func expandUPCE(_ digits: String, allowBareSixDigits: Bool = true) -> String? {
        let numberSystem: Character
        let body: String
        let providedCheck: Character?
        switch digits.count {
        case 6 where allowBareSixDigits:
            numberSystem = "0"
            body = digits
            providedCheck = nil
        case 8:
            guard let first = digits.first, first == "0" || first == "1" else { return nil }
            numberSystem = first
            body = String(digits.dropFirst().dropLast())
            providedCheck = digits.last
        default:
            return nil
        }
        guard body.count == 6 else { return nil }
        let digitsInBody = Array(body)
        let expandedBody: String
        switch digitsInBody[5] {
        case "0", "1", "2":
            expandedBody = "\(numberSystem)\(digitsInBody[0])\(digitsInBody[1])\(digitsInBody[5])0000\(digitsInBody[2])\(digitsInBody[3])\(digitsInBody[4])"
        case "3":
            expandedBody = "\(numberSystem)\(digitsInBody[0])\(digitsInBody[1])\(digitsInBody[2])00000\(digitsInBody[3])\(digitsInBody[4])"
        case "4":
            expandedBody = "\(numberSystem)\(digitsInBody[0])\(digitsInBody[1])\(digitsInBody[2])\(digitsInBody[3])00000\(digitsInBody[4])"
        default:
            expandedBody = "\(numberSystem)\(digitsInBody[0])\(digitsInBody[1])\(digitsInBody[2])\(digitsInBody[3])\(digitsInBody[4])0000\(digitsInBody[5])"
        }
        guard expandedBody.count == 11 else { return nil }
        let check = BarcodeCheckDigit.compute(expandedBody)
        if let providedCheck, String(providedCheck) != String(check) { return nil }
        let upca = expandedBody + String(check)
        guard BarcodeCheckDigit.isValidGTIN(upca) else { return nil }
        return upca
    }

    private static func compactDigits(from trimmed: String) -> String? {
        let withoutParens = trimmed.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        let allowed = CharacterSet.decimalDigits
            .union(.whitespacesAndNewlines)
            .union(CharacterSet(charactersIn: "-"))
        guard withoutParens.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        let digits = withoutParens.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return String(digits)
    }

    private static func symbologyHint(_ metadataType: String?) -> BarcodeSymbology? {
        switch metadataType {
        case "org.gs1.EAN-13": return .ean13
        case "org.gs1.EAN-8": return .ean8
        case "org.gs1.UPC-E": return .upce
        case "org.gs1.ITF14", "org.iso.Interleaved2of5": return .itf14
        case "org.iso.Code128", "org.iso.Code39": return .code128
        default: return nil
        }
    }
}

enum BarcodeFormatting {
    /// Groups a GTIN the way a UPC-A is printed: `0 12345 67890 5`.
    static func grouped(_ code: String) -> String {
        let digits = String(code.filter(\.isNumber))
        let upc: String
        if digits.count == 13, digits.first == "0" {
            upc = String(digits.dropFirst())
        } else if digits.count == 12 {
            upc = digits
        } else {
            return digits
        }
        guard upc.count == 12 else { return digits }
        let chars = Array(upc)
        return "\(chars[0]) \(String(chars[1...5])) \(String(chars[6...10])) \(chars[11])"
    }
}

struct BarcodeCatalogEntry: Equatable {
    var gtin: String
    var displayName: String
}

/// Retail UPC-A codes for common back-bar bottles, stored as GTIN-13.
/// Other sizes and unknown brands stay on the manual add path. Nothing is fetched.
enum BarcodeCatalog {
    static let entries: [BarcodeCatalogEntry] = [
        BarcodeCatalogEntry(gtin: "0075496000407", displayName: "Angostura Bitters"),
        BarcodeCatalogEntry(gtin: "0721059047500", displayName: "Campari"),
        BarcodeCatalogEntry(gtin: "0087236565107", displayName: "Cointreau"),
        BarcodeCatalogEntry(gtin: "0721059001311", displayName: "Aperol"),
        BarcodeCatalogEntry(gtin: "0086891026237", displayName: "Luxardo Maraschino"),
        BarcodeCatalogEntry(gtin: "0898804001008", displayName: "St-Germain"),
        BarcodeCatalogEntry(gtin: "0088004190187", displayName: "Peychaud's Bitters"),
        BarcodeCatalogEntry(gtin: "0089540122717", displayName: "Kahlúa"),
        BarcodeCatalogEntry(gtin: "0898195001175", displayName: "Fever-Tree Tonic"),
        BarcodeCatalogEntry(gtin: "0086767210067", displayName: "Baileys"),
        BarcodeCatalogEntry(gtin: "0088110110307", displayName: "Tanqueray"),
        BarcodeCatalogEntry(gtin: "0619947000020", displayName: "Tito's"),
    ]

    private static let byGTIN: [String: String] = {
        var map: [String: String] = [:]
        for entry in entries { map[entry.gtin] = entry.displayName }
        return map
    }()

    static func displayName(matching parsed: ParsedBarcode) -> String? {
        for key in parsed.lookupKeys {
            if let name = byGTIN[key] { return name }
        }
        return nil
    }
}

struct BarcodeProductDraft: Equatable, Identifiable {
    var displayName: String
    var barcode: String
    var isRecognized: Bool
    var id: String { barcode }
}

struct BarcodeConfirmedItem: Equatable {
    var name: String
    var category: InventoryCategory
    var barcode: String
    var canonicalName: String
    var isInStock: Bool

    static func make(name: String, barcode: String) -> BarcodeConfirmedItem? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !IngredientNormalizer.normalize(trimmed).isEmpty else { return nil }
        guard let parsed = BarcodeParser.parse(payload: barcode) else { return nil }
        return BarcodeConfirmedItem(
            name: trimmed,
            category: IngredientNormalizer.category(for: trimmed),
            barcode: parsed.normalizedCode,
            canonicalName: IngredientNormalizer.canonicalName(for: trimmed),
            isInStock: true
        )
    }
}

struct BarcodeStockSnapshot: Equatable {
    var name: String
    var barcode: String?
    var isInStock: Bool
}

struct ExistingBarcodeMatch: Equatable, Identifiable {
    var name: String
    var isInStock: Bool
    var scannedCode: String
    var canAttachBarcode: Bool
    var id: String { "\(name)|\(scannedCode)|\(canAttachBarcode)" }
}

enum BarcodeExistingAction: Equatable {
    case markInStockAndSaveBarcode
    case markInStock
    case saveBarcode
    case none

    var buttonTitle: String {
        switch self {
        case .markInStockAndSaveBarcode: return "Mark in stock and save barcode"
        case .markInStock: return "Mark in stock"
        case .saveBarcode: return "Save barcode"
        case .none: return "Done"
        }
    }
}

enum BarcodeScanPlan: Equatable {
    case add(BarcodeProductDraft)
    case alreadyInBar(ExistingBarcodeMatch)
    case needsName(barcode: String)
}

enum BarcodeCommit: Equatable {
    case insert(BarcodeConfirmedItem)
    case alreadyInBar(ExistingBarcodeMatch)
}

enum BarcodeResolver {
    static func existingAction(isInStock: Bool, canAttachBarcode: Bool) -> BarcodeExistingAction {
        switch (isInStock, canAttachBarcode) {
        case (false, true): return .markInStockAndSaveBarcode
        case (false, false): return .markInStock
        case (true, true): return .saveBarcode
        case (true, false): return .none
        }
    }

    static func plan(parsed: ParsedBarcode, stock: [BarcodeStockSnapshot]) -> BarcodeScanPlan {
        let code = parsed.normalizedCode
        if let displayName = BarcodeCatalog.displayName(matching: parsed) {
            switch commit(name: displayName, barcode: code, stock: stock) {
            case .insert(let item):
                return .add(BarcodeProductDraft(displayName: item.name, barcode: item.barcode, isRecognized: true))
            case .alreadyInBar(let match):
                return .alreadyInBar(match)
            case nil:
                return .needsName(barcode: code)
            }
        }
        if let hit = stock.first(where: { BarcodeParser.sameProductCode($0.barcode, code) }) {
            return .alreadyInBar(ExistingBarcodeMatch(
                name: hit.name,
                isInStock: hit.isInStock,
                scannedCode: code,
                canAttachBarcode: false
            ))
        }
        return .needsName(barcode: code)
    }

    static func commit(name: String, barcode: String, stock: [BarcodeStockSnapshot]) -> BarcodeCommit? {
        guard let confirmed = BarcodeConfirmedItem.make(name: name, barcode: barcode) else { return nil }
        if let hit = stock.first(where: { BarcodeParser.sameProductCode($0.barcode, confirmed.barcode) }) {
            return .alreadyInBar(ExistingBarcodeMatch(
                name: hit.name,
                isInStock: hit.isInStock,
                scannedCode: confirmed.barcode,
                canAttachBarcode: false
            ))
        }
        let normalized = IngredientNormalizer.normalize(confirmed.name)
        if let hit = stock.first(where: { IngredientNormalizer.normalize($0.name) == normalized }) {
            let canAttach = hit.barcode?.isEmpty != false
            return .alreadyInBar(ExistingBarcodeMatch(
                name: hit.name,
                isInStock: hit.isInStock,
                scannedCode: confirmed.barcode,
                canAttachBarcode: canAttach
            ))
        }
        return .insert(confirmed)
    }
}
