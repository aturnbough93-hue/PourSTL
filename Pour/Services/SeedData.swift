import Foundation
import SwiftData

/// Seeded library of classic cocktails. Local-only; a remote cache layer
/// (TheCocktailDB) can be added later without touching user data.
enum SeedData {

    static func seedIfNeeded(in context: ModelContext) throws {
        let existing = try context.fetchCount(FetchDescriptor<Recipe>())
        guard existing == 0 else { return }

        for spec in recipes {
            let recipe = Recipe(
                name: spec.name,
                glassType: spec.glass,
                method: spec.method,
                instructions: spec.instructions,
                garnish: spec.garnish,
                tags: spec.tags,
                isCustom: false
            )
            for (index, line) in spec.lines.enumerated() {
                let ingredient = IngredientLine(
                    name: line.name,
                    amount: line.amount,
                    unit: line.unit,
                    note: line.note,
                    isOptional: line.isOptional,
                    position: index
                )
                recipe.ingredients.append(ingredient)
            }
            context.insert(recipe)
        }

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demoInventory") {
            seedDemoInventory(in: context)
        }
        #endif

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    #if DEBUG
    /// Small starter bar used for demos and screenshots (debug builds only).
    private static func seedDemoInventory(in context: ModelContext) {
        let demo: [(String, InventoryCategory, Bool)] = [
            ("London Dry Gin", .spirits, true),
            ("Bourbon", .spirits, true),
            ("Sweet Vermouth", .vermouthWine, true),
            ("Dry Vermouth", .vermouthWine, true),
            ("Campari", .liqueurs, true),
            ("Angostura Bitters", .bitters, true),
            ("Simple Syrup", .syrups, true),
            ("Lime Juice", .juices, true),
            ("Lemon Juice", .juices, true),
            ("Soda Water", .mixers, true),
            ("Mint", .produce, true),
            ("Aperol", .liqueurs, false),
        ]
        for (name, category, inStock) in demo {
            context.insert(InventoryItem(name: name, category: category, isInStock: inStock))
        }
    }
    #endif

    private struct SeedLine {
        let name: String
        let amount: Double
        let unit: String
        let isOptional: Bool
        let note: String?

        init(_ name: String, _ amount: Double, _ unit: String, optional: Bool = false, note: String? = nil) {
            self.name = name
            self.amount = amount
            self.unit = unit
            self.isOptional = optional
            self.note = note
        }
    }

    private struct SeedRecipe {
        let name: String
        let glass: String
        let method: String
        let instructions: String
        let garnish: String?
        let tags: [String]
        let lines: [SeedLine]
    }

