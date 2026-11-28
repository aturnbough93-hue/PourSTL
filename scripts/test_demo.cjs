'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
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

test('shopping text groups pending items and retains multiple source recipes without duplicate entries', () => {
  let state = Demo.addIngredient(Demo.defaults(), 'Ice', 'shopping');
  const gin = { id: 'gin', name: 'Gin', optional: false };
  state = Demo.addMissing(state, { name: 'Negroni', ingredients: [gin] });
  state = Demo.addMissing(state, { name: 'Martini', ingredients: [gin] });
  state = Demo.addMissing(state, { name: 'Negroni', ingredients: [gin] });
  state = Demo.validateState(JSON.parse(JSON.stringify(state)));
  assert.equal(Demo.shoppingText(state), 'PourSTL Shopping List\n\nFor recipes\n• Gin — for Martini, Negroni\n\nOther items\n• Ice');
  assert.deepEqual(Demo.removeShoppingItem(state, 'gin').shoppingRecipes, {});
  assert.deepEqual(Demo.purchase(state, 'gin').shoppingRecipes, {});
});

test('the browser suggests stocked swaps only for measurable ingredient lines', () => {
  const lime = { id: 'lime-juice', unit: 'oz', optional: false };
  const syrup = { id: 'simple-syrup', unit: 'oz', optional: false };
  const recipe = { ingredients: [lime, syrup] };
  const inventory = ['lemon-juice', 'demerara-syrup'];
  const match = Demo.matchRecipe(recipe, inventory);
  assert.equal(match.canMake, false);
  assert.equal(Demo.canMakeWithSwaps(match, inventory), true);
  assert.equal(Demo.stockedSwap(lime, inventory), 'Lemon juice');
  assert.equal(Demo.stockedSwap({ ...lime, unit: 'wedge' }, inventory), null);
  assert.equal(Demo.canMakeWithSwaps(match, ['lemon-juice']), false);
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

test('Rye in My Bar satisfies rye whiskey without matching unrelated ingredients', () => {
  const bar = {
    ...Demo.defaults(),
    inventory: ['sweet-vermouth', 'angostura-bitters', 'absinthe', 'sugar-cubes', 'peychauds-bitters'],
  };
  const stocked = Demo.addIngredient(bar, 'Rye', 'inventory');
  const flour = Demo.addIngredient(bar, 'Rye Flour', 'inventory');
  for (const recipe of ['manhattan', 'sazerac']) {
    assert.equal(Demo.matchRecipe(recipe, stocked.inventory).canMake, true, recipe);
    assert.deepEqual(Demo.addMissing(stocked, recipe).shopping, [], recipe);
    assert.deepEqual(Demo.addMissing(flour, recipe).shopping, ['rye-whiskey'], recipe);
  }
  assert.deepEqual(Demo.addMissing(stocked, 'old-fashioned').shopping, ['bourbon']);
});

test('saved Rye in My Bar survives reloading as rye whiskey', () => {
  const saved = {
    ...Demo.defaults(),
    ingredientNames: ['Rye'],
    inventory: ['rye', 'sweet-vermouth', 'angostura-bitters'],
  };
  const reloaded = Demo.validateState(saved);
  assert.deepEqual(reloaded.inventory, ['rye-whiskey', 'sweet-vermouth', 'angostura-bitters']);
  assert.deepEqual(Demo.addMissing(reloaded, 'manhattan').shopping, []);
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

function bootTryPage({ compact = false, singleColumn = false, clipboardWrite, execCommandResult = false, initialState, beacon, fetchMock, visibilityState = 'visible' } = {}) {
  const siteDir = path.join(__dirname, '..', 'website');
  const html = fs.readFileSync(path.join(siteDir, 'try.html'), 'utf8');
  const ids = new Set([...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]));

  const documentListeners = new Map();
  const doc = {
    activeElement: null,
    visibilityState,
    execCommand: () => execCommandResult,
    addEventListener: (type, listener) => documentListeners.set(type, listener),
    removeEventListener: (type, listener) => {
      if (documentListeners.get(type) === listener) documentListeners.delete(type);
    },
  };
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
    get disabled() { return this._disabled; }
    set disabled(disabled) {
      this._disabled = Boolean(disabled);
      if (this._disabled && doc.activeElement === this) doc.activeElement = doc.body;
    }
    setAttribute(name, value) { this.attributes.set(name, String(value)); }
    getAttribute(name) { return this.attributes.get(name) ?? null; }
    toggleAttribute(name, force) {
      if (force) this.attributes.set(name, '');
      else this.attributes.delete(name);
    }
    addEventListener(type, listener) {
      if (!this.listeners.has(type)) this.listeners.set(type, []);
      this.listeners.get(type).push(listener);
    }
    remove() {
      if (!this.parentNode) return;
      this.parentNode.children = this.parentNode.children.filter(child => child !== this);
      this.parentNode = null;
      if (doc.activeElement === this) doc.activeElement = doc.body;
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
    select() { this.selected = true; this.focus(); }
    scrollIntoView() {}
    querySelector(selector) {
      const classMatch = /^\.([a-z0-9-]+)$/i.exec(selector);
      const recipeMatch = /^\[data-recipe="([^"]+)"\]$/.exec(selector);
      for (const child of this.children) {
        if (classMatch && child.className?.split(/\s+/).includes(classMatch[1])) return child;
        if (recipeMatch && child.dataset?.recipe === recipeMatch[1]) return child;
        const found = child.querySelector?.(selector);
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
  recipesPanel.append(byId.get('recipes'));
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
  if (initialState) storage.set('pour.browser-demo.v1', JSON.stringify(initialState));
  const windowListeners = new Map();
  const timeouts = new Map();
  let nextTimeout = 0;
  const navigator = clipboardWrite ? { clipboard: { writeText: clipboardWrite } } : {};
  if (beacon) navigator.sendBeacon = beacon;
  const win = {
    document: doc,
    navigator,
    Blob: globalThis.Blob,
    isSecureContext: Boolean(clipboardWrite),
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
    addEventListener: (type, listener) => windowListeners.set(type, listener),
    setTimeout(callback) {
      timeouts.set(++nextTimeout, callback);
      return nextTimeout;
    },
    clearTimeout: id => timeouts.delete(id),
    setInterval: () => 0,
    clearInterval() {},
    confirm: () => true,
    crypto: globalThis.crypto,
    fetch: fetchMock,
  };
  win.window = win;

  const context = vm.createContext(win);
  for (const file of ['recipe-catalog.js', 'demo-core.js', 'bar-assistant.js', 'feature-analytics.js', 'try.js']) {
    vm.runInContext(fs.readFileSync(path.join(siteDir, file), 'utf8'), context, { filename: file });
  }
  return { byId, doc, barPanel, recipesPanel, detailPanel, mediaQueries, timeouts, windowListeners, documentListeners };
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

test('successful recipe copy announces beside its action and restores focus to Copy', async () => {
  let copiedText = '';
  const page = bootTryPage({ clipboardWrite: async text => { copiedText = text; } });
  const copy = page.byId.get('copy');
  copy.focus();
  page.byId.get('feedback').textContent = 'Previous status.';
  page.byId.get('copy-feedback').textContent = 'Old copy status.';

  const pendingCopy = copy.listeners.get('click')[0]();
  assert.equal(page.doc.activeElement, page.doc.body);
  await pendingCopy;

  assert.match(copiedText, /Negroni/);
  assert.equal(page.byId.get('copy-label').textContent, 'Copied');
  assert.equal(page.byId.get('copy-icon').getAttribute('hidden'), '');
  assert.equal(page.byId.get('copied-icon').getAttribute('hidden'), null);
  assert.equal(page.byId.get('copy-feedback').textContent, 'Negroni recipe copied to clipboard.');
  assert.equal(page.byId.get('feedback').textContent, '');
  assert.equal(page.doc.activeElement, copy);
  assert.equal(page.byId.get('manual-copy').hidden, true);

  assert.equal(page.timeouts.size, 1);
  page.timeouts.values().next().value();
  assert.equal(page.byId.get('copy-label').textContent, 'Copy recipe');
  assert.equal(page.byId.get('copy-icon').getAttribute('hidden'), null);
  assert.equal(page.byId.get('copied-icon').getAttribute('hidden'), '');
  assert.equal(page.byId.get('copy-feedback').textContent, '');
  assert.equal(page.doc.activeElement, copy);
});

for (const mode of ['clipboard', 'legacy', 'manual']) {
  test(`shopping copy preserves or restores focus as appropriate for ${mode}`, async () => {
    let resolve, reject;
    const promise = new Promise((res, rej) => { resolve = res; reject = rej; });
    const page = bootTryPage({
      initialState: Demo.addIngredient(Demo.defaults(), 'Gin', 'shopping'),
      clipboardWrite: () => promise,
      execCommandResult: mode === 'legacy',
    });
    const copy = page.byId.get('copy-shopping');
    const input = page.byId.get('shopping-name');
    copy.focus();
    const pending = copy.listeners.get('click')[0]();
    input.focus();
    if (mode === 'clipboard') resolve();
    else reject(new Error('denied'));
    await pending;

    if (mode === 'manual') {
      const text = page.byId.get('shopping-copy-text');
      assert.equal(page.byId.get('shopping-copy-fallback').hidden, false);
      assert.equal(page.doc.activeElement, text);
      assert.equal(text.selected, true);
    } else {
      assert.equal(page.doc.activeElement, input);
      assert.equal(input.focusCount, mode === 'legacy' ? 2 : 1);
      assert.equal(page.byId.get('feedback').textContent, 'Shopping list copied to clipboard.');
    }
  });
}

test('a rejected clipboard write cannot show a shopping list cleared during the write', async () => {
  let rejectClipboard;
  const clipboardWrite = new Promise((_, reject) => { rejectClipboard = reject; });
  const page = bootTryPage({
    initialState: Demo.addIngredient(Demo.defaults(), 'Gin', 'shopping'),
    clipboardWrite: () => clipboardWrite,
  });
  const pendingCopy = page.byId.get('copy-shopping').listeners.get('click')[0]();

  page.byId.get('reset-dialog').close = () => {};
  page.byId.get('confirm-reset').listeners.get('click')[0]();
  rejectClipboard(new Error('denied'));
  await pendingCopy;

  assert.equal(page.byId.get('shopping-copy-fallback').hidden, true);
  assert.equal(page.byId.get('shopping-copy-text').value ?? '', '');
});

test('pending recipe copy preserves focus moved to another control', async () => {
  let completeClipboardWrite;
  const clipboardWrite = new Promise(resolve => { completeClipboardWrite = resolve; });
  const page = bootTryPage({ clipboardWrite: () => clipboardWrite });
  const copy = page.byId.get('copy');
  const search = page.byId.get('search');
  copy.focus();

  const pendingCopy = copy.listeners.get('click')[0]();
  search.focus();
  completeClipboardWrite();
  await pendingCopy;

  assert.equal(page.doc.activeElement, search);
  assert.equal(copy.focusCount, 1);
  assert.equal(page.byId.get('copy-feedback').textContent, 'Negroni recipe copied to clipboard.');
});

test('successful legacy copy fallback restores focus to Copy when it did not move', async () => {
  const page = bootTryPage({ execCommandResult: true });
  const copy = page.byId.get('copy');
  copy.focus();

  await copy.listeners.get('click')[0]();

  assert.equal(page.doc.activeElement, copy);
  assert.equal(page.byId.get('copy-feedback').textContent, 'Negroni recipe copied to clipboard.');
});

test('legacy copy fallback preserves a control focused while clipboard was pending', async () => {
  let denyClipboardWrite;
  const clipboardWrite = new Promise((_resolve, reject) => { denyClipboardWrite = reject; });
  const page = bootTryPage({ clipboardWrite: () => clipboardWrite, execCommandResult: true });
  const copy = page.byId.get('copy');
  const search = page.byId.get('search');
  copy.focus();

  const pendingCopy = copy.listeners.get('click')[0]();
  search.focus();
  denyClipboardWrite(new Error('denied'));
  await pendingCopy;

  assert.equal(page.doc.activeElement, search);
  assert.equal(page.byId.get('copy-feedback').textContent, 'Negroni recipe copied to clipboard.');
});

test('pending copy does not restore stale confirmation after servings change', async () => {
  let completeClipboardWrite;
  const clipboardWrite = new Promise(resolve => { completeClipboardWrite = resolve; });
  const page = bootTryPage({ clipboardWrite: () => clipboardWrite });
  const copy = page.byId.get('copy');
  const more = page.byId.get('more');
  const copyFeedback = page.byId.get('copy-feedback');
  copy.focus();

  const pendingCopy = copy.listeners.get('click')[0]();
  more.focus();
  more.listeners.get('click')[0]();
  completeClipboardWrite();
  await pendingCopy;

  assert.equal(copyFeedback.textContent, '');
  assert.equal(page.byId.get('copy-label').textContent, 'Copy recipe');
  assert.equal(page.doc.activeElement, more);
  assert.equal(copy.focusCount, 1);
});

test('pending copy does not announce success after a same-ID recipe edit syncs from another tab', async () => {
  const recipe = {
    id: 'custom-7d8cc6b0-4650-4b35-a9b7-a465a1e3352d',
    name: 'Yuzu Fizz',
    instructions: 'Stir over ice.',
    ingredients: [{ name: 'Yuzu syrup', amount: 20, unit: 'ml' }],
  };
  const initialState = { ...Demo.defaults(), customRecipes: [recipe], selected: recipe.id };
  let completeClipboardWrite;
  let copiedText;
  const page = bootTryPage({
    initialState,
    clipboardWrite: text => {
      copiedText = text;
      return new Promise(resolve => { completeClipboardWrite = resolve; });
    },
  });
  const pendingCopy = page.byId.get('copy').listeners.get('click')[0]();
  assert.match(copiedText, /Stir over ice\./);

  const editedRecipe = { ...recipe, instructions: 'Shake with ice.' };
  page.windowListeners.get('storage')({
    key: 'pour.browser-demo.v1',
    newValue: JSON.stringify({ ...initialState, customRecipes: [editedRecipe] }),
  });
  assert.equal(page.byId.get('recipe-title').textContent, 'Yuzu Fizz');
  assert.equal(page.byId.get('instructions').textContent, editedRecipe.instructions);

  completeClipboardWrite();
  await pendingCopy;
  assert.equal(page.byId.get('copy-feedback').textContent, '');
  assert.equal(page.byId.get('copy-label').textContent, 'Copy recipe');
});

test('recipe selection, servings, and units clear the previous copy confirmation', async () => {
  const page = bootTryPage({ singleColumn: true, clipboardWrite: async () => {} });
  const copy = page.byId.get('copy').listeners.get('click')[0];
  const status = page.byId.get('copy-feedback');
  const copyLabel = page.byId.get('copy-label');

  await copy();
  page.byId.get('more').listeners.get('click')[0]();
  assert.equal(status.textContent, '');
  assert.equal(copyLabel.textContent, 'Copy recipe');
  assert.equal(page.timeouts.size, 0);

  await copy();
  page.byId.get('unit-ml').listeners.get('click')[0]();
  assert.equal(status.textContent, '');
  assert.equal(copyLabel.textContent, 'Copy recipe');

  await copy();
  const otherRecipe = page.byId.get('recipes').children.find(button => button.dataset.recipe !== 'negroni');
  otherRecipe.listeners.get('click')[0]();
  assert.notEqual(page.byId.get('recipe-title').textContent, 'Negroni');
  assert.equal(status.textContent, '');
  assert.equal(copyLabel.textContent, 'Copy recipe');
});

test('blocked recipe copy keeps the selected manual-copy flow and close focus return', async () => {
  const page = bootTryPage({ clipboardWrite: async () => { throw new Error('denied'); }, execCommandResult: false });
  const copy = page.byId.get('copy');

  await copy.listeners.get('click')[0]();

  assert.equal(page.byId.get('copy-feedback').textContent, '');
  assert.equal(page.byId.get('copy-label').textContent, 'Copy recipe');
  assert.match(page.byId.get('feedback').textContent, /blocked clipboard access/);
  assert.equal(page.byId.get('manual-copy').hidden, false);
  assert.match(page.byId.get('recipe-copy').value, /Negroni/);
  assert.equal(page.byId.get('recipe-copy').selected, true);
  assert.equal(page.doc.activeElement, page.byId.get('recipe-copy'));

  page.byId.get('close-copy').listeners.get('click')[0]();
  assert.equal(page.byId.get('manual-copy').hidden, true);
  assert.equal(page.doc.activeElement, copy);
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
  assert.deepEqual(Assistant.parseIntent('Is my bar stored on the cloud?'), { type: 'privacy' });
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

  const cloudPrivacyReply = Assistant.answer('Is my bar stored on the cloud?', state);
  assert.match(cloudPrivacyReply.text, /does not use an AI model or send questions anywhere/);

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

test('feature analytics sends only coarse allowlisted action counts', async () => {
  const sent = [];
  const page = bootTryPage({
    fetchMock(url, options) {
      sent.push({ url, ...options });
      return Promise.resolve({ ok: true });
    },
  });

  assert.equal(sent.length, 1, 'app_open should be recorded once during startup');
  page.byId.get('unit-ml').listeners.get('click')[0]();
  page.byId.get('more').listeners.get('click')[0]();
  assert.equal(sent.length, 3);

  const payloads = [];
  for (const { body } of sent) payloads.push(JSON.parse(body));
  assert.deepEqual(payloads.map(payload => payload.events[0].name), ['app_open', 'unit_toggle', 'serving_scale']);
  assert.ok(sent.every(entry => entry.url === '/api/analytics' && entry.credentials === 'omit'));
  assert.ok(sent.every(entry => entry.referrerPolicy === 'no-referrer'));
  const serialized = payloads.map(payload => JSON.stringify(payload)).join('\n');
  assert.deepEqual(Object.keys(payloads[0].events[0]).sort(), ['name', 'path']);
  assert.doesNotMatch(serialized, /negroni|lime|gin|question|inventory/i);
});

test('analytics Pages Function accepts only valid coarse event batches', async () => {
  const moduleUrl = pathToFileURL(path.join(__dirname, '..', 'functions', 'api', 'analytics.js'));
  const { onRequestPost, onRequest } = await import(moduleUrl);
  const writes = [];
  const env = {
    FEATURE_ANALYTICS: {
      writeDataPoint(point) { writes.push(point); },
    },
  };
  const request = new Request('https://pourstl.com/api/analytics', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ events: [{ name: 'recipe_view', path: '/try' }] }),
  });
  const response = await onRequestPost({ request, env });
  assert.equal(response.status, 202);
  assert.equal(writes.length, 1);
  assert.deepEqual(writes[0], {
    indexes: ['recipe_view'],
    blobs: ['web_try', '/try', 'production', 'standard'],
    doubles: [1],
  });

  const bad = await onRequestPost({
    request: new Request('https://pourstl.com/api/analytics', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ events: [{ name: 'ingredient_name:gin' }] }),
    }),
    env,
  });
  assert.equal(bad.status, 400);
  assert.equal(writes.length, 1);

  const wrongMediaType = await onRequestPost({
    request: new Request('https://pourstl.com/api/analytics', {
      method: 'POST',
      headers: { 'content-type': 'text/plain; application/json' },
      body: JSON.stringify({ events: [{ name: 'app_open' }] }),
    }),
    env,
  });
  assert.equal(wrongMediaType.status, 415);

  const preview = await onRequestPost({
    request: new Request('https://devin-feature-analytics-web.pourstl.pages.dev/api/analytics', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ events: [{ name: 'app_open' }] }),
    }),
    env,
  });
  assert.equal(preview.status, 202);
  assert.equal(writes[1].blobs[2], 'preview');

  const headless = await onRequestPost({
    request: new Request('https://pourstl.com/api/analytics', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'user-agent': 'Mozilla/5.0 HeadlessChrome/142.0.0.0 Safari/537.36',
      },
      body: JSON.stringify({ events: [{ name: 'app_open' }] }),
    }),
    env,
  });
  assert.equal(headless.status, 202);
  assert.equal(writes[2].blobs[3], 'headless_automation');

  const oversizedStream = new ReadableStream({
    start(controller) {
      controller.enqueue(new TextEncoder().encode(' '.repeat(2048)));
      controller.enqueue(new TextEncoder().encode(' '.repeat(2049)));
      controller.close();
    },
  });
  const oversized = await onRequestPost({
    request: new Request('https://pourstl.com/api/analytics', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: oversizedStream,
      duplex: 'half',
    }),
    env,
  });
  assert.equal(oversized.status, 413);
  assert.equal(writes.length, 3);
  assert.equal(onRequest().status, 405);
});

