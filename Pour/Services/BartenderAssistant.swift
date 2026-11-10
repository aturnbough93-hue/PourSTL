import Foundation

/// Snapshot the assistant can answer from. Matching, search, and scaling still
/// go through `RecipeEngine` and `Measure`; this only carries the caller's data.
struct AssistantLibrary {
    var recipes: [Recipe]
    var inventory: [InventoryItem]
    var preferredUnit: UnitPreference
}

struct AssistantReply: Equatable {
    var text: String
    var followUps: [String]
    /// Shown with every reply so the answer is visibly on-device.
    var sourceNote: String

    static let onDeviceNote = "From recipes and inventory on this device."
}

enum AssistantAnswerError: Error, Equatable {
    /// The local data could not be turned into a safe answer.
    case couldNotAnswer
}

/// Question the bartender sheet can ask. A later backend can conform to this
/// without changing the sheet. The v1 app ships only `LocalBartenderAssistant`.
protocol BartenderAssistant {
    func answer(_ question: String, in library: AssistantLibrary) async throws -> AssistantReply
}

enum AssistantIntent: Equatable {
    case whatCanIMake(focus: String?)
    case substitution(ingredient: String, recipeName: String?)
    case scale(recipeQuery: String, servings: Double?)
    case missingIngredients(recipeQuery: String)
    case recipe(recipeQuery: String)
    case inventory
    case privacy
    case help
    case empty
    case unrecognized
}

/// Deterministic question routing. No model and no network.
enum AssistantQuestionParser {
    static func intent(for raw: String) -> AssistantIntent {
        let text = IngredientNormalizer.normalize(raw)
        if text.isEmpty { return .empty }
        if isPrivacy(text) { return .privacy }
        if isHelp(text) { return .help }
        if let substitution = substitution(in: text), !isPlainMakeQuestion(text) {
            return substitution
        }
        if let focus = whatCanIMake(in: text) { return focus }
        if let missing = missing(in: text) { return missing }
        if let recipe = recipe(in: text) { return recipe }
        if let scale = scale(in: text) { return scale }
        if isInventory(text) { return .inventory }
        return .unrecognized
    }

    private static let makePhrases = [
        "what cocktails can i make",
        "what drinks can i make",
        "which cocktails can i make",
        "which drinks can i make",
        "what am i able to make",
        "what can i make",
        "what can you make",
        "what can i mix",
        "what should i make",
        "what can i drink",
    ]

    private static let substitutionMarkers = [
        "substitutes for ",
        "substitute for ",
        "substitution for ",
        "substitutions for ",
        "instead of ",
        "in place of ",
        "stand in for ",
        "swap out ",
        "replace ",
        "dont have ",
        "do not have ",
        "out of ",
        "without ",
    ]

    private static func isPlainMakeQuestion(_ text: String) -> Bool {
        guard makePhrases.contains(where: { text.contains($0) }) else { return false }
        if text.contains("substitut") || text.contains("instead of") || text.contains("dont have")
            || text.contains("do not have") || text.contains("without ") {
            return false
        }
        return true
    }

    private static func whatCanIMake(in text: String) -> AssistantIntent? {
        guard let phrase = makePhrases.filter({ text.contains($0) }).max(by: { $0.count < $1.count }) else {
            return nil
        }
        return .whatCanIMake(focus: focus(after: phrase, in: text))
    }

    private static func focus(after phrase: String, in text: String) -> String? {
        guard let range = text.range(of: phrase) else { return nil }
        var rest = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
        if rest.hasPrefix("for ") {
            let token = rest.dropFirst(4).split(separator: " ").first.map(String.init) ?? ""
            if parseNumber(token) != nil { return nil }
        }
        for prefix in ["with ", "using ", "from ", "out of "] where rest.hasPrefix(prefix) {
            rest = String(rest.dropFirst(prefix.count))
            break
        }
        let focus = trimFiller(rest)
        if focus.isEmpty || focus == "my bar" || focus == "the bar" || focus == "what i have" {
            return nil
        }
        return focus
    }

