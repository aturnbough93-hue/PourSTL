(function () {
  'use strict';
  const Demo = window.PourDemo;
  if (!Demo) return;
  const $ = id => document.getElementById(id);
  const storageKey = 'pour.browser-demo.v1';
  let state = Demo.defaults();
  let storageAvailable = true;
  let filter = 'all';
  let query = '';
  const compact = window.matchMedia('(max-width: 1000px)');
  let inventoryExpanded = !compact.matches;

  try {
    const saved = window.localStorage.getItem(storageKey);
    if (saved) state = Demo.validateState(JSON.parse(saved));
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
      ? 'Browser demo · saved on this browser'
      : 'Browser demo · changes last for this tab only';
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
    return Demo.recipes.find(recipe => recipe.id === state.selected);
  }

  function renderInventory() {
    for (const item of Demo.inventory) {
      const label = node('label', 'inventory-option');
      const input = node('input');
      input.type = 'checkbox';
      input.value = item.id;
      input.checked = state.inventory.includes(item.id);
      input.addEventListener('change', () => {
        state.inventory = input.checked
          ? [...new Set([...state.inventory, item.id])]
          : state.inventory.filter(id => id !== item.id);
        state = Demo.validateState(state);
        render();
        save();
        feedback(`${item.name} ${input.checked ? 'added to' : 'removed from'} your bar.`);
      });
      label.append(input, node('span', '', item.name));
      $('inventory').append(label);
    }
  }

  function renderShopping() {
    $('shopping').replaceChildren();
    $('shopping-empty').hidden = state.shopping.length > 0;
    for (const id of state.shopping) {
      const item = Demo.inventory.find(entry => entry.id === id);
      const row = node('li', 'shopping-item');
      const purchase = node('button', '', 'Purchased');
      purchase.type = 'button';
      purchase.setAttribute('aria-label', `Mark ${item.name} purchased and add to My Bar`);
      purchase.addEventListener('click', () => {
        state = Demo.purchase(state, id);
        render();
        save();
        const nextPurchase = $('shopping').querySelector('button');
        const stockedInput = $('inventory').querySelector(`input[value="${id}"]`);
        (nextPurchase || ($('inventory-controls').hidden ? $('inventory-toggle') : stockedInput)).focus({ preventScroll: true });
        feedback(`${item.name} purchased and added to your bar.`);
      });
      row.append(node('span', '', item.name), purchase);
      $('shopping').append(row);
    }
  }

  function renderRecipes() {
    const results = Demo.searchRecipes(query, filter, state.inventory);
    // Keep the selected recipe visible when a search or availability filter changes.
    if (results.length && !results.some(recipe => recipe.id === state.selected)) {
      state.selected = results[0].id;
    }
    $('recipes').replaceChildren();
    $('no-results').hidden = results.length > 0;
    $('all-filter').setAttribute('aria-pressed', String(filter === 'all'));
    $('ready-filter').setAttribute('aria-pressed', String(filter === 'can-make'));
    for (const recipe of results) {
      const match = Demo.matchRecipe(recipe, state.inventory);
      const button = node('button', 'recipe-button');
      button.type = 'button';
      button.dataset.recipe = recipe.id;
      button.setAttribute('aria-current', String(state.selected === recipe.id));
      const label = node('span', '', recipe.name);
      const status = node('span', `availability${match.canMake ? ' ready' : ''}`);
      if (match.canMake) status.append(checkIcon());
      status.append(document.createTextNode(match.canMake ? 'Can make' : `Missing ${match.missing.length}`));
      button.append(label, status);
      button.addEventListener('click', () => {
        state.selected = recipe.id;
        renderRecipes();
        renderDetail();
        save();
        if (window.matchMedia('(max-width: 700px)').matches) {
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
      svg.setAttribute('role', 'img');
      svg.setAttribute('aria-label', `${recipe.glass} glass illustration`);
      const path = document.createElementNS(svg.namespaceURI, 'path');
      path.setAttribute('d', recipe.glass === 'Martini'
        ? 'M16 17h64L48 53 16 17Zm32 36v28M29 81h38M25 27h46'
        : 'M22 23h52l-5 52H27l-5-52Zm3 15h46M33 48l13-4 4 15-13 4Zm19 5 12-3 3 13-12 3Z');
      svg.append(path);
      media.append(svg);
    }
  }

  function renderDetail() {
    const recipe = currentRecipe();
    const match = Demo.matchRecipe(recipe, state.inventory);
    renderMedia(recipe);
    $('recipe-title').textContent = recipe.name;
    $('recipe-meta').textContent = `${recipe.glass} · ${recipe.method}`;
    $('recipe-status').classList.toggle('ready', match.canMake);
    $('recipe-status').replaceChildren();
    if (match.canMake) $('recipe-status').append(checkIcon());
    $('recipe-status').append(document.createTextNode(match.canMake ? 'Can make' : `Missing ${match.missing.length} ${match.missing.length === 1 ? 'ingredient' : 'ingredients'}`));
    $('servings').textContent = String(state.servings);
    $('less').disabled = state.servings === 1;
    $('more').disabled = state.servings === 24;
    $('unit-oz').setAttribute('aria-pressed', String(state.unit === 'oz'));
    $('unit-ml').setAttribute('aria-pressed', String(state.unit === 'ml'));
    $('ingredients').replaceChildren();
    for (const item of recipe.ingredients) {
      const row = node('div', `ingredient-row${item.optional ? ' optional' : ''}`);
      const name = node('dt', '', item.name);
      if (item.optional) name.append(node('span', 'optional-label', ' · optional'));
      row.append(name, node('dd', '', Demo.formatMeasure(item.amount, item.unit, state.servings, state.unit)));
      $('ingredients').append(row);
    }
    $('instructions').textContent = recipe.instructions;
    $('garnish').textContent = recipe.garnish ? `Garnish: ${recipe.garnish}.` : '';
    $('garnish').hidden = !recipe.garnish;
    const unlisted = match.missing.filter(item => !state.shopping.includes(item.id));
    $('add-missing').disabled = unlisted.length === 0;
    $('add-missing').textContent = match.canMake ? 'No missing ingredients'
      : unlisted.length ? 'Add missing to list' : 'Missing items on list';
  }

  function render() {
    for (const input of $('inventory').querySelectorAll('input')) {
      input.checked = state.inventory.includes(input.value);
    }
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

  $('inventory-toggle').addEventListener('click', () => {
    inventoryExpanded = !inventoryExpanded;
    updateInventoryVisibility();
  });
  compact.addEventListener('change', updateInventoryVisibility);
  $('search').addEventListener('input', event => {
    query = event.target.value;
    const count = renderRecipes();
    renderDetail();
    save();
    feedback(`${count} ${count === 1 ? 'recipe matches' : 'recipes match'} your search.`);
  });
  for (const [id, value] of [['all-filter', 'all'], ['ready-filter', 'can-make']]) {
    $(id).addEventListener('click', () => {
      filter = value;
      const count = render();
      save();
      feedback(`${count} ${count === 1 ? 'recipe' : 'recipes'} ${filter === 'can-make' ? 'you can make with your bar' : 'shown'}.`);
    });
  }
  $('clear-filters').addEventListener('click', () => {
    query = '';
    filter = 'all';
    $('search').value = '';
    render();
    save();
    $('search').focus();
    feedback('Search and filters cleared. All six recipes are shown.');
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
    state = Demo.addMissing(state, currentRecipe());
    render();
    save();
    const added = state.shopping.length - previousCount;
    feedback(`${added} missing ${added === 1 ? 'ingredient added' : 'ingredients added'} to your shopping list.`);
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

  $('copy').addEventListener('click', async () => {
    const recipe = currentRecipe();
    const text = Demo.recipeText(recipe, state.servings, state.unit);
    $('copy').disabled = true;
    let copied = false;
    try {
      if (window.navigator.clipboard && window.isSecureContext) {
        await window.navigator.clipboard.writeText(text);
        copied = true;
      }
    } catch (_) { /* Some browsers require the legacy copy fallback. */ }
    if (!copied) copied = fallbackCopy(text);
    $('copy').disabled = false;
    if (copied) {
      $('manual-copy').hidden = true;
      $('copy').focus({ preventScroll: true });
      feedback(`${recipe.name} recipe copied to clipboard.`);
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

  const resetDialog = $('reset-dialog');
  function reset() {
    state = Demo.defaults();
    query = '';
    filter = 'all';
    $('search').value = '';
    $('manual-copy').hidden = true;
    try { window.localStorage.removeItem(storageKey); } catch (_) { storageAvailable = false; }
    render();
    storageNote();
    feedback('Demo reset. Your starter bar has gin, Campari, and sweet vermouth.');
  }
  $('reset').addEventListener('click', () => {
    if (typeof resetDialog.showModal === 'function') {
      resetDialog.showModal();
      $('cancel-reset').focus();
    } else if (window.confirm('Reset this browser demo? This clears your demo bar and shopping list and restores the starter ingredients.')) {
      reset();
    }
  });
  $('cancel-reset').addEventListener('click', () => resetDialog.close());
  $('confirm-reset').addEventListener('click', () => {
    reset();
    resetDialog.close();
  });
  resetDialog.addEventListener('close', () => $('reset').focus());

  renderInventory();
  render();
  storageNote();
  updateInventoryVisibility();
  $('workspace').hidden = false;
})();
