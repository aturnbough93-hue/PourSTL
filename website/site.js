'use strict';

const toggle = document.querySelector('.nav-toggle');
const menu = document.getElementById('nav-menu');
const mobileLayout = window.matchMedia('(max-width: 860px)');

function setMenuOpen(open, restoreFocus = false) {
  menu.classList.toggle('open', open);
  toggle.setAttribute('aria-expanded', String(open));
  toggle.setAttribute('aria-label', open ? 'Close navigation menu' : 'Open navigation menu');
  if (restoreFocus) toggle.focus();
}

toggle.addEventListener('click', () => {
  setMenuOpen(toggle.getAttribute('aria-expanded') !== 'true');
});

menu.querySelectorAll('a').forEach(link => {
  link.addEventListener('click', () => {
    setMenuOpen(false);
    // Move keyboard focus to the destination so the next Tab follows the page.
    const href = link.getAttribute('href');
    const target = href.startsWith('#') ? document.getElementById(href.slice(1)) : null;
    if (target) {
      target.setAttribute('tabindex', '-1');
      target.focus({ preventScroll: true });
    }
  });
});

document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && menu.classList.contains('open')) {
    event.preventDefault();
    setMenuOpen(false, true);
  }
});

document.addEventListener('click', event => {
  if (!event.target.closest('nav')) setMenuOpen(false);
});

// This is a disclosure menu, not a modal: keyboard users can Tab out normally.
document.querySelector('nav').addEventListener('focusout', event => {
  if (!event.currentTarget.contains(event.relatedTarget)) {
    setMenuOpen(false);
    // Some browsers blur a newly hidden mobile link before the media-query
    // change event runs. Keep keyboard focus in the visible desktop navigation.
    if (!mobileLayout.matches && menu.contains(event.target) && !event.relatedTarget) {
      document.querySelector('.nav-links a').focus();
    }
  }
});

mobileLayout.addEventListener('change', () => {
  const wasInMenu = menu.contains(document.activeElement);
  setMenuOpen(false);
  if (wasInMenu) {
    const destination = document.querySelector('.nav-links a');
    (mobileLayout.matches ? toggle : destination).focus();
  }
});
