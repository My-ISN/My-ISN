# Changelog

### [1.1.0] - 2026-07-12

### Penambahan v1.1.0

- **Sistem Telemetri & Analitik (`TrackingService`)**: Layanan penjejakan sesi, fitur (`logCurrentFeature`), performa, crash log, serta status sistem (baterai, RAM) dengan antrean offline dan sinkronisasi batch berkala ke server. Seluruh halaman utama telah diinstrumentasi (Attendance, Dashboard, Work Log, dll.).
- **Modul Projects & Tasks**: Implementasi penuh manajemen proyek dan tugas, mencakup halaman list, detail, form tambah/edit, serta integrasi dengan `ProjectTaskService` dan RBAC.
- **Modul Passwords**: Manajer kata sandi internal (`PasswordListPage`) dengan detail sandi dan dialog berbagi aman (`PasswordShareSheet`).
- **Modul Reports**: Laporan terpadu (`ReportsPage`) dengan integrasi grafik visual (`fl_chart`) dan filter periode dinamis.
- **Modul AI Chat ISN**: Chatbot AI internal khusus untuk platform ISN (`AiChatIsnPage`) yang mendukung riwayat chat dan prompt cepat.
- **In-App Update — Progress Bar OTA**: Proses pembaruan APK dalam aplikasi kini menampilkan progress bar unduhan real-time (LinearProgressIndicator) langsung di bottom sheet.
- **Heartbeat Service & Maintenance Mode**: Pemantauan keaktifan pengguna secara real-time yang mendeteksi maintenance mode (HTTP 503) dan mengarahkan otomatis ke `MaintenancePage`.
- **Connectivity Wrapper**: Banner no-internet bergaya glassmorphism dengan transisi animasi ketika status koneksi berubah offline.
- **TopNotification Widget**: Banner overlay custom di bagian atas layar untuk menampilkan pesan mendesak dengan transisi slide dan auto-dismiss.
- **Quick Menu Customization**: Fitur baru untuk mempersonalisasi menu cepat di Dashboard (pin hingga 5 menu) dan menyimpannya di secure storage.
- **LogService & SearchableDropdown**: Utility logging menggunakan PrettyPrinter dan widget pencarian dropdown yang reusable.
- **Modul QuickSend & Job Desk**: Implementasi modul komunikasi cepat (QuickSend) dan manajemen daftar pekerjaan (Job Desk) terintegrasi sistem perizinan.
- **Modul Personal Finance**: Implementasi manajemen keuangan pribadi (pemasukan, pengeluaran, saldo) dengan standardisasi desain premium dan lokalisasi multi-bahasa.
- **Modul Creative Idea & Helpdesk**: Fitur penampung ide kreatif karyawan dan menu pengaduan tiket bantuan teknis terintegrasi native.
- **Asisten AI Cerdas**: Chatbot interaktif menggunakan Google Gemini 1.5 Flash untuk informasi penyewaan laptop dan stok unit.
- **Worklog Integration & Todo Collaboration**: Pembuatan worklog yang dapat ditarik langsung dari todo selesai, serta sistem todo bertipe personal/tim dengan delegasi tugas.
- **UI — Sidebar Categorization & Radius**: Pengelompokan menu sidebar (Work, Financial, Support), standarisasi sudut membulat 24px, dan header search menu di App Bar.
- **UI — SecondaryAppBar Everywhere**: Integrasi navigasi atas sekunder pada seluruh halaman detail dan form input.
- **UI — Global Standardization**: Migrasi total ke gaya desain "Flat Premium" tanpa bayangan (elevation: 0) dengan garis pembatas halus.

### Perubahan v1.1.0

- **Sidebar Menu**: Modul Payroll, Announcements, Projects, Tasks, Reports, dan Passwords kini dapat diakses langsung dari Side Drawer.
- **CustomAppBar & Todo Count**: NotificationManager kini menampilkan jumlah todo belum selesai di samping lonceng notifikasi.
- **Optimisasi & Refaktorisasi Todo**: Pemecahan file monolitik `todo_list_page.dart` menjadi widget modular terpisah guna performa yang lebih gegas.
- **Diagnosis Hub Refactor**: Desain ulang antarmuka diagnostic (Internet, Versi, Storage, Notifikasi) mengikuti visual Flat Premium.
- **AI Assistant Transformation**: Pengalihan chatbot AI umum menjadi Knowledge Base yang terfokus pada data internal perusahaan.
- **Finance Formatting**: Input nominal uang otomatis terformat dengan pemisah ribuan ketika diketik, dengan default akun payer dan metode bank transfer.
- **Migration**: Migrasi seluruh parameter warna legacy `withAlpha` & `withOpacity` ke API modern Flutter 3.22+ `withValues()`.

### Perbaikan v1.1.0

- **Tracking & Async Safety**: Penanganan error telemetri dengan try-catch agar kegagalan sync tidak merusak alur aplikasi, serta audit mounted context pada operasi async.
- **Auth & Session Fixes**: Perbaikan finger print login pasca-migrasi domain (PHP 7.4 compatibility) dan penanganan sesi Google Sign-In yang tidak tersimpan di secure storage.
- **UI Overflow Fixes**: Perbaikan RenderFlex overflow pada navigasi bawah, rent plan label wrapping, layout bar filter, dan setup alur LoginPage.
- **Navigation & Lifecycle**: Perbaikan navigasi error `setState() called when widget tree was locked` pada bottom nav bar dan tautan menu Payroll di sidebar yang sebelumnya tidak merespon saat diklik.

