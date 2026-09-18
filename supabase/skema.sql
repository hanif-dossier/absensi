-- Absensi & Gaji Usaha Minyak: skema database (Supabase proyek "markasku", tabel berawalan minyak_).
-- Sengaja TIDAK memakai auth.users: pemilik masuk dengan sandi, karyawan dengan PIN, lewat fungsi di bawah.
-- Dengan begitu aplikasi ini tidak terkait akun Markasku maupun Hanif Dossier.
-- Semua tabel dikunci RLS tanpa kebijakan apa pun: satu-satunya pintu adalah fungsi SECURITY DEFINER.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.minyak_karyawan (
  kode text primary key,                       -- slug nama, mis. "bang-hen"
  data jsonb not null,                         -- { nama, aktif, minggu[], hutang[] } sama dengan panel lama
  pin_hash text,                               -- bcrypt; null = belum punya PIN (belum bisa masuk)
  gagal int not null default 0,                -- hitungan salah PIN berturut-turut
  kunci_sampai timestamptz,                    -- terkunci sementara sampai waktu ini
  diubah timestamptz not null default now()
);
create table if not exists public.minyak_pemilik (
  id int primary key default 1 check (id = 1), -- hanya satu baris
  sandi_hash text not null,
  gagal int not null default 0,
  kunci_sampai timestamptz
);
create table if not exists public.minyak_sesi (
  token_hash text primary key,                 -- sha256(token); token asli hanya ada di HP pemakai
  peran text not null check (peran in ('pemilik','karyawan')),
  kode text references public.minyak_karyawan(kode) on delete cascade,
  dibuat timestamptz not null default now(),
  kedaluwarsa timestamptz not null
);
alter table public.minyak_karyawan enable row level security;
alter table public.minyak_pemilik  enable row level security;
alter table public.minyak_sesi     enable row level security;

-- Pembantu: sha256 heksadesimal
create or replace function public.minyak__h(t text) returns text language sql immutable
set search_path = public, extensions as $f$ select encode(extensions.digest(t, 'sha256'), 'hex') $f$;

-- Pembantu: baca sesi dari token. Baris kosong kalau tidak sah atau kedaluwarsa.
create or replace function public.minyak__sesi(p_token text) returns public.minyak_sesi language sql stable security definer
set search_path = public, extensions as $f$
  select s from public.minyak_sesi s where s.token_hash = public.minyak__h(coalesce(p_token,'')) and s.kedaluwarsa > now() $f$;

-- MASUK. p_kode = 'pemilik' atau kode karyawan. Salah 5 kali => terkunci 15 menit.
-- Sengaja mengembalikan {ok:false} (bukan raise) supaya hitungan gagal tidak ikut di-rollback.
create or replace function public.minyak_masuk(p_kode text, p_pin text) returns jsonb language plpgsql security definer
set search_path = public, extensions as $f$
declare v_kode text := lower(trim(coalesce(p_kode,''))); v_hash text; v_kunci timestamptz; v_nama text; v_token text; v_peran text; v_aktif boolean := true;
begin
  if v_kode = 'pemilik' then
    select sandi_hash, kunci_sampai into v_hash, v_kunci from minyak_pemilik where id = 1; v_peran := 'pemilik'; v_nama := 'Pemilik';
  else
    select pin_hash, kunci_sampai, data->>'nama', coalesce((data->>'aktif')::boolean, true) into v_hash, v_kunci, v_nama, v_aktif from minyak_karyawan where kode = v_kode; v_peran := 'karyawan';
  end if;
  if v_kunci is not null and v_kunci > now() then
    return jsonb_build_object('ok', false, 'pesan', 'Terlalu banyak percobaan. Coba lagi pukul ' || to_char(v_kunci at time zone 'Asia/Jakarta', 'HH24:MI') || ' WIB.');
  end if;
  if v_hash is null or p_pin is null or v_hash <> extensions.crypt(p_pin, v_hash) or (v_peran = 'karyawan' and not coalesce(v_aktif, true)) then
    if v_peran = 'pemilik' then
      update minyak_pemilik set kunci_sampai = case when gagal + 1 >= 5 then now() + interval '15 minutes' else kunci_sampai end, gagal = case when gagal + 1 >= 5 then 0 else gagal + 1 end where id = 1;
    else
      update minyak_karyawan set kunci_sampai = case when gagal + 1 >= 5 then now() + interval '15 minutes' else kunci_sampai end, gagal = case when gagal + 1 >= 5 then 0 else gagal + 1 end where kode = v_kode;
    end if;
    return jsonb_build_object('ok', false, 'pesan', 'Kode atau PIN salah.');
  end if;
  if v_peran = 'pemilik' then update minyak_pemilik set gagal = 0, kunci_sampai = null where id = 1;
  else update minyak_karyawan set gagal = 0, kunci_sampai = null where kode = v_kode; end if;
  v_token := encode(extensions.gen_random_bytes(24), 'hex');
  delete from minyak_sesi where kedaluwarsa < now();
  insert into minyak_sesi(token_hash, peran, kode, kedaluwarsa)
    values (minyak__h(v_token), v_peran, case when v_peran = 'karyawan' then v_kode end, now() + case when v_peran = 'pemilik' then interval '30 days' else interval '90 days' end);
  return jsonb_build_object('ok', true, 'token', v_token, 'peran', v_peran, 'kode', case when v_peran = 'karyawan' then v_kode end, 'nama', v_nama);