    private static func substitution(in text: String) -> AssistantIntent? {
        var earliest: Range<String.Index>?
        for marker in substitutionMarkers {
            guard let range = text.range(of: marker) else { continue }
            if earliest == nil || range.lowerBound < earliest!.lowerBound {
                earliest = range
            }
        }
        guard let earliest else { return nil }
        let phrase = trimFiller(String(text[earliest.upperBound...]))
        let parts = splitIngredientAndRecipe(phrase)
        guard !parts.ingredient.isEmpty else { return nil }
        return .substitution(ingredient: parts.ingredient, recipeName: parts.recipeName)
    }

    private static func splitIngredientAndRecipe(_ phrase: String) -> (ingredient: String, recipeName: String?) {
        let markers = [" in a ", " in an ", " in the ", " for a ", " for an ", " for the ", " from a ", " from the ", " in "]
        for marker in markers {
            guard let range = phrase.range(of: marker) else { continue }
            let ingredient = trimFiller(String(phrase[..<range.lowerBound]))
            let recipe = trimFiller(String(phrase[range.upperBound...]))
            if !ingredient.isEmpty, !recipe.isEmpty {
                return (ingredient, recipe)
            }
        }
        return (trimFiller(phrase), nil)
    }

    private static func scale(in text: String) -> AssistantIntent? {
        let multipliers: [(String, Double)] = [("double", 2), ("triple", 3), ("quadruple", 4), ("half", 0.5)]
        for (word, factor) in multipliers where text.hasPrefix(word + " ") {
            let name = trimFiller(String(text.dropFirst(word.count + 1)))
            guard !name.isEmpty else { return nil }
            return .scale(recipeQuery: name, servings: factor)
        }
        for verb in ["scale ", "batch "] where text.hasPrefix(verb) {
            let rest = String(text.dropFirst(verb.count))
            if let parsed = trailingServings(rest) {
                let name = trimFiller(parsed.name)
                guard !name.isEmpty else { return nil }
                return .scale(recipeQuery: name, servings: parsed.servings)
            }
            let name = trimFiller(rest)
            guard !name.isEmpty else { return nil }
            return .scale(recipeQuery: name, servings: nil)
        }
        if let parsed = trailingServings(text) {
            let name = trimFiller(parsed.name)
            let blocked = ["what", "substitut", "missing", "how", "help", "who"]
            if blocked.contains(where: { name.contains($0) }) { return nil }
            guard !name.isEmpty else { return nil }
            return .scale(recipeQuery: name, servings: parsed.servings)
        }
        return nil
    }

    private static func trailingServings(_ text: String) -> (name: String, servings: Double)? {
        for separator in [" for ", " to ", " by "] {
            guard let range = text.range(of: separator, options: .backwards) else { continue }
            let name = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let rest = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, let servings = servingsToken(rest) else { continue }
            return (name, servings)
        }
        return nil
    }

    private static func servingsToken(_ rest: String) -> Double? {
        let tokens = rest.split(separator: " ").map(String.init)
        guard let first = tokens.first, let value = parseNumber(first), value.isFinite else { return nil }
        let suffix = tokens.dropFirst().joined(separator: " ")
        let allowed: Set<String> = [
            "", "serving", "servings", "person", "people", "guest", "guests",
            "drink", "drinks", "cocktail", "cocktails", "time", "times",
        ]
        return allowed.contains(suffix) ? value : nil
    }

