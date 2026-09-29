# Absensi & Gaji

Aplikasi web (bisa dipasang di HP) untuk usaha minyak: pemilik mengisi gaji harian, potongan, dan hutang;
tiap karyawan masuk dengan PIN dan hanya melihat datanya sendiri.

- `index.html` seluruh aplikasi (tanpa build tool), `sw.js` + `manifest.json` supaya bisa dipasang.
- `supabase/skema.sql` tabel `minyak_*` dan fungsi pintu (`minyak_masuk`, `minyak_data`, `minyak_simpan`, ...).
  Tabel dikunci RLS tanpa kebijakan; semua akses lewat fungsi yang memeriksa token sesi.
- `supabase/pasang.mjs` memasang skema, mengimpor data, membuat sandi pemilik dan PIN awal.
- **Akun bos** (kode `bos`, sandi di `rahasia/absensi-minyak.txt`): melihat semua yang dilihat pemilik (gaji per
  karyawan, keuangan, harga toko, laporan PDF) tanpa satu pun tombol ubah; fungsi tulis di database menolak peran `bos`.
- **Keuangan** disusun sebagai alur: kalimat ringkasan, lalu omzet → modal → laba kotor → biaya → laba bersih,
  per hari, per pengantar, per jenis, biaya per kelompok, tren laba bersih. PDF mengikuti urutan yang sama (`ringkasKeu`).
- **Harga Toko**: harga curah (per kendi) dan dus per toko, dengan riwayat perubahan. Pemilik mengisi lewat ubin
  "Harga Toko" (hanya kotak yang berubah yang disimpan; harga sama tidak dicatat ulang); karyawan melihatnya di tab
  "Harga toko". Data satu JSON di `minyak_nilai` kunci `harga`: fungsi `minyak_harga_baca` (semua sesi) dan
  `minyak_harga_tulis` (pemilik saja).
- **Invoice Harian** (ubin di beranda pemilik): satu invoice untuk satu hari pengantaran (satu pengantar), berisi
  semua toko, disusun seperti lembar harian Excel penjualan (toko, barang, qty, berat, harga, jumlah, retur, hutang) dan
  rekapan akhirnya (toko hutang, bayar hutang lama, pengeluaran, setoran, selisih kas). Unduhan: invoice harian PDF,
  surat jalan harian PDF (tanpa harga, kolom tanda tangan tiap toko), nota dan surat jalan per toko (format berkas Word
  surat jalan, satu halaman per toko dalam satu PDF), dan Excel bersusunan lembar penjualan. Daftar hutang toko bisa
  ditandai lunas. Data di `minyak_nilai` kunci `invoice`, ditulis lewat `minyak_invoice_tulis` (pemilik saja); kepala
  surat hanya ada di database, tidak di kode.
- **Invoice masuk Keuangan** (`gabungInvoiceKeu`): saat data keuangan dimuat, invoice harian yang hari dan pengantarnya
  belum ada di Excel penjualan ditambahkan ke minggu, hari, pengantar, jenis, dan biaya (hanya di aplikasi; database
  keuangan tetap hasil Excel). Yang sudah ada di Excel dilewati supaya tidak terhitung dua kali. Kendi kosong tidak masuk
  omzet; modal curah = kg x modal per kg minggu Excel terakhir. Kartu invoice menampilkan statusnya.

Tidak ada data gaji maupun rahasia di repo ini.