end $f$;

-- DATA. Pemilik: semua karyawan. Karyawan: hanya miliknya sendiri.
create or replace function public.minyak_data(p_token text) returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $f$
declare s minyak_sesi := minyak__sesi(p_token);
begin
  if s.token_hash is null then return jsonb_build_object('ok', false, 'pesan', 'Sesi habis. Masuk lagi.'); end if;
  if s.peran = 'pemilik' then
    return jsonb_build_object('ok', true, 'peran', 'pemilik',
      'karyawan', coalesce((select jsonb_object_agg(kode, data) from minyak_karyawan), '{}'::jsonb),
      'pin', coalesce((select jsonb_object_agg(kode, pin_hash is not null) from minyak_karyawan), '{}'::jsonb));
  end if;
  return jsonb_build_object('ok', true, 'peran', 'karyawan', 'kode', s.kode,
    'data', (select data from minyak_karyawan where kode = s.kode),
    'diubah', (select diubah from minyak_karyawan where kode = s.kode));
end $f$;

-- SIMPAN (pemilik). p_semua = { kode: {nama, aktif, minggu, hutang}, ... }; hanya kode yang dikirim yang ditimpa.
create or replace function public.minyak_simpan(p_token text, p_semua jsonb) returns jsonb language plpgsql security definer
set search_path = public, extensions as $f$
declare s minyak_sesi := minyak__sesi(p_token); k text; n int := 0;
begin
  if s.token_hash is null or s.peran <> 'pemilik' then return jsonb_build_object('ok', false, 'pesan', 'Hanya pemilik yang bisa menyimpan.'); end if;
  for k in select jsonb_object_keys(p_semua) loop
    if k !~ '^[a-z0-9]+(-[a-z0-9]+)*$' or k = 'pemilik' then continue; end if;
    insert into minyak_karyawan(kode, data) values (k, p_semua->k)
      on conflict (kode) do update set data = excluded.data, diubah = now();
    n := n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'tersimpan', n);
end $f$;

-- ATUR PIN karyawan (pemilik). PIN 6 angka.
create or replace function public.minyak_atur_pin(p_token text, p_kode text, p_pin text) returns jsonb language plpgsql security definer
set search_path = public, extensions as $f$
declare s minyak_sesi := minyak__sesi(p_token);
begin
  if s.token_hash is null or s.peran <> 'pemilik' then return jsonb_build_object('ok', false, 'pesan', 'Hanya pemilik.'); end if;
  if coalesce(p_pin,'') !~ '^[0-9]{6}$' then return jsonb_build_object('ok', false, 'pesan', 'PIN harus 6 angka.'); end if;
  update minyak_karyawan set pin_hash = extensions.crypt(p_pin, extensions.gen_salt('bf', 10)), gagal = 0, kunci_sampai = null where kode = p_kode;
  if not found then return jsonb_build_object('ok', false, 'pesan', 'Karyawan tidak ditemukan. Simpan dulu datanya.'); end if;
  delete from minyak_sesi where kode = p_kode;   -- PIN diganti => HP lama harus masuk ulang
  return jsonb_build_object('ok', true);