test('feature analytics counts the first visible open and skips reset and no-op changes', () => {
  const names = [];
  const page = bootTryPage({
    visibilityState: 'hidden',
    fetchMock(_url, { body }) {
      names.push(JSON.parse(body).events[0].name);
      return Promise.resolve({ ok: true });
    },
  });
  const click = id => page.byId.get(id).listeners.get('click')[0]();

  assert.deepEqual(names, []);
  page.documentListeners.get('visibilitychange')();
  assert.deepEqual(names, []);
  page.doc.visibilityState = 'visible';
  page.documentListeners.get('visibilitychange')();
  assert.equal(page.documentListeners.has('visibilitychange'), false);

  click('less');
  click('unit-oz');
  click('starter-bar');
  click('starter-bar');
  click('reset');
  click('less');
  click('more');
  assert.deepEqual(names, ['app_open', 'my_bar_add', 'serving_scale']);
});

test('recipe views count selections and single-column jumps to the detail', () => {
  const names = [];
  const fetchMock = (_url, { body }) => {
    names.push(JSON.parse(body).events[0].name);
    return Promise.resolve({ ok: true });
  };
  const clickRecipe = (page, selected) => page.byId.get('recipes').children
    .find(button => button.getAttribute('aria-current') === String(selected)).listeners.get('click')[0]();

  const desktop = bootTryPage({ fetchMock });
  clickRecipe(desktop, true);
  assert.deepEqual(names, ['app_open']);
  clickRecipe(desktop, false);
  clickRecipe(desktop, true);
  assert.deepEqual(names, ['app_open', 'recipe_view']);

  const phone = bootTryPage({ compact: true, singleColumn: true, fetchMock });
  clickRecipe(phone, true);
  assert.deepEqual(names, ['app_open', 'recipe_view', 'app_open', 'recipe_view']);
});
