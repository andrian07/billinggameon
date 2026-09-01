# Changelog

## 1.10.0+21

### Integrasi gameon (server pusat) — customer, saldo, point, waktu tersimpan

- **Menu Member** kini mengambil data langsung dari gameon (online), bukan salinan lokal —
  termasuk **kolom SALDO baru** di daftar member di samping POIN.
- **Katalog paket Saldo** dan **katalog Tukar Point** dipindah ke gameon; billing_api hanya proxy.
  Menu-menu ini **wajib** koneksi ke gameon — kalau server pusat tidak bisa dihubungi, menu tidak
  bisa dibuka (tidak ada data lokal yang basi).
- **Buka meja dengan member** wajib validasi ke gameon: nama member diambil dari gameon dan
  disimpan sebagai snapshot; kalau gameon down atau member tidak ditemukan, buka meja pakai member
  ditolak. Buka meja tanpa member tetap jalan offline.
- **Tambah saldo (top-up)**, **potong saldo (Potong Saldo)**, **penambahan point**, **simpan
  waktu**, dan **pakai waktu tersimpan** semuanya diproses langsung di gameon (atomik + idempoten).
  Cabang hanya menyimpan `transaksi_saldo` (rekap kasir) dan nota transaksi.
- Kolom `customer_saldo` / `customer_point` lokal di-nol-kan dan tidak lagi dipakai.
- Notifikasi permintaan top-up member: tampil sebagai daftar; konfirmasi persetujuan muncul saat
  baris diketuk (pilih metode "Diterima via" lalu Setujui). Auto-refresh tiap 5 detik.

### Fitur dari billingbilliad

- **PIN keamanan** untuk aksi destruktif (batal meja, cancel transaksi cafe, hapus keep) —
  Setting > PIN, hanya owner yang bisa mengatur/mengaktifkan.
- **Harga 3 tingkat** (Harga 1/2/3) di Setting > Harga.
- **Promo dengan jadwal**: batasan hari + jendela jam berlaku promo.
- **Ubah metode pembayaran** dari daftar transaksi (billing & cafe) — kecuali "Potong Saldo".
- **Laporan Pembelian** + kolom No. Invoice Supplier pada pembelian.
- **Filter tanggal** di Tutup Kas.
- Batal meja dibatasi 6 menit pertama sesi; meja dengan promo paket (Fix) tidak bisa tambah durasi;
  timer kedaluwarsa ditandai merah; tombol "Urutkan Timer" untuk menyortir meja Timer paling dekat
  habis; ringkasan omzet ("Rincian Transaksi") hanya untuk owner.
- Daftar hak akses role disamakan dengan menu sidebar (Member, Tukar Point, dll).

### Rilis

- Ditambahkan GitHub Actions workflow `Release Windows` — build otomatis `.zip` Windows saat
  push tag `v*.*.*` dan membuat GitHub Release.
- Ditambahkan `.gitignore` (berhenti melacak folder `build/`).
