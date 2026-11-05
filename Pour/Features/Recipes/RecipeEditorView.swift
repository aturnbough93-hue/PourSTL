import SwiftUI
import SwiftData

/// Create or edit a custom recipe. Glass selection uses the spec's
/// corrected SF Symbol mapping.
struct RecipeEditorView: View {
    let recipe: Recipe?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showSaveError = false
    @State private var name = ""
    @State private var glassType = "Coupe"
    @State private var method = "Shaken"
    @State private var instructions = ""
    @State private var garnish = ""
    @State private var tagsText = ""
    @State private var lines: [EditableLine] = [EditableLine()]

    struct EditableLine: Identifiable {
        let id = UUID()
        var name = ""
        var amount: Double = 1
        var unit: BarUnit = .ounce
        var isOptional = false
        var note = ""
    }

    private var canSave: Bool {
        let namedLines = lines.filter { !IngredientNormalizer.normalize($0.name).isEmpty }
        return !IngredientNormalizer.normalize(name).isEmpty
            && !namedLines.isEmpty
            && namedLines.allSatisfy { Measure(amount: $0.amount, unit: $0.unit).isValidRecipeAmount }
    }

    private let methods = ["Shaken", "Stirred", "Built", "Muddled", "Blended", "Layered", "Hot"]

    init(recipe: Recipe? = nil) {
        self.recipe = recipe
        if let recipe {
            _name = State(initialValue: recipe.name)
            _glassType = State(initialValue: recipe.glassType.isEmpty ? "Coupe" : recipe.glassType)
            _method = State(initialValue: recipe.method.isEmpty ? "Shaken" : recipe.method)
            _instructions = State(initialValue: recipe.instructions)
            _garnish = State(initialValue: recipe.garnish ?? "")
            _tagsText = State(initialValue: recipe.tags.joined(separator: ", "))
            _lines = State(initialValue: recipe.sortedIngredients.map {
                EditableLine(name: $0.name, amount: $0.amount, unit: BarUnit.parse($0.unit), isOptional: $0.isOptional, note: $0.note ?? "")
            })
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name", text: $name)
                        .accessibilityLabel("Recipe name")
                    Picker("Method", selection: $method) {
                        ForEach(methods, id: \.self) { Text($0).tag($0) }
                    }
                    .accessibilityLabel("Method")
                    TextField("Garnish (optional)", text: $garnish)
                    TextField("Tags, comma separated", text: $tagsText)
                        .autocorrectionDisabled()
                }

                Section {
                    glassPicker
                } header: {
                    Text("Glass")
                        .accessibilityLabel("Glass type, \(glassType)")
                }

                Section {
                    ForEach($lines) { $line in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                TextField("Ingredient", text: $line.name)
                                    .frame(maxWidth: .infinity)
                                    .accessibilityLabel("Ingredient name")
                                TextField("1.5", value: $line.amount, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                    .accessibilityLabel("Measure for \(line.name.isEmpty ? "ingredient" : line.name)")
                                Picker("Unit", selection: $line.unit) {
                                    ForEach(BarUnit.allCases, id: \.self) { unit in
                                        Text(unit.displayName.isEmpty ? "each" : unit.displayName).tag(unit)
                                    }
                                }
                                .labelsHidden()
                                .accessibilityLabel("Unit for \(line.name.isEmpty ? "ingredient" : line.name)")
                                Button {
                                    lines.removeAll { $0.id == line.id }
                                    Haptics.lightTick()
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(PourColor.destructive)
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .accessibilityLabel("Remove \(line.name.isEmpty ? "ingredient" : line.name)")
                                .accessibilityAddTraits(.isButton)
                            }
                            HStack(spacing: 8) {
                                TextField("Note (e.g. \"to top\")", text: $line.note)
                                    .font(.caption)
                                    .accessibilityLabel("Note for \(line.name.isEmpty ? "ingredient" : line.name)")
                                Spacer()
                                Button {
                                    line.isOptional.toggle()
                                    Haptics.selection()
                                } label: {
                                    Text("optional")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(line.isOptional ? .black : PourColor.textTertiary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(line.isOptional ? PourColor.accentFill : PourColor.surface, in: Capsule())
                                }
                                .accessibilityLabel("\(line.name.isEmpty ? "Ingredient" : line.name) optional, \(line.isOptional ? "on" : "off")")
                                .accessibilityAddTraits(.isButton)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    Button {
                        lines.append(EditableLine())
                        Haptics.selection()
                    } label: {
                        Label("Add ingredient", systemImage: "plus.circle")
                    }
                    .accessibilityLabel("Add ingredient")
                    .accessibilityAddTraits(.isButton)
                } header: {
                    Text("Ingredients")
                } footer: {
                    Text("Use positive amounts. Rinses and top-ups can be left at zero.")
                }

                Section("Method") {
                    TextEditor(text: $instructions)
                        .frame(minHeight: 100)
                        .accessibilityLabel("Instructions")
                }
            }
            .scrollContentBackground(.hidden)
            .background(PourColor.background)
            .navigationTitle(recipe == nil ? "New recipe" : "Edit recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel")
                        .accessibilityAddTraits(.isButton)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .accessibilityLabel("Save recipe")
                        .accessibilityAddTraits(.isButton)
                }
            }
            .alert("Recipe wasn’t saved", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your edits are still here. Check available device storage and try again.")
            }
        }
    }

