'use strict';
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const assert = require('node:assert/strict');
const Demo = require('../website/demo-core.js');
const Assistant = require('../website/bar-assistant.js');

test('catalog has the native specs and all required ingredients exist in inventory', () => {
  assert.ok(Demo.recipes.length >= 31);
  const ids = new Set(Demo.inventory.map(item => item.id));
  for (const recipe of Demo.recipes) {
    for (const line of recipe.ingredients.filter(line => !line.optional)) assert.ok(ids.has(line.id));
  }
  assert.equal(Demo.recipes.find(recipe => recipe.id === 'martini').ingredients[0].amount, 2.5);
  assert.equal(Demo.recipes.find(recipe => recipe.id === 'daiquiri').ingredients[2].amount, 0.75);
});

test('new bars start empty and the starter bar can make a Negroni without garnish', () => {
  const first = Demo.defaults();
  const second = Demo.defaults();
  assert.deepEqual(second.inventory, []);
  first.inventory.push('gin');
  assert.deepEqual(second.inventory, []);
  const match = Demo.matchRecipe('negroni', Demo.starterInventory);
  assert.equal(match.canMake, true);
  assert.deepEqual(match.missing, []);
  assert.deepEqual(match.optionalMissing.map(item => item.id), ['orange-twist']);
});

test('taking a bottle out of stock immediately changes matching and can-make filter', () => {
  const state = Demo.defaults();
  state.inventory = Demo.starterInventory.slice();
  assert.deepEqual(Demo.searchRecipes('', 'can-make', state).map(item => item.id), ['negroni']);
  state.inventory = state.inventory.filter(id => id !== 'campari');
  assert.equal(Demo.matchRecipe('negroni', state.inventory).canMake, false);
  assert.deepEqual(Demo.matchRecipe('negroni', state.inventory).missing.map(item => item.id), ['campari']);
  assert.equal(Demo.searchRecipes('', 'can-make', state).length, 0);
});

test('search matches recipe names, normalized ingredient terms and tags', () => {
  const state = Demo.defaults();
  state.inventory = Demo.inventory.map(item => item.id);
  assert.ok(Demo.searchRecipes('  DÁIQUIRI ', 'all', state).some(item => item.id === 'daiquiri'));
  assert.ok(Demo.searchRecipes('dry vermouth', 'all', state).some(item => item.id === 'martini'));
  assert.ok(Demo.searchRecipes('bourbon sour', 'all', state).some(item => item.id === 'whiskey-sour'));
  assert.ok(Demo.searchRecipes('rum', 'can-make', state).length > 3);
  assert.equal(Demo.searchRecipes('nonexistent', 'all', state).length, 0);
});

test('filter empty states offer specific guidance only without a search query', () => {
  assert.equal(Demo.recipeEmptyState('', 'favorites'), 'favorites');
  assert.equal(Demo.recipeEmptyState('  ', 'can-make'), 'can-make');
  assert.equal(Demo.recipeEmptyState('', 'all'), 'search');
  for (const filter of ['all', 'favorites', 'can-make']) {
    assert.equal(Demo.recipeEmptyState('nonexistent', filter), 'search');
  }
});

test('malformed persisted values reset safely without leaking arbitrary fields', () => {
  for (const bad of [null, undefined, false, 'bad json', [], { version: 3 }]) assert.deepEqual(Demo.validateState(bad), Demo.defaults());
  const state = Demo.validateState({version: 1, inventory: ['gin', 'gin', '__proto__', {}, null, 'unknown'], shopping: ['dry-vermouth', 'dry-vermouth', 'constructor'], servings: Infinity, selected: '__proto__', unit: 'html', unsafe: '<script>'});
  assert.deepEqual(state, {...Demo.defaults(), inventory: ['gin'], shopping: ['dry-vermouth']});
  assert.deepEqual(Demo.validateState({version: 1, inventory: [], shopping: []}).inventory, []);
  assert.deepEqual(Demo.validateState({version: 1, inventory: ['gin'], shopping: ['gin', 'campari']}).shopping, ['campari']);
});

