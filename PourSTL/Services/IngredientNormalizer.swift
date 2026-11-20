import Foundation

enum InventoryCategory: String, CaseIterable, Codable {
    case spirits
    case liqueurs
    case vermouthWine
    case bitters
    case mixers
    case syrups
    case juices
    case produce
    case dairy
    case other

    var displayName: String {
        switch self {
        case .spirits: return "Spirits"
        case .liqueurs: return "Liqueurs"
        case .vermouthWine: return "Vermouth & Wine"
        case .bitters: return "Bitters"
        case .mixers: return "Mixers"
        case .syrups: return "Syrups"
        case .juices: return "Juices"
        case .produce: return "Produce & Garnish"
        case .dairy: return "Dairy & Eggs"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .spirits: return "wineglass"
        case .liqueurs: return "drop"
        case .vermouthWine: return "wineglass.fill"
        case .bitters: return "eyedropper"
        case .mixers: return "bubbles.and.sparkles"
        case .syrups: return "drop.fill"
        case .juices: return "leaf"
        case .produce: return "carrot"
        case .dairy: return "cup.and.saucer"
        case .other: return "square.stack.3d.up"
        }
    }
}

/// Local alias map that folds brand names, styles and spellings down to canonical
/// ingredient names. Canonical names power inventory matching, "What can I make"
/// and search; display names are never replaced.
enum IngredientNormalizer {

