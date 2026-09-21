// Menyalin data "Dashboard Keuangan Minyak" dari Docfarm ke database (tabel minyak_nilai, kunci 'keuangan'),
// supaya aplikasi bisa menampilkannya HANYA untuk pemilik. Tanpa dependensi: Node 18+ saja.
//   node muat-keuangan.mjs            -> ambil, tampilkan ringkasan, simpan
//   node muat-keuangan.mjs --lihat    -> ambil dan tampilkan saja (tidak menyimpan)
//   node muat-keuangan.mjs --berkas <dashboard.html>  -> dari berkas lokal, bukan Docfarm
// Kunci: variabel lingkungan SINKRON_KUNCI (GitHub Actions) atau berkas rahasia lokal. Ini kunci SEMPIT: hanya bisa
// menulis data keuangan lewat fungsi minyak_tulis_nilai, bukan kunci service database.
import fs from 'fs';
const HALAMAN = 'https://doc.farm/dashboard-keuangan-minyak';
const lihatSaja = process.argv.includes('--lihat');

const URL_ = 'https://hzxfheydtrjhizbwbddh.supabase.co', PUBLIK = 'sb_publishable_3c_5VhfP4Z9g1dSU9c00HQ_0QkuiHTm';   // keduanya memang publik
let KUNCI = process.env.SINKRON_KUNCI;
if (!KUNCI) KUNCI = (fs.readFileSync('D:/Ai Agent/rahasia/absensi-minyak.txt', 'utf8').match(/^SINKRON_KUNCI=(\S+)$/m) || [])[1];
if (!KUNCI && !lihatSaja) throw new Error('SINKRON_KUNCI tidak ada');

// 1. Halaman Docfarm membungkus isi dalam <iframe src="/api/documents/<id>/raw-html?...token">; ikuti iframe itu.
//    --berkas <html>: baca dari berkas dashboard di laptop (pembaruan otomatis n8n), bukan dari Docfarm.
const iB = process.argv.indexOf('--berkas'), berkas = iB > 0 ? process.argv[iB + 1] : null;
let html;
if (berkas) html = fs.readFileSync(berkas, 'utf8');
else {
  const bungkus = await (await fetch(HALAMAN)).text();
  const src = (bungkus.match(/<iframe src="([^"]+)"/) || [])[1];
  if (!src) throw new Error('iframe Docfarm tidak ditemukan; format halaman berubah?');
  html = await (await fetch('https://doc.farm' + src.replace(/&amp;/g, '&'))).text();
}

// 2. Petik variabel dari skrip halaman. D adalah JSON murni; sisanya literal JS sederhana yang dipetik dengan regex (tanpa eval).
const ambil = (re, nama) => { const m = html.match(re); if (!m) throw new Error('tidak menemukan ' + nama); return m[1]; };
const D = JSON.parse(ambil(/const D=(\{[\s\S]*?\});\s*const WK=/, 'D'));
const WK = JSON.parse(ambil(/const WK=(\[[^\]]*\])/, 'WK'));
const pasangan = (teks, reNilai) => Object.fromEntries([...teks.matchAll(reNilai)].map(m => [m[1], m[2]]));
const PER = pasangan(ambil(/const PER=\{([^}]*)\}/, 'PER'), /(\d+):'([^']*)'/g);
const HARI = Object.fromEntries(Object.entries(pasangan(ambil(/const HARI=\{([^}]*)\}/, 'HARI'), /(\d+):(\d+)/g)).map(([k, v]) => [k, +v]));
const TGL = pasangan(ambil(/const TGL=\{([^}]*)\}/, 'TGL'), /([A-Z]+):'([^']*)'/g);
const CURW = +ambil(/const CURW=(\d+)/, 'CURW');
const sub = ambil(/<p class="sub">([\s\S]*?)<\/p>/, 'sub').replace(/&nbsp;/g, ' ').replace(/&middot;/g, '·').replace(/\s+/g, ' ').trim();

// 3. Catatan anomali & kaki halaman ditulis sebagai gabungan string JS ('...'+'...'). Gabungkan lalu rapikan HTML-nya.
const gabung = js => [...js.matchAll(/'((?:[^'\\]|\\.)*)'/g)].map(m => m[1].replace(/\\'/g, "'")).join('');
const entitas = s => s.replace(/&middot;/g, '·').replace(/&amp;/g, '&').replace(/&ldquo;|&rdquo;/g, '"').replace(/&nbsp;/g, ' ').replace(/&ndash;/g, '–');
const hanyaTebal = s => entitas(s).replace(/<(?!\/?(b|i)>)[^>]*>/g, '');          // sisakan <b> dan <i> saja
const flagsJs = ambil(/getElementById\('flags'\)\.innerHTML=([\s\S]*?);\s*\n\s*const NS=/, 'flags');
const catatan = [...gabung(flagsJs).matchAll(/<div class="(ok|flag|info)"><h4>([\s\S]*?)<\/h4><p>([\s\S]*?)<\/p><\/div>/g)]
  .map(m => ({ jenis: m[1], judul: hanyaTebal(m[2]).replace(/<[^>]*>/g, ''), isi: hanyaTebal(m[3]) }));
const kakiJs = ambil(/getElementById\('foot'\)\.innerHTML=([\s\S]*?);\s*\n\}\)\(\);/, 'foot');
const kaki = gabung(kakiJs).split(/<br\s*\/?>/).map(hanyaTebal).filter(Boolean);

const nilai = { D, WK, PER, HARI, TGL, CURW, sub, catatan, kaki, sumber: berkas ? 'laptop pemilik' : HALAMAN, diambil: new Date().toISOString() };
const t = D[CURW].tot;
console.log(`minggu ${WK[0]}–${WK[WK.length - 1]}, sorotan M${CURW}: omzet ${t.omset.toLocaleString('id-ID')}, laba bersih ${t.bersih.toLocaleString('id-ID')}; catatan ${catatan.length}, kaki ${kaki.length}`);
if (lihatSaja) process.exit(0);

// 4. Simpan lewat fungsi database yang memeriksa kunci sempit tadi.
const r = await fetch(`${URL_}/rest/v1/rpc/minyak_tulis_nilai`, { method: 'POST',
  headers: { apikey: PUBLIK, Authorization: 'Bearer ' + PUBLIK, 'Content-Type': 'application/json' },
  body: JSON.stringify({ p_rahasia: KUNCI, p_kunci: 'keuangan', p_nilai: nilai }) });
const hasil = await r.json().catch(() => ({}));
if (!r.ok || !hasil.ok) throw new Error('gagal menyimpan: ' + r.status + ' ' + JSON.stringify(hasil).slice(0, 200));
console.log('tersimpan ke minyak_nilai[keuangan]');
