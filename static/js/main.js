(() => {
  const menu = document.querySelector('.mobile-menu');
  const sidebar = document.querySelector('.admin-sidebar');
  if (menu && sidebar) {
    menu.addEventListener('click', () => sidebar.classList.toggle('open'));
    document.addEventListener('click', (ev) => {
      if (!sidebar.contains(ev.target) && !menu.contains(ev.target)) sidebar.classList.remove('open');
    });
  }
  const variant = document.querySelector('#variant_id');
  if (variant && variant.options.length && variant.selectedOptions[0].disabled) {
    const next = Array.from(variant.options).find(option => !option.disabled);
    if (next) variant.value = next.value;
  }
})();

(() => {
  const form = document.querySelector('[data-suggestions-url]');
  if (!form) return;

  const input = form.elements.q;
  const list = form.querySelector('.search-suggestions');
  let timer;
  let pending;

  function closeSuggestions() {
    clearTimeout(timer);
    pending?.abort();
    list.replaceChildren();
    list.hidden = true;
  }

  async function loadSuggestions(query) {
    pending = new AbortController();
    const { signal } = pending;
    const url = new URL(form.dataset.suggestionsUrl, window.location.origin);
    url.searchParams.set('q', query);

    try {
      const response = await fetch(url, { signal });
      if (!response.ok) return;
      const products = await response.json();
      if (signal.aborted) return;

      for (const product of products) {
        const item = document.createElement('li');
        const link = document.createElement('a');
        const category = document.createElement('small');
        link.href = product.url;
        link.textContent = product.name;
        category.textContent = product.category;
        link.append(category);
        item.append(link);
        list.append(item);
      }
      list.hidden = products.length === 0;
    } catch {
      // The normal search form still works if suggestions are unavailable.
    }
  }

  function queueSuggestions() {
    closeSuggestions();
    const query = input.value.trim();
    if (query) timer = setTimeout(() => loadSuggestions(query), 180);
  }

  input.addEventListener('input', event => {
    if (event.isComposing) closeSuggestions();
    else queueSuggestions();
  });
  input.addEventListener('compositionend', queueSuggestions);
  input.addEventListener('focus', event => {
    if (!form.contains(event.relatedTarget)) queueSuggestions();
  });
  form.addEventListener('focusout', event => {
    if (event.relatedTarget && !form.contains(event.relatedTarget)) closeSuggestions();
  });
  document.addEventListener('pointerdown', event => {
    if (!form.contains(event.target)) closeSuggestions();
  });
  form.addEventListener('keydown', event => {
    if (event.key === 'Escape') {
      if (list.contains(event.target)) input.focus();
      closeSuggestions();
    }
    if (event.key === 'ArrowDown' && !list.hidden) {
      event.preventDefault();
      const next = event.target.closest('li')?.nextElementSibling;
      (next?.querySelector('a') || list.querySelector('a'))?.focus();
    }
    if (event.key === 'ArrowUp' && list.contains(event.target)) {
      event.preventDefault();
      const previous = event.target.closest('li')?.previousElementSibling;
      (previous?.querySelector('a') || input).focus();
    }
  });
})();
