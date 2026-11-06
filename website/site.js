'use strict';

const toggle = document.querySelector('.nav-toggle');
const menu = document.getElementById('nav-menu');
const mobileLayout = window.matchMedia('(max-width: 860px)');

function setMenuOpen(open, restoreFocus = false) {
  menu.classList.toggle('open', open);
  document.body.classList.toggle('nav-open', open);
  toggle.setAttribute('aria-expanded', String(open));
  toggle.setAttribute('aria-label', open ? 'Close navigation menu' : 'Open navigation menu');
  if (restoreFocus) toggle.focus({ preventScroll: true });
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

// Mouse clicks keep the overlay mounted until click so the tap cannot fall
// through to the page. iOS Safari often never emits that click on a
// non-interactive div, and pointerDown ignores focusout for the whole tap, so
// a touch or pen release on the empty overlay closes it here instead.
let pointerDown = false;
let overlayPress = null;

function targetElement(event) {
  const node = event.target;
  return node instanceof Element ? node : (node && node.parentElement) || null;
}

function isEmptyOverlayTarget(target) {
  return !!target && menu.contains(target) && !target.closest('a, button, summary');
}

function swallowFollowingClick() {
  let timer = 0;
  const release = () => {
    clearTimeout(timer);
    document.removeEventListener('click', sink, true);
    document.removeEventListener('pointerdown', release, true);
  };
  const sink = event => {
    // Keyboard activation (detail 0) must still reach the hamburger.
    if (event.detail === 0) return;
    event.preventDefault();
    event.stopPropagation();
    release();
    toggle.focus({ preventScroll: true });
  };
  document.addEventListener('click', sink, true);
  // A new tap starts with pointerdown, before its click. Let that click through.
  document.addEventListener('pointerdown', release, true);
  timer = setTimeout(release, 1000);
}

function clearOverlayPressSoon() {
  const press = overlayPress;
  setTimeout(() => {
    if (overlayPress === press) overlayPress = null;
  }, 0);
}

function dismissEmptyOverlay(event, x, y) {
  const press = overlayPress;
  if (!press || event.pointerType === 'mouse') return;
  if (press.handled) {
    if (event.cancelable) event.preventDefault();
    return;
  }
  if (!menu.classList.contains('open') || menu.scrollTop !== press.scroll) return;
  // Hit-test the release point. Touch pointerup stays on the pointerdown
  // target, which would mis-read a drag from the overlay onto a link.
  // If the hit test returns nothing, the event target is the overlay itself.
  const released = document.elementFromPoint(x, y) || targetElement(event);
  if (!isEmptyOverlayTarget(released)) return;
  if (event.cancelable) event.preventDefault();
  press.handled = true;
  swallowFollowingClick();
  setMenuOpen(false, true);
}

document.addEventListener('pointerdown', event => {
  pointerDown = true;
  const target = targetElement(event);
  overlayPress = menu.classList.contains('open')
    && event.isPrimary !== false
    && !(event.button > 0)
    && isEmptyOverlayTarget(target)
    ? { scroll: menu.scrollTop, handled: false }
    : null;
}, true);

document.addEventListener('pointerup', event => {
  pointerDown = false;
  dismissEmptyOverlay(event, event.clientX, event.clientY);
  clearOverlayPressSoon();
}, true);

document.addEventListener('pointercancel', () => {
  pointerDown = false;
  overlayPress = null;
}, true);

menu.addEventListener('touchend', event => {
  const touch = event.changedTouches[0];
  if (!touch || event.touches.length !== 0) return;
  dismissEmptyOverlay(event, touch.clientX, touch.clientY);
  clearOverlayPressSoon();
}, { passive: false });

document.addEventListener('click', event => {
  if (!menu.classList.contains('open')) return;
  const target = event.target instanceof Element ? event.target : event.target.parentElement;
  if (!target || toggle.contains(target) || target.closest('#nav-menu a')) return;
  // Empty overlay and other non-controls return focus to the hamburger, like Escape.
  // A tap on another link or button still activates that control.
  const activatedControl = target.closest('a, button, summary');
  setMenuOpen(false, !activatedControl);
});

// This is a disclosure menu, not a modal: keyboard users can Tab out normally.
document.querySelector('nav').addEventListener('focusout', event => {
  if (!event.currentTarget.contains(event.relatedTarget)) {
    if (pointerDown) return;
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