    private static let recipes: [SeedRecipe] = [
        SeedRecipe(
            name: "Martini", glass: "Martini", method: "Stirred",
            instructions: "Add gin and vermouth to a mixing glass filled with ice. Stir until well chilled, about 20 seconds. Strain into a chilled martini glass. Express a lemon twist over the surface, or garnish with olives.",
            garnish: "Lemon twist or olives",
            tags: ["gin", "stirred", "spirit-forward", "classic", "up"],
            lines: [
                SeedLine("London Dry Gin", 2.5, "oz"),
                SeedLine("Dry Vermouth", 0.5, "oz"),
                SeedLine("Orange Bitters", 1, "dashes", optional: true),
            ]
        ),
        SeedRecipe(
            name: "Negroni", glass: "Rocks", method: "Stirred",
            instructions: "Add gin, Campari and sweet vermouth to a mixing glass with ice. Stir until chilled. Strain over a large ice cube in a rocks glass. Garnish with an orange twist.",
            garnish: "Orange twist",
            tags: ["gin", "bitter", "stirred", "classic", "equal parts"],
            lines: [
                SeedLine("Gin", 1, "oz"),
                SeedLine("Campari", 1, "oz"),
                SeedLine("Sweet Vermouth", 1, "oz"),
                SeedLine("Orange Twist", 1, "twist", optional: true),
            ]
        ),
        SeedRecipe(
            name: "Old Fashioned", glass: "Old Fashioned", method: "Built",
            instructions: "Place the sugar cube in a rocks glass and saturate with bitters. Muddle until dissolved. Add bourbon and a large ice cube, then stir briefly to chill and dilute. Express an orange twist over the top.",
            garnish: "Orange twist",
            tags: ["bourbon", "whiskey", "stirred", "classic", "spirit-forward"],
            lines: [
                SeedLine("Sugar Cube", 1, "cube"),
                SeedLine("Angostura Bitters", 3, "dashes"),
                SeedLine("Bourbon", 2, "oz"),
                SeedLine("Orange Twist", 1, "twist", optional: true),
            ]
        ),
        SeedRecipe(
            name: "Manhattan", glass: "Coupe", method: "Stirred",
            instructions: "Add rye, sweet vermouth and bitters to a mixing glass with ice. Stir until well chilled. Strain into a chilled coupe. Garnish with a cocktail cherry.",
            garnish: "Cocktail cherry",
            tags: ["rye", "whiskey", "stirred", "classic", "up"],
            lines: [
                SeedLine("Rye Whiskey", 2, "oz"),
                SeedLine("Sweet Vermouth", 1, "oz"),
                SeedLine("Angostura Bitters", 2, "dashes"),
                SeedLine("Maraschino Cherry", 1, "each", optional: true),
            ]
        ),
        SeedRecipe(
            name: "Margarita", glass: "Rocks", method: "Shaken",
            instructions: "Shake tequila, lime juice and orange liqueur with ice until chilled. Strain over fresh ice in a salt-rimmed rocks glass (rim optional). Garnish with a lime wedge.",
            garnish: "Lime wedge, salt rim (optional)",
            tags: ["tequila", "shaken", "sour", "classic", "citrus"],
            lines: [
                SeedLine("Tequila", 2, "oz"),
                SeedLine("Lime Juice", 1, "oz"),
                SeedLine("Orange Liqueur", 1, "oz"),
                SeedLine("Salt", 1, "pinch", optional: true),
                SeedLine("Lime Wedge", 1, "wedge", optional: true),
            ]
        ),
        SeedRecipe(
            name: "Daiquiri", glass: "Coupe", method: "Shaken",
            instructions: "Shake rum, lime juice and simple syrup with ice until well chilled. Double-strain into a chilled coupe. No garnish needed.",
            garnish: nil,
            tags: ["rum", "shaken", "sour", "classic", "citrus"],
            lines: [
                SeedLine("White Rum", 2, "oz"),
                SeedLine("Lime Juice", 1, "oz"),
                SeedLine("Simple Syrup", 0.75, "oz"),
            ]
        ),
        SeedRecipe(
            name: "Mojito", glass: "Highball", method: "Built",
            instructions: "Gently muddle mint with lime juice and simple syrup in a highball glass — bruise, don't shred. Add rum and fill with crushed ice. Top with soda and stir briefly. Garnish with a mint sprig.",
            garnish: "Mint sprig",
            tags: ["rum", "built", "refreshing", "classic", "mint"],
            lines: [
                SeedLine("Mint Leaves", 8, "leaf"),
                SeedLine("White Rum", 2, "oz"),
                SeedLine("Lime Juice", 0.75, "oz"),
                SeedLine("Simple Syrup", 0.75, "oz"),
                SeedLine("Soda Water", 2, "oz", note: "to top"),
            ]
        ),
        SeedRecipe(
            name: "Whiskey Sour", glass: "Rocks", method: "Shaken",
            instructions: "Shake bourbon, lemon juice, syrup and egg white (if using) without ice for 10 seconds, then add ice and shake hard. Strain over fresh ice. Garnish with a cherry or lemon wheel.",
            garnish: "Cherry or lemon wheel",
            tags: ["bourbon", "whiskey", "shaken", "sour", "classic"],
            lines: [
                SeedLine("Bourbon", 2, "oz"),
                SeedLine("Lemon Juice", 0.75, "oz"),
                SeedLine("Simple Syrup", 0.75, "oz"),
                SeedLine("Egg White", 1, "each", optional: true),
                SeedLine("Angostura Bitters", 3, "dashes", optional: true),
            ]
        ),
        SeedRecipe(
            name: "Cosmopolitan", glass: "Martini", method: "Shaken",
            instructions: "Shake vodka, orange liqueur, lime and cranberry with ice until well chilled. Double-strain into a chilled martini glass. Garnish with an orange twist.",
            garnish: "Orange twist",
            tags: ["vodka", "shaken", "sour", "modern classic", "citrus"],
            lines: [
                SeedLine("Citrus Vodka", 1.5, "oz"),
                SeedLine("Orange Liqueur", 1, "oz"),
                SeedLine("Lime Juice", 0.5, "oz"),
                SeedLine("Cranberry Juice", 0.5, "oz"),
            ]
        ),
        SeedRecipe(
            name: "Moscow Mule", glass: "Copper Mug", method: "Built",
            instructions: "Fill a copper mug with ice. Add vodka and lime juice, then top with ginger beer. Stir gently and garnish with a lime wedge.",
            garnish: "Lime wedge",
            tags: ["vodka", "built", "refreshing", "ginger", "classic"],
            lines: [
                SeedLine("Vodka", 2, "oz"),
                SeedLine("Ginger Beer", 4, "oz", note: "to top"),
                SeedLine("Lime Juice", 0.5, "oz"),
            ]
        ),
        SeedRecipe(
            name: "Aperol Spritz", glass: "Wine", method: "Built",
            instructions: "Fill a wine glass with ice. Add prosecco, then Aperol, then a splash of soda. Stir once and garnish with an orange slice.",
            garnish: "Orange slice",
            tags: ["aperitivo", "built", "refreshing", "bubbly", "low abv"],
            lines: [
                SeedLine("Prosecco", 3, "oz"),
                SeedLine("Aperol", 2, "oz"),
                SeedLine("Soda Water", 1, "oz"),
                SeedLine("Orange Slice", 1, "slice", optional: true),
            ]
        ),
        SeedRecipe(
            name: "Espresso Martini", glass: "Coupe", method: "Shaken",
            instructions: "Shake vodka, coffee liqueur, fresh espresso and syrup hard with ice. Double-strain into a chilled coupe. Garnish with three coffee beans.",
            garnish: "Three coffee beans",
            tags: ["vodka", "shaken", "coffee", "modern classic"],
            lines: [
                SeedLine("Vodka", 2, "oz"),
                SeedLine("Coffee Liqueur", 1, "oz"),
                SeedLine("Espresso", 1, "oz"),
                SeedLine("Simple Syrup", 0.25, "oz", optional: true),
            ]
        ),
        SeedRecipe(
            name: "Sidecar", glass: "Coupe", method: "Shaken",
            instructions: "Shake cognac, orange liqueur and lemon juice with ice until chilled. Double-strain into a chilled coupe (sugar rim optional).",
            garnish: "Sugar rim (optional)",
            tags: ["cognac", "brandy", "shaken", "sour", "classic"],
            lines: [
                SeedLine("Cognac", 2, "oz"),
                SeedLine("Orange Liqueur", 1, "oz"),
                SeedLine("Lemon Juice", 0.75, "oz"),
            ]
        ),
        SeedRecipe(
            name: "Boulevardier", glass: "Rocks", method: "Stirred",
            instructions: "Stir bourbon, Campari and sweet vermouth with ice until chilled. Strain over a large cube in a rocks glass. Garnish with an orange twist.",
            garnish: "Orange twist",
            tags: ["bourbon", "bitter", "stirred", "classic"],
            lines: [
                SeedLine("Bourbon", 1.5, "oz"),
                SeedLine("Campari", 1, "oz"),
                SeedLine("Sweet Vermouth", 1, "oz"),
                SeedLine("Orange Twist", 1, "twist", optional: true),
            ]
        ),
        SeedRecipe(
            name: "Sazerac", glass: "Old Fashioned", method: "Stirred",
            instructions: "Rinse a chilled rocks glass with absinthe and discard the excess. Stir rye, sugar and Peychaud's with ice, then strain into the rinsed glass. Express a lemon peel over the surface.",
            garnish: "Lemon peel",
            tags: ["rye", "whiskey", "stirred", "classic", "spirit-forward"],
            lines: [
                SeedLine("Absinthe", 1, "rinse"),
                SeedLine("Sugar Cube", 1, "cube"),
                SeedLine("Peychaud's Bitters", 3, "dashes"),
                SeedLine("Rye Whiskey", 2, "oz"),
                SeedLine("Lemon Twist", 1, "twist", optional: true),
            ]
        ),
        SeedRecipe(
            name: "French 75", glass: "Flute", method: "Shaken",
            instructions: "Shake gin, lemon juice and simple syrup with ice. Strain into a flute and top with champagne. Garnish with a lemon twist.",
            garnish: "Lemon twist",
            tags: ["gin", "bubbly", "shaken", "classic", "citrus"],
            lines: [
                SeedLine("Gin", 1, "oz"),
                SeedLine("Lemon Juice", 0.5, "oz"),
                SeedLine("Simple Syrup", 0.5, "oz"),
                SeedLine("Champagne", 2, "oz", note: "to top"),
            ]
        ),
        SeedRecipe(
            name: "Mai Tai", glass: "Rocks", method: "Shaken",
            instructions: "Shake both rums, lime juice, curaçao and orgeat with ice. Strain over crushed ice in a rocks glass. Garnish with a spent lime half and a mint sprig.",
            garnish: "Lime shell and mint sprig",
            tags: ["rum", "tiki", "shaken", "classic"],
            lines: [
                SeedLine("White Rum", 1, "oz"),
                SeedLine("Dark Rum", 1, "oz"),
                SeedLine("Lime Juice", 0.75, "oz"),
                SeedLine("Orange Liqueur", 0.5, "oz"),
                SeedLine("Orgeat", 0.5, "oz"),
            ]
        ),
        SeedRecipe(
            name: "Tom Collins", glass: "Collins", method: "Built",
            instructions: "Shake gin, lemon juice and syrup with ice (or build directly). Strain into a Collins glass over fresh ice and top with soda. Garnish with a lemon wheel.",
            garnish: "Lemon wheel",
            tags: ["gin", "built", "refreshing", "classic", "citrus"],
            lines: [
                SeedLine("Gin", 2, "oz"),
                SeedLine("Lemon Juice", 1, "oz"),
                SeedLine("Simple Syrup", 0.5, "oz"),
                SeedLine("Soda Water", 2, "oz", note: "to top"),
            ]
        ),
        SeedRecipe(
            name: "Gimlet", glass: "Coupe", method: "Shaken",
            instructions: "Shake gin, lime juice and simple syrup with ice until well chilled. Double-strain into a chilled coupe. Garnish with a lime wheel.",
            garnish: "Lime wheel",
            tags: ["gin", "shaken", "sour", "classic", "citrus"],
            lines: [
                SeedLine("Gin", 2, "oz"),
                SeedLine("Lime Juice", 0.75, "oz"),
                SeedLine("Simple Syrup", 0.5, "oz"),
            ]
        ),
        SeedRecipe(
            name: "Aviation", glass: "Coupe", method: "Shaken",
            instructions: "Shake gin, maraschino, lemon juice and crème de violette with ice. Double-strain into a chilled coupe. Garnish with a cherry.",
            garnish: "Cherry",
            tags: ["gin", "shaken", "sour", "classic"],
            lines: [
                SeedLine("Gin", 1.5, "oz"),
                SeedLine("Maraschino Liqueur", 0.5, "oz"),
                SeedLine("Lemon Juice", 0.5, "oz"),
                SeedLine("Crème de Violette", 0.25, "oz", optional: true),
            ]
        ),
        SeedRecipe(
            name: "Paper Plane", glass: "Coupe", method: "Shaken",
            instructions: "Shake bourbon, Aperol, amaro and lemon juice with ice until chilled. Double-strain into a chilled coupe. No garnish.",
            garnish: nil,
            tags: ["bourbon", "shaken", "modern classic", "equal parts"],
            lines: [
                SeedLine("Bourbon", 0.75, "oz"),
                SeedLine("Aperol", 0.75, "oz"),
                SeedLine("Amaro Nonino", 0.75, "oz"),
                SeedLine("Lemon Juice", 0.75, "oz"),
            ]
        ),
        SeedRecipe(
            name: "Clover Club", glass: "Coupe", method: "Shaken",
            instructions: "Dry-shake gin, raspberry syrup, lemon juice and egg white, then shake with ice. Double-strain into a chilled coupe.",
            garnish: "Three raspberries",
            tags: ["gin", "shaken", "sour", "classic"],
            lines: [
                SeedLine("Gin", 1.5, "oz"),
                SeedLine("Raspberry Syrup", 0.5, "oz"),
                SeedLine("Lemon Juice", 0.5, "oz"),
                SeedLine("Egg White", 1, "each"),
            ]
        ),
        SeedRecipe(
            name: "Dark 'n' Stormy", glass: "Highball", method: "Built",
            instructions: "Fill a highball with ice. Add ginger beer, then float dark rum on top. Garnish with a lime wedge.",
            garnish: "Lime wedge",
            tags: ["rum", "built", "refreshing", "ginger"],
            lines: [
                SeedLine("Dark Rum", 2, "oz"),
                SeedLine("Ginger Beer", 4, "oz", note: "to top"),
                SeedLine("Lime Wedge", 1, "wedge", optional: true),
            ]
        ),
        SeedRecipe(
            name: "Paloma", glass: "Highball", method: "Built",
            instructions: "Build in a salt-rimmed (optional) highball over ice: tequila, lime juice, then top with grapefruit soda. Garnish with a lime wedge.",
            garnish: "Lime wedge, salt rim (optional)",
            tags: ["tequila", "built", "refreshing", "citrus"],
            lines: [
                SeedLine("Tequila", 2, "oz"),
                SeedLine("Grapefruit Soda", 4, "oz", note: "to top"),
                SeedLine("Lime Juice", 0.5, "oz"),
                SeedLine("Salt", 1, "pinch", optional: true),
            ]
        ),
        SeedRecipe(
            name: "Bee's Knees", glass: "Coupe", method: "Shaken",
            instructions: "Shake gin, honey syrup and lemon juice with ice until chilled. Double-strain into a chilled coupe.",
            garnish: "Lemon twist",
            tags: ["gin", "shaken", "sour", "classic", "honey"],
            lines: [
                SeedLine("Gin", 2, "oz"),
                SeedLine("Honey Syrup", 0.75, "oz"),
                SeedLine("Lemon Juice", 0.75, "oz"),
            ]
        ),
        SeedRecipe(
            name: "Corpse Reviver #2", glass: "Coupe", method: "Shaken",
            instructions: "Shake gin, orange liqueur, Lillet and lemon juice with ice. Strain into an absinthe-rinsed coupe (dash optional). Garnish with an orange peel.",
            garnish: "Orange peel",
            tags: ["gin", "shaken", "sour", "classic", "equal parts"],
            lines: [
                SeedLine("Gin", 0.75, "oz"),
                SeedLine("Orange Liqueur", 0.75, "oz"),
                SeedLine("Lillet Blanc", 0.75, "oz"),
                SeedLine("Lemon Juice", 0.75, "oz"),
                SeedLine("Absinthe", 1, "dashes", optional: true),
            ]
        ),
        SeedRecipe(
            name: "Last Word", glass: "Coupe", method: "Shaken",
            instructions: "Shake gin, green Chartreuse, maraschino and lime juice with ice. Double-strain into a chilled coupe.",
            garnish: nil,
            tags: ["gin", "shaken", "equal parts", "classic", "herbal"],
            lines: [
                SeedLine("Gin", 0.75, "oz"),
                SeedLine("Green Chartreuse", 0.75, "oz"),
                SeedLine("Maraschino Liqueur", 0.75, "oz"),
                SeedLine("Lime Juice", 0.75, "oz"),
            ]
        ),
        SeedRecipe(
            name: "Mint Julep", glass: "Julep Cup", method: "Built",
            instructions: "Gently muddle mint with simple syrup in a julep cup. Add bourbon and fill with crushed ice, churning until the cup frosts. Top with more crushed ice and a big mint bouquet.",
            garnish: "Mint bouquet",
            tags: ["bourbon", "built", "refreshing", "mint", "classic"],
            lines: [
                SeedLine("Mint Leaves", 8, "leaf"),
                SeedLine("Simple Syrup", 0.5, "oz"),
                SeedLine("Bourbon", 2.5, "oz"),
                SeedLine("Crushed Ice", 1, "scoop", optional: true),
            ]
        ),
        SeedRecipe(
            name: "Amaretto Sour", glass: "Rocks", method: "Shaken",
            instructions: "Shake amaretto, lemon juice, syrup and egg white (if using) hard with ice. Strain over fresh ice. Garnish with a cherry and lemon twist.",
            garnish: "Cherry and lemon twist",
            tags: ["amaretto", "shaken", "sour", "sweet"],
            lines: [
                SeedLine("Amaretto", 1.5, "oz"),
                SeedLine("Lemon Juice", 0.75, "oz"),
                SeedLine("Simple Syrup", 0.25, "oz"),
                SeedLine("Egg White", 1, "each", optional: true),
            ]
        ),
        SeedRecipe(
            name: "Hemingway Daiquiri", glass: "Coupe", method: "Shaken",
            instructions: "Shake rum, maraschino, grapefruit and lime juice with ice until chilled. Double-strain into a chilled coupe. Served dry — no sugar, as Papa wanted.",
            garnish: nil,
            tags: ["rum", "shaken", "sour", "classic", "citrus"],
            lines: [
                SeedLine("White Rum", 2, "oz"),
                SeedLine("Maraschino Liqueur", 0.5, "oz"),
                SeedLine("Grapefruit Juice", 0.75, "oz"),
                SeedLine("Lime Juice", 0.5, "oz"),
            ]
        ),
        SeedRecipe(
            name: "Irish Coffee", glass: "Irish Coffee", method: "Built",
            instructions: "Warm a glass mug. Add whiskey and syrup, then hot coffee and stir. Float lightly whipped cream over the back of a warm spoon.",
            garnish: "Lightly whipped cream float",
            tags: ["whiskey", "coffee", "hot", "classic"],
            lines: [
                SeedLine("Irish Whiskey", 1.5, "oz"),
                SeedLine("Hot Coffee", 4, "oz", note: "to top"),
                SeedLine("Demerara Syrup", 0.5, "oz"),
                SeedLine("Cream", 1, "oz", optional: true),
            ]
        ),
    ]
}
