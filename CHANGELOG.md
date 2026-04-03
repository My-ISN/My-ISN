# Changelog

## [1.1.0] - 2026-04-03

### Added

- **Helpdesk — Modul Tiket Pengaduan**: Implementasi menu Helpdesk (`Icons.support_agent_outlined`) untuk pelaporan kendala teknis dan administrasi langsung dari aplikasi mobile.
- **Asisten AI Cerdas (FoxBot)**: Implementasi asisten AI interaktif menggunakan **Google Gemini 1.5 Flash** untuk membantu menjawab pertanyaan seputar penyewaan laptop, stok, dan prosedur sewa secara real-time.
- **Quick Action Pills**: Penambahan tombol aksi cepat di bagian atas keyboard Bot AI untuk pertanyaan umum (harga sewa, daftar laptop, cara sewa, dll) agar pengguna lebih mudah berinteraksi.
- **Quick Menu — AI Bot & Creative Idea**: Penambahan akses cepat untuk menu **AI Bot** dan **Creative Idea** pada sidebar (status: *On Progress*).
- **Worklog — Seleksi dari Todo List**: Fitur pembuatan laporan kerja (*Worklog*) kini mendukung pengambilan data langsung dari tugas yang sudah selesai pada hari tersebut melalui tombol **"Pilih dari Todo List"** (sebelumnya: "Pilih dari Jobdesk").

### Changed

- **UI — Modernisasi Masif (Visi 2026)**: Desain ulang lebih dari 50% antarmuka aplikasi dengan standar premium untuk pengalaman pengguna yang lebih intuitif dan elit.
- **UI — Full Theme Integration (Login & Register)**: Integrasi penuh sistem tema (*Light/Dark Mode*) pada halaman modul otentikasi. Menghapus seluruh warna *hardcoded* guna memastikan kenyamanan visual yang konsisten.
- **UI — Helpdesk Interaction Redesign**: Area input balasan tiket kini menggunakan desain premium yang identik dengan antarmuka Chat Bot AI, lengkap dengan *floating action buttons* dan *rounded containers*.
- **UI — Standardisasi Form & Detail**: Implementasi `SecondaryAppBar` dan tata letak berbasis *sectioned cards* pada seluruh halaman Tambah/Edit (Finance, Worklog) dan Detail (Ticket, Employee, Rent Plan).
- **UI — Branding Refinement**: Logo aplikasi pada halaman login diperbarui dengan container sirkular premium dan efek bayangan (*shadow*) yang adaptif terhadap tema.
- **Finance — Format Amount Otomatis**: Field nominal pada form Add/Edit Income & Expense kini otomatis memformat angka dengan titik pemisah ribuan saat pengguna mengetik (contoh: `1000` → `1.000`).
- **Finance — Default Values**: Akun 'Payer' kini otomatis terisi user yang sedang login dan 'Payment Method' default menjadi **Bank Transfer**.
- **Todo List — Voice-to-Text Bahasa Indonesia**: Fitur pengenalan suara dikunci untuk mendeteksi **Bahasa Indonesia (`id_ID`)** demi akurasi maksimal.
- **UI — Modern Pill Bottom Navigation**: Desain ulang total bar navigasi bawah menggunakan gaya **Modern Pill** dengan animasi *sliding width transition* yang mulus.
- **UI — Popup Update & Changelog Premium**: Redesign total jendela notifikasi menjadi **Premium Bottom Sheet** yang seragam dengan desain sistem lainnya.
- **UI — Rent Plan List Layout**: Perbaikan simetri pada badge status dan tombol aksi di daftar persewaan agar lebih rapi.
- **UI — Rent Plan Long Text Handling**: Penanganan label Bahasa Indonesia yang panjang pada halaman Detail Rent Plan menggunakan teknik **ellipsis** pada label dan **flexible wrapping** pada nilai data untuk mencegah *RenderFlex* overflow.

### Fixed Bug

