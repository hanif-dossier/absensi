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
- **Invoice Harian** (ubin di beranda pemilik): satu invoice = satu hari, persis lembar harian Excel penjualan: beberapa
  blok (Mobil 1, Mobil 2, Gudang), tiap blok berisi baris toko (nama, barang, qty, berat, harga, jumlah, Bayar hutang,
  Hutang; retur/satuan/alamat/modal di "Lain") dan rekapan akhirnya (pengeluaran, setoran, selisih kas). Hari baru
  menyalin susunan blok hari sebelumnya. Hutang toko dihitung sendiri: semua hutang - semua bayar (kolom Bayar atau bayar
  langsung/transfer dari halaman daftar). Unduhan: invoice harian PDF (semua blok), surat jalan per mobil PDF, nota dan
  surat jalan per toko (format berkas Word), Excel bersusunan lembar harian (blok demi blok). Data di `minyak_nilai`
  kunci `invoice` ({ profil, daftar, bayar }), ditulis lewat `minyak_invoice_tulis` (pemilik saja); kepala surat hanya
  ada di database. Bentuk lama (satu pengantar per invoice) diubah otomatis oleh `normHarian`.
- **Hutang toko** (halaman Invoice Harian): saldo bon lama dari LAPORAN HUTANG PENJUALAN.xlsx dipindah sekali lewat
  `alat/hutang-impor.mjs` (baca `alat/hutang_excel.py`) ke `invoice.awal` (tgl, toko, jalur, jumlah, kendi) + `invoice.jalur`.
  Sisa = bon lama + hutang di invoice - bayar (bon tertua lunas dulu); kendi kosong dikurangi retur. Daftar per jalur,
  tombol Atur (samakan nama toko / pindah jalur), cetak PDF "Bon Hutang" per jalur seperti lembar Excel.
- **Invoice masuk Keuangan** (`gabungInvoiceKeu`): saat data keuangan dimuat, invoice harian yang hari dan pengantarnya
  belum ada di Excel penjualan ditambahkan ke minggu, hari, pengantar, jenis, dan biaya (hanya di aplikasi; database
  keuangan tetap hasil Excel). Yang sudah ada di Excel dilewati supaya tidak terhitung dua kali. Kendi kosong tidak masuk
  omzet. Kartu invoice menampilkan statusnya.
- **Modal di invoice harian**: otomatis dari data Pembelian minyak (rata-rata harga per kg pembelian curah 7 hari
  terakhir sampai tanggal invoice, ditimbang kg; dus dari pembelian dus terakhir; cadangan modal Excel terakhir).
  Diketik hanya kalau beda, per hari atau per toko (tombol "Lain"). Nilai yang dipakai disimpan di invoice.
  Dipakai untuk laba kotor di aplikasi, keuangan, laporan harian, dan dashboard; tidak tercetak di PDF untuk toko.
- **Lembar isian** seperti Excel di laptop: satu toko satu baris (retur, alamat, modal toko dilipat di "Lain"), Enter
  pindah ke kotak berikutnya dan menambah toko baru di kotak terakhir. Di HP tetap berbentuk kartu.
- **Laporan harian & dashboard** (laptop, `alat/gabung-invoice.mjs` dipanggil `perbarui-otomatis.mjs`): invoice harian
  minggu itu dijadikan blok pengantar seperti sheet Excel sebelum laporan disusun (anti dobel per hari + pengantar).
  `--terbaru` memilih minggu terbaru dari Excel atau invoice, jadi minggu tanpa berkas Excel tetap dilaporkan.
- **Bebas Hutang** (ubin di beranda; pemilik dan bos boleh mengisi): daftar hutang bos (kreditur, jenis, sisa pokok,
  bunga % per bulan, cicilan wajib, tanggal cicil, jatuh tempo, jaminan, tunggakan), catatan cicilan yang dibayar
  (bagian bunga dipisah, sisa pokok berkurang otomatis), pengambilan pribadi dan biaya tetap di luar Excel. Kemampuan
  bayar = laba bersih rata-rata per bulan dari Keuangan - prive - biaya tetap - bunga; perkiraan lunas kasar. Data di
  `minyak_nilai` kunci `hutang-bos` lewat `minyak_nilai_tulis` (pemilik/bos, kunci dibatasi). Tahap 1 dari rencana
  bebas hutang; tahap berikutnya (neraca, kebocoran, jadwal pelunasan) menyusul.

Tidak ada data gaji maupun rahasia di repo ini.
