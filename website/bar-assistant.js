(function (root, factory) {
  'use strict';
  if (typeof module === 'object' && module.exports) {
    module.exports = factory(require('./demo-core.js'));
  } else {
    root.PourAssistant = factory(root.PourWeb);
  }
})(globalThis, function (App) {
  'use strict';

  const MAX_SERVINGS = 24;
  const ON_DEVICE_NOTE = 'From recipes and My Bar in this browser.';
  const STARTER_QUESTIONS = [
    'What can I make?',
    'What can I substitute for Campari?',
    'Scale the Negroni for 4',
  ];

  const EXTRA_ALIASES = new Map([
    ['beefeater', 'gin'],
    ['tanqueray', 'gin'],
    ['bombay sapphire', 'gin'],
    ['hendricks', 'gin'],
    ['london dry gin', 'gin'],
    ['dry gin', 'gin'],
    ['plymouth gin', 'gin'],
    ['titos', 'vodka'],
    ['grey goose', 'vodka'],
    ['absolut', 'vodka'],
    ['makers mark', 'bourbon'],
    ['buffalo trace', 'bourbon'],
    ['bulleit bourbon', 'bourbon'],
    ['wild turkey', 'bourbon'],
    ['woodford reserve', 'bourbon'],
    ['rye', 'rye-whiskey'],
    ['rittenhouse', 'rye-whiskey'],
    ['sazerac rye', 'rye-whiskey'],
    ['bulleit rye', 'rye-whiskey'],
    ['jameson', 'irish-whiskey'],
    ['bushmills', 'irish-whiskey'],
    ['bacardi', 'white-rum'],
    ['light rum', 'white-rum'],
    ['silver rum', 'white-rum'],
    ['blanco tequila', 'tequila'],
    ['silver tequila', 'tequila'],
    ['reposado tequila', 'tequila'],
    ['patron', 'tequila'],
    ['espolon', 'tequila'],
    ['cointreau', 'triple-sec'],
    ['grand marnier', 'triple-sec'],
    ['combier', 'triple-sec'],
    ['carpano antica', 'sweet-vermouth'],
    ['rosso vermouth', 'sweet-vermouth'],
    ['dolin rouge', 'sweet-vermouth'],
    ['dolin dry', 'dry-vermouth'],
    ['noilly prat', 'dry-vermouth'],
    ['fresh lime juice', 'lime-juice'],
    ['lime', 'lime-juice'],
    ['fresh lemon juice', 'lemon-juice'],
    ['lemon', 'lemon-juice'],
    ['rich simple syrup', 'simple-syrup'],
    ['sugar syrup', 'simple-syrup'],
    ['angostura', 'angostura-bitters'],
    ['peychauds', 'peychauds-bitters'],
    ['club soda', 'soda-water'],
    ['sparkling water', 'soda-water'],
    ['seltzer', 'soda-water'],
    ['prosecco', 'sparkling-wine'],
    ['champagne', 'sparkling-wine'],
  ]);

  const ASSUMED_AVAILABLE = new Set(['ice', 'water', 'crushed-ice', 'hot-water']);

  const STAND_INS = {
    gin: ['vodka'],
    vodka: ['gin'],
    bourbon: ['rye-whiskey', 'whiskey'],
    'rye-whiskey': ['bourbon', 'whiskey'],
    whiskey: ['bourbon', 'rye-whiskey'],
    scotch: ['irish-whiskey'],
    'irish-whiskey': ['scotch', 'bourbon'],
    'white-rum': ['aged-rum'],
    'aged-rum': ['white-rum', 'dark-rum'],
    'dark-rum': ['aged-rum'],
    tequila: ['mezcal'],
    mezcal: ['tequila'],
    cognac: ['bourbon'],
    campari: ['aperol'],
    aperol: ['campari'],
    'lime-juice': ['lemon-juice'],
    'lemon-juice': ['lime-juice'],
    'simple-syrup': ['honey-syrup', 'agave-syrup', 'demerara-syrup'],
    'honey-syrup': ['simple-syrup', 'agave-syrup'],
    'agave-syrup': ['simple-syrup', 'honey-syrup'],
    'demerara-syrup': ['simple-syrup', 'honey-syrup'],
    grenadine: ['raspberry-syrup'],
    'raspberry-syrup': ['grenadine'],
    'sweet-vermouth': ['blanc-vermouth'],
    'dry-vermouth': ['blanc-vermouth'],
    'blanc-vermouth': ['dry-vermouth', 'sweet-vermouth'],
    'ginger-beer': ['ginger-ale'],
    'ginger-ale': ['ginger-beer'],
    cream: ['milk'],
    milk: ['cream'],
    'angostura-bitters': ['orange-bitters'],
    'orange-bitters': ['angostura-bitters'],
    'triple-sec': ['orange-curacao'],
    'orange-curacao': ['triple-sec'],
  };

  const DIETARY_MARKERS = [
    'allerg', 'intoleran', 'dietary', 'dairy free', 'dairyfree', 'lactose',
    'gluten free', 'glutenfree', 'celiac', 'coeliac', 'vegan', 'vegetarian',
    'nut free', 'nutfree', 'egg free', 'eggfree', 'soy free', 'soyfree',
    'sugar free', 'sugarfree', 'low sugar', 'diabet', 'halal', 'kosher',
    'alcohol free', 'alcoholfree', 'non alcoholic', 'nonalcoholic', 'zero proof',
    'pregnan', 'medication', 'cant have ', 'cannot have ',
    'without dairy', 'no dairy', 'without milk', 'no milk', 'without nuts', 'no nuts',
    'without egg', 'no egg', 'without gluten', 'no gluten', 'without alcohol', 'no alcohol',
    'avoid ', 'avoiding ', 'safe for ', 'sober',
  ];

  const MAKE_PHRASES = [
    'what cocktails can i make',
    'what drinks can i make',
    'which cocktails can i make',
    'which drinks can i make',
    'what am i able to make',
    'what can i make',
    'what can you make',
    'what can i mix',
    'what should i make',
    'what can i drink',
  ];

  const SUBSTITUTION_MARKERS = [
    'substitutes for ',
    'substitute for ',
    'substitution for ',
    'substitutions for ',
    'instead of ',
    'in place of ',
    'stand in for ',
    'swap out ',
    'replace ',
    'dont have ',
    'do not have ',
    'out of ',
    'without ',
  ];

  const MISSING_MARKERS = [
    'what am i missing for ',
    'what am i missing from ',
    'missing ingredients for ',
    'what do i need for ',
    'what do i need to make ',
    'what do i have to make ',
    'can i make ',
  ];

  const RECIPE_MARKERS = ['how do i make ', 'how to make ', 'recipe for '];

  const INVENTORY_PHRASES = [
    'whats in my bar', 'what is in my bar', 'what do i have',
    'whats in stock', 'what is in stock', 'my inventory',
    'whats out of stock', 'what is out of stock', 'out of stock',
    'what do i have in stock', 'what do i have out of stock',
    'show my bar', 'show my inventory', 'list my bar', 'my bar inventory',
  ];

  const PRIVACY_PHRASES = [
    'upload', 'send my', 'send this', 'cloud', 'internet', 'chatgpt', 'openai',
    'api key', 'off this device', 'off the phone', 'remote model', 'remote server',
    'who can see', 'is this private', 'privacy', 'train a model', 'go online',
    'are you online', 'use the internet',
  ];

  const NUMBER_WORDS = {
    one: 1, two: 2, three: 3, four: 4, five: 5,
    six: 6, seven: 7, eight: 8, nine: 9, ten: 10,
    twelve: 12, half: 0.5,
  };

  const SERVING_SUFFIXES = new Set([
    '', 'serving', 'servings', 'person', 'people', 'guest', 'guests',
    'drink', 'drinks', 'cocktail', 'cocktails', 'time', 'times',
  ]);

  const COUNT_UNITS = {
    each: ['', ''], dash: ['dash', 'dashes'], cube: ['cube', 'cubes'],
    twist: ['twist', 'twists'], wedge: ['wedge', 'wedges'], pinch: ['pinch', 'pinches'],
    leaf: ['leaf', 'leaves'], barspoon: ['barspoon', 'barspoons'], part: ['part', 'parts'],
    sprig: ['sprig', 'sprigs'], rinse: ['rinse', 'rinses'], scoop: ['scoop', 'scoops'],
    slice: ['slice', 'slices'],
  };

  function cleanText(raw) {
    return App.normalize(raw)
      .replace(/['’]/gu, '')
      .replace(/[^\p{L}\p{N}]+/gu, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function normalizeQuestion(raw) {
    const str = String(raw || '');
    const pattern = /(^|[^\p{L}\p{N}])([-+−]?(?:\d+(?:\.\d+)?|\.\d+))(?=$|[^\p{L}\p{N}])/gu;
    const parts = [];
    let last = 0;
    for (const match of str.matchAll(pattern)) {
      const lead = match[1];
      const numStart = match.index + lead.length;
      const before = cleanText(str.slice(last, numStart));
      if (before) parts.push(before);
      parts.push(match[2].replace(/−/g, '-'));
      last = numStart + match[2].length;
    }
    const tail = cleanText(str.slice(last));
    if (tail) parts.push(tail);
    return parts.join(' ').trim();
  }

  function trimFiller(raw) {
    let text = String(raw || '').trim();
    const articles = ['the ', 'a ', 'an ', 'my ', 'our '];
    const suffixes = [' please', ' tonight', ' right now', ' now'];
    let changed = true;
    while (changed) {
      changed = false;
      for (const article of articles) {
        if (text.startsWith(article)) {
          text = text.slice(article.length).trim();
          changed = true;
        }
      }
      for (const suffix of suffixes) {
        if (text.endsWith(suffix)) {
          text = text.slice(0, -suffix.length).trim();
          changed = true;
        }
      }
    }
    return text;
  }

  function parseNumber(token) {
    if (Object.prototype.hasOwnProperty.call(NUMBER_WORDS, token)) {
      return NUMBER_WORDS[token];
    }
    if (!/^[-+]?(?:\d+(?:\.\d+)?|\.\d+)$/.test(token)) return null;
    const value = Number(token);
    return Number.isFinite(value) ? value : null;
  }

  function servingsToken(rest) {
    const tokens = rest.split(' ').filter(Boolean);
    if (!tokens.length) return null;
    const value = parseNumber(tokens[0]);
    if (value === null) return null;
    const suffix = tokens.slice(1).join(' ');
    return SERVING_SUFFIXES.has(suffix) ? value : null;
  }

  function trailingServings(text) {
    for (const sep of [' for ', ' to ', ' by ']) {
      const idx = text.lastIndexOf(sep);
      if (idx === -1) continue;
      const name = text.slice(0, idx).trim();
      const rest = text.slice(idx + sep.length).trim();
      const servings = servingsToken(rest);
      if (name && servings !== null) return { name, servings };
    }
    return null;
  }

  function isPlainMakeQuestion(text) {
    if (!MAKE_PHRASES.some(phrase => text.includes(phrase))) return false;
    if (text.includes('substitut') || text.includes('instead of')
        || text.includes('dont have') || text.includes('do not have')
        || text.includes('without ')) {
      return false;
    }
    return true;
  }

  function splitIngredientAndRecipe(phrase) {
    const markers = [
      ' in a ', ' in an ', ' in the ', ' for a ', ' for an ', ' for the ',
      ' from a ', ' from the ', ' in ',
    ];
    for (const marker of markers) {
      const idx = phrase.indexOf(marker);
      if (idx === -1) continue;
      const ingredient = trimFiller(phrase.slice(0, idx));
      const recipeName = trimFiller(phrase.slice(idx + marker.length));
      if (ingredient && recipeName) return { ingredient, recipeName };
    }
    return { ingredient: trimFiller(phrase), recipeName: null };
  }

  function parseSubstitution(text) {
    let earliest = null;
    for (const marker of SUBSTITUTION_MARKERS) {
      const idx = text.indexOf(marker);
      if (idx === -1) continue;
      if (!earliest || idx < earliest.idx) earliest = { idx, end: idx + marker.length };
    }
    if (!earliest) return null;
    const phrase = trimFiller(text.slice(earliest.end));
    const parts = splitIngredientAndRecipe(phrase);
    if (!parts.ingredient) return null;
    return { type: 'substitution', ingredient: parts.ingredient, recipeName: parts.recipeName };
  }

  function parseWhatCanIMake(text) {
    let best = null;
    for (const phrase of MAKE_PHRASES) {
      if (text.includes(phrase) && (!best || phrase.length > best.length)) best = phrase;
    }
    if (!best) return null;
    let rest = text.slice(text.indexOf(best) + best.length).trim();
    if (rest.startsWith('for ')) {
      const token = rest.slice(4).split(' ')[0] || '';
      if (parseNumber(token) !== null) return { type: 'whatCanIMake', focus: null };
    }
    for (const prefix of ['with ', 'using ', 'from ', 'out of ']) {
      if (rest.startsWith(prefix)) {
        rest = rest.slice(prefix.length);
        break;
      }
    }
    const focus = trimFiller(rest);
    if (!focus || focus === 'bar' || focus === 'what i have') {
      return { type: 'whatCanIMake', focus: null };
    }
    return { type: 'whatCanIMake', focus };
  }

  function parseMissing(text) {
    for (const marker of MISSING_MARKERS) {
      const idx = text.indexOf(marker);
      if (idx === -1) continue;
      const recipeQuery = trimFiller(text.slice(idx + marker.length));
      if (recipeQuery) return { type: 'missingIngredients', recipeQuery };
    }
    return null;
  }

  function parseRecipe(text) {
    for (const marker of RECIPE_MARKERS) {
      const idx = text.indexOf(marker);
      if (idx === -1) continue;
      const name = trimFiller(text.slice(idx + marker.length));
      if (!name) return null;
      const parsed = trailingServings(name);
      if (parsed) {
        return { type: 'recipe', recipeQuery: trimFiller(parsed.name), servings: parsed.servings };
      }
      return { type: 'recipe', recipeQuery: name, servings: 1 };
    }
    return null;
  }

  function parseScale(text) {
    const multipliers = [['double', 2], ['triple', 3], ['quadruple', 4], ['half', 0.5]];
    for (const [word, servings] of multipliers) {
      if (text.startsWith(word + ' ')) {
        const recipeQuery = trimFiller(text.slice(word.length + 1));
        if (recipeQuery) return { type: 'scale', recipeQuery, servings };
        return null;
      }
    }
    for (const verb of ['scale ', 'batch ']) {
      if (text.startsWith(verb)) {
        const rest = text.slice(verb.length);
        const parsed = trailingServings(rest);
        if (parsed) {
          const recipeQuery = trimFiller(parsed.name);
          if (recipeQuery) return { type: 'scale', recipeQuery, servings: parsed.servings };
          return null;
        }
        const recipeQuery = trimFiller(rest);
        if (recipeQuery) return { type: 'scale', recipeQuery, servings: null };
        return null;
      }
    }
    const parsed = trailingServings(text);
    if (parsed) {
      const recipeQuery = trimFiller(parsed.name);
      const blocked = ['what', 'substitut', 'missing', 'how', 'help', 'who'];
      if (recipeQuery && !blocked.some(word => recipeQuery.includes(word))) {
        return { type: 'scale', recipeQuery, servings: parsed.servings };
      }
    }
    return null;
  }

  function parseIntent(raw) {
    const text = normalizeQuestion(raw);
    if (!text) return { type: 'empty' };
    if (PRIVACY_PHRASES.some(phrase => text.includes(phrase))) return { type: 'privacy' };
    if (DIETARY_MARKERS.some(marker => text.includes(marker))) {
      return { type: 'unsupportedDietaryRequest' };
    }
    if (['help', 'help me', 'help please'].includes(text)
        || ['what can you do', 'what do you do', 'how does this work', 'how do you work']
          .some(phrase => text.includes(phrase))) {
      return { type: 'help' };
    }
    const trimmed = trimFiller(text);
    if (INVENTORY_PHRASES.some(phrase => trimmed === trimFiller(phrase))) {
      return { type: 'inventory' };
    }
    const sub = parseSubstitution(text);
    if (sub && !isPlainMakeQuestion(text)) return sub;
    const make = parseWhatCanIMake(text);
    if (make) return make;
    const missing = parseMissing(text);
    if (missing) return missing;
    const recipe = parseRecipe(text);
    if (recipe) return recipe;
    const scale = parseScale(text);
    if (scale) return scale;
    return { type: 'unrecognized' };
  }

  function canonicalID(raw) {
    const cleaned = cleanText(raw);
    if (EXTRA_ALIASES.has(cleaned)) return EXTRA_ALIASES.get(cleaned);
    const slug = cleaned.replace(/\s+/g, '-');
    if (EXTRA_ALIASES.has(slug)) return EXTRA_ALIASES.get(slug);
    const catalogMatch = App.inventory.find(item => item.id === slug);
    if (catalogMatch) return catalogMatch.id;
    return slug;
  }

  function titled(raw) {
    return String(raw || '')
      .replace(/-/g, ' ')
      .split(/\s+/)
      .filter(Boolean)
      .map(word => word[0].toUpperCase() + word.slice(1))
      .join(' ');
  }

  function listed(items) {
    if (items.length === 0) return '';
    if (items.length === 1) return items[0];
    if (items.length === 2) return items[0] + ' and ' + items[1];
    return items.slice(0, -1).join(', ') + ', and ' + items[items.length - 1];
  }

  function allRecipes(state) {
    return [...App.recipes, ...(state?.customRecipes || [])];
  }

  function ingredientNameMap(state) {
    const map = new Map();
    for (const item of App.listIngredients(state)) map.set(item.id, item.name);
    return map;
  }

  function displayName(id, names) {
    return names.get(id) || titled(id);
  }

  function makeReply(text, followUps) {
    const unique = [];
    for (const item of followUps || []) {
      if (item && !unique.includes(item)) unique.push(item);
    }
    return { text, followUps: unique, sourceNote: ON_DEVICE_NOTE };
  }

  function containsPhrase(text, phrase) {
    if (!phrase || phrase.length < 3) return false;
    return (' ' + text + ' ').includes(' ' + phrase + ' ');
  }

  function findRecipe(query, recipes) {
    const q = cleanText(query);
    if (!q) return { kind: 'none' };
    const exact = recipes.filter(r => cleanText(r.name) === q);
    if (exact.length === 1) return { kind: 'one', recipe: exact[0] };
    if (exact.length > 1) return { kind: 'many', recipes: exact };

    const contained = recipes.filter(r => containsPhrase(q, cleanText(r.name)));
    if (contained.length) {
      const bestLen = Math.max(...contained.map(r => cleanText(r.name).length));
      const tied = contained.filter(r => cleanText(r.name).length === bestLen);
      if (tied.length === 1) return { kind: 'one', recipe: tied[0] };
      return { kind: 'many', recipes: tied.sort((a, b) => a.name.localeCompare(b.name)) };
    }

    const partial = recipes.filter(r => containsPhrase(cleanText(r.name), q));
    if (partial.length === 1) return { kind: 'one', recipe: partial[0] };
    if (partial.length > 1) {
      return { kind: 'many', recipes: partial.sort((a, b) => a.name.localeCompare(b.name)) };
    }

    const terms = q.split(' ').filter(Boolean);
    const searched = recipes.filter(r => {
      const hay = cleanText([r.name, r.method, r.glass, ...(r.tags || []),
        ...r.ingredients.map(i => i.name)].join(' '));
      return terms.every(term => hay.includes(term));
    });
    if (searched.length === 1) return { kind: 'one', recipe: searched[0] };
    if (searched.length > 1) {
      return { kind: 'many', recipes: searched.sort((a, b) => a.name.localeCompare(b.name)) };
    }
    return { kind: 'none' };
  }

  function clarification(found, prompt, followUps) {
    const normalizedNames = found.map(r => cleanText(r.name));
    if (new Set(normalizedNames).size < normalizedNames.length) {
      return makeReply(
        'Your library has multiple recipes with the same name. Give them distinct names in the recipe editor so I can select the right one. I haven\'t selected a recipe.',
        ['What can I make?']
      );
    }
    const names = listed(found.slice(0, 5).map(r => r.name));
    return makeReply(prompt + ' I found ' + names + '.', followUps);
  }

  function formatNumber(value) {
    if (value > 0 && value < 0.001) return Number(value.toPrecision(2)).toString();
    return Number(value.toFixed(3)).toString();
  }

  function formatScaledMeasure(amount, unit, factor, preference) {
    if (!Number.isFinite(amount) || amount < 0) return '—';
    const scaled = amount * factor;
    if (unit === 'oz' || unit === 'ml') {
      const target = preference === 'ml' ? 'ml' : 'oz';
      const conv = unit === target ? 1 : unit === 'oz' ? 29.5735 : 1 / 29.5735;
      return formatNumber(scaled * conv) + ' ' + target;
    }
    if (unit === 'topUp') return 'to top';
    if (unit === 'rinse' && scaled === 0) return 'rinse';
    const pair = COUNT_UNITS[unit === 'dashes' ? 'dash' : unit] || [unit, unit];
    const label = pair[scaled === 1 ? 0 : 1];
    return [formatNumber(scaled), label].filter(Boolean).join(' ');
  }

  function servingsPhrase(factor) {
    if (factor === 0.5) return 'half the written spec';
    if (Number.isInteger(factor)) {
      return factor + ' ' + (factor === 1 ? 'serving' : 'servings');
    }
    return formatNumber(factor) + ' times the written spec';
  }

  function buildSpec(recipe, factor, unit, includeInstructions) {
    const lines = [recipe.name + ' for ' + servingsPhrase(factor) + ':'];
    for (const line of recipe.ingredients) {
      const measure = formatScaledMeasure(line.amount, line.unit, factor, unit);
      const optional = line.optional ? ' (optional)' : '';
      lines.push('• ' + measure + ' ' + line.name + optional);
    }
    const meta = [recipe.method, recipe.glass].filter(Boolean);
    if (meta.length) {
      lines.push('');
      lines.push(meta.join(' · '));
    }
    if (recipe.garnish) lines.push('Garnish: ' + recipe.garnish);
    if (includeInstructions && recipe.instructions) {
      lines.push('');
      lines.push(recipe.instructions);
    }
    lines.push('');
    lines.push('Measures use the same scaling as the recipe screen.');
    return lines.join('\n');
  }

  function answerWhatCanIMake(focus, state) {
    const recipes = allRecipes(state);
    if (!recipes.length) {
      return makeReply('Your recipe library is empty, so there is nothing to match yet.', STARTER_QUESTIONS);
    }
    if (!state.inventory.length) {
      return makeReply('My Bar is empty, so nothing can be matched yet. Stock a bottle or tap Stock a starter bar, then ask again.', ['What can I make?']);
    }

    let pool = recipes;
    if (focus) {
      const parts = focus.split(' and ').map(p => p.trim()).filter(Boolean);
      if (parts.length) {
        pool = recipes.filter(recipe => parts.every(part => {
          const cid = canonicalID(part);
          return recipe.ingredients.some(line => line.id === cid || canonicalID(line.name) === cid);
        }));
      }
      if (!pool.length) {
        return makeReply('I don\'t have a drink that uses ' + titled(focus) + ' in your recipes.', ['What can I make?']);
      }
    }

    const matches = pool.map(recipe => ({ recipe, ...App.matchRecipe(recipe, state.inventory) }));
    const ready = matches.filter(m => m.canMake).sort((a, b) => a.recipe.name.localeCompare(b.recipe.name));
    const almost = matches
      .filter(m => !m.canMake && m.missing.length >= 1 && m.missing.length <= 2)
      .sort((a, b) => a.missing.length - b.missing.length || a.recipe.name.localeCompare(b.recipe.name));

    const lines = [];
    if (!ready.length) {
      lines.push(focus
        ? 'No drinks that use ' + titled(focus) + ' can be made from what\'s in stock.'
        : 'Nothing in your recipes can be made from what\'s in stock.');
    } else {
      const noun = ready.length === 1 ? 'drink' : 'drinks';
      lines.push('You can make ' + ready.length + ' ' + noun + ' from My Bar:');
      for (const m of ready.slice(0, 8)) lines.push('• ' + m.recipe.name);
      if (ready.length > 8) lines.push('And ' + (ready.length - 8) + ' more.');
    }

    if (almost.length) {
      if (lines.length) lines.push('');
      lines.push('Almost there:');
      for (const m of almost.slice(0, 4)) {
        lines.push('• ' + m.recipe.name + ' - missing ' + m.missing.map(i => i.name).join(', '));
      }
    }

    const followUps = [];
    if (ready[0]) followUps.push('Scale the ' + ready[0].recipe.name + ' for 4');
    if (almost[0]) followUps.push('What am I missing for a ' + almost[0].recipe.name + '?');
    if (!followUps.length) followUps.push('What can I substitute for Campari?');
    return makeReply(lines.join('\n'), followUps);
  }

  function answerSubstitution(rawIngredient, recipeName, state) {
    const recipes = allRecipes(state);
    const names = ingredientNameMap(state);
    const stocked = new Set(state.inventory);
    const cid = canonicalID(rawIngredient);
    const display = titled(rawIngredient);
    const canonicalDisplay = displayName(cid, names);
    const lines = [];
    let resolvedRecipe = null;

    if (recipeName) {
      const hit = findRecipe(recipeName, recipes);
      if (hit.kind === 'many') {
        return clarification(
          hit.recipes,
          'Which drink do you mean?',
          hit.recipes.slice(0, 3).map(r => 'What can I substitute for ' + rawIngredient + ' in a ' + r.name + '?')
        );
      }
      if (hit.kind === 'one') {
        resolvedRecipe = hit.recipe;
        const used = hit.recipe.ingredients.some(line => line.id === cid || canonicalID(line.name) === cid);
        if (used) {
          lines.push(hit.recipe.name + ' uses ' + (cid === cleanText(rawIngredient).replace(/\s+/g, '-') ? display : canonicalDisplay) + '.');
        } else {
          lines.push(hit.recipe.name + ' doesn\'t call for ' + display + '.');
        }
      } else {
        lines.push('I could not find ' + titled(recipeName) + ' in your recipes.');
      }
    }

    const normalizedSlug = cleanText(rawIngredient).replace(/\s+/g, '-');
    if (cid !== normalizedSlug) {
      lines.push(display + ' already counts as ' + canonicalDisplay + ' in your bar.');
    }

    const standIns = STAND_INS[cid] || [];
    if (!standIns.length && cid === normalizedSlug) {
      lines.push('I don\'t have a stand-in for ' + display + ' in the offline list.');
    } else if (standIns.length) {
      lines.push('If you\'re out, these change the drink:');
      for (const alt of standIns) {
        const status = stocked.has(alt) ? 'in your bar' : 'not in your bar';
        lines.push('• ' + displayName(alt, names) + ' - ' + status);
      }
    }

    if (ASSUMED_AVAILABLE.has(cid)) {
      lines.push(canonicalDisplay + ' is treated as already on hand.');
    } else if (stocked.has(cid)) {
      lines.push(display + ' is in your bar.');
    } else {
      lines.push(display + ' is not in your bar.');
    }

    const followUps = ['What can I make?'];
    if (resolvedRecipe) followUps.push('Scale the ' + resolvedRecipe.name + ' for 4');
    return makeReply(lines.join('\n'), followUps);
  }

  function answerScaledRecipe(recipe, servings, state, includeInstructions) {
    if (!Number.isFinite(servings) || servings <= 0) {
      return makeReply('Servings have to be greater than zero.', ['Scale the ' + recipe.name + ' for 4']);
    }
    const factor = Math.min(servings, MAX_SERVINGS);
    const lead = servings > MAX_SERVINGS
      ? 'PourSTL Web scales up to ' + MAX_SERVINGS + ' servings. Showing ' + recipe.name + ' for ' + MAX_SERVINGS + ' servings.\n\n'
      : '';
    return makeReply(
      lead + buildSpec(recipe, factor, state.unit, includeInstructions),
      ['What can I make?', 'What am I missing for a ' + recipe.name + '?']
    );
  }

  function answerScale(query, servings, state) {
    const hit = findRecipe(query, allRecipes(state));
    if (hit.kind === 'none') {
      return makeReply('I could not find ' + titled(query) + ' in your recipes. Try the drink\'s full name.', STARTER_QUESTIONS);
    }
    if (hit.kind === 'many') {
      return clarification(
        hit.recipes,
        'Which drink should I scale?',
        hit.recipes.slice(0, 3).map(r => 'Scale the ' + r.name + ' for 4')
      );
    }
    if (servings === null || servings === undefined) {
      return makeReply(
        'How many servings should I scale ' + hit.recipe.name + ' to?',
        ['Scale the ' + hit.recipe.name + ' for 4', 'Half the ' + hit.recipe.name]
      );
    }
    return answerScaledRecipe(hit.recipe, servings, state, false);
  }

  function answerMissing(query, state) {
    const hit = findRecipe(query, allRecipes(state));
    if (hit.kind === 'none') {
      return makeReply('I could not find ' + titled(query) + ' in your recipes.', ['What can I make?']);
    }
    if (hit.kind === 'many') {
      return clarification(
        hit.recipes,
        'Which drink do you mean?',
        hit.recipes.slice(0, 3).map(r => 'What am I missing for a ' + r.name + '?')
      );
    }
    const match = App.matchRecipe(hit.recipe, state.inventory);
    const lines = [];
    if (match.canMake) {
      lines.push('You can make ' + hit.recipe.name + ' with what\'s in stock.');
    } else {
      lines.push(hit.recipe.name + ' still needs ' + listed(match.missing.map(i => i.name)) + '.');
    }
    if (match.optionalMissing.length) {
      lines.push('Optional and not in your bar: ' + listed(match.optionalMissing.map(i => i.name)) + '.');
    }
    return makeReply(lines.join('\n'), ['Scale the ' + hit.recipe.name + ' for 4', 'What can I make?']);
  }

  function answerRecipe(query, servings, state) {
    const hit = findRecipe(query, allRecipes(state));
    if (hit.kind === 'none') {
      return makeReply('I could not find ' + titled(query) + ' in your recipes.', ['What can I make?']);
    }
    if (hit.kind === 'many') {
      return clarification(
        hit.recipes,
        'Which drink do you mean?',
        hit.recipes.slice(0, 3).map(r => 'How do I make a ' + r.name + '?')
      );
    }
    return answerScaledRecipe(hit.recipe, servings, state, true);
  }

  function answerInventory(state) {
    if (!state.inventory.length) {
      return makeReply('My Bar is empty. Stock a bottle and I can match drinks against it.', ['What can I make?']);
    }
    const names = ingredientNameMap(state);
    const stockedNames = state.inventory.map(id => displayName(id, names)).sort((a, b) => a.localeCompare(b));
    const lines = ['In stock (' + stockedNames.length + '): ' + listed(stockedNames.slice(0, 12)) + '.'];
    if (stockedNames.length > 12) lines.push('And ' + (stockedNames.length - 12) + ' more in stock.');
    if (state.shopping.length) {
      const shoppingNames = state.shopping.map(id => displayName(id, names)).sort((a, b) => a.localeCompare(b));
      lines.push('On your shopping list (' + shoppingNames.length + '): ' + listed(shoppingNames.slice(0, 8)) + '.');
    }
    return makeReply(lines.join('\n'), ['What can I make?']);
  }

  function answer(question, state) {
    const current = state || App.defaults();
    const intent = parseIntent(question);
    switch (intent.type) {
      case 'empty':
        return makeReply('Ask what you can make, what can stand in for a bottle, or how to scale a recipe.', STARTER_QUESTIONS);
      case 'privacy':
        return makeReply(
          'This offline recipe helper uses a fixed set of question patterns and your recipes and My Bar in this browser. It does not use an AI model or send questions anywhere. This conversation is cleared when you close the dialog.',
          STARTER_QUESTIONS
        );
      case 'unsupportedDietaryRequest':
        return makeReply(
          'I can\'t verify allergies, dietary restrictions, or whether a drink is alcohol-free. Recipes and stand-ins aren\'t checked for those needs. Check every ingredient\'s label and the manufacturer\'s information before choosing a drink.',
          []
        );
      case 'help':
      case 'unrecognized':
        return makeReply(
          'I\'m an offline recipe helper with a fixed set of question patterns. Ask what you can make with My Bar, a stand-in for an ingredient, missing ingredients, or scaled measures. Stock matching checks ingredient presence, not bottle quantities or dietary needs.',
          STARTER_QUESTIONS
        );
      case 'inventory':
        return answerInventory(current);
      case 'whatCanIMake':
        return answerWhatCanIMake(intent.focus, current);
      case 'substitution':
        return answerSubstitution(intent.ingredient, intent.recipeName, current);
      case 'scale':
        return answerScale(intent.recipeQuery, intent.servings, current);
      case 'missingIngredients':
        return answerMissing(intent.recipeQuery, current);
      case 'recipe':
        return answerRecipe(intent.recipeQuery, intent.servings, current);
      default:
        return makeReply(
          'I\'m an offline recipe helper with a fixed set of question patterns. Ask what you can make with My Bar, a stand-in for an ingredient, missing ingredients, or scaled measures.',
          STARTER_QUESTIONS
        );
    }
  }

  return {
    ON_DEVICE_NOTE,
    STARTER_QUESTIONS,
    STAND_INS,
    parseIntent,
    answer,
  };
});