test('servings are integer-bounded and only known recipe/unit selections survive', () => {
  assert.equal(Demo.validateState({version: 1, servings: 99}).servings, 24);
  assert.equal(Demo.validateState({version: 1, servings: -5}).servings, 1);
  assert.equal(Demo.validateState({version: 1, servings: 2.9}).servings, 2);
  assert.equal(Demo.validateState({version: 1, servings: '9'}).servings, 1);
  assert.equal(Demo.validateState({version: 1, selected: 'martini', unit: 'ml'}).selected, 'martini');
  assert.equal(Demo.validateState({version: 1, selected: 'martini', unit: 'ml'}).unit, 'ml');
});

test('shopping deduplicates missing ingredients and purchasing changes recipe availability', () => {
  const state = Demo.defaults();
  state.inventory = ['gin'];
  const once = Demo.addMissing(state, 'martini');
  const twice = Demo.addMissing(once, 'martini');
  assert.deepEqual(twice.shopping, ['dry-vermouth']);
  assert.deepEqual(state.shopping, []);
  assert.equal(Demo.matchRecipe('martini', twice.inventory).canMake, false);
  const purchased = Demo.purchase(twice, 'dry-vermouth');
  assert.equal(Demo.matchRecipe('martini', purchased.inventory).canMake, true);
  assert.deepEqual(purchased.shopping, []);
  assert.deepEqual(Demo.purchase(purchased, '__proto__'), purchased);
  assert.deepEqual(Demo.purchase(purchased, 'bourbon'), purchased);
});

test('shopping shared ingredient is listed once across recipes', () => {
  let state = {...Demo.defaults(), inventory: []};
  state = Demo.addMissing(state, 'martini');
  state = Demo.addMissing(state, 'negroni');
  assert.equal(state.shopping.filter(id => id === 'gin').length, 1);
  assert.equal(state.shopping.length, 4);
});

test('scaling and conversion retain small/countable native units', () => {
  assert.equal(Demo.formatMeasure(2, 'oz', 1, 'ml'), '59.147 ml');
  assert.equal(Demo.formatMeasure(0.75, 'oz', 3, 'ml'), '66.54 ml');
  assert.equal(Demo.formatMeasure(2.5, 'oz', 2, 'oz'), '5 oz');
  assert.equal(Demo.formatMeasure(29.5735, 'ml', 1, 'oz'), '1 oz');
  assert.equal(Demo.formatMeasure(3, 'dash', 2, 'ml'), '6 dashes');
  assert.equal(Demo.formatMeasure(1, 'cube', 1, 'ml'), '1 cube');
  assert.equal(Demo.formatMeasure(1, 'cube', 2, 'ml'), '2 cubes');
  assert.equal(Demo.formatMeasure(1, 'each', 2, 'oz'), '2');
  assert.equal(Demo.formatMeasure(NaN, 'oz', 2, 'ml'), '—');
  assert.equal(Demo.formatMeasure(1, 'oz', 500, 'oz'), '24 oz');
});

test('copied recipe text includes selected quantities, optional items, and full instructions', () => {
  const text = Demo.recipeText('old-fashioned', 2, 'ml');
  assert.match(text, /Old Fashioned — 2 servings/);
  assert.match(text, /118\.294 ml Bourbon/);
  assert.match(text, /6 dashes Angostura Bitters/);
  assert.match(text, /2 twists Orange Twist \(optional\)/);
  assert.match(text, /Muddle until dissolved/);
  assert.match(text, /Check ingredients and allergies/);
  assert.equal(Demo.recipeText('not-a-recipe', 1, 'oz'), '');
});

test('custom recipes, flavors, and favorites survive validation and can use the shopping flow', () => {
  const id = 'custom-7d8cc6b0-4650-4b35-a9b7-a465a1e3352d';
  const recipe = {
    id, name: 'Yuzu Fizz', instructions: 'Stir over ice.',
    ingredients: [
      { name: 'Yuzu syrup', amount: 20, unit: 'ml', note: 'Use chilled' },
      { name: 'Soda water', unit: 'topUp', optional: true },
    ],
  };
  let state = Demo.validateState({
    ...Demo.defaults(), customRecipes: [recipe], favorites: [id], selected: id,
  });
  assert.equal(state.selected, id);
  assert.equal(Demo.searchRecipes('yuzu', 'favorites', state)[0].id, id);
  assert.ok(Demo.recipeText(state.customRecipes[0], 2, 'ml').includes('40 ml Yuzu syrup — Use chilled'));
  state = Demo.addMissing(state, id);
  assert.deepEqual(state.shopping, ['yuzu-syrup']);
  state = Demo.purchase(state, 'yuzu-syrup');
  assert.equal(Demo.matchRecipe(state.customRecipes[0], state.inventory).canMake, true);
  const reloaded = Demo.validateState(JSON.parse(JSON.stringify(state)));
  assert.deepEqual(reloaded, state);
  const deleted = Demo.validateState({ ...reloaded, customRecipes: [] });
  assert.deepEqual(deleted.favorites, []);
  assert.deepEqual(deleted.inventory, ['yuzu-syrup']);
});

