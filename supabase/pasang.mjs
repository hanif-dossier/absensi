// Memasang database Absensi & Gaji: jalankan skema, impor data panel lama, buat sandi pemilik + PIN karyawan.
// Jalankan dari folder yang punya modul "pg" (npm i pg):  node pasang.mjs <folder-json-karyawan> [--pin-ulang]
// - Skema aman dijalankan berulang (create if not exists / create or replace).
// - Data karyawan ditimpa dari JSON hanya kalau diberi folder; PIN & sandi hanya dibuat kalau belum ada (atau --pin-ulang).
// - Sandi & PIN yang baru dibuat ditulis ke D:/Ai Agent/rahasia/absensi-minyak.txt (tidak pernah dicetak ke layar).
import fs from 'fs'; import path from 'path'; import crypto from 'crypto'; import pg from 'pg';

const RAHASIA = 'D:/Ai Agent/rahasia/supabase-markasku.txt';
const KELUAR  = 'D:/Ai Agent/rahasia/absensi-minyak.txt';
const SKEMA   = 'D:/Ai Agent/absensi/supabase/skema.sql';
const folder = process.argv[2] && !process.argv[2].startsWith('--') ? process.argv[2] : null;
const pinUlang = process.argv.includes('--pin-ulang');

const pw = (fs.readFileSync(RAHASIA, 'utf8').match(/^DB_PASSWORD=(.+)$/m) || [])[1].trim();
const db = new pg.Client({ host: 'aws-0-ap-south-1.pooler.supabase.com', port: 5432, user: 'postgres.hzxfheydtrjhizbwbddh',
  password: pw, database: 'postgres', ssl: { rejectUnauthorized: false } });
await db.connect();

await db.query(fs.readFileSync(SKEMA, 'utf8'));
console.log('skema terpasang');

if (folder) {
  for (const f of fs.readdirSync(folder).filter(f => f.endsWith('.json'))) {
    const kode = path.basename(f, '.json'); const data = JSON.parse(fs.readFileSync(path.join(folder, f), 'utf8'));
    delete data.__name__; delete data.version;
    await db.query(`insert into minyak_karyawan(kode, data) values ($1, $2)
      on conflict (kode) do update set data = excluded.data, diubah = now()`, [kode, data]);
    console.log('impor', kode, '-', (data.minggu || []).length, 'minggu');
  }
}

// PIN 6 angka acak yang tidak berpola gampang (bukan 000000, 123456, dst.)
const pinAcak = () => { for (;;) { const p = String(crypto.randomInt(0, 1e6)).padStart(6, '0');
  if (!/^(\d)\1{5}$/.test(p) && !'01234567890 09876543210'.includes(p)) return p; } };
// Sandi pemilik: 4 kata + angka, gampang diketik di HP
const KATA = ['minyak','jeriken','gudang','subuh','kapuas','tembaga','lentera','pasar','dermaga','senja','roda','kunci','kopi','hujan','bukit','perahu'];
const sandiAcak = () => Array.from({ length: 4 }, () => KATA[crypto.randomInt(0, KATA.length)]).join('-') + '-' + crypto.randomInt(10, 100);

const baris = [];
const { rows: pem } = await db.query('select 1 from minyak_pemilik where id = 1');
if (!pem.length || pinUlang) {
  const s = sandiAcak();
  await db.query(`insert into minyak_pemilik(id, sandi_hash) values (1, extensions.crypt($1, extensions.gen_salt('bf', 10)))
    on conflict (id) do update set sandi_hash = excluded.sandi_hash, gagal = 0, kunci_sampai = null`, [s]);
  baris.push(`PEMILIK  kode: pemilik   sandi: ${s}`);
}
const { rows: kar } = await db.query(`select kode, data->>'nama' nama, pin_hash is not null punya from minyak_karyawan order by kode`);
for (const k of kar) {
  if (k.punya && !pinUlang) continue;
  const p = pinAcak();
  await db.query(`update minyak_karyawan set pin_hash = extensions.crypt($1, extensions.gen_salt('bf', 10)), gagal = 0, kunci_sampai = null where kode = $2`, [p, k.kode]);
  baris.push(`${k.nama.padEnd(12)} kode: ${k.kode.padEnd(10)} PIN: ${p}`);
}
if (baris.length) {
  const kepala = `# Absensi & Gaji Usaha Minyak - sandi pemilik dan PIN awal karyawan (dibuat ${new Date().toISOString().slice(0, 16)}Z)\n# JANGAN dibagikan utuh. Beri tiap karyawan hanya baris miliknya. PIN bisa diganti dari dalam aplikasi.\n`;
  fs.writeFileSync(KELUAR, kepala + baris.join('\n') + '\n');
  console.log(baris.length, 'sandi/PIN baru ditulis ke', KELUAR);
} else console.log('tidak ada sandi/PIN baru');

const { rows: cek } = await db.query('select count(*)::int n, count(pin_hash)::int berpin from minyak_karyawan');
console.log('karyawan:', cek[0].n, 'berpin:', cek[0].berpin);
await db.end();
