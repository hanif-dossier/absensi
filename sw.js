// Service worker sederhana: halaman selalu diambil dari jaringan dulu (supaya pembaruan langsung terasa),
// baru jatuh ke simpanan kalau sedang tanpa internet. Panggilan ke database tidak pernah disimpan.
const NAMA = 'minyak-v12';
self.addEventListener('install', e => { self.skipWaiting(); e.waitUntil(caches.open(NAMA).then(c => c.addAll(['./', 'manifest.json', 'ikon.svg']))); });
self.addEventListener('activate', e => e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== NAMA).map(k => caches.delete(k)))).then(() => self.clients.claim())));
self.addEventListener('fetch', e => { const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin) return;
  e.respondWith(fetch(e.request).then(r => { const s = r.clone(); caches.open(NAMA).then(c => c.put(e.request, s)); return r; }).catch(() => caches.match(e.request).then(r => r || caches.match('./')))); });
