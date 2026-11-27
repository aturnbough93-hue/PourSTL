(function () {
  'use strict';
  const App = window.PourWeb;
  if (!App) return;
  const Assistant = window.PourAssistant;
  const $ = id => document.getElementById(id);
  const storageKey = 'pour.browser-demo.v1';
  let state = App.defaults();
  let storageAvailable = true;
  let filter = 'all';
  let query = '';
  let inventoryQuery = '';
  let editorID = null;
  let timerEndsAt = 0;
  let timerTick;
  let copyFeedbackTimeout;
  const compact = window.matchMedia('(max-width: 1000px)');
  const singleColumn = window.matchMedia('(max-width: 700px)');
  let inventoryExpanded = !compact.matches;

  try {
    const saved = window.localStorage.getItem(storageKey);
    if (saved) state = App.validateState(JSON.parse(saved));
  } catch (_) {
    storageAvailable = false;
  }

  function node(tag, className, text) {
    const result = document.createElement(tag);
    if (className) result.className = className;
    if (text !== undefined) result.textContent = text;
    return result;
  }

  function checkIcon() {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('aria-hidden', 'true');
    const path = document.createElementNS(svg.namespaceURI, 'path');
    path.setAttribute('d', 'm5 12 4 4L19 6');
    svg.append(path);
    return svg;
  }

  function feedback(message) {
    $('feedback').textContent = message;
  }

  function storageNote() {
    $('storage-note').textContent = storageAvailable
      ? 'Saved in this browser'
      : 'Storage unavailable. Changes last for this tab only.';
  }

  function save() {
    try {
      window.localStorage.setItem(storageKey, JSON.stringify(state));
      storageAvailable = true;
    } catch (_) {
      storageAvailable = false;
    }
    storageNote();
  }

  function currentRecipe() {
    return App.resolveRecipe(state.selected, state.customRecipes);
  }

  function renderInventory() {
    const results = App.listIngredients(state).filter(item => App.normalize(item.name).includes(inventoryQuery));
    results.sort((a, b) => Number(state.inventory.includes(b.id)) - Number(state.inventory.includes(a.id)));
    const container = $('inventory');
    container.replaceChildren();
    $('inventory-empty').hidden = results.length > 0;
    $('starter-bar').hidden = state.inventory.length > 0;
    for (const item of results) {
      const label = node('label', 'inventory-option');
      const input = node('input');
      input.type = 'checkbox';
      input.value = item.id;
      input.checked = state.inventory.includes(item.id);
      input.addEventListener('change', () => {
        state.inventory = input.checked
          ? [...state.inventory, item.id]
          : state.inventory.filter(id => id !== item.id);
        const wasChecked = input.checked;
        render();
        save();
        container.querySelector('input[value="' + item.id + '"]')?.focus({ preventScroll: true });
        feedback(item.name + (wasChecked ? ' stocked.' : ' removed from My Bar.'));
      });
      label.append(input, node('span', '', item.name));
      container.append(label);
    }
  }

  function renderShopping() {
    const names = new Map(App.listIngredients(state).map(item => [item.id, item.name]));
    $('shopping').replaceChildren();
    $('shopping-empty').hidden = state.shopping.length > 0;
    $('copy-shopping').disabled = state.shopping.length === 0;
    $('shopping-copy-fallback').hidden = true;
    for (const id of state.shopping) {
      const name = names.get(id);
      const row = node('li', 'shopping-item');
      const actions = node('div', 'shopping-actions');
      const purchase = node('button', '', 'Purchased');
      purchase.type = 'button';
      purchase.setAttribute('aria-label', 'Mark ' + name + ' purchased and add to My Bar');
      purchase.addEventListener('click', () => {
        state = App.purchase(state, id);
        render();
        save();
        $('shopping-name').focus({ preventScroll: true });
        feedback(name + ' purchased and added to My Bar.');
      });
      const remove = node('button', '', 'Remove');
      remove.type = 'button';
      remove.setAttribute('aria-label', 'Remove ' + name + ' from shopping list');
      remove.addEventListener('click', () => {
        state = App.removeShoppingItem(state, id);
        render();
        save();
        $('shopping-name').focus({ preventScroll: true });
        feedback(name + ' removed from shopping list.');
      });
      actions.append(purchase, remove);
      const sources = Object.hasOwn(state.shoppingRecipes, id) ? state.shoppingRecipes[id] : [];
      const label = node('span', '', name);
      if (sources.length) label.append(node('span', 'ingredient-note', 'for ' + sources.join(', ')));
      row.append(label, actions);
      $('shopping').append(row);
    }
  }

  function renderRecipes() {
    const results = App.searchRecipes(query, filter, state);
    // Keep the selected recipe visible when a search or availability filter changes.
    if (results.length && !results.some(recipe => recipe.id === state.selected)) {
      state.selected = results[0].id;
    }
    $('recipes').replaceChildren();
    const emptyState = results.length ? null : App.recipeEmptyState(query, filter);
    $('no-results').hidden = !emptyState;
    for (const name of ['search', 'favorites', 'can-make']) {
      $('empty-' + name).hidden = emptyState !== name;
    }
    $('all-filter').setAttribute('aria-pressed', String(filter === 'all'));
    $('ready-filter').setAttribute('aria-pressed', String(filter === 'can-make'));
    $('favorites-filter').setAttribute('aria-pressed', String(filter === 'favorites'));
    document.querySelector('.detail-panel').hidden = results.length === 0;
    for (const recipe of results) {
      const match = App.matchRecipe(recipe, state.inventory);
      const button = node('button', 'recipe-button');
      button.type = 'button';
      button.dataset.recipe = recipe.id;
      button.setAttribute('aria-current', String(state.selected === recipe.id));
      const label = node('span', '', recipe.name);
      const status = node('span', `availability${match.canMake ? ' ready' : ''}`);
      if (match.canMake) status.append(checkIcon());
      status.append(document.createTextNode(match.canMake ? 'Can make' :
        App.canMakeWithSwaps(match, state.inventory) ? 'Can make with swaps' : `Missing ${match.missing.length}`));
      button.append(label, status);
      button.addEventListener('click', () => {
        state.selected = recipe.id;
        renderRecipes();
        renderDetail();
        save();
        if (singleColumn.matches) {
          $('recipe-title').focus({ preventScroll: true });
          document.querySelector('.detail-panel').scrollIntoView({ block: 'start' });
        } else {
          document.querySelector(`[data-recipe="${recipe.id}"]`).focus({ preventScroll: true });
        }
      });
      $('recipes').append(button);
    }
    return results.length;
  }

  function renderMedia(recipe) {
    const media = $('recipe-media');
    // Preserve the image on quantity changes to avoid a distracting reload.
    if (media.dataset.recipe === recipe.id) return;
    media.dataset.recipe = recipe.id;
    media.replaceChildren();
    if (recipe.image) {
      const photo = node('img');
      photo.src = recipe.image;
      photo.alt = `${recipe.name} cocktail`;
      photo.width = 680;
      photo.height = 190;
      media.append(photo);
    } else {
      const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      svg.setAttribute('viewBox', '0 0 96 96');
      svg.setAttribute('aria-hidden', 'true');
      const path = document.createElementNS(svg.namespaceURI, 'path');
      path.setAttribute('d', recipe.glass === 'Martini'
        ? 'M16 17h64L48 53 16 17Zm32 36v28M29 81h38M25 27h46'
        : 'M22 23h52l-5 52H27l-5-52Zm3 15h46M33 48l13-4 4 15-13 4Zm19 5 12-3 3 13-12 3Z');
      svg.append(path);
      media.append(svg);
    }
  }

  function renderDetail() {
    setCopyConfirmation();
    const recipe = currentRecipe();
    if (!recipe) return;
    if (!$('manual-copy').hidden) {
      $('recipe-copy').value = App.recipeText(recipe, state.servings, state.unit);
    }
    const match = App.matchRecipe(recipe, state.inventory);
    renderMedia(recipe);
    $('recipe-title').textContent = recipe.name;
    $('favorite').setAttribute('aria-pressed', String(state.favorites.includes(recipe.id)));
    $('edit-recipe').hidden = !recipe.id.startsWith('custom-');
    $('recipe-meta').textContent = [recipe.glass, recipe.method].filter(Boolean).join(' · ');
    $('recipe-status').classList.toggle('ready', match.canMake);
    $('recipe-status').replaceChildren();
    if (match.canMake) $('recipe-status').append(checkIcon());
    $('recipe-status').append(document.createTextNode(match.canMake ? 'Can make' :
      App.canMakeWithSwaps(match, state.inventory) ? 'Can make with swaps' :
        `Missing ${match.missing.length} ${match.missing.length === 1 ? 'ingredient' : 'ingredients'}`));
    $('servings').textContent = String(state.servings);
    $('less').disabled = state.servings === 1;
    $('more').disabled = state.servings === 24;
    $('unit-oz').setAttribute('aria-pressed', String(state.unit === 'oz'));
    $('unit-ml').setAttribute('aria-pressed', String(state.unit === 'ml'));
    $('ingredients').replaceChildren();
    for (const item of recipe.ingredients) {
      const row = node('div', `ingredient-row${item.optional ? ' optional' : ''}`);
      const name = node('dt', '', item.name);
      if (match.missing.includes(item)) {
        name.append(' ', node('span', 'missing-label', 'Missing'));
        const swap = App.stockedSwap(item, state.inventory);
        if (swap) name.append(node('span', 'ingredient-note', `Try ${swap} to taste`));
      }
      if (item.optional) name.append(node('span', 'optional-label', ' · optional'));
      if (item.note) name.append(node('span', 'ingredient-note', item.note));
      row.append(name, node('dd', '', App.formatMeasure(item.amount, item.unit, state.servings, state.unit)));
      $('ingredients').append(row);
    }
    $('instructions').textContent = recipe.instructions;
    $('garnish').textContent = recipe.garnish ? `Garnish: ${recipe.garnish}.` : '';
    $('garnish').hidden = !recipe.garnish;
    const unlisted = match.missing.filter(item => !Object.hasOwn(state.shoppingRecipes, item.id)
      || !state.shoppingRecipes[item.id].includes(recipe.name));
    $('add-missing').disabled = unlisted.length === 0;
    $('add-missing').textContent = match.canMake ? 'No missing ingredients'
      : unlisted.length ? 'Add missing to list' : 'Missing items on list';
  }

  function render() {
    renderInventory();
    renderShopping();
    const count = renderRecipes();
    renderDetail();
    return count;
  }

  function updateInventoryVisibility() {
    $('inventory-controls').hidden = compact.matches && !inventoryExpanded;
    $('inventory-toggle').setAttribute('aria-expanded', String(!compact.matches || inventoryExpanded));
    $('inventory-toggle').textContent = inventoryExpanded ? 'Hide ingredients' : 'Show ingredients';
  }

  function updatePanelOrder() {
    const workspace = $('workspace');
    const bar = workspace.querySelector('.bar-panel');
    if (singleColumn.matches ? bar === workspace.lastElementChild : bar === workspace.firstElementChild) return;

    const focused = document.activeElement;
    if (singleColumn.matches) workspace.append(bar);
    else workspace.prepend(bar);
    if (bar.contains(focused)) focused.focus();
  }

  $('inventory-toggle').addEventListener('click', () => {
    inventoryExpanded = !inventoryExpanded;
    updateInventoryVisibility();
  });
  compact.addEventListener('change', updateInventoryVisibility);
  singleColumn.addEventListener('change', updatePanelOrder);
  $('back-to-recipes').addEventListener('click', () => {
    const selectedResult = $('recipes').querySelector('[aria-current="true"]');
    if (!selectedResult) return;
    selectedResult.focus({ preventScroll: true });
    selectedResult.scrollIntoView({ block: 'center', inline: 'nearest' });
  });
  $('search').addEventListener('input', event => {
    query = event.target.value;
    const count = renderRecipes();
    renderDetail();
    save();
    feedback(`${count} ${count === 1 ? 'recipe matches' : 'recipes match'} your search.`);
  });
  function setRecipeFilter(value) {
    filter = value;
    const count = render();
    save();
    feedback(`${count} ${count === 1 ? 'recipe' : 'recipes'} ${filter === 'can-make' ? 'you can make with your bar' : 'shown'}.`);
  }
  for (const [id, value] of [['all-filter', 'all'], ['ready-filter', 'can-make'], ['favorites-filter', 'favorites']]) {
    $(id).addEventListener('click', () => setRecipeFilter(value));
  }
  $('browse-drinks').addEventListener('click', () => {
    setRecipeFilter('all');
    $('all-filter').focus();
  });
  $('open-my-bar').addEventListener('click', () => {
    inventoryExpanded = true;
    updateInventoryVisibility();
    $(state.inventory.length ? 'stock-name' : 'starter-bar').focus();
  });
  $('clear-filters').addEventListener('click', () => {
    query = '';
    filter = 'all';
    $('search').value = '';
    render();
    save();
    $('search').focus();
    feedback('Search and filters cleared.');
  });
  for (const [id, delta] of [['less', -1], ['more', 1]]) {
    $(id).addEventListener('click', () => {
      state.servings = Math.max(1, Math.min(24, state.servings + delta));
      renderDetail();
      save();
      feedback(`Recipe scaled to ${state.servings} ${state.servings === 1 ? 'serving' : 'servings'}.`);
    });
  }
  for (const unit of ['oz', 'ml']) {
    $(`unit-${unit}`).addEventListener('click', () => {
      state.unit = unit;
      renderDetail();
      save();
      feedback(`Liquid measurements shown in ${unit === 'ml' ? 'milliliters' : 'ounces'}. Dashes and garnish units stay as written.`);
    });
  }
  $('add-missing').addEventListener('click', () => {
    const previousCount = state.shopping.length;
    state = App.addMissing(state, currentRecipe());
    render();
    save();
    const added = state.shopping.length - previousCount;
    feedback(added
      ? `${added} missing ${added === 1 ? 'ingredient added' : 'ingredients added'} to your shopping list.`
      : 'Recipe noted on your shopping list.');
  });

  function fallbackCopy(text) {
    const textarea = node('textarea');
    textarea.value = text;
    textarea.setAttribute('aria-hidden', 'true');
    textarea.style.position = 'fixed';
    textarea.style.top = '-9999px';
    document.body.append(textarea);
    textarea.select();
    let copied = false;
    try { copied = document.execCommand('copy'); } catch (_) { /* Show manual copy below. */ }
    textarea.remove();
    return copied;
  }

  $('copy-shopping').addEventListener('click', async () => {
    const text = App.shoppingText(state);
    let copied = false;
    try {
      if (window.navigator.clipboard && window.isSecureContext) {
        await window.navigator.clipboard.writeText(text);
        copied = true;
      }
    } catch (_) { /* Some browsers require the legacy copy fallback. */ }
    if (copied || fallbackCopy(text)) {
      $('shopping-copy-fallback').hidden = true;
      $('copy-shopping').focus({ preventScroll: true });
      feedback('Shopping list copied to clipboard.');
    } else {
      $('shopping-copy-fallback').hidden = false;
      $('shopping-copy-text').value = text;
      $('shopping-copy-text').focus();
      $('shopping-copy-text').select();
      feedback('Your browser blocked clipboard access. The shopping list text is selected for manual copying.');
    }
  });

  function setCopyConfirmation(message = '') {
    window.clearTimeout(copyFeedbackTimeout);
    const copied = Boolean(message);
    $('copy-label').textContent = copied ? 'Copied' : 'Copy recipe';
    $('copy-icon').toggleAttribute('hidden', copied);
    $('copied-icon').toggleAttribute('hidden', !copied);
    $('copy-feedback').textContent = message;
    copyFeedbackTimeout = message ? window.setTimeout(setCopyConfirmation, 3000) : undefined;
  }

  $('copy').addEventListener('click', async () => {
    const copy = $('copy');
    const restoreCopyFocus = document.activeElement === copy;
    const text = App.recipeText(currentRecipe(), state.servings, state.unit);
    setCopyConfirmation();
    $('feedback').textContent = '';
    copy.disabled = true;
    let copied = false;
    try {
      if (window.navigator.clipboard && window.isSecureContext) {
        await window.navigator.clipboard.writeText(text);
        copied = true;
      }
    } catch (_) { /* Some browsers require the legacy copy fallback. */ }
    let focusedBeforeFallback = null;
    if (!copied) {
      focusedBeforeFallback = document.activeElement;
      copied = fallbackCopy(text);
    }
    copy.disabled = false;
    if (copied && document.activeElement === document.body) {
      if (focusedBeforeFallback && focusedBeforeFallback !== document.body) {
        focusedBeforeFallback.focus({ preventScroll: true });
      } else if (restoreCopyFocus) {
        copy.focus({ preventScroll: true });
      }
    }
    if (copied) {
      $('manual-copy').hidden = true;
      const recipe = currentRecipe();
      if (recipe && App.recipeText(recipe, state.servings, state.unit) === text) {
        setCopyConfirmation(`${recipe.name} recipe copied to clipboard.`);
      }
    } else {
      $('manual-copy').hidden = false;
      $('recipe-copy').value = text;
      $('recipe-copy').focus();
      $('recipe-copy').select();
      feedback('Your browser blocked clipboard access. The recipe text is selected below; copy it using your browser or keyboard.');
    }
  });
  $('close-copy').addEventListener('click', () => {
    $('manual-copy').hidden = true;
    $('copy').focus();
  });

  $('inventory-search').addEventListener('input', event => {
    inventoryQuery = App.normalize(event.target.value);
    renderInventory();
  });

  $('starter-bar').addEventListener('click', () => {
    state.inventory = App.starterInventory.slice();
    render();
    save();
    $('inventory-search').focus();
    feedback('Gin, Campari, and sweet vermouth stocked.');
  });

  for (const [form, field, destination] of [
    ['stock-form', 'stock-name', 'inventory'], ['shopping-form', 'shopping-name', 'shopping'],
  ]) {
    $(form).addEventListener('submit', event => {
      event.preventDefault();
      const input = $(field);
      const next = App.addIngredient(state, input.value, destination);
      if (next === state) {
        feedback('Enter an ingredient name with a letter or number.');
        return;
      }
      const name = input.value.trim();
      state = next;
      input.value = '';
      render();
      save();
      input.focus();
      feedback(name + (destination === 'inventory' ? ' stocked in My Bar.' : ' added to your shopping list.'));
    });
  }

  $('favorite').addEventListener('click', () => {
    const recipe = currentRecipe();
    const wasFavorite = state.favorites.includes(recipe.id);
    state.favorites = wasFavorite ? state.favorites.filter(id => id !== recipe.id) : [...state.favorites, recipe.id];
    render();
    save();
    if (wasFavorite && filter === 'favorites') $('favorites-filter').focus();
    feedback(recipe.name + (wasFavorite ? ' removed from favorites.' : ' saved to favorites.'));
  });

  const editor = $('recipe-dialog');
  const rows = $('editor-ingredients');
  const unitNames = { each: 'count', topUp: 'to top', ml: 'mL' };

  window.addEventListener('storage', event => {
    if (event.key !== storageKey && event.key !== null) return;
    let incoming;
    try {
      incoming = event.newValue ? App.validateState(JSON.parse(event.newValue)) : App.defaults();
    } catch (_) {
      return;
    }
    const selected = state.selected;
    state = incoming;
    if (App.resolveRecipe(selected, state.customRecipes)) state.selected = selected;
    render();
  });

  function editorField(labelText, input) {
    const label = node('label', '', labelText);
    label.append(input);
    return label;
  }

  function addEditorRow(line = {}) {
    const row = node('div', 'editor-line');
    const name = node('input');
    name.className = 'line-name';
    name.required = true;
    name.maxLength = 80;
    name.value = line.name || '';
    const amount = node('input');
    amount.className = 'line-amount';
    amount.type = 'number';
    amount.step = 'any';
    amount.min = '0.001';
    amount.max = '10000';
    amount.required = true;
    amount.value = line.amount || '';
    const unit = node('select', 'line-unit');
    for (const value of App.units) {
      const option = node('option', '', unitNames[value] || value);
      option.value = value;
      unit.append(option);
    }
    unit.value = line.unit || 'oz';
    const updateAmount = () => { amount.disabled = unit.value === 'topUp'; };
    unit.addEventListener('change', updateAmount);
    updateAmount();
    const optional = node('input', 'line-optional');
    optional.type = 'checkbox';
    optional.checked = line.optional === true;
    const note = node('input', 'line-note');
    note.value = line.note || '';
    note.maxLength = 120;
    const remove = node('button', 'text-button', 'Remove ingredient');
    remove.type = 'button';
    remove.addEventListener('click', () => {
      if (rows.children.length === 1) {
        $('editor-error').textContent = 'A recipe needs at least one ingredient.';
        return;
      }
      row.remove();
      $('editor-error').textContent = '';
      $('add-line').focus();
    });
    row.append(editorField('Ingredient', name), editorField('Amount', amount),
      editorField('Unit', unit), editorField('Optional', optional), editorField('Ingredient note', note), remove);
    rows.append(row);
    return name;
  }

  function openEditor(recipe) {
    if (!recipe && state.customRecipes.length >= App.maxCustomRecipes) {
      feedback('You’ve reached the limit of 250 custom recipes in this browser.');
      return;
    }
    editorID = recipe?.id || null;
    $('editor-title').textContent = editorID ? 'Edit recipe' : 'New recipe';
    $('editor-error').textContent = '';
    $('delete-recipe').hidden = !editorID;
    for (const key of ['name', 'instructions', 'glass', 'method', 'garnish']) $('editor-' + key).value = recipe?.[key] || '';
    rows.replaceChildren();
    for (const line of recipe?.ingredients || [{}]) addEditorRow(line);
    editor.showModal();
    $('editor-name').focus();
  }

  $('new-recipe').addEventListener('click', () => openEditor());
  $('edit-recipe').addEventListener('click', () => openEditor(currentRecipe()));
  $('add-line').addEventListener('click', () => {
    if (rows.children.length >= 40) {
      $('editor-error').textContent = 'A recipe supports up to 40 ingredients.';
      return;
    }
    addEditorRow().focus();
  });
  $('cancel-recipe').addEventListener('click', () => editor.close());
  $('recipe-form').addEventListener('submit', event => {
    event.preventDefault();
    const raw = { id: editorID || 'custom-' + crypto.randomUUID() };
    for (const key of ['name', 'instructions', 'glass', 'method', 'garnish']) raw[key] = $('editor-' + key).value;
    raw.ingredients = [...rows.children].map(row => ({
      name: row.querySelector('.line-name').value,
      amount: row.querySelector('.line-amount').valueAsNumber,
      unit: row.querySelector('.line-unit').value,
      optional: row.querySelector('.line-optional').checked,
      note: row.querySelector('.line-note').value,
    }));
    const recipe = App.validateRecipe(raw);
    if (!recipe) {
      $('editor-error').textContent = 'Check the recipe name, instructions, and each ingredient name and amount.';
      return;
    }
    const existing = state.customRecipes.findIndex(item => item.id === recipe.id);
    if (existing === -1 && state.customRecipes.length >= App.maxCustomRecipes) {
      $('editor-error').textContent = 'You’ve reached the limit of 250 custom recipes in this browser.';
      return;
    }
    if (existing === -1) state.customRecipes.push(recipe);
    else state.customRecipes[existing] = recipe;
    state = App.validateState({ ...state, selected: recipe.id });
    query = '';
    filter = 'all';
    $('search').value = '';
    render();
    save();
    editor.close();
    $('recipe-title').focus();
    feedback(recipe.name + ' saved.');
  });
  $('delete-recipe').addEventListener('click', () => {
    const recipe = state.customRecipes.find(item => item.id === editorID);
    if (!recipe) {
      editor.close();
      $('new-recipe').focus();
      feedback('Recipe already deleted.');
      return;
    }
    if (!window.confirm('Delete ' + recipe.name + ' from your saved recipes?')) return;
    state = App.validateState({ ...state, customRecipes: state.customRecipes.filter(item => item.id !== editorID) });
    render();
    save();
    editor.close();
    $('new-recipe').focus();
    feedback(recipe.name + ' deleted.');
  });

  function showTimerControls(running) {
    $('timer-setup').hidden = running;
    $('timer-running').hidden = !running;
  }

  function stopTimer() {
    window.clearInterval(timerTick);
    timerEndsAt = 0;
    showTimerControls(false);
    $('timer-display').textContent = '';
    $('timer-complete').hidden = true;
  }

  function updateTimer() {
    const seconds = Math.max(0, Math.ceil((timerEndsAt - Date.now()) / 1000));
    if (seconds > 0) {
      $('timer-display').textContent = Math.floor(seconds / 60) + ':' + String(seconds % 60).padStart(2, '0');
      return;
    }
    const stopHadFocus = document.activeElement === $('timer-stop');
    stopTimer();
    $('timer-complete').hidden = false;
    if (stopHadFocus) $('timer-start').focus({ preventScroll: true });
    feedback('Prep timer finished.');
    if (typeof navigator.vibrate === 'function') navigator.vibrate(200);
  }

  $('timer-start').addEventListener('click', () => {
    const duration = $('timer-seconds');
    if (!duration.reportValidity() || !Number.isInteger(duration.valueAsNumber)) return;
    const startHadFocus = document.activeElement === $('timer-start');
    timerEndsAt = Date.now() + duration.valueAsNumber * 1000;
    $('timer-complete').hidden = true;
    showTimerControls(true);
    if (startHadFocus) $('timer-stop').focus();
    timerTick = window.setInterval(updateTimer, 250);
    updateTimer();
    feedback('Prep timer started.');
  });
  $('timer-stop').addEventListener('click', () => {
    stopTimer();
    $('timer-start').focus();
    feedback('Prep timer stopped.');
  });

  const assistantDialog = $('assistant-dialog');
  const assistantLog = $('assistant-log');
  const assistantInput = $('assistant-input');
  let assistantTurns = [];

  function buildAssistantTurnNode(turn) {
    const item = node('div', 'assistant-turn assistant-turn-' + turn.kind);
    const bubble = node('div', 'assistant-bubble');
    const lines = turn.text.split('\n');
    for (let i = 0; i < lines.length; i += 1) {
      if (i > 0) bubble.append(document.createElement('br'));
      bubble.append(document.createTextNode(lines[i]));
    }
    item.append(bubble);
    if (turn.sourceNote) item.append(node('p', 'assistant-note', turn.sourceNote));
    if (turn.followUps && turn.followUps.length) {
      const prompts = node('div', 'assistant-prompts');
      for (const follow of turn.followUps) {
        const button = node('button', 'assistant-prompt', follow);
        button.type = 'button';
        button.addEventListener('click', () => askAssistant(follow));
        prompts.append(button);
      }
      item.append(prompts);
    }
    return item;
  }

  function renderAssistant() {
    if (!assistantLog || !Assistant) return;
    assistantLog.replaceChildren();
    if (!assistantTurns.length) {
      const empty = node('div', 'assistant-empty');
      empty.append(
        node('h3', '', 'Ask your bar'),
        node('p', '', 'An offline recipe helper for what you can make, ingredient stand-ins, and scaled measures. It uses recipes and My Bar in this browser.')
      );
      const prompts = node('div', 'assistant-prompts');
      for (const question of Assistant.STARTER_QUESTIONS) {
        const button = node('button', 'assistant-prompt', question);
        button.type = 'button';
        button.addEventListener('click', () => askAssistant(question));
        prompts.append(button);
      }
      empty.append(prompts);
      assistantLog.append(empty);
      return;
    }
    for (const turn of assistantTurns) {
      assistantLog.append(buildAssistantTurnNode(turn));
    }
    assistantLog.scrollTop = assistantLog.scrollHeight;
  }

  function askAssistant(rawQuestion) {
    if (!Assistant) return;
    const question = String(rawQuestion || '').trim();
    if (!question) return;
    if (assistantInput) assistantInput.value = '';
    const wasEmpty = assistantTurns.length === 0;
    const userTurn = { kind: 'user', text: question };
    const reply = Assistant.answer(question, state);
    const assistantTurn = {
      kind: 'assistant',
      text: reply.text,
      sourceNote: reply.sourceNote,
      followUps: reply.followUps,
    };
    assistantTurns.push(userTurn, assistantTurn);
    if (assistantLog) {
      if (wasEmpty) assistantLog.replaceChildren();
      const assistantTurnNode = buildAssistantTurnNode(assistantTurn);
      assistantLog.append(buildAssistantTurnNode(userTurn), assistantTurnNode);
      assistantLog.scrollTop += assistantTurnNode.getBoundingClientRect().top - assistantLog.getBoundingClientRect().top;
    }
    assistantInput?.focus({ preventScroll: true });
  }

  function clearAssistant() {
    assistantTurns = [];
    if (assistantInput) assistantInput.value = '';
    renderAssistant();
  }

  if (assistantDialog && Assistant) {
    $('open-assistant')?.addEventListener('click', () => {
      renderAssistant();
      if (typeof assistantDialog.showModal === 'function') assistantDialog.showModal();
      else assistantDialog.setAttribute('open', '');
      assistantInput?.focus();
    });
    $('close-assistant')?.addEventListener('click', () => {
      if (typeof assistantDialog.close === 'function') assistantDialog.close();
      else {
        assistantDialog.removeAttribute?.('open');
        clearAssistant();
        $('open-assistant')?.focus();
      }
    });
    assistantDialog.addEventListener('close', () => {
      clearAssistant();
      $('open-assistant')?.focus();
    });
    $('assistant-form')?.addEventListener('submit', event => {
      event.preventDefault();
      askAssistant(assistantInput?.value || '');
    });
  }

  const resetDialog = $('reset-dialog');
  function reset() {
    state = App.defaults();
    query = '';
    inventoryQuery = '';
    filter = 'all';
    $('search').value = '';
    $('inventory-search').value = '';
    $('manual-copy').hidden = true;
    clearAssistant();
    stopTimer();
    try { window.localStorage.removeItem(storageKey); } catch (_) { storageAvailable = false; }
    render();
    storageNote();
    feedback('PourSTL Web data cleared.');
  }
  $('reset').addEventListener('click', () => {
    if (typeof resetDialog.showModal === 'function') {
      resetDialog.showModal();
      $('cancel-reset').focus();
    } else if (window.confirm('Clear your PourSTL Web data from this browser?')) {
      reset();
    }
  });
  $('cancel-reset').addEventListener('click', () => resetDialog.close());
  $('confirm-reset').addEventListener('click', () => {
    reset();
    resetDialog.close();
  });
  resetDialog.addEventListener('close', () => $('reset').focus());

  render();
  storageNote();
  updateInventoryVisibility();
  updatePanelOrder();
  $('workspace').hidden = false;
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('web-app-worker.js', { scope: '/try' }).catch(() => {});
  }
})();