    /// Glass-type picker rendered as a wrapping grid of SF Symbols per spec mapping.
    private var glassPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76))], spacing: 10) {
            ForEach(GlassIcon.pickerGlasses, id: \.self) { glass in
                let selected = glass == glassType
                Button {
                    glassType = glass
                    Haptics.selection()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selected ? GlassIcon.fillSymbol(for: glass) : GlassIcon.symbol(for: glass))
                            .font(.title3)
                        Text(glass)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(selected ? .black : PourColor.textSecondary)
                    .background(selected ? PourColor.accentFill : PourColor.surface, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? .clear : PourColor.border))
                }
                .accessibilityLabel("Glass type, \(glass)\(selected ? ", selected" : "")")
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.vertical, 4)
    }

    private func save() {
        guard canSave else { return }
        let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        let validLines = lines.filter { !IngredientNormalizer.normalize($0.name).isEmpty }

        if let recipe {
            recipe.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            recipe.glassType = glassType
            recipe.method = method
            recipe.instructions = instructions
            recipe.garnish = garnish.isEmpty ? nil : garnish
            recipe.tags = tags
            recipe.isCustom = true
            for line in recipe.ingredients { modelContext.delete(line) }
            recipe.ingredients = []
            for (index, line) in validLines.enumerated() {
                recipe.ingredients.append(IngredientLine(
                    name: line.name.trimmingCharacters(in: .whitespaces),
                    amount: line.amount,
                    unit: line.unit.rawValue,
                    note: line.note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : line.note.trimmingCharacters(in: .whitespaces),
                    isOptional: line.isOptional,
                    position: index
                ))
            }
        } else {
            let new = Recipe(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                glassType: glassType,
                method: method,
                instructions: instructions,
                garnish: garnish.isEmpty ? nil : garnish,
                tags: tags,
                isCustom: true
            )
            for (index, line) in validLines.enumerated() {
                new.ingredients.append(IngredientLine(
                    name: line.name.trimmingCharacters(in: .whitespaces),
                    amount: line.amount,
                    unit: line.unit.rawValue,
                    note: line.note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : line.note.trimmingCharacters(in: .whitespaces),
                    isOptional: line.isOptional,
                    position: index
                ))
            }
            modelContext.insert(new)
        }
        do {
            try modelContext.save()
            Haptics.success()
            dismiss()
        } catch {
            modelContext.rollback()
            showSaveError = true
        }
    }
}
