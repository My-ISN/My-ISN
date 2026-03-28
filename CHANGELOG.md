# Changelog

## [0.13.0] - 2026-03-28

### Added

- **Modul Hutang Premium**: Desain ulang total dialog "Tambah Hutang" dan "Bayar Cicilan" menggunakan **Premium Bottom Sheet** yang sepenuhnya *theme-aware* (support Dark/Light Mode) dan memiliki estetika *high-fidelity*.
- **Hapus Hutang**: Fitur penghapusan data hutang permanen lengkap dengan sinkronisasi ke tabel cicilan dan dialog konfirmasi keamanan.
- **Mandatori Bukti Pembayaran**: Mewajibkan unggahan file bukti transfer untuk setiap transaksi hutang dengan implementasi `MultipartRequest` dan validasi *real-time*.
- **Modul Tambah Rent Plan**: Implementasi halaman baru untuk registrasi sewa laptop dengan validasi wilayah (Provinsi/Kota/Kecamatan/Desa) dan pilihan jaminan yang dinamis.
- **Dasbor Customer**: Peningkatan visual pada halaman dashboard untuk tipe user **Customer**, mencakup ringkasan sewa aktif dan status pembayaran.
- **Modul Finance (WIP)**: Kerangka dasar modul keuangan perusahaan (under development) untuk pemantauan arus kas dan piutang.

### Changed

- **Logika Pembayaran Sebagian**: Sisa pembayaran kini tetap berada pada baris cicilan bulan berjalan (tidak membuat baris baru), sehingga riwayat pembayaran lebih bersih dan akurat.
- **Sinkronisasi Saldo Otomatis**: Perbaikan algoritma backend agar total "Dibayar" pada ringkasan sewa menjumlahkan seluruh `paid_amount` secara *real-time*.
- **Penataan Ulang UI (Tab EDIT)**: Reorder section untuk alur kerja yang lebih intuitif: Data Penyewa → Alamat KTP → Domisili → Dokumen Jaminan → Detail Sewa (bawah).
- **Standarisasi UI Popup**: Seluruh dialog input (Add Rent Plan, Add Debt, Pay Installment, Todo) kini menggunakan format **Premium Bottom Sheet** yang konsisten, responsif, dan elegan.
- **Visual Feedback Dinamis**: Warna pill tab "HUTANG" kini otomatis berubah merah hanya jika terdapat hutang aktif. Aksen merah pada menu "Belum Ada Hutang" diperkental menggunakan `RedAccent`.
- **Performance Optimization**: Optimasi query database pada dashboard dan detail rental untuk meminimalkan waktu loading data yang kompleks.

### Fixed

- **Payment Validation**: Validasi input nominal agar tidak dapat melebihi sisa kewajiban cicilan bulan berjalan.
- **Null-Safety Fix**: Perbaikan error `withOpacity()` pada warna dinamis saat berpindah tema (Dark/Light mode).
- **History UI Cleanup**: Perbaikan tampilan list riwayat cicilan agar lebih responsif dan informatif.

## [0.12.2] - 2026-03-28

### Added

- **Hapus Akun**: Fitur hapus akun untuk pengguna tipe **Customer**. Muncul di bagian bawah halaman Settings dengan alur keamanan: scroll teks peringatan hingga bawah → centang checkbox → konfirmasi → akun dihapus permanen dan otomatis logout.

### Changed

- **Login API**: Respons login kini menyertakan field `user_role_id` untuk identifikasi tipe pengguna yang lebih konsisten.

---

## [0.12.1] - 2026-03-27

### Added

- **Worklog Edit**: Fitur edit laporan kerja langsung dari aplikasi mobile.
- **In-App Document View**: Lihat KTP, NPWP, dan PO penyewa langsung di detail rental tanpa keluar aplikasi.
- **Todo List Edit**: Fitur edit deskripsi tugas pada daftar Todo.
- **Success Feedback**: Notifikasi konfirmasi (Snackbar) saat berhasil menambah atau mengubah data di Todo List.

### Changed

- **Todo List UI**: Dialog tambah tugas diperbarui menjadi **Bottom Sheet** yang lebih simpel, cepat, dan modern.
- **UI Consistency**: Notifikasi Snackbar diselaraskan agar muncul dari bawah dan mendorong tombol aksi terapung (FAB) ke atas.
- **Gradle Update**: Konfigurasi proyek dipaksa menggunakan **Java 17** untuk menghilangkan peringatan *obsolete* Java 8 saat build.

### Fixed

- **Todo Store Bug**: Perbaikan masalah gagal simpan saat edit Todo (penanganan kolom `updated_at`).
- **Rental Menu Cleanup**: Pembersihan menu detail rental (menonaktifkan fitur dalam pengembangan dan menghapus menu tidak terpakai).

## [0.11.0] - 2026-03-14

### Added

- **Auto Update Notification**: Notifikasi otomatis saat ada versi aplikasi baru.
- **Modul Todo List**: Implementasi modul baru Todo List untuk manajemen tugas harian.
- **Deep Linking Notifikasi**: Klik notifikasi pengumuman/todo langsung membuka halaman detail.

### Fixed

- **Database Optimization**: Perbaikan query lambat pada dashboard dan daftar karyawan.
- **Connection Stability**: Optimasi pengecekan login di API.
- **Payroll Payment Integration**: Implementasi fitur pembayaran gaji via Flip API.
- **Payroll UI Overflow**: Perbaikan tampilan dialog payroll yang berantakan di layar kecil.
- **Localization**: Penambahan terjemahan Indonesia untuk halaman karyawan.