test('manual shopping supports restocking and preserves previous browser data', () => {
  let state = Demo.validateState({ version: 1, inventory: ['gin'], shopping: ['dry-vermouth'], selected: 'martini' });
  state = Demo.addIngredient(state, 'Gin', 'shopping');
  state = Demo.addIngredient(state, 'Agave nectar', 'inventory');
  assert.deepEqual(state.inventory, ['gin', 'agave-nectar']);
  assert.deepEqual(state.shopping, ['dry-vermouth', 'gin']);
  assert.equal(state.selected, 'martini');
  assert.deepEqual(Demo.purchase(state, 'gin').inventory, state.inventory);
  assert.equal(Demo.addIngredient(state, '  ', 'inventory'), state);
});

function bootTryPage({ compact = false, singleColumn = false } = {}) {
  const siteDir = path.join(__dirname, '..', 'website');
  const html = fs.readFileSync(path.join(siteDir, 'try.html'), 'utf8');
  const ids = new Set([...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]));

  const doc = { activeElement: null };
  class FakeElement {
    constructor(tag, id = '', className = '') {
      this.tagName = tag.toUpperCase();
      this.id = id;
      this.className = className;
      this.hidden = false;
      this.disabled = false;
      this.checked = false;
      this.value = '';
      this.textContent = '';
      this.children = [];
      this.parentNode = null;
      this.dataset = {};
      this.style = {};
      this.attributes = new Map();
      this.listeners = new Map();
      this.focusCount = 0;
      this.classList = {
        toggle: (name, force) => {
          const classes = new Set(this.className.split(/\s+/).filter(Boolean));
          const add = force === undefined ? !classes.has(name) : Boolean(force);
          if (add) classes.add(name);
          else classes.delete(name);
          this.className = [...classes].join(' ');
        },
      };
    }
    get firstElementChild() { return this.children[0] || null; }
    get lastElementChild() { return this.children[this.children.length - 1] || null; }
    setAttribute(name, value) { this.attributes.set(name, String(value)); }
    getAttribute(name) { return this.attributes.get(name) ?? null; }
    addEventListener(type, listener) {
      if (!this.listeners.has(type)) this.listeners.set(type, []);
      this.listeners.get(type).push(listener);
    }
    remove() {
      if (!this.parentNode) return;
      this.parentNode.children = this.parentNode.children.filter(child => child !== this);
      this.parentNode = null;
    }
    append(...nodes) {
      for (const node of nodes) {
        if (typeof node === 'string') continue;
        node.remove();
        node.parentNode = this;
        this.children.push(node);
      }
    }
    prepend(...nodes) {
      for (let i = nodes.length - 1; i >= 0; i--) {
        const node = nodes[i];
        if (typeof node === 'string') continue;
        node.remove();
        node.parentNode = this;
        this.children.unshift(node);
      }
    }
    replaceChildren(...nodes) {
      for (const child of this.children) child.parentNode = null;
      this.children = [];
      this.append(...nodes);
    }
    contains(target) {
      let current = target;
      while (current) {
        if (current === this) return true;
        current = current.parentNode;
      }
      return false;
    }
    focus() {
      doc.activeElement = this;
      this.focusCount += 1;
    }
    querySelector(selector) {
      const classMatch = /^\.([a-z0-9-]+)$/i.exec(selector);
      for (const child of this.children) {
        if (classMatch && child.className.split(/\s+/).includes(classMatch[1])) return child;
        const found = child.querySelector(selector);
        if (found) return found;
      }
      return null;
    }
  }

  const byId = new Map();
  for (const id of ids) {
    const el = new FakeElement('div', id);
    if (id === 'workspace' || id === 'manual-copy') el.hidden = true;
    byId.set(id, el);
  }
  const barPanel = new FakeElement('section', '', 'panel bar-panel');
  const recipesPanel = new FakeElement('section', '', 'panel recipes-panel');
  const detailPanel = new FakeElement('section', '', 'panel detail-panel');
  byId.get('inventory-controls').append(byId.get('stock-name'));
  barPanel.append(byId.get('bar-title'), byId.get('inventory-toggle'), byId.get('inventory-controls'));
  byId.get('workspace').append(barPanel, recipesPanel, detailPanel);

  const root = new FakeElement('body');
  root.append(byId.get('workspace'));

  doc.body = root;
  doc.getElementById = id => byId.get(id) || null;
  doc.querySelector = selector => root.querySelector(selector);
  doc.createElement = tag => new FakeElement(tag);
  doc.createElementNS = (_ns, tag) => new FakeElement(tag);
  doc.createTextNode = text => ({ textContent: String(text), remove() {}, parentNode: null });

  const mediaQueries = new Map();
  const makeMediaQuery = (query, initial) => {
    const listeners = [];
    const mql = {
      media: query,
      matches: initial,
      addEventListener(type, fn) { if (type === 'change') listeners.push(fn); },
      setMatches(next) {
        this.matches = next;
        for (const fn of listeners) fn({ matches: next, media: query });
      },
    };
    mediaQueries.set(query, mql);
    return mql;
  };

  const storage = new Map();
  const win = {
    document: doc,
    navigator: {},
    localStorage: {
      getItem: key => (storage.has(key) ? storage.get(key) : null),
      setItem: (key, value) => storage.set(key, String(value)),
      removeItem: key => storage.delete(key),
    },
    matchMedia(query) {
      if (mediaQueries.has(query)) return mediaQueries.get(query);
      if (query.includes('1000px')) return makeMediaQuery(query, compact);
      if (query.includes('700px')) return makeMediaQuery(query, singleColumn);
      return makeMediaQuery(query, false);
    },
    addEventListener() {},
    setInterval: () => 0,
    clearInterval() {},
    confirm: () => true,
    crypto: globalThis.crypto,
  };
  win.window = win;

  const context = vm.createContext(win);
  for (const file of ['recipe-catalog.js', 'demo-core.js', 'bar-assistant.js', 'try.js']) {
    vm.runInContext(fs.readFileSync(path.join(siteDir, file), 'utf8'), context, { filename: file });
  }
  return { byId, doc, barPanel, recipesPanel, detailPanel, mediaQueries };
}