end $f$;

-- GANTI sandi/PIN sendiri. Pemilik: sandi min. 8 karakter. Karyawan: PIN 6 angka.
create or replace function public.minyak_ganti_sandi(p_token text, p_lama text, p_baru text) returns jsonb language plpgsql security definer
set search_path = public, extensions as $f$
declare s minyak_sesi := minyak__sesi(p_token); v_hash text;
begin
  if s.token_hash is null then return jsonb_build_object('ok', false, 'pesan', 'Sesi habis. Masuk lagi.'); end if;
  if s.peran = 'pemilik' then
    select sandi_hash into v_hash from minyak_pemilik where id = 1;
    if v_hash <> extensions.crypt(coalesce(p_lama,''), v_hash) then return jsonb_build_object('ok', false, 'pesan', 'Sandi lama salah.'); end if;
    if length(coalesce(p_baru,'')) < 8 then return jsonb_build_object('ok', false, 'pesan', 'Sandi baru minimal 8 karakter.'); end if;
    update minyak_pemilik set sandi_hash = extensions.crypt(p_baru, extensions.gen_salt('bf', 10)) where id = 1;
    delete from minyak_sesi where peran = 'pemilik' and token_hash <> s.token_hash;
  else
    select pin_hash into v_hash from minyak_karyawan where kode = s.kode;
    if v_hash <> extensions.crypt(coalesce(p_lama,''), v_hash) then return jsonb_build_object('ok', false, 'pesan', 'PIN lama salah.'); end if;
    if coalesce(p_baru,'') !~ '^[0-9]{6}$' then return jsonb_build_object('ok', false, 'pesan', 'PIN baru harus 6 angka.'); end if;
    update minyak_karyawan set pin_hash = extensions.crypt(p_baru, extensions.gen_salt('bf', 10)) where kode = s.kode;
    delete from minyak_sesi where kode = s.kode and token_hash <> s.token_hash;
  end if;
  return jsonb_build_object('ok', true);
end $f$;

create or replace function public.minyak_keluar(p_token text) returns jsonb language sql security definer
set search_path = public, extensions as $f$
  with d as (delete from public.minyak_sesi where token_hash = public.minyak__h(coalesce(p_token,'')) returning 1) select jsonb_build_object('ok', true) $f$;

-- Hak panggil: hanya fungsi "pintu" yang boleh dipanggil dari aplikasi (kunci publik = peran anon).
revoke all on function public.minyak__h(text), public.minyak__sesi(text) from public, anon, authenticated;
grant execute on function public.minyak_masuk(text,text), public.minyak_data(text), public.minyak_simpan(text,jsonb),
  public.minyak_atur_pin(text,text,text), public.minyak_ganti_sandi(text,text,text), public.minyak_keluar(text) to anon, authenticated;
notify pgrst, 'reload schema';

-- =====================================================================================================
-- NILAI BEBAS (pemilik saja): dipakai untuk data Dashboard Keuangan Minyak (kunci 'keuangan').
-- Diisi oleh supabase/muat-keuangan.mjs (kunci service, melewati RLS); dibaca aplikasi lewat fungsi di bawah.
-- =====================================================================================================
create table if not exists public.minyak_nilai (
  kunci text primary key,
  nilai jsonb not null,
  diubah timestamptz not null default now()
);
alter table public.minyak_nilai enable row level security;

create or replace function public.minyak_ambil_nilai(p_token text, p_kunci text) returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $f$
declare s minyak_sesi := minyak__sesi(p_token);
begin
  if s.token_hash is null then return jsonb_build_object('ok', false, 'pesan', 'Sesi habis. Masuk lagi.'); end if;
  if s.peran <> 'pemilik' then return jsonb_build_object('ok', false, 'pesan', 'Hanya pemilik.'); end if;
  return jsonb_build_object('ok', true, 'nilai', (select nilai from minyak_nilai where kunci = p_kunci),
    'diubah', (select diubah from minyak_nilai where kunci = p_kunci));
