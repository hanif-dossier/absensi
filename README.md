# Absensi & Gaji

Aplikasi web (bisa dipasang di HP) untuk usaha minyak: pemilik mengisi gaji harian, potongan, dan hutang;
tiap karyawan masuk dengan PIN dan hanya melihat datanya sendiri.

- `index.html` seluruh aplikasi (tanpa build tool), `sw.js` + `manifest.json` supaya bisa dipasang.
- `supabase/skema.sql` tabel `minyak_*` dan fungsi pintu (`minyak_masuk`, `minyak_data`, `minyak_simpan`, ...).
  Tabel dikunci RLS tanpa kebijakan; semua akses lewat fungsi yang memeriksa token sesi.
- `supabase/pasang.mjs` memasang skema, mengimpor data, membuat sandi pemilik dan PIN awal.
- **Harga Toko**: harga curah (per kendi) dan dus per toko, dengan riwayat perubahan. Pemilik mengisi lewat ubin
  "Harga Toko" (hanya kotak yang berubah yang disimpan; harga sama tidak dicatat ulang); karyawan melihatnya di tab
  "Harga toko". Data satu JSON di `minyak_nilai` kunci `harga`: fungsi `minyak_harga_baca` (semua sesi) dan
  `minyak_harga_tulis` (pemilik saja).

Tidak ada data gaji maupun rahasia di repo ini.
