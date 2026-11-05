(function (root, factory) {
  'use strict';
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.PourDemo = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  function freeze(value) {
    Object.values(value).forEach(child => {
      if (child && typeof child === 'object') freeze(child);
    });
    return Object.freeze(value);
  }

  const inventory = freeze([
    { id: 'gin', name: 'Gin', category: 'Spirits' },
    { id: 'campari', name: 'Campari', category: 'Liqueurs & modifiers' },
    { id: 'sweet-vermouth', name: 'Sweet vermouth', category: 'Liqueurs & modifiers' },
    { id: 'white-rum', name: 'White rum', category: 'Spirits' },
    { id: 'bourbon', name: 'Bourbon', category: 'Spirits' },
    { id: 'tequila', name: 'Blanco tequila', category: 'Spirits' },
    { id: 'dry-vermouth', name: 'Dry vermouth', category: 'Liqueurs & modifiers' },
    { id: 'orange-liqueur', name: 'Orange liqueur', category: 'Liqueurs & modifiers' },
    { id: 'lime-juice', name: 'Lime juice', category: 'Citrus & syrups' },
    { id: 'lemon-juice', name: 'Lemon juice', category: 'Citrus & syrups' },
    { id: 'simple-syrup', name: 'Simple syrup', category: 'Citrus & syrups' },
    { id: 'sugar-cubes', name: 'Sugar cubes', category: 'Citrus & syrups' },
    { id: 'angostura-bitters', name: 'Angostura bitters', category: 'Bitters' }
  ]);

  function ingredient(id, name, amount, unit = 'oz', optional = false) {
    return { id, name, amount, unit, optional };
  }

  // These six specs mirror Pour/Services/SeedData.swift. Matching is based on
  // required ingredients, not bottle quantities, equipment, garnish, or allergies.
  const recipes = freeze([
    {
      id: 'negroni', name: 'Negroni', glass: 'Rocks', method: 'Stirred',
      image: 'assets/negroni.webp',
      instructions: 'Add gin, Campari and sweet vermouth to a mixing glass with ice. Stir until chilled. Strain over a large ice cube in a rocks glass. Garnish with an orange twist.',
      garnish: 'Orange twist', tags: ['gin', 'bitter', 'stirred', 'classic', 'equal parts'],
      ingredients: [ingredient('gin', 'Gin', 1), ingredient('campari', 'Campari', 1), ingredient('sweet-vermouth', 'Sweet Vermouth', 1), ingredient('orange-twist', 'Orange Twist', 1, 'twist', true)]
    },
    {
      id: 'martini', name: 'Martini', glass: 'Martini', method: 'Stirred', image: null,
      instructions: 'Add gin and vermouth to a mixing glass filled with ice. Stir until well chilled, about 20 seconds. Strain into a chilled martini glass. Express a lemon twist over the surface, or garnish with olives.',
      garnish: 'Lemon twist or olives', tags: ['gin', 'stirred', 'spirit-forward', 'classic', 'up'],
      ingredients: [ingredient('gin', 'London Dry Gin', 2.5), ingredient('dry-vermouth', 'Dry Vermouth', 0.5), ingredient('orange-bitters', 'Orange Bitters', 1, 'dash', true)]
    },
    {
      id: 'daiquiri', name: 'Daiquiri', glass: 'Coupe', method: 'Shaken', image: 'assets/daiquiri.webp',
      instructions: 'Shake rum, lime juice and simple syrup with ice until well chilled. Double-strain into a chilled coupe. No garnish needed.',
      garnish: null, tags: ['rum', 'shaken', 'sour', 'classic', 'citrus'],
      ingredients: [ingredient('white-rum', 'White Rum', 2), ingredient('lime-juice', 'Lime Juice', 1), ingredient('simple-syrup', 'Simple Syrup', 0.75)]
    },
    {
      id: 'old-fashioned', name: 'Old Fashioned', glass: 'Old Fashioned', method: 'Built', image: 'assets/old-fashioned.webp',
      instructions: 'Place the sugar cube in a rocks glass and saturate with bitters. Muddle until dissolved. Add bourbon and a large ice cube, then stir briefly to chill and dilute. Express an orange twist over the top.',
      garnish: 'Orange twist', tags: ['bourbon', 'whiskey', 'stirred', 'classic', 'spirit-forward'],
      ingredients: [ingredient('sugar-cubes', 'Sugar Cube', 1, 'cube'), ingredient('angostura-bitters', 'Angostura Bitters', 3, 'dash'), ingredient('bourbon', 'Bourbon', 2), ingredient('orange-twist', 'Orange Twist', 1, 'twist', true)]
    },
    {
      id: 'margarita', name: 'Margarita', glass: 'Rocks', method: 'Shaken', image: null,
      instructions: 'Shake tequila, lime juice and orange liqueur with ice until chilled. Strain over fresh ice in a salt-rimmed rocks glass (rim optional). Garnish with a lime wedge.',
      garnish: 'Lime wedge, salt rim (optional)', tags: ['tequila', 'shaken', 'sour', 'classic', 'citrus'],
      ingredients: [ingredient('tequila', 'Tequila', 2), ingredient('lime-juice', 'Lime Juice', 1), ingredient('orange-liqueur', 'Orange Liqueur', 1), ingredient('salt', 'Salt', 1, 'pinch', true), ingredient('lime-wedge', 'Lime Wedge', 1, 'wedge', true)]
    },
    {
      id: 'whiskey-sour', name: 'Whiskey Sour', glass: 'Rocks', method: 'Shaken', image: null,
      instructions: 'Shake bourbon, lemon juice, syrup and egg white (if using) without ice for 10 seconds, then add ice and shake hard. Strain over fresh ice. Garnish with a cherry or lemon wheel.',
      garnish: 'Cherry or lemon wheel', tags: ['bourbon', 'whiskey', 'shaken', 'sour', 'classic'],
      ingredients: [ingredient('bourbon', 'Bourbon', 2), ingredient('lemon-juice', 'Lemon Juice', 0.75), ingredient('simple-syrup', 'Simple Syrup', 0.75), ingredient('egg-white', 'Egg White', 1, 'each', true), ingredient('angostura-bitters', 'Angostura Bitters', 3, 'dash', true)]
    }
  ]);

  const inventoryIDs = new Set(inventory.map(item => item.id));
  const recipeIDs = new Set(recipes.map(recipe => recipe.id));
  const startingInventory = ['gin', 'campari', 'sweet-vermouth'];

  function defaults() {
    return { version: 1, inventory: startingInventory.slice(), shopping: [], servings: 1, unit: 'oz', selected: 'negroni' };
  }

  function cleanIDs(value, fallback) {
    if (!Array.isArray(value)) return fallback.slice();
    return [...new Set(value.filter(id => typeof id === 'string' && inventoryIDs.has(id)))];
  }

  function boundedServings(value) {
    return typeof value === 'number' && Number.isFinite(value) ? Math.max(1, Math.min(24, Math.trunc(value))) : 1;
  }

  function validateState(raw) {
    const fallback = defaults();
    if (!raw || typeof raw !== 'object' || Array.isArray(raw) || raw.version !== 1) return fallback;
    const stocked = cleanIDs(raw.inventory, fallback.inventory);
    return {
      version: 1,
      inventory: stocked,
      shopping: cleanIDs(raw.shopping, []).filter(id => !stocked.includes(id)),
      servings: boundedServings(raw.servings),
      unit: raw.unit === 'ml' ? 'ml' : 'oz',
      selected: recipeIDs.has(raw.selected) ? raw.selected : fallback.selected
    };
  }

  function resolveRecipe(recipe) {
    return recipes.find(item => item.id === (typeof recipe === 'string' ? recipe : recipe && recipe.id));
  }

  function matchRecipe(recipe, stockIDs) {
    const spec = resolveRecipe(recipe);
    if (!spec) return { canMake: false, missing: [], optionalMissing: [] };
    const stocked = new Set(cleanIDs(stockIDs, []));
    const missing = spec.ingredients.filter(item => !item.optional && !stocked.has(item.id));
    const optionalMissing = spec.ingredients.filter(item => item.optional && !stocked.has(item.id));
    return { canMake: missing.length === 0, missing, optionalMissing };
  }

  function normalize(value) {
    return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim();
  }

  function searchRecipes(query, filter, stockIDs) {
    const terms = normalize(query).split(/\s+/).filter(Boolean);
    const canMakeOnly = ['can-make', 'canMake', 'can'].includes(filter);
    return recipes.filter(recipe => {
      const text = normalize([recipe.name, recipe.method, recipe.glass, ...recipe.tags, ...recipe.ingredients.map(item => item.name)].join(' '));
      return terms.every(term => text.includes(term)) && (!canMakeOnly || matchRecipe(recipe, stockIDs).canMake);
    });
  }

  function formatNumber(value) {
    return Number(value.toFixed(2)).toString();
  }

  function formatMeasure(amount, unit, servings, preference) {
    if (!Number.isFinite(amount) || amount < 0) return '—';
    const scaled = amount * boundedServings(servings);
    if (unit === 'oz' || unit === 'ml') {
      const requestedUnit = preference === 'ml' ? 'ml' : 'oz';
      const factor = unit === requestedUnit ? 1 : unit === 'oz' ? 29.5735 : 1 / 29.5735;
      return `${formatNumber(scaled * factor)} ${requestedUnit}`;
    }
    if (unit === 'topUp') return 'to top';
    const labels = {
      each: ['', ''], dash: ['dash', 'dashes'], dashes: ['dash', 'dashes'],
      cube: ['cube', 'cubes'], twist: ['twist', 'twists'], wedge: ['wedge', 'wedges'],
      pinch: ['pinch', 'pinches'], leaf: ['leaf', 'leaves'], barspoon: ['barspoon', 'barspoons'],
      part: ['part', 'parts'], sprig: ['sprig', 'sprigs'], rinse: ['rinse', 'rinses']
    };
    const pair = Object.prototype.hasOwnProperty.call(labels, unit) ? labels[unit] : [unit, unit];
    const label = pair[scaled === 1 ? 0 : 1];
    return `${formatNumber(scaled)}${label ? ' ' + label : ''}`;
  }

  function addMissing(state, recipe) {
    const next = validateState(state);
    const missing = matchRecipe(recipe, next.inventory).missing.map(item => item.id);
    next.shopping = [...new Set([...next.shopping, ...missing])];
    return next;
  }

  function purchase(state, id) {
    const next = validateState(state);
    // Only an item actually on the list can be purchased. This keeps stale UI
    // actions and unknown storage values from creating inventory entries.
    if (next.shopping.includes(id) && inventoryIDs.has(id)) {
      next.inventory = [...new Set([...next.inventory, id])];
      next.shopping = next.shopping.filter(item => item !== id);
    }
    return next;
  }

  function recipeText(recipe, servings, unit) {
    const spec = resolveRecipe(recipe);
    if (!spec) return '';
    const count = boundedServings(servings);
    return [
      `${spec.name} — ${count} ${count === 1 ? 'serving' : 'servings'}`,
      `${spec.method} · ${spec.glass}`,
      '',
      ...spec.ingredients.map(item => `${formatMeasure(item.amount, item.unit, count, unit)} ${item.name}${item.optional ? ' (optional)' : ''}`),
      '', spec.instructions,
      ...(spec.garnish ? [`Garnish: ${spec.garnish}`] : []),
      '', 'From the Pour browser demo. Check ingredients and allergies before serving.'
    ].join('\n');
  }

  return freeze({ inventory, recipes, defaults, validateState, matchRecipe, searchRecipes, formatMeasure, addMissing, purchase, recipeText });
});
