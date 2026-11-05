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