    private static func parseNumber(_ token: String) -> Double? {
        let words: [String: Double] = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "twelve": 12, "half": 0.5,
        ]
        if let word = words[token] { return word }
        guard let value = Double(token), value.isFinite else { return nil }
        return value
    }

    private static func missing(in text: String) -> AssistantIntent? {
        let markers = [
            "what am i missing for ",
            "what am i missing from ",
            "missing ingredients for ",
            "what do i need for ",
            "what do i need to make ",
            "can i make ",
        ]
        guard let marker = markers.first(where: { text.contains($0) }),
              let range = text.range(of: marker) else { return nil }
        let name = trimFiller(String(text[range.upperBound...]))
        guard !name.isEmpty else { return nil }
        return .missingIngredients(recipeQuery: name)
    }

    private static func recipe(in text: String) -> AssistantIntent? {
        let markers = ["how do i make ", "how to make ", "recipe for "]
        guard let marker = markers.first(where: { text.contains($0) }),
              let range = text.range(of: marker) else { return nil }
        let name = trimFiller(String(text[range.upperBound...]))
        guard !name.isEmpty else { return nil }
        return .recipe(recipeQuery: name)
    }

    private static func isInventory(_ text: String) -> Bool {
        let phrases = [
            "whats in my bar", "what is in my bar", "what do i have",
            "whats in stock", "what is in stock", "my inventory",
            "show my bar", "show my inventory", "list my bar", "my bar inventory",
        ]
        return phrases.contains { text == $0 || text.hasPrefix($0 + " ") }
    }

    private static func isPrivacy(_ text: String) -> Bool {
        let phrases = [
            "upload", "send my", "send this", "cloud", "internet", "chatgpt", "openai",
            "api key", "off this device", "off the phone", "remote model", "remote server",
            "who can see", "is this private", "privacy", "train a model", "go online",
            "are you online", "use the internet",
        ]
        return phrases.contains { text.contains($0) }
    }

    private static func isHelp(_ text: String) -> Bool {
        if ["help", "help me", "help please"].contains(text) { return true }
        let phrases = ["what can you do", "what do you do", "how does this work", "how do you work"]
        return phrases.contains { text.contains($0) }
    }

    private static func trimFiller(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let articles = ["the ", "a ", "an ", "my ", "our "]
        let suffixes = [" please", " tonight", " right now", " now"]
        var changed = true
        while changed {
            changed = false
            for article in articles where text.hasPrefix(article) {
                text = String(text.dropFirst(article.count)).trimmingCharacters(in: .whitespaces)
                changed = true
            }
            for suffix in suffixes where text.hasSuffix(suffix) {
                text = String(text.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                changed = true
            }
        }
        return text
    }
}

/// Different-bottle stand-ins. Same-ingredient labels stay in `IngredientNormalizer`.
enum IngredientStandIns {
    static let table: [String: [String]] = [
        "gin": ["vodka"],
        "vodka": ["gin"],
        "bourbon": ["rye whiskey", "whiskey"],
        "rye whiskey": ["bourbon", "whiskey"],
        "whiskey": ["bourbon", "rye whiskey"],
        "scotch": ["irish whiskey"],
        "irish whiskey": ["scotch", "bourbon"],
        "white rum": ["aged rum"],
        "aged rum": ["white rum", "dark rum"],
        "dark rum": ["aged rum"],
        "tequila": ["mezcal"],
        "mezcal": ["tequila"],
        "cognac": ["bourbon"],
        "campari": ["aperol"],
        "aperol": ["campari"],
        "lime juice": ["lemon juice"],
        "lemon juice": ["lime juice"],
        "simple syrup": ["honey syrup", "agave syrup", "demerara syrup"],
        "honey syrup": ["simple syrup", "agave syrup"],
        "agave syrup": ["simple syrup", "honey syrup"],
        "demerara syrup": ["simple syrup", "honey syrup"],
        "grenadine": ["raspberry syrup"],
        "raspberry syrup": ["grenadine"],
        "sweet vermouth": ["blanc vermouth"],
        "dry vermouth": ["blanc vermouth"],
        "blanc vermouth": ["dry vermouth", "sweet vermouth"],
        "ginger beer": ["ginger ale"],
        "ginger ale": ["ginger beer"],
        "cream": ["milk"],
        "milk": ["cream"],
        "angostura bitters": ["orange bitters"],
        "orange bitters": ["angostura bitters"],
    ]

    static func alternatives(for raw: String) -> [String] {
        table[IngredientNormalizer.canonicalName(for: raw)] ?? []
    }
}

/// Answers from the on-device library. This type never opens a connection.
struct LocalBartenderAssistant: BartenderAssistant {
    static let starterQuestions = [
        "What can I make?",
        "What can I substitute for Campari?",
        "Scale the Negroni for 4",
    ]

