# Changelog

## v1.11.0 — 2026-09-02

Menu Game, penjaga bentrok booking, poin dihitung saat pembayaran, dan sinkronisasi
transaksi/booking ke & dari gameon.

### Menu baru — Setting > Game
- Katalog game dengan isian: Image Game, Nama Game, **Cabang**, **Console**,
  **Tersedia di Ruangan** (dari kategori meja), Keterangan.
- Cabang, Console, dan Ruangan **bisa pilih lebih dari satu** (chip multi-select).
- Data terpusat di gameon (pola sama dengan Tukar Point); file gambar disimpan di
  billing_api (`uploads/game/`), opsional dengan gambar default.
- Perizinan lewat Role & Akses (menu code `setting_game`).

### Booking Room
- Dua tab: **Belum Lewat** / **Sudah Lewat** (booking yang jam mulai + durasinya
  sudah habis), masing-masing dengan jumlahnya.
- Default menampilkan **semua tanggal**, bukan hanya hari ini.
- Booking yang sudah lewat: baris tampil redup, tombol "Buka Meja" dinonaktifkan.
- Menekan "Buka Meja" sebelum jam mulai → modal **"Belum waktunya"**.
- Auto-refresh dipercepat jadi **3 detik**, ditambah tombol **Sinkronkan** dan
  indikator **"Sinkron: Xs lalu"** (jadi merah kalau data sudah lama tidak diperbarui).
- Badge notifikasi = jumlah booking yang **belum di-acc dan belum lewat** (bukan lagi
  jumlah baris notifikasi yang belum dibaca).
- Notifikasi desktop kini muncul **sekali** per booking, tidak berulang tiap polling.
- Booking yang sudah dibuka mejanya otomatis ditandai terbaca → tidak muncul lagi.

### Buka Meja (Billing)
- **Peringatan bentrok**: bila kategori meja punya booking member yang jamnya
  beririsan dengan sesi Timer yang mau dibuka, muncul dialog konfirmasi
  (kasir tetap bisa melanjutkan).
- **Peringatan data basi**: bila data booking lokal sudah lama tidak tersinkron
  dari gameon (kemungkinan masalah jaringan).
- Pengecekan memakai mirror booking lokal di billing_api yang di-refresh tiap 3 detik
  — tidak perlu online ke gameon setiap kali buka meja.

### Poin member
- Poin **tidak lagi diberikan saat buka meja/booking** — seluruh poin diberikan
  saat **pembayaran**, baik mode Timer maupun Reguler.
- Patokan poin = **durasi yang dibayar**, bukan durasi main. Contoh: saat simpan
  waktu, pelanggan membayar penuh (mis. 25 jam) → langsung dapat poin 25 jam; saat
  sisa waktu itu dipakai lagi → tidak dapat poin (sudah dapat penuh di awal).

### Laporan Billing
- Kolom **Promo** — nama promo yang dipakai; promo tipe Fix menampilkan nominal paketnya.
- Kolom **Diskon** menampilkan **0** untuk promo tipe Fix (nominalnya sudah tercermin
  di subtotal/total).
- Kolom **Keterangan** — nota yang dibayar pakai sisa waktu menyebut nilai tagihan
  yang seharusnya. Total diskon di footer ikut menyesuaikan.

### Promo Cafe (baru)
- Halaman Promo dipisah menjadi tab **Promo Billing** dan **Promo Cafe**.
- Promo Cafe: harga promo tetap untuk sekumpulan produk; saat dipakai di POS,
  subtotal produk-produk tersebut di keranjang di-reprice ke harga promo.
- Dialog pembayaran cafe: pilih promo cafe + isi keterangan promo; potongan dihitung otomatis.

### Perhitungan hari (backend)
- Semua laporan dan Tutup Kas memakai rentang hari **06:00:00–23:59:59 pada tanggal
  itu sendiri** (sebelumnya 04:00–03:00 keesokan hari, dan 05:00 untuk rekap kasir).
  Transaksi jam 00:00–05:59 tidak lagi masuk ke perhitungan hari mana pun.

### Sinkronisasi ke gameon (backend)
- Setiap transaksi **billing & cafe** (dibuat / dibatalkan / diedit metode bayarnya)
  di-push ke gameon (tabel `branch_transaction*`) untuk laporan terpusat. Idempoten
  per (cabang, nomor invoice); tidak ada backfill data lama.
- Setiap polling booking sekaligus me-refresh mirror booking lokal per cabang.

### Perbaikan lain
- Notifikasi desktop permintaan Top Up juga hanya muncul sekali per permintaan.
- Badge notifikasi (booking & top up) tidak lagi "nyangkut" di angka lama saat
  koneksi ke gameon bermasalah — angka disegarkan dari data yang sudah tercatat lokal.

---

### Catatan deploy

Rilis ini mengubah **3 komponen** — semuanya perlu di-update bersamaan:

1. **billinggameon** (aplikasi Flutter) — build baru dari rilis ini.
2. **billing_api** — `controllers/Billing.php`, `Cafe.php`, `Master.php`, `Setting.php`,
   `Report.php`; `models/Billing_model.php`, `Cafe_model.php`, `Master_model.php`;
   `libraries/Gameon.php`. Buat folder `uploads/game/` dan pastikan writable oleh web server.
   DB `billing_flutter`: tabel baru `booking_request`, `booking_sync_state`;
   kolom baru `transaction.transaction_saved_time_value`; row `ms_menu` untuk `setting_game`.
3. **gameon** — `controllers/Api.php`, `models/Api_model.php`.
   DB `gameon`: tabel baru `ms_game`, `branch_transaction`, `branch_transaction_cafe`,
   `branch_transaction_cafe_detail`; folder gambar game.

---

## v1.10.0

gameon online integration + billiard features (lihat commit `fb52c37`).