end $f$;
grant execute on function public.minyak_ambil_nilai(text,text) to anon, authenticated;
notify pgrst, 'reload schema';

-- =====================================================================================================
-- TULIS NILAI dari luar (GitHub Actions) dengan kunci sempit: hanya boleh menulis kunci 'keuangan'.
-- Kunci aslinya ada di rahasia/absensi-minyak.txt dan secret GitHub SINKRON_KUNCI; di sini hanya sha256-nya.
-- =====================================================================================================
alter table public.minyak_pemilik add column if not exists sinkron_hash text;
create or replace function public.minyak_tulis_nilai(p_rahasia text, p_kunci text, p_nilai jsonb) returns jsonb language plpgsql security definer
set search_path = public, extensions as $f$
begin
  if p_kunci <> 'keuangan' then return jsonb_build_object('ok', false, 'pesan', 'kunci tidak diizinkan'); end if;
  if coalesce(length(p_rahasia), 0) < 32 or not exists (select 1 from minyak_pemilik where id = 1 and sinkron_hash = minyak__h(p_rahasia)) then
    return jsonb_build_object('ok', false, 'pesan', 'ditolak'); end if;
  insert into minyak_nilai(kunci, nilai) values (p_kunci, p_nilai) on conflict (kunci) do update set nilai = excluded.nilai, diubah = now();
  return jsonb_build_object('ok', true);
end $f$;
grant execute on function public.minyak_tulis_nilai(text,text,jsonb) to anon, authenticated;
notify pgrst, 'reload schema';

-- =====================================================================================================
-- HARGA TOKO: harga jual minyak curah (per kendi) dan dus per toko, lengkap dengan riwayat perubahan.
-- Disimpan di minyak_nilai kunci 'harga' berbentuk
--   { toko: [ { id, nama, aktif, curah: [{tgl, harga}, ...], dus: [{tgl, harga}, ...] }, ... ] }
-- Riwayat hanya bertambah saat harga BERUBAH (harga sama = tidak dicatat lagi). Semua yang punya sesi sah
-- (pemilik maupun karyawan) boleh MEMBACA; hanya pemilik boleh MENULIS.
-- =====================================================================================================
create or replace function public.minyak_harga_baca(p_token text) returns jsonb language plpgsql stable security definer
set search_path = public, extensions as $f$
declare s minyak_sesi := minyak__sesi(p_token);
begin
  if s.token_hash is null then return jsonb_build_object('ok', false, 'pesan', 'Sesi habis. Masuk lagi.'); end if;
  return jsonb_build_object('ok', true, 'nilai', coalesce((select nilai from minyak_nilai where kunci = 'harga'), '{"toko":[]}'::jsonb),
    'diubah', (select diubah from minyak_nilai where kunci = 'harga'));
end $f$;

create or replace function public.minyak_harga_tulis(p_token text, p_nilai jsonb) returns jsonb language plpgsql security definer
set search_path = public, extensions as $f$
declare s minyak_sesi := minyak__sesi(p_token);
begin
  if s.token_hash is null then return jsonb_build_object('ok', false, 'pesan', 'Sesi habis. Masuk lagi.'); end if;
  if s.peran <> 'pemilik' then return jsonb_build_object('ok', false, 'pesan', 'Hanya pemilik.'); end if;
  if jsonb_typeof(p_nilai->'toko') is distinct from 'array' then return jsonb_build_object('ok', false, 'pesan', 'Bentuk data salah.'); end if;
  if length(p_nilai::text) > 500000 then return jsonb_build_object('ok', false, 'pesan', 'Data terlalu besar.'); end if;
  insert into minyak_nilai(kunci, nilai) values ('harga', p_nilai) on conflict (kunci) do update set nilai = excluded.nilai, diubah = now();
  return jsonb_build_object('ok', true, 'diubah', now());
end $f$;
grant execute on function public.minyak_harga_baca(text), public.minyak_harga_tulis(text,jsonb) to anon, authenticated;
notify pgrst, 'reload schema';