    func answer(_ question: String, in library: AssistantLibrary) async throws -> AssistantReply {
        try Task.checkCancellation()
        switch AssistantQuestionParser.intent(for: question) {
        case .empty:
            return reply("Ask what you can make, what can stand in for a bottle, or how to scale a recipe.", followUps: Self.starterQuestions)
        case .privacy:
            return reply("Answers come from your recipes and My Bar on this device. Nothing is sent off the phone, and this assistant does not use a remote model.", followUps: Self.starterQuestions)
        case .help, .unrecognized:
            return reply("I can answer from this device: what you can make with My Bar, stand-ins for a bottle, and scaled measures.", followUps: Self.starterQuestions)
        case .inventory:
            return inventoryAnswer(library)
        case .whatCanIMake(let focus):
            return whatCanIMake(focus: focus, library: library)
        case .substitution(let ingredient, let recipeName):
            return substitutionAnswer(ingredient: ingredient, recipeName: recipeName, library: library)
        case .scale(let recipeQuery, let servings):
            return try scaleAnswer(query: recipeQuery, servings: servings, library: library)
        case .missingIngredients(let recipeQuery):
            return missingAnswer(query: recipeQuery, library: library)
        case .recipe(let recipeQuery):
            return try recipeAnswer(query: recipeQuery, library: library)
        }
    }

    private func reply(_ text: String, followUps: [String]) -> AssistantReply {
        AssistantReply(text: text, followUps: followUps, sourceNote: AssistantReply.onDeviceNote)
    }

    private func whatCanIMake(focus: String?, library: AssistantLibrary) -> AssistantReply {
        if library.recipes.isEmpty {
            return reply("Your recipe library is empty, so there is nothing to match yet.", followUps: Self.starterQuestions)
        }
        if library.inventory.isEmpty {
            return reply("My Bar is empty, so nothing can be matched yet. Add bottles there and ask again.", followUps: ["What can I make?"])
        }
        if !library.inventory.contains(where: \.isInStock) {
            return reply("Nothing in My Bar is marked in stock, so no drinks match. Turn a bottle back on and ask again.", followUps: ["What can I make?"])
        }

        let pool = recipes(in: library, focusedOn: focus)
        if let focus, pool.isEmpty {
            return reply("I don't have a drink that uses \(Self.titled(focus)) in your recipes.", followUps: ["What can I make?"])
        }
        let ranked = RecipeEngine.rankedMatches(recipes: pool, inventory: library.inventory)
        let ready = ranked.filter(\.canMake)
        let almost = ranked.filter(\.isAlmost)

        var lines: [String] = []
        if ready.isEmpty {
            if let focus, !focus.isEmpty {
                lines.append("No drinks that use \(Self.titled(focus)) can be made from what's in stock.")
            } else {
                lines.append("Nothing in your recipes can be made from what's in stock.")
            }
        } else {
            let noun = ready.count == 1 ? "drink" : "drinks"
            lines.append("You can make \(ready.count) \(noun) from My Bar:")
            for match in ready.prefix(8) {
                lines.append("• \(match.recipe.name)")
            }
            if ready.count > 8 {
                lines.append("And \(ready.count - 8) more.")
            }
        }
        if !almost.isEmpty {
            if !lines.isEmpty { lines.append("") }
            lines.append("Almost there:")
            for match in almost.prefix(4) {
                let missing = match.missing.map(\.name).joined(separator: ", ")
                lines.append("• \(match.recipe.name) - missing \(missing)")
            }
        }

        var followUps: [String] = []
        if let first = ready.first {
            followUps.append("Scale the \(first.recipe.name) for 4")
        }
        if let first = almost.first {
            followUps.append("What am I missing for a \(first.recipe.name)?")
        }
        if followUps.isEmpty { followUps = ["What can I substitute for Campari?"] }
        return reply(lines.joined(separator: "\n"), followUps: followUps)
    }