---

## [1.0.0] - 2026-04-01

### Penambahan v1.0.0

- **Speech-to-Text (Todo List)**: Terobosan baru fitur perekaman suara (*voice typing*) pada form "Tambah" dan "Edit" To-Do List menggunakan ikon mikrofon yang responsif dan terintegrasi native.
- **Modul Perpanjangan Sewa (Rent Extend)**: Implementasi fitur perpanjangan masa sewa laptop dengan kalkulasi harga dinamis berdasarkan tier harga (`mas_harga`) langsung dari detail rental.
- **Universal Search (Employees)**: Fitur pencarian karyawan di seluruh modul dengan filter departemen dan status aktif secara real-time.
- **Dark Mode Support**: Implementasi awal sistem tema gelap pada modul Dashboard dan Settings.
- **Unit Testing Suite**: Penambahan suite pengujian otomatis untuk validasi logika keuangan dan sinkronisasi data.

### Perbaikan v1.0.0

- **Error Handling**: Perbaikan crash "Unable to load asset" dengan mengganti placeholder yang hilang menjadi foto formal resmi (`default_formal.webp`) atau inisial dinamis.
- **Localization Sync**: Perbaikan label lokalisasi yang sebelumnya menampilkan teks JSON mentah (Map string) menjadi label yang tepat di kedua bahasa.

### Perubahan v1.0.0

- **Sinkronisasi Bahasa**: Penambahan key yang hilang (`order_number`, `validation.required`, dll) ke `en.json`. Kedua file bahasa kini sinkron 100% pada 829 baris.
- **Penyempurnaan UI Detail**: Menghapus section "Rental Progress" (visual progress bar) untuk tampilan yang lebih bersih dan fokus pada administrasi serta invoice.
- **Optimasi Image Loading**: Penggunaan `CachedNetworkImage` pada seluruh daftar karyawan dan laptop untuk menghemat kuota data dan memperlancar scrolling.
- **Visual Feedback Dinamis**: Warna pill tab "HUTANG" kini otomatis berubah merah hanya jika terdapat hutang aktif. Aksen merah pada menu "Belum Ada Hutang" diperkental menggunakan `RedAccent`.
- **Performance Optimization**: Optimasi query database pada dashboard dan detail rental untuk meminimalkan waktu loading data yang kompleks.

### Perbaikan Lanjutan v1.0.0

- **Modul Konfigurasi Role**: Pemisahan mutlak *key identifier* antara akses "Main Finance" Web dan "Mobile Apps Finance" pada sistem ERP HRIS untuk menuntaskan *bug* di mana menu aplikasi tidak bisa dimatikan (*status persistency fix*).
- **Kalkulasi Harga Unit**: Perbaikan logika penentuan harga sewa laptop pada modul "Tambah Rent Plan" agar otomatis menarik harga dari tier yang aktif (`mas_harga`).
- **Notification Routing**: Perbaikan deep-link notifikasi yang sebelumnya selalu mengarah ke beranda, kini tepat ke modul yang bersangkutan (Ticket/Todo).

## [0.12.2] - 2026-03-28

### Penambahan v0.12.2

- **Hapus Akun**: Fitur hapus akun untuk pengguna tipe **Customer**. Muncul di bagian bawah halaman Settings dengan alur keamanan: scroll teks peringatan hingga bawah → centang checkbox → konfirmasi → akun dihapus permanen dan otomatis logout.

### Perubahan v0.12.2

- **Login API**: Respons login kini menyertakan field `user_role_id` untuk identifikasi tipe pengguna yang lebih konsisten.

## [0.12.1] - 2026-03-27

### Penambahan v0.12.1

- **Worklog Edit**: Fitur edit laporan kerja langsung dari aplikasi mobile.
- **In-App Document View**: Lihat KTP, NPWP, dan PO penyewa langsung di detail rental tanpa keluar aplikasi.
- **Success Feedback**: Notifikasi konfirmasi (Snackbar) saat berhasil menambah atau mengubah data di Todo List.

### Perubahan v0.12.1

- **Todo List UI**: Dialog tambah tugas diperbarui menjadi **Bottom Sheet** yang lebih simpel, cepat, dan modern.
- **UI Consistency**: Notifikasi Snackbar diselaraskan agar muncul dari bawah dan mendorong tombol aksi terapung (FAB) ke atas.

### Perbaikan v0.12.1

- **Todo Store Bug**: Perbaikan masalah gagal simpan saat edit Todo (penanganan kolom `updated_at`).
- **Rental Menu Cleanup**: Pembersihan menu detail rental (menonaktifkan fitur dalam pengembangan dan menghapus menu tidak terpakai).

## [0.11.0] - 2026-03-14

### Penambahan v0.11.0

- **Auto Update Notification**: Notifikasi otomatis saat ada versi aplikasi baru.
- **Modul Todo List**: Implementasi modul baru Todo List untuk manajemen tugas harian.

### Perbaikan v0.11.0

- **Database Optimization**: Perbaikan query lambat pada dashboard dan daftar karyawan.
- **Connection Stability**: Optimasi pengecekan login di API.
