'use strict';

const cachePrefix = 'pourstl-web-';
const cacheName = cachePrefix + '__POURSTL_BUILD__';
const appPage = '/try';
const appAssets = [
  appPage, '/try.css', '/recipe-catalog.js', '/demo-core.js', '/try.js', '/app.webmanifest',
  '/assets/brand-icon.png', '/assets/apple-touch-icon.png', '/assets/app-icon-192.png', '/assets/app-icon-512.png',
  '/assets/boulevardier.webp', '/assets/daiquiri.webp', '/assets/negroni.webp', '/assets/old-fashioned.webp',
];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(cacheName).then(cache =>
    cache.addAll(appAssets.map(path => new Request(path, { cache: 'reload' })))));
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter(name => name.startsWith(cachePrefix) && name !== cacheName)
      .map(name => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin) return;
  const navigation = event.request.mode === 'navigate' && ['/try', '/try.html'].includes(url.pathname);
  const asset = event.request.mode !== 'navigate' && appAssets.includes(url.pathname);
  if (!navigation && !asset) return;

  event.respondWith((async () => {
    const cache = await caches.open(cacheName);
    if (navigation) {
      return await cache.match(appPage) || fetch(event.request);
    }
    return await cache.match(url.pathname) || fetch(event.request);
  })());
});