- **UI — CustomBottomNav Stability**: Perbaikan fatal error `setState() called when widget tree was locked` saat transisi navigasi antar halaman utama.
- **UI — LoginPage Syntax Fix**: Perbaikan kesalahan struktur *widget tree* (kurung tutup) pada modul branding yang menyebabkan kegagalan build.
- **UI — Layout Overflow Fix**: Perbaikan error `RenderFlex overflow` pada bar navigasi menggunakan `LayoutBuilder` untuk kalkulasi lebar yang presisi.
- **Payroll Navigation**: Perbaikan tautan menu Payroll di sidebar yang sebelumnya tidak merespon saat diklik.g sebelumnya tidak merespon saat diklik.

---

## [1.0.0] - 2026-04-01

### Added

- **Speech-to-Text (Todo List)**: Terobosan baru fitur perekaman suara (*voice typing*) pada form "Tambah" dan "Edit" To-Do List menggunakan ikon mikrofon yang responsif dan terintegrasi native.
- **Modul Perpanjangan Sewa (Rent Extend)**: Implementasi fitur perpanjangan masa sewa laptop dengan kalkulasi harga dinamis berdasarkan tier harga (`mas_harga`) langsung dari detail rental.
- **Lokalisasi Penuh Modul Rent Plan**: Migrasi seluruh teks hardcoded ke sistem multi-bahasa (`id.json` & `en.json`) mencakup halaman daftar, detail, dan tambah pesanan secara komprehensif.
- **Live Search Rent Plan**: Fitur pencarian otomatis real-time dengan debounce 500ms untuk akses data penyewaan yang lebih cepat.
- **Internal Document Viewer**: Mengembalikan "LIHAT DOKUMEN" sebagai tab internal dengan fitur *pinch zoom* (`InteractiveViewer`) untuk pengalaman peninjauan berkas yang seamless.
- **Modul Hutang**: Desain ulang total dialog "Tambah Hutang" dan "Bayar Cicilan" menggunakan **Premium Bottom Sheet** yang sepenuhnya *theme-aware*.
- **Hapus Hutang**: Fitur penghapusan data hutang permanen lengkap dengan sinkronisasi ke tabel cicilan dan dialog konfirmasi keamanan.
- **Mandatori Bukti Pembayaran**: Mewajibkan unggahan file bukti transfer untuk setiap transaksi hutang dengan implementasi `MultipartRequest` dan validasi *real-time*.
- **Integrasi Google Drive (Rent Plan)**: Seluruh berkas dokumen penyewa (KTP, NPWP, PO) dan foto jaminan kini otomatis dienkripsi dan disimpan secara aman di **Google Drive Cloud Storage** untuk efisiensi penyimpanan server lokal.
- **Peningkatan Doc Viewer**: Desain ulang antarmuka *internal document viewer* pada detail rental dengan navigasi tab yang lebih intuitif, mendukung *full-screen visual review* dengan pinch-to-zoom.
- **Dashboard Quick Apps**: Pembaruan desain menu akses cepat (Quick Apps) dengan layout grid yang lebih modern, responsif, dan visual ikon yang lebih tajam.
- **Icon Visibility Upgrade**: Pembedaan ikon visual antara menu **Finance** (Ikon Dompet) dan **Payroll** (Ikon Slip Gaji) guna meningkatkan efisiensi navigasi pengguna.
- **Modul Finance Premium**: Implementasi penuh manajemen keuangan perusahaan dengan standar desain premium.
- **Summary & Sectioned UI**: Penggunaan kartu gradasi (`Color(0xFF7E57C2)`) dan *Sectioned Cards* untuk pengelompokan data input.
- **Unified Add Data**: Halaman tambah data dinamis untuk **Akun**, **Pemasukan**, dan **Pengeluaran** dalam satu alur.
- **Manajemen Akun**: Fitur hapus akun permanen dengan dialog konfirmasi aman dan sinkronisasi saldo real-time.
- **Premium Bottom Panel**: Implementasi panel aksi bawah melengkung (*curved top corners*) dengan radius 30 untuk estetika yang lebih modern.
- **Employees Module Fixes**:
- **UI Consistency**: Memindahkan tombol **Simpan** dari AppBar ke *bottomNavigationBar* lebar agar seragam dengan modul Keuangan.
- **UI/UX Refinement**: Dukungan penuh Dark/Light theme untuk form Tambah Karyawan dan panel bawah melengkung (radius 30).
- **Error Handling**: Perbaikan crash "Unable to load asset" dengan mengganti placeholder yang hilang menjadi foto formal resmi (`default_formal.webp`) atau inisial dinamis.
- **Localization Sync**: Perbaikan label lokalisasi yang sebelumnya menampilkan teks JSON mentah (Map string) menjadi label yang tepat di kedua bahasa.

