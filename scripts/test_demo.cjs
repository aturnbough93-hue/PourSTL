'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const Demo = require('../website/demo-core.js');

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