    private func recipes(in library: AssistantLibrary, focusedOn focus: String?) -> [Recipe] {
        guard let focus, !focus.isEmpty else { return library.recipes }
        let parts = focus
            .components(separatedBy: " and ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return library.recipes }
        return library.recipes.filter { recipe in
            parts.allSatisfy { part in
                !RecipeEngine.search(recipes: [recipe], query: part).isEmpty
            }
        }
    }

    private func substitutionAnswer(ingredient raw: String, recipeName: String?, library: AssistantLibrary) -> AssistantReply {
        let canonical = IngredientNormalizer.canonicalName(for: raw)
        let display = Self.titled(raw)
        let canonicalDisplay = Self.titled(canonical)
        var lines: [String] = []

        if let recipeName {
            switch find(recipeName, in: library.recipes) {
            case .one(let recipe):
                let used = recipe.sortedIngredients.contains { $0.canonicalName == canonical }
                if used {
                    let name = canonical == IngredientNormalizer.normalize(raw) ? display : canonicalDisplay
                    lines.append("\(recipe.name) uses \(name).")
                } else {
                    lines.append("\(recipe.name) doesn't call for \(display).")
                }
            case .many(let found):
                lines.append("I found more than one drink for that: \(joinedNames(found)).")
            case .none:
                lines.append("I could not find \(Self.titled(recipeName)) in your recipes.")
            }
        }

        if canonical != IngredientNormalizer.normalize(raw) {
            lines.append("\(display) already counts as \(canonicalDisplay) in your bar.")
        }

        let labels = knownLabels(for: canonical, excluding: raw)
        if !labels.isEmpty {
            lines.append("Other labels for \(canonicalDisplay) include \(listed(labels)).")
        }

        let standIns = IngredientStandIns.alternatives(for: raw)
        if standIns.isEmpty && labels.isEmpty && canonical == IngredientNormalizer.normalize(raw) {
            lines.append("I don't have a stand-in for \(display) in the on-device list.")
        } else if !standIns.isEmpty {
            lines.append("If you're out, these change the drink:")
            for item in standIns {
                let status = isOnHand(item, inventory: library.inventory) ? "in your bar" : "not in your bar"
                lines.append("• \(Self.titled(item)) - \(status)")
            }
        }

        if IngredientNormalizer.assumedAvailable.contains(canonical) {
            lines.append("\(canonicalDisplay) is treated as already on hand.")
        } else if isOnHand(raw, inventory: library.inventory) {
            lines.append("\(display) is in your bar.")
        } else {
            lines.append("\(display) is not in your bar.")
        }

        var followUps = ["What can I make?"]
        if let recipeName, case .one(let recipe) = find(recipeName, in: library.recipes) {
            followUps.append("Scale the \(recipe.name) for 4")
        }
        return reply(lines.joined(separator: "\n"), followUps: followUps)
    }

    private func scaleAnswer(query: String, servings: Double?, library: AssistantLibrary) throws -> AssistantReply {
        switch find(query, in: library.recipes) {
        case .none:
            return reply("I could not find \(Self.titled(query)) in your recipes. Try the drink's full name.", followUps: Self.starterQuestions)
        case .many(let found):
            return reply("Which drink should I scale? I found \(joinedNames(found)).", followUps: found.prefix(3).map { "Scale the \($0.name) for 4" })
        case .one(let recipe):
            guard let servings else {
                return reply("How many servings should I scale \(recipe.name) to?", followUps: ["Scale the \(recipe.name) for 4", "Half the \(recipe.name)"])
            }
            guard servings.isFinite else { throw AssistantAnswerError.couldNotAnswer }
            if servings <= 0 {
                return reply("Servings have to be greater than zero.", followUps: ["Scale the \(recipe.name) for 4"])
            }
            guard recipe.sortedIngredients.allSatisfy({ $0.amount.isFinite }) else {
                throw AssistantAnswerError.couldNotAnswer
            }
            var factor = servings
            var lead = ""
            let maximum = Double(RecipeScaling.maximumServings)
            if factor > maximum {
                lead = "The recipe screen scales up to \(RecipeScaling.maximumServings) servings, so this stops there.\n\n"
                factor = maximum
            }
            return reply(lead + spec(for: recipe, factor: factor, unit: library.preferredUnit, includeInstructions: false), followUps: [
                "What can I make?",
                "What am I missing for a \(recipe.name)?",
            ])
        }
    }

    private func missingAnswer(query: String, library: AssistantLibrary) -> AssistantReply {
        switch find(query, in: library.recipes) {
        case .none:
            return reply("I could not find \(Self.titled(query)) in your recipes.", followUps: ["What can I make?"])
        case .many(let found):
            return reply("Which drink do you mean? I found \(joinedNames(found)).", followUps: found.prefix(3).map { "What am I missing for a \($0.name)?" })
        case .one(let recipe):
            let match = RecipeEngine.match(recipe, inventory: library.inventory)
            var lines: [String] = []
            if match.canMake {
                lines.append("You can make \(recipe.name) with what's in stock.")
            } else if match.missing.isEmpty {
                lines.append("\(recipe.name) doesn't need anything else from My Bar.")
            } else {
                lines.append("\(recipe.name) still needs \(listed(match.missing.map(\.name))).")
            }
            if !match.missingOptional.isEmpty {
                lines.append("Optional and not in your bar: \(listed(match.missingOptional.map(\.name))).")
            }
            return reply(lines.joined(separator: "\n"), followUps: ["Scale the \(recipe.name) for 4", "What can I make?"])
        }
    }

    private func recipeAnswer(query: String, library: AssistantLibrary) throws -> AssistantReply {
        switch find(query, in: library.recipes) {
        case .none:
            return reply("I could not find \(Self.titled(query)) in your recipes.", followUps: ["What can I make?"])
        case .many(let found):
            return reply("Which drink do you mean? I found \(joinedNames(found)).", followUps: found.prefix(3).map { "How do I make a \($0.name)?" })
        case .one(let recipe):
            guard recipe.sortedIngredients.allSatisfy({ $0.amount.isFinite }) else {
                throw AssistantAnswerError.couldNotAnswer
            }
            return reply(spec(for: recipe, factor: 1, unit: library.preferredUnit, includeInstructions: true), followUps: [
                "Scale the \(recipe.name) for 4",
                "What am I missing for a \(recipe.name)?",
            ])
        }
    }

    private func inventoryAnswer(_ library: AssistantLibrary) -> AssistantReply {
        if library.inventory.isEmpty {
            return reply("My Bar is empty. Add a bottle and I can match drinks against it.", followUps: ["What can I make?"])
        }
        let onHand = library.inventory.filter(\.isInStock)
        let out = library.inventory.filter { !$0.isInStock }
        var lines: [String] = []
        if onHand.isEmpty {
            lines.append("Nothing in My Bar is marked in stock.")
        } else {
            let names = onHand.map(\.name).sorted()
            lines.append("In stock (\(onHand.count)): \(listed(Array(names.prefix(12)))).")
            if names.count > 12 {
                lines.append("And \(names.count - 12) more in stock.")
            }
        }
        if !out.isEmpty {
            lines.append("Marked out (\(out.count)): \(listed(out.map(\.name).sorted().prefix(8).map { String($0) })).")
        }
        return reply(lines.joined(separator: "\n"), followUps: ["What can I make?"])
    }

    private func spec(for recipe: Recipe, factor: Double, unit: UnitPreference, includeInstructions: Bool) -> String {
        var lines: [String] = ["\(recipe.name) for \(servingsPhrase(factor)):"]
        for line in recipe.sortedIngredients {
            let measure = line.measure.scaled(by: factor).formatted(for: unit)
            let optional = line.isOptional ? " (optional)" : ""
            lines.append("• \(measure) \(line.name)\(optional)")
        }
        var meta: [String] = []
        if !recipe.method.isEmpty { meta.append(recipe.method) }
        if !recipe.glassType.isEmpty { meta.append(recipe.glassType) }
        if !meta.isEmpty {
            lines.append("")
            lines.append(meta.joined(separator: " · "))
        }
        if let garnish = recipe.garnish, !garnish.isEmpty {
            lines.append("Garnish: \(garnish)")
        }
        if includeInstructions, !recipe.instructions.isEmpty {
            lines.append("")
            lines.append(recipe.instructions)
        }
        lines.append("")
        lines.append("Measures use the same scaling as the recipe screen.")
        return lines.joined(separator: "\n")
    }

    /// Same stock rule as Home: canonical names, aliases, overrides, and in-stock only.
    private func isOnHand(_ name: String, inventory: [InventoryItem]) -> Bool {
        let probe = Recipe(name: "On hand")
        probe.ingredients = [IngredientLine(name: name, amount: 1, unit: "oz")]
        return RecipeEngine.match(probe, inventory: inventory).canMake
    }

    private func knownLabels(for canonical: String, excluding raw: String) -> [String] {
        let excluded: Set<String> = [
            canonical,
            IngredientNormalizer.normalize(raw),
            IngredientNormalizer.canonicalName(for: raw),
        ]
        let labels = IngredientNormalizer.aliasMap
            .filter { $0.value == canonical && !excluded.contains($0.key) }
            .map(\.key)
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count < rhs.count }
                return lhs < rhs
            }
        return labels.prefix(5).map(Self.titled)
    }

    private enum RecipeHit {
        case one(Recipe)
        case many([Recipe])
        case none
    }

    private func find(_ query: String, in recipes: [Recipe]) -> RecipeHit {
        let q = IngredientNormalizer.normalize(query)
        guard !q.isEmpty else { return .none }
        if let exact = recipes.first(where: { IngredientNormalizer.normalize($0.name) == q }) {
            return .one(exact)
        }
        let contained = recipes.filter { containsPhrase(q, phrase: IngredientNormalizer.normalize($0.name)) }
        if let bestLength = contained.map({ IngredientNormalizer.normalize($0.name).count }).max() {
            let tied = contained.filter { IngredientNormalizer.normalize($0.name).count == bestLength }
            if tied.count == 1, let only = tied.first { return .one(only) }
            if tied.count > 1 { return .many(tied.sorted { $0.name < $1.name }) }
        }
        let partial = recipes.filter { containsPhrase(IngredientNormalizer.normalize($0.name), phrase: q) }
        if partial.count == 1, let only = partial.first { return .one(only) }
        if partial.count > 1 { return .many(partial.sorted { $0.name < $1.name }) }
        let searched = RecipeEngine.search(recipes: recipes, query: query)
        if searched.count == 1, let only = searched.first { return .one(only) }
        if searched.count > 1 { return .many(searched.sorted { $0.name < $1.name }) }
        return .none
    }

    private func containsPhrase(_ text: String, phrase: String) -> Bool {
        guard !phrase.isEmpty, phrase.count >= 3 else { return false }
        var rest = text[...]
        while let range = rest.range(of: phrase) {
            let beforeOK = range.lowerBound == rest.startIndex || rest[rest.index(before: range.lowerBound)] == " "
            let afterOK = range.upperBound == rest.endIndex || rest[range.upperBound] == " "
            if beforeOK && afterOK { return true }
            rest = rest[range.upperBound...]
        }
        return false
    }

    private func servingsPhrase(_ servings: Double) -> String {
        if servings == 0.5 { return "half the written spec" }
        if servings == servings.rounded() {
            let count = Int(servings)
            return "\(count) \(count == 1 ? "serving" : "servings")"
        }
        return "\(Measure.formatNumber(servings)) times the written spec"
    }

    private func joinedNames(_ recipes: [Recipe]) -> String {
        listed(recipes.sorted { $0.name < $1.name }.prefix(5).map(\.name))
    }

    private func listed<S: Sequence>(_ items: S) -> String where S.Element == String {
        let values = Array(items)
        switch values.count {
        case 0: return ""
        case 1: return values[0]
        case 2: return "\(values[0]) and \(values[1])"
        default:
            return values.dropLast().joined(separator: ", ") + ", and " + values[values.count - 1]
        }
    }

    private static func titled(_ raw: String) -> String {
        raw.split(separator: " ").map { word in
            guard let first = word.first else { return "" }
            return first.uppercased() + word.dropFirst()
        }.joined(separator: " ")
    }
}