    /// Lowercase, diacritic-folded, punctuation-collapsed form.
    static func normalize(_ raw: String) -> String {
        raw.lowercased()
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "&", with: " and ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Canonical ingredient name for a display name or alias.
    static func canonicalName(for raw: String) -> String {
        let key = normalize(raw)
        if let canonical = aliasMap[key] { return canonical }
        // Handle leading modifiers ("fresh lime juice", "chilled water") as a fallback.
        for modifier in ["fresh ", "chilled ", "dry ", "sweet ", "premium "] where key.hasPrefix(modifier) {
            let trimmed = String(key.dropFirst(modifier.count))
            if let canonical = aliasMap[trimmed] { return canonical }
        }
        return key
    }

    /// Ingredients a bar always has — excluded from "can make" computation.
    static let assumedAvailable: Set<String> = ["ice", "water"]

    static func category(for rawOrCanonical: String) -> InventoryCategory {
        let canonical = canonicalName(for: rawOrCanonical)
        return categoryMap[canonical] ?? .other
    }

    // MARK: - Category map (canonical name -> inventory category)

    static let categoryMap: [String: InventoryCategory] = [
        // spirits
        "gin": .spirits, "vodka": .spirits, "white rum": .spirits, "dark rum": .spirits,
        "aged rum": .spirits, "overproof rum": .spirits, "rhum agricole": .spirits, "cachaca": .spirits,
        "tequila": .spirits, "mezcal": .spirits, "bourbon": .spirits, "rye whiskey": .spirits,
        "whiskey": .spirits, "scotch": .spirits, "irish whiskey": .spirits, "cognac": .spirits,
        "apple brandy": .spirits, "pisco": .spirits, "absinthe": .spirits,
        // liqueurs
        "orange liqueur": .liqueurs, "maraschino liqueur": .liqueurs, "elderflower liqueur": .liqueurs,
        "coffee liqueur": .liqueurs, "irish cream": .liqueurs, "amaretto": .liqueurs,
        "green chartreuse": .liqueurs, "yellow chartreuse": .liqueurs, "fernet": .liqueurs,
        "amaro nonino": .liqueurs, "amaro": .liqueurs, "aperol": .liqueurs, "campari": .liqueurs,
        "cynar": .liqueurs, "benedictine": .liqueurs, "drambuie": .liqueurs, "frangelico": .liqueurs,
        "raspberry liqueur": .liqueurs, "creme de cassis": .liqueurs, "creme de menthe": .liqueurs,
        "creme de cacao": .liqueurs, "creme de violette": .liqueurs, "peach schnapps": .liqueurs,
        "apricot brandy": .liqueurs, "cherry liqueur": .liqueurs, "limoncello": .liqueurs,
        "galliano": .liqueurs, "sambuca": .liqueurs, "jagermeister": .liqueurs, "melon liqueur": .liqueurs,
        "pimms": .liqueurs, "suze": .liqueurs, "allspice dram": .liqueurs, "falernum": .liqueurs,
        // vermouth & wine
        "sweet vermouth": .vermouthWine, "dry vermouth": .vermouthWine, "blanc vermouth": .vermouthWine,
        "lillet blanc": .vermouthWine, "champagne": .vermouthWine, "sparkling wine": .vermouthWine,
        "sherry": .vermouthWine, "port": .vermouthWine, "madeira": .vermouthWine, "marsala": .vermouthWine,
        "dubonnet": .vermouthWine, "red wine": .vermouthWine, "white wine": .vermouthWine,
        // bitters
        "angostura bitters": .bitters, "orange bitters": .bitters, "peychauds bitters": .bitters,
        "chocolate bitters": .bitters, "celery bitters": .bitters,
        // mixers
        "soda water": .mixers, "tonic water": .mixers, "ginger beer": .mixers, "ginger ale": .mixers,
        "cola": .mixers, "lemon lime soda": .mixers, "grapefruit soda": .mixers, "tomato juice": .mixers,
        // syrups
        "simple syrup": .syrups, "demerara syrup": .syrups, "honey syrup": .syrups, "agave syrup": .syrups,
        "orgeat": .syrups, "grenadine": .syrups, "raspberry syrup": .syrups, "ginger syrup": .syrups,
        "vanilla syrup": .syrups, "lavender syrup": .syrups,
        // juices
        "lime juice": .juices, "lemon juice": .juices, "orange juice": .juices, "grapefruit juice": .juices,
        "cranberry juice": .juices, "pineapple juice": .juices, "apple juice": .juices,
        "passion fruit puree": .juices,
        // produce & garnish
        "lime": .produce, "lemon": .produce, "orange": .produce, "mint": .produce, "basil": .produce,
        "rosemary": .produce, "thyme": .produce, "cucumber": .produce, "cherry": .produce, "olive": .produce,
        "olive brine": .produce, "salt": .produce, "black pepper": .produce, "cinnamon": .produce,
        "nutmeg": .produce, "celery salt": .produce, "raspberry": .produce, "strawberry": .produce,
        "pineapple": .produce, "apple": .produce, "grapefruit": .produce, "jalapeno": .produce,
        "ginger": .produce, "vanilla extract": .produce,
        // dairy & eggs
        "cream": .dairy, "milk": .dairy, "coconut cream": .dairy, "egg white": .dairy,
        "egg yolk": .dairy, "egg": .dairy, "espresso": .other,
        // staples
        "sugar": .other, "ice": .other, "water": .other,
    ]

    // MARK: - Alias map (normalized display name/alias -> canonical name)

    static let aliasMap: [String: String] = [
        // Gin
        "gin": "gin", "london dry gin": "gin", "beefeater": "gin", "tanqueray": "gin",
        "bombay sapphire": "gin", "hendricks": "gin", "plymouth gin": "gin", "the botanist": "gin",
        "gordons": "gin", "sipsmith": "gin", "old tom gin": "gin", "genever": "gin",
        "aviation gin": "gin", "roker gin": "gin", "navy strength gin": "gin",
        // Vodka
        "vodka": "vodka", "absolut": "vodka", "grey goose": "vodka", "ketel one": "vodka",
        "titos": "vodka", "smirnoff": "vodka", "stolichnaya": "vodka", "belvedere": "vodka",
        "citrus vodka": "vodka", "vanilla vodka": "vodka", "citron vodka": "vodka",
        // Rum
        "white rum": "white rum", "light rum": "white rum", "rum": "white rum",
        "bacardi": "white rum", "havana club": "white rum", "flor de cana": "white rum",
        "dark rum": "dark rum", "black rum": "dark rum", "goslings": "dark rum",
        "myerss": "dark rum", "kraken": "dark rum",
        "aged rum": "aged rum", "anejo rum": "aged rum", "appleton": "aged rum",
        "diplomatico": "aged rum", "plantation rum": "aged rum", "jamaican rum": "aged rum",
        "overproof rum": "overproof rum", "151 rum": "overproof rum", "wray and nephew": "overproof rum",
        "lemon hart 151": "overproof rum", "plantation oftd": "overproof rum",
        "rhum agricole": "rhum agricole", "cachaca": "cachaca",
        // Agave
        "tequila": "tequila", "blanco tequila": "tequila", "silver tequila": "tequila",
        "tequila blanco": "tequila", "reposado tequila": "tequila", "reposado": "tequila",
        "anejo tequila": "tequila", "patron": "tequila", "patron silver": "tequila",
        "don julio": "tequila", "espolon": "tequila", "herradura": "tequila", "casamigos": "tequila",
        "mezcal": "mezcal", "del maguey": "mezcal", "del maguey vida": "mezcal", "vida mezcal": "mezcal",
        "joven mezcal": "mezcal",
        // Whiskey
        "bourbon": "bourbon", "buffalo trace": "bourbon", "makers mark": "bourbon",
        "jim beam": "bourbon", "wild turkey": "bourbon", "bulleit": "bourbon", "bulleit bourbon": "bourbon",
        "woodford reserve": "bourbon", "evan williams": "bourbon", "four roses": "bourbon",
        "knob creek": "bourbon", "elijah craig": "bourbon",
        "rye": "rye whiskey", "rye whiskey": "rye whiskey", "rittenhouse": "rye whiskey",
        "sazerac rye": "rye whiskey", "old overholt": "rye whiskey", "whistlepig": "rye whiskey",
        "bulleit rye": "rye whiskey", "dickel rye": "rye whiskey",
        "whiskey": "whiskey", "whisky": "whiskey", "blended whiskey": "whiskey",
        "canadian whisky": "whiskey", "tennessee whiskey": "whiskey", "jack daniels": "whiskey",
        "scotch": "scotch", "scotch whisky": "scotch", "blended scotch": "scotch",
        "single malt": "scotch", "single malt scotch": "scotch", "johnnie walker": "scotch",
        "famous grouse": "scotch", "monkey shoulder": "scotch", "dewars": "scotch",
        "irish whiskey": "irish whiskey", "jameson": "irish whiskey", "bushmills": "irish whiskey",
        "redbreast": "irish whiskey", "proper twelve": "irish whiskey", "tullamore dew": "irish whiskey",
        // Brandy
        "cognac": "cognac", "brandy": "cognac", "hennessy": "cognac", "remy martin": "cognac",
        "courvoisier": "cognac", "armagnac": "cognac", "vs cognac": "cognac", "vsop": "cognac",
        "apple brandy": "apple brandy", "applejack": "apple brandy", "calvados": "apple brandy",
        "lairds": "apple brandy", "pisco": "pisco",
        // Bitter/spirit misc
        "absinthe": "absinthe", "pernod": "absinthe", "pernod absinthe": "absinthe",
        "herbsaint": "absinthe", "kubler": "absinthe", "st george absinthe": "absinthe",
        "pastis": "absinthe",

        // Liqueurs
        "orange liqueur": "orange liqueur", "triple sec": "orange liqueur", "cointreau": "orange liqueur",
        "grand marnier": "orange liqueur", "orange curacao": "orange liqueur", "curacao": "orange liqueur",
        "dry curacao": "orange liqueur", "combier": "orange liqueur", "pierre ferrand curacao": "orange liqueur",
        "blue curacao": "orange liqueur",
        "maraschino liqueur": "maraschino liqueur", "maraschino": "maraschino liqueur",
        "luxardo maraschino": "maraschino liqueur",
        "elderflower liqueur": "elderflower liqueur", "st germain": "elderflower liqueur",
        "elderflower cordial": "elderflower liqueur",
        "coffee liqueur": "coffee liqueur", "kahlua": "coffee liqueur", "tia maria": "coffee liqueur",
        "mr black": "coffee liqueur",
        "irish cream": "irish cream", "baileys": "irish cream",
        "amaretto": "amaretto", "disaronno": "amaretto",
        "green chartreuse": "green chartreuse", "chartreuse verte": "green chartreuse",
        "yellow chartreuse": "yellow chartreuse", "chartreuse jaune": "yellow chartreuse",
        "fernet": "fernet", "fernet branca": "fernet",
        "amaro nonino": "amaro nonino", "nonino": "amaro nonino",
        "amaro": "amaro", "averna": "amaro", "montenegro": "amaro", "ramazzotti": "amaro",
        "aperol": "aperol", "campari": "campari", "cynar": "cynar",
        "benedictine": "benedictine", "dom benedictine": "benedictine",
        "drambuie": "drambuie", "frangelico": "frangelico", "hazelnut liqueur": "frangelico",
        "raspberry liqueur": "raspberry liqueur", "chambord": "raspberry liqueur",
        "creme de cassis": "creme de cassis", "cassis": "creme de cassis",
        "creme de menthe": "creme de menthe", "white creme de menthe": "creme de menthe",
        "green creme de menthe": "creme de menthe",
        "creme de cacao": "creme de cacao", "white creme de cacao": "creme de cacao",
        "dark creme de cacao": "creme de cacao",
        "creme de violette": "creme de violette", "violet liqueur": "creme de violette",
        "peach schnapps": "peach schnapps", "peach liqueur": "peach schnapps",
        "apricot brandy": "apricot brandy", "apricot liqueur": "apricot brandy",
        "cherry liqueur": "cherry liqueur", "cherry heering": "cherry liqueur", "heering": "cherry liqueur",
        "limoncello": "limoncello", "galliano": "galliano", "galliano l autentico": "galliano",
        "sambuca": "sambuca", "jagermeister": "jagermeister",
        "melon liqueur": "melon liqueur", "midori": "melon liqueur",
        "pimms": "pimms", "pimms no 1": "pimms", "suze": "suze",
        "allspice dram": "allspice dram", "pimento dram": "allspice dram",
        "falernum": "falernum", "velvet falernum": "falernum",

        // Vermouth & wine
        "sweet vermouth": "sweet vermouth", "vermouth rosso": "sweet vermouth",
        "vermouth rouge": "sweet vermouth", "red vermouth": "sweet vermouth",
        "carpano antica": "sweet vermouth", "dolin rouge": "sweet vermouth",
        "martini rosso": "sweet vermouth", "cocchi torino": "sweet vermouth",
        "punt e mes": "sweet vermouth", "antica formula": "sweet vermouth",
        "dry vermouth": "dry vermouth", "dolin dry": "dry vermouth", "noilly prat": "dry vermouth",
        "martini dry": "dry vermouth", "vermouth sec": "dry vermouth",
        "blanc vermouth": "blanc vermouth", "vermouth blanc": "blanc vermouth",
        "bianco vermouth": "blanc vermouth", "dolin blanc": "blanc vermouth",
        "lillet blanc": "lillet blanc", "lillet": "lillet blanc", "kina lillet": "lillet blanc",
        "cocchi americano": "lillet blanc", "lillet rose": "lillet blanc",
        "champagne": "champagne", "prosecco": "champagne", "sparkling wine": "champagne",
        "cava": "champagne", "brut sparkling wine": "champagne",
        "sherry": "sherry", "fino sherry": "sherry", "oloroso": "sherry", "amontillado": "sherry",
        "manzanilla": "sherry", "port": "port", "ruby port": "port", "madeira": "madeira",
        "marsala": "marsala", "dubonnet": "dubonnet",
        "red wine": "red wine", "white wine": "white wine",

        // Bitters
        "angostura bitters": "angostura bitters", "aromatic bitters": "angostura bitters",
        "angostura": "angostura bitters", "bitters": "angostura bitters", "ango": "angostura bitters",
        "orange bitters": "orange bitters", "regans orange bitters": "orange bitters",
        "angostura orange": "orange bitters",
        "peychauds bitters": "peychauds bitters", "peychauds": "peychauds bitters",
        "chocolate bitters": "chocolate bitters", "celery bitters": "celery bitters",

        // Syrups & sweeteners
        "simple syrup": "simple syrup", "sugar syrup": "simple syrup", "syrup": "simple syrup",
        "gomme": "simple syrup", "gomme syrup": "simple syrup",
        "demerara syrup": "demerara syrup", "rich syrup": "demerara syrup",
        "rich demerara syrup": "demerara syrup",
        "honey syrup": "honey syrup", "honey": "honey syrup", "honey water": "honey syrup",
        "agave syrup": "agave syrup", "agave nectar": "agave syrup",
        "orgeat": "orgeat", "almond syrup": "orgeat",
        "grenadine": "grenadine", "pomegranate syrup": "grenadine",
        "raspberry syrup": "raspberry syrup", "ginger syrup": "ginger syrup",
        "vanilla syrup": "vanilla syrup", "lavender syrup": "lavender syrup",
        "lime cordial": "lime cordial", "roses lime": "lime cordial", "roses lime juice": "lime cordial",

        // Juices & fruit
        "lime juice": "lime juice", "lime": "lime juice", "limes": "lime juice",
        "lime wedge": "lime juice", "lime wheel": "lime juice", "lime twist": "lime juice",
        "lemon juice": "lemon juice", "lemon": "lemon juice", "lemons": "lemon juice",
        "lemon wedge": "lemon juice", "lemon twist": "lemon juice", "lemon peel": "lemon juice",
        "lemon wheel": "lemon juice",
        "orange juice": "orange juice", "oj": "orange juice",
        "orange": "orange", "oranges": "orange", "orange twist": "orange", "orange peel": "orange",
        "orange wheel": "orange", "orange slice": "orange", "orange wedge": "orange",
        "orange zest": "orange", "flamed orange peel": "orange",
        "grapefruit juice": "grapefruit juice", "grapefruit": "grapefruit juice",
        "grapefruit soda": "grapefruit soda", "jarritos grapefruit": "grapefruit soda",
        "ting": "grapefruit soda", "squirt": "grapefruit soda", "fresca": "grapefruit soda",
        "cranberry juice": "cranberry juice",
        "pineapple juice": "pineapple juice",
        "pineapple": "pineapple", "pineapple wedge": "pineapple", "pineapple leaf": "pineapple",
        "apple juice": "apple juice", "passion fruit puree": "passion fruit puree",
        "passionfruit syrup": "passion fruit puree",
        "tomato juice": "tomato juice", "clamato": "tomato juice",
        "raspberry": "raspberry", "raspberries": "raspberry", "strawberry": "strawberry",
        "strawberries": "strawberry", "apple": "apple",

        // Dairy & eggs & coffee
        "cream": "cream", "heavy cream": "cream", "whipping cream": "cream",
        "double cream": "cream", "half and half": "cream",
        "milk": "milk", "coconut cream": "coconut cream", "cream of coconut": "coconut cream",
        "coco lopez": "coconut cream",
        "egg white": "egg white", "eggwhite": "egg white", "aquafaba": "egg white",
        "egg yolk": "egg yolk", "egg": "egg", "whole egg": "egg",
        "espresso": "espresso", "coffee": "espresso", "fresh espresso": "espresso",
        "brewed coffee": "espresso", "cold brew": "espresso", "hot coffee": "espresso",

        // Mixers
        "soda water": "soda water", "club soda": "soda water", "seltzer": "soda water",
        "sparkling water": "soda water", "soda": "soda water", "soda water chilled": "soda water",
        "tonic water": "tonic water", "tonic": "tonic water", "fever tree tonic": "tonic water",
        "ginger beer": "ginger beer", "ginger ale": "ginger ale",
        "cola": "cola", "coca cola": "cola", "coke": "cola", "pepsi": "cola",
        "lemon lime soda": "lemon lime soda", "sprite": "lemon lime soda", "7up": "lemon lime soda",

        // Produce & garnish
        "mint": "mint", "mint leaves": "mint", "mint sprig": "mint", "mint sprigs": "mint",
        "basil": "basil", "rosemary": "rosemary", "thyme": "thyme",
        "cucumber": "cucumber", "cucumber slice": "cucumber",
        "cherry": "cherry", "cherries": "cherry", "maraschino cherry": "cherry",
        "cocktail cherry": "cherry", "luxardo cherry": "cherry", "brandied cherry": "cherry",
        "olive": "olive", "olives": "olive", "cocktail olives": "olive", "green olive": "olive",
        "olive brine": "olive brine", "olive juice": "olive brine",
        "salt": "salt", "sea salt": "salt", "kosher salt": "salt", "saline solution": "salt",
        "celery salt": "salt", "rim salt": "salt", "flaky salt": "salt",
        "black pepper": "black pepper", "cinnamon": "cinnamon", "nutmeg": "nutmeg",
        "jalapeno": "jalapeno", "ginger": "ginger", "vanilla extract": "vanilla extract",

        // Staples
        "sugar": "sugar", "sugar cube": "sugar", "sugar cubes": "sugar", "demerara sugar": "sugar",
        "white sugar": "sugar", "superfine sugar": "sugar", "powdered sugar": "sugar",
        "ice": "ice", "ice cubes": "ice", "crushed ice": "ice", "pebble ice": "ice",
        "water": "water", "hot water": "water", "boiling water": "water", "warm water": "water",
        "worcestershire sauce": "worcestershire sauce", "tabasco": "worcestershire sauce",
        "hot sauce": "worcestershire sauce", "pepper sauce": "worcestershire sauce",
    ]
}
