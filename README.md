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
- **Invoice & Surat Jalan** (ubin di beranda pemilik): nota penjualan ke toko. Satu nomor invoice diunduh jadi dua PDF
  hitam-putih: invoice (No, Nama Barang, Qty, Berat, Harga, Jumlah, total, terbilang, tanda terima dan hormat kami) dan
  surat jalan tanpa harga (Nama Barang, Qty, Berat, Keterangan, PERHATIAN, tiga tanda tangan), mengikuti berkas Word
  surat jalan pemilik. Harga terisi dari Harga Toko pada tanggal invoice. Status belum lunas atau lunas; invoice bisa
  diubah atau dibatalkan (tidak dihapus). Data di `minyak_nilai` kunci `invoice`, ditulis lewat `minyak_invoice_tulis`
  (pemilik saja). Kepala surat (nama usaha, alamat, telepon) hanya ada di database, tidak di kode.

Tidak ada data gaji maupun rahasia di repo ini.
