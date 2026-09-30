// Service worker sederhana: halaman selalu diambil dari jaringan dulu (supaya pembaruan langsung terasa),
// baru jatuh ke simpanan kalau sedang tanpa internet. Panggilan ke database tidak pernah disimpan.
const NAMA = 'minyak-v34';
self.addEventListener('install', e => { self.skipWaiting(); e.waitUntil(caches.open(NAMA).then(c => c.addAll(['./', 'manifest.json', 'ikon.svg']))); });
self.addEventListener('activate', e => e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== NAMA).map(k => caches.delete(k)))).then(() => self.clients.claim())));
self.addEventListener('fetch', e => { const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin) return;
  // no-cache: selalu tanya server dulu (versi baru langsung terpakai, tidak menunggu simpanan browser 10 menit)
  const segar = e.request.mode === 'navigate' ? new Request(e.request.url, { cache: 'no-cache', credentials: 'same-origin' }) : new Request(e.request, { cache: 'no-cache' });
  e.respondWith(fetch(segar).then(r => { const s = r.clone(); caches.open(NAMA).then(c => c.put(e.request, s)); return r; }).catch(() => caches.match(e.request).then(r => r || caches.match('./')))); });