test('/try starts cleanly and orders panels for desktop and single-column viewports', () => {
  const desktop = bootTryPage({ compact: false, singleColumn: false });
  assert.equal(desktop.byId.get('workspace').hidden, false);
  assert.equal(desktop.byId.get('workspace').firstElementChild, desktop.barPanel);
  assert.ok(desktop.byId.get('recipes').children.length >= 31);

  const phone = bootTryPage({ compact: true, singleColumn: true });
  assert.equal(phone.byId.get('workspace').hidden, false);
  assert.equal(phone.byId.get('workspace').lastElementChild, phone.barPanel);

  // Breakpoint toggle moves My Bar between end and start while preserving focus inside it.
  const stockInput = desktop.byId.get('stock-name');
  stockInput.focus();
  const focusBefore = stockInput.focusCount;
  const singleColumn = desktop.mediaQueries.get('(max-width: 700px)');
  singleColumn.setMatches(true);
  assert.equal(desktop.byId.get('workspace').lastElementChild, desktop.barPanel);
  assert.equal(desktop.doc.activeElement, stockInput);
  assert.ok(stockInput.focusCount > focusBefore);

  singleColumn.setMatches(false);
  assert.equal(desktop.byId.get('workspace').firstElementChild, desktop.barPanel);
  assert.equal(desktop.doc.activeElement, stockInput);
});

