(function (root, factory) {
  'use strict';
  if (typeof module === 'object' && module.exports) {
    module.exports = factory(require('./recipe-catalog.js'));
  } else {
    root.PourWeb = factory(pourRecipeCatalog);
  }
})(globalThis, function (catalog) {
  'use strict';

  const legacyIngredientIDs = new Map([['rye', 'rye-whiskey']]);
  const ingredientAliases = new Map([
    ...legacyIngredientIDs,
    ['london-dry-gin', 'gin'], ['blanco-tequila', 'tequila'],
    ['sugar-cube', 'sugar-cubes'], ['mint-leaves', 'mint'],
    ['angostura', 'angostura-bitters'], ['peychauds', 'peychauds-bitters'],
  ]);
  const volumeUnits = ['oz', 'ml'];
  const countUnits = {
    each: ['', ''], dash: ['dash', 'dashes'], cube: ['cube', 'cubes'],
    twist: ['twist', 'twists'], wedge: ['wedge', 'wedges'], pinch: ['pinch', 'pinches'],
    leaf: ['leaf', 'leaves'], barspoon: ['barspoon', 'barspoons'], part: ['part', 'parts'],
    sprig: ['sprig', 'sprigs'], rinse: ['rinse', 'rinses'], scoop: ['scoop', 'scoops'],
    slice: ['slice', 'slices'],
  };
  const units = [...volumeUnits, ...Object.keys(countUnits), 'topUp'];
  const starterInventory = ['gin', 'campari', 'sweet-vermouth'];
  const maxCustomRecipes = 250;

  function normalize(value) {
    return String(value || '').normalize('NFKD').replace(/\p{M}/gu, '').toLowerCase().trim();
  }

  function ingredientID(name) {
    const id = normalize(name).replace(/['’]/gu, '').replace(/[^\p{L}\p{N}]+/gu, '-').replace(/^-|-$/g, '');
    return ingredientAliases.get(id) || id;
  }

  const recipes = catalog.map(recipe => ({
    ...recipe,
    ingredients: recipe.ingredients.map(line => ({ ...line, id: ingredientID(line.name) })),
  })).sort((a, b) => Number(b.id === 'negroni') - Number(a.id === 'negroni') || a.name.localeCompare(b.name));
  const catalogNames = new Map();
  for (const recipe of recipes) {
    for (const line of recipe.ingredients) {
      if (!catalogNames.has(line.id)) catalogNames.set(line.id, line.name);
    }
  }

  const recipeIDs = new Set(recipes.map(recipe => recipe.id));
  const inventory = [...catalogNames].map(([id, name]) => ({ id, name }));

  function defaults() {
    return {
      version: 2, inventory: [], shopping: [], servings: 1, unit: 'oz', selected: 'negroni',
      customRecipes: [], ingredientNames: [], favorites: [],
    };
  }

  function cleanIDs(value, allowed, legacyIDs) {
    if (!Array.isArray(value)) return [];
    return [...new Set(value.filter(id => typeof id === 'string')
      .map(id => legacyIDs?.get(id) ?? id).filter(id => allowed.has(id)))];
  }

  function boundedServings(value) {
    return typeof value === 'number' && Number.isFinite(value) ? Math.max(1, Math.min(24, Math.trunc(value))) : 1;
  }

  function boundedText(value, limit) {
    return typeof value === 'string' ? value.trim().slice(0, limit) : '';
  }

  function validateRecipe(raw) {
    if (!raw || !/^custom-[a-f0-9-]{36}$/.test(raw.id)) return null;
    const name = boundedText(raw.name, 80);
    const instructions = boundedText(raw.instructions, 1500);
    if (!name || !instructions || !Array.isArray(raw.ingredients)
        || raw.ingredients.length < 1 || raw.ingredients.length > 40) return null;

    const ingredients = [];
    for (const line of raw.ingredients) {
      const ingredientName = boundedText(line?.name, 80);
      const id = ingredientID(ingredientName);
      const unit = line?.unit;
      const amount = unit === 'topUp' ? 0 : line?.amount;
      if (!id || !units.includes(unit) || !Number.isFinite(amount) || amount > 10_000
          || (unit !== 'topUp' && amount <= 0)) return null;
      ingredients.push({
        id, name: ingredientName, amount, unit, optional: line.optional === true, note: boundedText(line.note, 120),
      });
    }
    return {
      id: raw.id, name, instructions, ingredients, garnish: boundedText(raw.garnish, 100),
      glass: boundedText(raw.glass, 40), method: boundedText(raw.method, 40),
      tags: [], image: null,
    };
  }

  function validateState(raw) {
    const fallback = defaults();
    if (!raw || ![1, 2].includes(raw.version)) return fallback;
    const customRecipes = new Map();
    const addedNames = new Map();
    for (const value of Array.isArray(raw.customRecipes) ? raw.customRecipes.slice(0, maxCustomRecipes) : []) {
      const recipe = validateRecipe(value);
      if (recipe) customRecipes.set(recipe.id, recipe);
    }
    for (const value of Array.isArray(raw.ingredientNames) ? raw.ingredientNames.slice(0, 10_000) : []) {
      const name = boundedText(value, 80);
      const id = ingredientID(name);
      if (id && !catalogNames.has(id)) addedNames.set(id, name);
    }
    for (const recipe of customRecipes.values()) {
      for (const { id, name } of recipe.ingredients) {
        if (!catalogNames.has(id) && !addedNames.has(id)) addedNames.set(id, name);
      }
    }
    const allNames = new Map([...catalogNames, ...addedNames]);
    const allRecipes = new Set([...recipeIDs, ...customRecipes.keys()]);
    const stocked = cleanIDs(raw.inventory, allNames, legacyIngredientIDs);
    const shopping = cleanIDs(raw.shopping, allNames, legacyIngredientIDs);
    return {
      version: 2, inventory: stocked, shopping: raw.version === 1 ? shopping.filter(id => !stocked.includes(id)) : shopping,
      servings: boundedServings(raw.servings), unit: raw.unit === 'ml' ? 'ml' : 'oz',
      selected: allRecipes.has(raw.selected) ? raw.selected : fallback.selected,
      customRecipes: [...customRecipes.values()], ingredientNames: [...addedNames.values()],
      favorites: cleanIDs(raw.favorites, allRecipes),
    };
  }

  function listIngredients(state) {
    return [...inventory, ...state.ingredientNames.map(name => ({ id: ingredientID(name), name }))]
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  function resolveRecipe(recipe, customRecipes = []) {
    if (recipe?.ingredients) return recipe;
    return [...recipes, ...customRecipes].find(item => item.id === recipe);
  }

  function matchRecipe(recipe, stockIDs) {
    const spec = resolveRecipe(recipe);
    if (!spec) return { canMake: false, missing: [], optionalMissing: [] };
    const stocked = new Set(stockIDs);
    const missing = spec.ingredients.filter(item => !item.optional && !stocked.has(item.id));
    const optionalMissing = spec.ingredients.filter(item => item.optional && !stocked.has(item.id));
    return { canMake: missing.length === 0, missing, optionalMissing };
  }

  function searchRecipes(query, filter, state) {
    const terms = normalize(query).split(/\s+/).filter(Boolean);
    return [...recipes, ...state.customRecipes].filter(recipe => {
      if (filter === 'favorites' && !state.favorites.includes(recipe.id)) return false;
      if (filter === 'can-make' && !matchRecipe(recipe, state.inventory).canMake) return false;
      const text = normalize([recipe.name, recipe.method, recipe.glass, ...recipe.tags,
        ...recipe.ingredients.map(item => item.name)].join(' '));
      return terms.every(term => text.includes(term));
    });
  }

  function recipeEmptyState(query, filter) {
    return !normalize(query) && (filter === 'favorites' || filter === 'can-make') ? filter : 'search';
  }

  function formatNumber(value) {
    if (value > 0 && value < 0.001) return Number(value.toPrecision(2)).toString();
    return Number(value.toFixed(3)).toString();
  }

  function formatMeasure(amount, unit, servings, preference) {
    if (!Number.isFinite(amount) || amount < 0) return '—';
    const scaled = amount * boundedServings(servings);
    if (volumeUnits.includes(unit)) {
      const target = preference === 'ml' ? 'ml' : 'oz';
      const factor = unit === target ? 1 : unit === 'oz' ? 29.5735 : 1 / 29.5735;
      return formatNumber(scaled * factor) + ' ' + target;
    }
    if (unit === 'topUp') return 'to top';
    if (unit === 'rinse' && scaled === 0) return 'rinse';
    const pair = countUnits[unit === 'dashes' ? 'dash' : unit] || [unit, unit];
    const label = pair[scaled === 1 ? 0 : 1];
    return [formatNumber(scaled), label].filter(Boolean).join(' ');
  }

  function addIngredient(state, rawName, destination) {
    const name = boundedText(rawName, 80);
    const id = ingredientID(name);
    if (!id || !['inventory', 'shopping'].includes(destination)) return state;
    const known = listIngredients(state).some(item => item.id === id);
    return validateState({
      ...state, [destination]: [...state[destination], id],
      ingredientNames: known ? state.ingredientNames : [...state.ingredientNames, name],
    });
  }

  function addMissing(state, recipe) {
    const spec = resolveRecipe(recipe, state.customRecipes);
    if (!spec) return state;
    const missing = matchRecipe(spec, state.inventory).missing.map(item => item.id);
    return validateState({ ...state, shopping: [...state.shopping, ...missing] });
  }

  function purchase(state, id) {
    if (!state.shopping.includes(id)) return state;
    return validateState({
      ...state, inventory: [...state.inventory, id], shopping: state.shopping.filter(item => item !== id),
    });
  }

  function recipeText(recipe, servings, unit) {
    const spec = resolveRecipe(recipe);
    if (!spec) return '';
    const count = boundedServings(servings);
    return [
      spec.name + ' — ' + count + (count === 1 ? ' serving' : ' servings'),
      [spec.method, spec.glass].filter(Boolean).join(' · '),
      '',
      ...spec.ingredients.map(item => [
        formatMeasure(item.amount, item.unit, count, unit), item.name,
        item.optional ? '(optional)' : '', item.note ? '— ' + item.note : '',
      ].filter(Boolean).join(' ')),
      '', spec.instructions,
      ...(spec.garnish ? ['Garnish: ' + spec.garnish] : []),
      '', 'From PourSTL. Check ingredients and allergies before serving.',
    ].join('\n');
  }

  return {
    inventory, recipes, units, starterInventory, maxCustomRecipes, defaults, validateState,
    validateRecipe, resolveRecipe, listIngredients, normalize, matchRecipe, searchRecipes, recipeEmptyState, formatMeasure,
    addIngredient, addMissing, purchase, recipeText,
  };
});