### Changed

- **Sinkronisasi Bahasa**: Penambahan key yang hilang (`order_number`, `validation.required`, dll) ke `en.json`. Kedua file bahasa kini sinkron 100% pada 829 baris.
- **Penyempurnaan UI Detail**: Menghapus section "Rental Progress" (visual progress bar) untuk tampilan yang lebih bersih dan fokus pada administrasi serta invoice.
- **Logika Pembayaran Sebagian**: Sisa pembayaran kini tetap berada pada baris cicilan bulan berjalan (tidak membuat baris baru), sehingga riwayat pembayaran lebih bersih dan akurat.
- **Sinkronisasi Saldo Otomatis**: Perbaikan algoritma backend agar total "Dibayar" pada ringkasan sewa menjumlahkan seluruh `paid_amount` secara *real-time*.
- **Penataan Ulang UI (Tab EDIT)**: Reorder section untuk alur kerja yang lebih intuitif: Data Penyewa → Alamat KTP → Domisili → Dokumen Jaminan → Detail Sewa (bawah).
- **Standarisasi UI Popup**: Seluruh dialog input (Add Rent Plan, Add Debt, Pay Installment, Todo) kini menggunakan format **Premium Bottom Sheet** yang konsisten, responsif, dan elegan.
- **Visual Feedback Dinamis**: Warna pill tab "HUTANG" kini otomatis berubah merah hanya jika terdapat hutang aktif. Aksen merah pada menu "Belum Ada Hutang" diperkental menggunakan `RedAccent`.
- **Performance Optimization**: Optimasi query database pada dashboard dan detail rental untuk meminimalkan waktu loading data yang kompleks.

### Fixed Bug

- **Modul Konfigurasi Role**: Pemisahan mutlak *key identifier* antara akses "Main Finance" Web dan "Mobile Apps Finance" pada sistem ERP HRIS untuk menuntaskan *bug* di mana menu aplikasi tidak bisa dimatikan (*status persistency fix*).
- **Kalkulasi Harga Unit**: Perbaikan logika penentuan harga sewa laptop pada modul "Tambah Rent Plan" agar otomatis menarik harga dari tier yang aktif (`mas_harga`).
- **Localization Bug**: Perbaikan kesalahan sintaksis dan pelabelan tipe penyewa (perusahaan/pribadi) yang sebelumnya belum ter-lokalisasi secara dinamis.
- **Payment Validation**: Validasi input nominal agar tidak dapat melebihi sisa kewajiban cicilan bulan berjalan.
- **Pagination UI Fix**: Perbaikan visual pada tombol navigasi halaman (ikon `<` dan `>`) agar sepenuhnya mendukung *Dark/Light mode* dengan *background* yang adaptif.
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

### Fixed Bug

- **Todo Store Bug**: Perbaikan masalah gagal simpan saat edit Todo (penanganan kolom `updated_at`).
- **Rental Menu Cleanup**: Pembersihan menu detail rental (menonaktifkan fitur dalam pengembangan dan menghapus menu tidak terpakai).

## [0.11.0] - 2026-03-14

### Added

- **Auto Update Notification**: Notifikasi otomatis saat ada versi aplikasi baru.
- **Modul Todo List**: Implementasi modul baru Todo List untuk manajemen tugas harian.
- **Deep Linking Notifikasi**: Klik notifikasi pengumuman/todo langsung membuka halaman detail.

### Fixed Bug

- **Database Optimization**: Perbaikan query lambat pada dashboard dan daftar karyawan.
- **Connection Stability**: Optimasi pengecekan login di API.
- **Payroll Payment Integration**: Implementasi fitur pembayaran gaji via Flip API.
- **Payroll UI Overflow**: Perbaikan tampilan dialog payroll yang berantakan di layar kecil.
- **Localization**: Penambahan terjemahan Indonesia untuk halaman karyawan.