test('service worker redirects /try/ to the cached offline app route', async () => {
  const origin = 'https://pourstl.com';
  const handlers = new Map();
  const appPage = new Response('PourSTL Web');
  const worker = fs.readFileSync(path.join(__dirname, '..', 'website', 'web-app-worker.js'), 'utf8');
  vm.runInNewContext(worker, {
    self: { location: { origin }, addEventListener: (type, handler) => handlers.set(type, handler) },
    caches: { open: async () => ({ match: async entry => entry === '/try' ? appPage : undefined }) },
    fetch: () => { throw new Error('Network unavailable'); },
    URL,
    Response,
  });
  function dispatch(request) {
    let response;
    handlers.get('fetch')({ request, respondWith: value => { response = value; } });
    return response;
  }
  const request = { url: origin + '/try/?saved=1', method: 'GET', mode: 'navigate' };
  const redirect = await dispatch(request);
  assert.ok(redirect, 'worker handles the trailing-slash navigation');
  assert.equal(redirect.status, 308);
  const url = redirect.headers.get('Location');
  assert.equal(url, origin + '/try?saved=1');
  assert.equal(await dispatch({ ...request, url }), appPage);
  assert.equal(dispatch({ ...request, mode: 'cors' }), undefined);
  assert.equal(dispatch({ ...request, url: origin + '/support/' }), undefined);
});

test('bar assistant parses intents accurately including scaling, substitutions, dietary, and privacy', () => {
  assert.deepEqual(Assistant.parseIntent('What can I make?'), { type: 'whatCanIMake', focus: null });
  assert.deepEqual(Assistant.parseIntent('What can I make with Beefeater?'), { type: 'whatCanIMake', focus: 'beefeater' });
  assert.deepEqual(Assistant.parseIntent('What can I substitute for Campari?'), { type: 'substitution', ingredient: 'campari', recipeName: null });
  assert.deepEqual(Assistant.parseIntent("I don't have Campari in a Negroni"), { type: 'substitution', ingredient: 'campari', recipeName: 'negroni' });
  assert.deepEqual(Assistant.parseIntent('Scale the Negroni for 4'), { type: 'scale', recipeQuery: 'negroni', servings: 4 });
  assert.deepEqual(Assistant.parseIntent('Half the Daiquiri'), { type: 'scale', recipeQuery: 'daiquiri', servings: 0.5 });
  assert.deepEqual(Assistant.parseIntent('Scale Negroni for -2'), { type: 'scale', recipeQuery: 'negroni', servings: -2 });
  assert.deepEqual(Assistant.parseIntent('How do I make a Negroni for 4?'), { type: 'recipe', recipeQuery: 'negroni', servings: 4 });
  assert.deepEqual(Assistant.parseIntent('What am I missing for a Martini?'), { type: 'missingIngredients', recipeQuery: 'martini' });
  assert.deepEqual(Assistant.parseIntent("What's in my bar?"), { type: 'inventory', mode: 'stocked' });
  assert.deepEqual(Assistant.parseIntent("What's out of stock?"), { type: 'inventory', mode: 'outOfStock' });
  assert.deepEqual(Assistant.parseIntent('Do you upload my bar to the cloud?'), { type: 'privacy' });
  assert.deepEqual(Assistant.parseIntent('Do you use cloud storage?'), { type: 'privacy' });
  assert.deepEqual(Assistant.parseIntent('Are my questions saved?'), { type: 'privacy' });
  assert.deepEqual(Assistant.parseIntent('Scale the Cloud Nine for 4'), { type: 'scale', recipeQuery: 'cloud nine', servings: 4 });
  assert.deepEqual(Assistant.parseIntent('What can I make with extra virgin olive oil?'), { type: 'whatCanIMake', focus: 'extra virgin olive oil' });
  assert.deepEqual(Assistant.parseIntent('What can I make tonight?'), { type: 'whatCanIMake', focus: null });
  assert.deepEqual(Assistant.parseIntent('How do I make a Negroni for 1/2?'), { type: 'recipe', recipeQuery: 'negroni', servings: 0.5 });
  assert.deepEqual(Assistant.parseIntent('What is gluten free and vegan?'), { type: 'unsupportedDietaryRequest' });
  assert.deepEqual(Assistant.parseIntent('How do I make a virgin Margarita?'), { type: 'unsupportedDietaryRequest' });
  assert.deepEqual(Assistant.parseIntent('   '), { type: 'empty' });
  assert.deepEqual(Assistant.parseIntent('Tell me a joke'), { type: 'unrecognized' });
});

