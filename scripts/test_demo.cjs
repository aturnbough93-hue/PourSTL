'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const Demo = require('../website/demo-core.js');

test('catalog has six native specs and all required ingredients exist in inventory', () => {
  assert.equal(Demo.recipes.length, 6);
  assert.equal(Demo.inventory.length, 13);
  const ids = new Set(Demo.inventory.map(item => item.id));
  for (const recipe of Demo.recipes) {
    for (const line of recipe.ingredients.filter(line => !line.optional)) assert.ok(ids.has(line.id));
  }
  assert.equal(Demo.recipes.find(recipe => recipe.id === 'martini').ingredients[0].amount, 2.5);
  assert.equal(Demo.recipes.find(recipe => recipe.id === 'daiquiri').ingredients[2].amount, 0.75);
});

test('defaults are independent and preserve optional garnish matching', () => {
  const first = Demo.defaults();
  const second = Demo.defaults();
  first.inventory.length = 0;
  assert.ok(second.inventory.length > 0);
  const match = Demo.matchRecipe('negroni', second.inventory);
  assert.equal(match.canMake, true);
  assert.deepEqual(match.missing, []);
  assert.deepEqual(match.optionalMissing.map(item => item.id), ['orange-twist']);
});

test('taking a bottle out of stock immediately changes matching and can-make filter', () => {
  const state = Demo.defaults();
  assert.deepEqual(Demo.searchRecipes('', 'can-make', state.inventory).map(item => item.id), ['negroni']);
  state.inventory = state.inventory.filter(id => id !== 'campari');
  assert.equal(Demo.matchRecipe('negroni', state.inventory).canMake, false);
  assert.deepEqual(Demo.matchRecipe('negroni', state.inventory).missing.map(item => item.id), ['campari']);
  assert.equal(Demo.searchRecipes('', 'can-make', state.inventory).length, 0);
});

test('search matches recipe names, normalized ingredient terms and tags', () => {
  const stocked = Demo.inventory.map(item => item.id);
  assert.deepEqual(Demo.searchRecipes('  DÁIQUIRI ', 'all', []).map(item => item.id), ['daiquiri']);
  assert.deepEqual(Demo.searchRecipes('dry vermouth', 'all', []).map(item => item.id), ['martini']);
  assert.deepEqual(Demo.searchRecipes('bourbon sour', 'all', []).map(item => item.id), ['whiskey-sour']);
  assert.equal(Demo.searchRecipes('rum', 'can-make', stocked).length, 1);
  assert.equal(Demo.searchRecipes('nonexistent', 'all', stocked).length, 0);
});

test('malformed persisted values reset safely without leaking arbitrary fields', () => {
  for (const bad of [null, undefined, false, 'bad json', [], { version: 3 }]) assert.deepEqual(Demo.validateState(bad), Demo.defaults());
  const state = Demo.validateState({version: 1, inventory: ['gin', 'gin', '__proto__', {}, null, 'unknown'], shopping: ['dry-vermouth', 'dry-vermouth', 'constructor'], servings: Infinity, selected: '__proto__', unit: 'html', unsafe: '<script>'});
  assert.deepEqual(state, {version: 1, inventory: ['gin'], shopping: ['dry-vermouth'], servings: 1, selected: 'negroni', unit: 'oz'});
  assert.deepEqual(Demo.validateState({version: 1, inventory: [], shopping: []}).inventory, []);
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
  assert.equal(Demo.formatMeasure(2, 'oz', 1, 'ml'), '59.15 ml');
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
  assert.match(text, /118\.29 ml Bourbon/);
  assert.match(text, /6 dashes Angostura Bitters/);
  assert.match(text, /2 twists Orange Twist \(optional\)/);
  assert.match(text, /Muddle until dissolved/);
  assert.match(text, /Check ingredients and allergies/);
  assert.equal(Demo.recipeText('not-a-recipe', 1, 'oz'), '');
});