test('bar assistant answers from My Bar, custom recipes, stand-ins, and scaling preferences', () => {
  const empty = Demo.defaults();
  const emptyReply = Assistant.answer('What can I make?', empty);
  assert.match(emptyReply.text, /My Bar is empty/);
  assert.equal(emptyReply.sourceNote, Assistant.ON_DEVICE_NOTE);

  const emptyWithShopping = Assistant.answer("What's in my bar?", { ...empty, shopping: ['dry-vermouth'] });
  assert.match(emptyWithShopping.text, /My Bar is empty/);
  assert.match(emptyWithShopping.text, /On your shopping list \(1\): Dry Vermouth\./);

  const state = { ...Demo.defaults(), inventory: [...Demo.starterInventory, 'aperol'], unit: 'ml' };
  const makeReply = Assistant.answer('What can I make?', state);
  assert.match(makeReply.text, /You can make 1 drink from My Bar:/);
  assert.match(makeReply.text, /Negroni/);

  const focusReply = Assistant.answer('What can I make with Beefeater?', state);
  assert.match(focusReply.text, /Negroni/);

  const unstockedOptionalFocus = Assistant.answer('What can I make with Orange Twist?', state);
  assert.match(unstockedOptionalFocus.text, /No drinks that use Orange Twist can be made/);
  assert.match(unstockedOptionalFocus.text, /Negroni - missing Orange Twist/);

  const subReply = Assistant.answer('What can I substitute for Campari in a Negroni?', state);
  assert.match(subReply.text, /Negroni uses Campari/);
  assert.match(subReply.text, /Aperol - in your bar/);

  const proseccoSub = Assistant.answer('What can I substitute for Prosecco?', { ...Demo.defaults(), inventory: ['prosecco'] });
  assert.match(proseccoSub.text, /Prosecco is in your bar/);

  const constructorSub = Assistant.answer('What can I substitute for constructor?', state);
  assert.match(constructorSub.text, /don't have a stand-in/);

  const scaleMl = Assistant.answer('Scale the Negroni for 4', state);
  assert.match(scaleMl.text, /Negroni for 4 servings:/);
  assert.match(scaleMl.text, /ml/);

  const halfOz = Assistant.answer('Half the Negroni', { ...state, unit: 'oz' });
  assert.match(halfOz.text, /half the written spec/);
  assert.match(halfOz.text, /0\.5 oz/);

  const fractionRecipe = Assistant.answer('How do I make a Negroni for 1/2?', { ...state, unit: 'oz' });
  assert.match(fractionRecipe.text, /half the written spec/);
  assert.match(fractionRecipe.text, /0\.5 oz/);

  const scaleMany = Assistant.answer('Scale the Sour for 2', state);
  assert.ok(scaleMany.followUps.length > 0);
  assert.ok(scaleMany.followUps.every(f => f.endsWith(' for 2')));

  const recipeMany = Assistant.answer('How do I make a Sour for 3?', state);
  assert.ok(recipeMany.followUps.length > 0);
  assert.ok(recipeMany.followUps.every(f => f.endsWith(' for 3?')));

  const customWithNote = {
    ...state,
    unit: 'oz',
    customRecipes: [{
      id: 'cloud-nine',
      name: 'Cloud Nine',
      method: 'Shaken',
      glass: 'Coupe',
      garnish: 'Lemon twist',
      instructions: 'Shake and strain.',
      ingredients: [{ id: 'gin', name: 'Gin', amount: 2, unit: 'oz', optional: false, note: 'chilled' }],
    }],
  };
  const noteReply = Assistant.answer('Scale the Cloud Nine for 4', customWithNote);
  assert.match(noteReply.text, /Cloud Nine for 4 servings:/);
  assert.match(noteReply.text, /8 oz Gin \(chilled\)/);

  const capped = Assistant.answer('Scale Negroni for 50', state);
  assert.match(capped.text, /scales up to 24 servings/);

  const badServings = Assistant.answer('Scale Negroni for 0', state);
  assert.match(badServings.text, /greater than zero/);

  const missingReply = Assistant.answer('What am I missing for a Martini?', { ...Demo.defaults(), inventory: ['gin'] });
  assert.match(missingReply.text, /Martini still needs Dry Vermouth/);

  const recipeReply = Assistant.answer('How do I make a Negroni?', state);
  assert.match(recipeReply.text, /Negroni for 1 serving:/);
  assert.match(recipeReply.text, /Stir/i);

  const inventoryReply = Assistant.answer("What's in my bar?", { ...state, shopping: ['dry-vermouth'] });
  assert.match(inventoryReply.text, /In stock \(4\):/);
  assert.match(inventoryReply.text, /On your shopping list \(1\):/);

  const outOfStockReply = Assistant.answer("What's out of stock?", { ...Demo.defaults(), inventory: ['gin', 'sweet-vermouth'] });
  assert.match(outOfStockReply.text, /Not currently in My Bar/);
  assert.match(outOfStockReply.text, /Campari/);

  const allExceptCrushedIce = Demo.listIngredients(Demo.defaults()).map(i => i.id).filter(id => id !== 'crushed-ice');
  const crushedIceOut = Assistant.answer("What's out of stock?", { ...Demo.defaults(), inventory: allExceptCrushedIce });
  assert.match(crushedIceOut.text, /Not currently in My Bar \(1\): Crushed Ice\./);

  const dietaryReply = Assistant.answer('Is Negroni safe for nut allergies?', state);
  assert.match(dietaryReply.text, /can't verify allergies/);
  assert.deepEqual(dietaryReply.followUps, []);

  const virginReply = Assistant.answer('How do I make a virgin Margarita?', state);
  assert.match(virginReply.text, /can't verify allergies/);

  const privacyReply = Assistant.answer('Do you send my bar to OpenAI?', state);
  assert.match(privacyReply.text, /does not use an AI model/);

  const helpReply = Assistant.answer('How does this work?', state);
  assert.match(helpReply.text, /cleared when you close the dialog/);

  // Every returned follow-up must parse to a recognized non-privacy intent.
  for (const reply of [emptyReply, makeReply, focusReply, subReply, scaleMl, missingReply, recipeReply, inventoryReply, outOfStockReply, privacyReply]) {
    for (const follow of reply.followUps) {
      const intent = Assistant.parseIntent(follow);
      assert.notEqual(intent.type, 'unrecognized', `Follow-up not understood: ${follow}`);
      assert.notEqual(intent.type, 'empty', `Follow-up empty: ${follow}`);
      assert.notEqual(intent.type, 'privacy', `Follow-up misrouted to privacy: ${follow}`);
    }
  }
});

test('bar assistant dialog opens, answers questions, appends turns without replacing prior nodes, and clears on close', () => {
  const page = bootTryPage({ compact: false, singleColumn: false });
  const openBtn = page.byId.get('open-assistant');
  const closeBtn = page.byId.get('close-assistant');
  const dialog = page.byId.get('assistant-dialog');
  const log = page.byId.get('assistant-log');
  const form = page.byId.get('assistant-form');
  const input = page.byId.get('assistant-input');

  const appendToLog = log.append.bind(log);
  const assistantReplyTops = [300, 400];
  log.scrollTop = 0;
  log.scrollHeight = 900;
  log.getBoundingClientRect = () => ({ top: 100 });
  log.append = (...nodes) => {
    for (const child of nodes) {
      if (child.className === 'assistant-turn assistant-turn-assistant') {
        child.getBoundingClientRect = () => ({ top: assistantReplyTops.shift() });
      }
    }
    appendToLog(...nodes);
  };

  openBtn.listeners.get('click')[0]();
  assert.ok(log.children.length > 0);
  assert.equal(log.children[0].className, 'assistant-empty');

  input.value = 'Scale the Negroni for 4';
  form.listeners.get('submit')[0]({ preventDefault() {} });
  assert.equal(log.children.length, 2);
  const firstUserNode = log.children[0];
  const firstAssistantNode = log.children[1];
  assert.equal(firstUserNode.className, 'assistant-turn assistant-turn-user');
  assert.equal(firstAssistantNode.className, 'assistant-turn assistant-turn-assistant');
  assert.equal(input.value, '');
  assert.equal(log.scrollTop, 200);
  assert.equal(page.doc.activeElement, input);

  input.value = 'What can I make?';
  form.listeners.get('submit')[0]({ preventDefault() {} });
  assert.equal(log.children.length, 4);
  assert.equal(log.children[0], firstUserNode);
  assert.equal(log.children[1], firstAssistantNode);
  assert.equal(log.scrollTop, 500);

  closeBtn.listeners.get('click')[0]();
  dialog.listeners.get('close')[0]();
  assert.equal(log.children.length, 1);
  assert.equal(log.children[0].className, 'assistant-empty');
  assert.equal(page.doc.activeElement, openBtn);
});
