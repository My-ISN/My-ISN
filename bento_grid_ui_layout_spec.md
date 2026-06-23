# Peta Arsitektur UI & Rencana Redesain Bento Grid (My-ISN Mobile App)

## 📌 Pendahuluan
Dokumen ini disusun untuk memetakan arsitektur UI saat ini pada aplikasi **My-ISN Mobile** sebagai panduan sebelum melakukan *sketching* atau desain di Figma. Target desain baru adalah menggunakan **Bento Grid UI**, yang menyusun elemen-elemen dashboard/halaman ke dalam grid kotak-kotak berukuran variatif (1x1, 2x1, 2x2, dll.) dengan sudut membulat (*rounded corners*), warna harmonis, mikro-animasi, dan visual premium.

---

## 📱 1. Lingkungan Global Aplikasi (Global Environments)

### A. Bottom Navigation Bar (Bilah Navigasi Bawah)
Mempunyai tampilan mengambang (*floating look*) dengan tinggi `80px` dan sudut membulat lebar (`borderRadius: 40`), dengan isi menu dinamis bergantung pada tipe akun pengguna:

*   **Tipe Akun: Staff / Karyawan**
    1.  **Beranda (Dashboard):**
        *   **Ikon:** `Icons.home_rounded`
        *   **Tujuan/Direct:** `StaffDashboardContent` (Konten dashboard utama staff).
    2.  **Absensi:**
        *   **Ikon:** `Icons.calendar_month_rounded`
        *   **Tujuan/Direct:** `AttendancePage` (Kalender absensi bulanan).
    3.  **Payroll:** *(Tampil jika izin `mobile_payroll_enable` aktif)*
        *   **Ikon:** `Icons.receipt_long_rounded`
        *   **Tujuan/Direct:** `PayrollPage` (Bilah laporan gaji & pembayaran).
    4.  **Profil:**
        *   **Ikon:** `Icons.person_rounded`
        *   **Tujuan/Direct:** `ProfilePage` (Profil data pribadi staff).

*   **Tipe Akun: Customer / Klien (Customer Mode)**
    1.  **Beranda (Dashboard):**
        *   **Ikon:** `Icons.home_rounded`
        *   **Tujuan/Direct:** `CustomerDashboardContent` (Katalog produk & sewa).
    2.  **Transaksi:**
        *   **Ikon:** `Icons.receipt_long_rounded`
        *   **Tujuan/Direct:** `TransactionPage` (Halaman pelacakan transaksi customer).
    3.  **Rent Plan (Penyewaan):**
        *   **Ikon:** `Icons.house_rounded`
        *   **Tujuan/Direct:** `RentPlanPage` (Rincian penyewaan aktif/rencana sewa).
    4.  **Profil:**
        *   **Ikon:** `Icons.person_rounded`
        *   **Tujuan/Direct:** `ProfilePage` (Profil data pribadi customer).

### B. Top Navigation Bar (Bilah AppBar Atas)
*   **Staff Mode (`CustomAppBar`):**
    *   **Elemen Kiri:** Foto profil lingkaran kecil dengan *border* halus (Direct: Profil) + Nama User & Sub-judul Departemen/Jabatan.
    *   **Elemen Kanan:**
        *   Tombol Bel Notifikasi (`Icons.notifications_none_rounded`) -> Direct: Halaman Notifikasi/Pengumuman (`AnnouncementPage`).
        *   Tombol Gear Pengaturan (`Icons.settings_rounded`) -> Direct: `SettingsPage`.
*   **Customer Mode (AppBar terintegrasi dalam Kolom Pencarian):**
    *   Bilah AppBar ini menyusut dan melekat (*sticky*) di bagian atas ketika digulir (*scrolling*).
    *   **Elemen Kiri:** Search Bar input ("Cari laptop impianmu...") -> Direct: Overlay Pencarian.
    *   **Elemen Kanan:**
        *   Tombol Keranjang (`Icons.shopping_cart_outlined`) -> Direct: Halaman Keranjang Belanja (`CartPage`), dilengkapi badge jumlah item merah.
        *   Foto profil bulat (Direct: Opens Drawer/Side Menu).

### C. Side Drawer (Menu Samping)
Akses navigasi cepat tambahan, terutama untuk customer:
*   **Header Drawer:** Foto profil user bulat besar, Nama Lengkap, Email, dan badge tipe akun (Staff / Customer).
*   **Menu List:**
    *   Beranda / Dashboard.
    *   Absensi (Staff saja).
    *   Payroll (Staff saja).
    *   Profil.
    *   Seluruh shortcut modul/fitur aktif sesuai izin pengguna.
    *   Tombol Keluar (Logout) merah di bagian paling bawah.

---

## 🔒 2. Flow Autentikasi (Authentication Pages)

### A. Halaman Login (`LoginPage`)
*   **Logo & Branding:**
    *   Logo: `assets/images/icon.webp` (Icon ISKOM). Ditampilkan dalam container bulat berbayang lembut (*soft shadow*).
    *   Judul Aplikasi: "My ISN Mobile" (`main.app_name`) menggunakan font Poppins tebal.
    *   Sub-judul: "Selamat Datang Kembali".
*   **Form Input:**
    *   Field Username/Email (`Icons.person_outline_rounded`).
    *   Field Password (`Icons.lock_outline_rounded`) + Tombol toggle mata untuk melihat password.
*   **Aksi & Navigasi Tambahan:**
    *   Checkbox "Ingat Saya" (Remember Me).
    *   Tombol teks "Lupa Kata Sandi?" -> Direct: Proses reset sandi.
    *   Tombol Utama "Masuk" -> Memproses validasi API -> Direct: `DashboardPage`.
    *   Teks Tautan "Belum punya akun? Daftar" -> Direct: `RegisterPage`.
*   **Metode Login Alternatif:**
    *   Tombol Sidik Jari (`Icons.fingerprint_rounded`) -> Terlihat jika biometrik aktif -> Direct: Autentikasi Biometrik lokal.
    *   Tombol Google Sign-In dengan Logo Google (`assets/images/google.svg`) -> Direct: Autentikasi via Akun Google.

### B. Halaman Register (`RegisterPage`)
*   Form input pendaftaran baru (Nama Lengkap, Username, Email, No. Telepon, Password, Konfirmasi Password).
*   Tombol Daftar dan Tautan kembali ke Halaman Login.

---

## 📊 3. Halaman Utama: Staff Dashboard (Bento Grid Candidates)

Pada redesain Bento Grid, elemen-elemen ini akan dibagi menjadi kartu-kartu grid berukuran proporsional:

### 🟩 Grid A: Header Profil (Ukuran Figma: 2x1)
*   **Konten:** Salam sapaan hangat ("Selamat Datang, [Nama]!"), Tanggal hari ini, Status Kehadiran Ringkas (Hari ini sudah masuk/belum).
*   **Elemen Visual:** Foto Profil bulat kecil, ikon status online hijau.
*   **Arah/Direct:** Mengarah ke halaman Profil jika diketuk.

### 🟩 Grid B: Shift & Jadwal Kerja (Ukuran Figma: 2x1)
*   **Konten:** Nama shift aktif ("Shift saya: [Shift Name]"), log jam kerja hari ini:
    *   Clock In (Jam Masuk): e.g. `08:00` atau `--:--`
    *   Clock Out (Jam Keluar): e.g. `17:00` atau `--:--`
    *   Break Out (Mulai Istirahat): e.g. `12:00` atau `--:--`
    *   Break In (Selesai Istirahat): e.g. `13:00` atau `--:--`
*   **Arah/Direct:** Mengarah ke Halaman Absensi (`AttendancePage`).

### 🟩 Grid C: Statistik Ringkas Kehadiran (Ukuran Figma: Grid 2x2 terbagi menjadi 4 sub-card 1x1)
Statistik ini menampilkan performa akumulasi bulan berjalan:
1.  **Durasi Kerja (Working Duration):**
    *   **Nilai:** e.g. `160h 20m`
    *   **Ikon:** `Icons.hourglass_empty` (Warna Hijau)
2.  **Cuti Saya (My Leave):**
    *   **Nilai:** Jumlah hari cuti terpakai, e.g. `2`
    *   **Ikon:** `Icons.calendar_today` (Warna Ungu)
3.  **Pengajuan Lembur (Overtime Request):**
    *   **Nilai:** Jumlah jam/pengajuan, e.g. `5`
    *   **Ikon:** `Icons.more_time` (Warna Ungu)
4.  **Dinas Luar (Travel Request):**
    *   **Nilai:** Jumlah perjalanan dinas luar, e.g. `1`
    *   **Ikon:** `Icons.flight_takeoff` (Warna Hijau)
*   **Arah/Direct:** Masing-masing mengarah ke modul detailnya (Cuti, Lembur, Dinas Luar).

### 🟩 Grid D: Menu Cepat / Modul Utama (Ukuran Figma: 2x2 atau Grid Fleksibel)
Berisi shortcut ke seluruh fitur internal ERP. Pengguna dapat memilih pin hingga maksimal 5 item.
*   **Arah/Direct:** Menampilkan pintasan dan tombol "Lihat Semua Menu" -> Direct ke `AllMenusPage`.

---

## 🛒 4. Halaman Utama: Customer Dashboard (Bento Grid Candidates)

Dashboard untuk customer dirancang lebih mengarah ke katalog dan informasi layanan sewa laptop:

### 🟩 Grid A: Carousel Promo (Ukuran Figma: 2x1)
*   **Konten:** Banner geser otomatis berisi penawaran menarik:
    *   Slide 1: "Laptop Generasi Baru Siap Disewa!" (Tag: NEW ARRIVAL)
    *   Slide 2: "Diskon Akhir Pekan Hingga 30%!" (Tag: BEST DEAL)
    *   Slide 3: "Stok Terbatas Amankan Unitmu!" (Tag: LIMITED)
*   **Gambar Latar:** Foto laptop premium estetik (dari Unsplash/generatif).
*   **Arah/Direct:** Detail Promo / Halaman Produk terkait.

### 🟩 Grid B: Bilah Pencarian & Aksi Cepat (Ukuran Figma: 2x0.5)
*   **Konten:** Form pencarian dengan teks panduan ("Cari laptop impianmu...") + tombol Cart & Profil.
*   **Arah/Direct:** Membuka overlay pencarian dinamis (Riwayat Pencarian & Rekomendasi).

### 🟩 Grid C: Ringkasan Status Finansial & Sewa (Ukuran Figma: 2x1 dibagi 2 kolom)
1.  **Sewa Aktif (Active Rentals):**
    *   **Konten:** Jumlah unit laptop yang sedang disewa saat ini, e.g. `3 Unit`
    *   **Ikon:** `Icons.laptop_mac_rounded` (Warna Hijau)
    *   **Direct:** Halaman Rent Plan.
2.  **Belum Dibayar (Total Unpaid):**
    *   **Konten:** Nominal tagihan sewa yang belum dilunasi, e.g. `Rp 1,500,000`
    *   **Ikon:** `Icons.account_balance_wallet_rounded` (Warna Merah)
    *   **Direct:** Halaman Detail Transaksi / Pembayaran.

### 🟩 Grid D: Tab Mode & Grid Katalog Laptop (Ukuran Figma: Grid Kolom Dinamis)
*   **Mode Selector:** Tombol tab geser untuk memilih antara mode **Penyewaan** (Rental) dan **Pembelian** (Purchase).
*   **Katalog Laptop:** Menampilkan kartu produk dengan:
    *   Gambar Laptop asli (dari direktori uploads server).
    *   Label Mode ("SEWA" atau "BARU").
    *   Nama Unit Laptop (e.g. "ThinkPad X1 Carbon Gen 9").
    *   Harga Sewa per Bulan / Harga Beli.
    *   Rating & Total Terjual (e.g. "⭐ 4.8 | Terjual 15").
    *   Lokasi Unit (e.g. "Bandung").
*   **Arah/Direct:** Mengarah ke halaman detail produk (`ProductDetailPage`).

### 🟩 Grid E: Card Bantuan Teknis (Ukuran Figma: 2x1)
*   **Konten:** Judul "Butuh Bantuan?" dan keterangan "Hubungi CS kami untuk bantuan teknis dan ketersediaan unit."
*   **Aksi:** Tombol WhatsApp "Chat di WhatsApp" -> Direct: Membuka aplikasi WhatsApp ke nomor CS `0895384314416` dengan teks *auto-fill*.
*   **Ikon Pendukung:** `Icons.support_agent_rounded` (Besar transparan).

---

## ⚙️ 5. Detail Struktur Halaman Fitur (Feature Pages Detail)

### A. Halaman Pengaturan (`SettingsPage`)
Di dalam Bento Grid, pengaturan ini dikelompokkan ke dalam kartu-kartu kategori:

| Nama Pengaturan / Item | Deskripsi Konten | Logo / Ikon | Target Aksi / Direct |
| :--- | :--- | :--- | :--- |
| **Ubah Bahasa** | Memilih bahasa operasional aplikasi (Bahasa Indonesia / English). | `Icons.language_rounded` (Ungu) | Membuka bottom sheet pilihan bahasa. |
| **Tema Aplikasi** | Memilih tema visual (Sistem / Light Mode / Dark Mode). | `Icons.brightness_4_rounded` (Ungu) | Membuka bottom sheet pilihan tema. |
| **Nada Notifikasi** | Memilih nada untuk pesan masuk (Default / Elegant / Magic / Relax). | `Icons.notifications_active_outlined` (Ungu) | Membuka bottom sheet pilihan suara notifikasi dengan tombol putar preview. |
| **Sidik Jari (Biometrik)** | Mengaktifkan/menonaktifkan sidik jari, pendaftaran ulang sidik jari, atau menghapus data biometrik. | `Icons.fingerprint` (Ungu / Hijau) | Toggle switch sidik jari & aksi hapus/daftar ulang biometrik. |
| **Informasi Akun** | Menampilkan foto profil bulat user, nama lengkap, dan email. | Circle Avatar Profil | Direct: Profil Pengguna (`ProfilePage`). |
| **Versi Aplikasi** | Menampilkan versi aplikasi saat ini (e.g. `1.0.4`). | `Icons.info_outline` (Ungu) | Info static saja (Non-klik). |
| **Kebijakan Privasi** | Membaca dokumen kebijakan privasi perusahaan. | `Icons.shield_outlined` (Ungu) | Membuka browser eksternal ke URL `/erp/privacy`. |
| **Bantuan & Dukungan** | Layanan keluhan tiket masalah. | `Icons.help_outline` (Ungu) | Direct: Halaman Helpdesk (`HelpdeskListPage`). |
| **Iskom Sarana Nusantara** | Teks hak cipta. | `Icons.business_outlined` (Ungu) | Teks static: "© 2026". |
| **Diagnosis Sistem** | Memeriksa status kesehatan aplikasi dan koneksi server. | `Icons.notifications_active_outlined` (Ungu) | Direct: Halaman Diagnosis (`DiagnosisHubPage`). |
| **Hapus Akun** | Menghapus permanen akun (Khusus tipe Customer). | `Icons.delete_forever_outlined` (Merah) | Membuka bottom sheet peringatan penghapusan & persetujuan syarat. |

---

### B. Halaman Profil (`ProfilePage`)
Berisi rincian data diri user yang dapat diedit:

| Nama Pengaturan / Item | Deskripsi Konten | Logo / Ikon | Target Aksi / Direct |
| :--- | :--- | :--- | :--- |
| **Header Profil** | Foto profil, Nama Lengkap, Username, Jabatan/Role, dan Tombol Edit Profil. | Circle Avatar Profil + `Icons.edit_rounded` | Direct: Mengedit info header profil (`ProfileEditPage`). |
| **Detail Info Utama** | Informasi ringkas mengenai Departemen kerja, Email, dan No. Kontak Telepon. | `Icons.business_rounded`, `Icons.email_rounded`, `Icons.phone_android_rounded` | Tampilan rincian info dasar. |
| **Kontrak Kerja** | Menampilkan rincian kontrak kerja karyawan (Khusus tipe Staff). | `Icons.assignment_rounded` | Direct: Halaman Rincian Kontrak (`ProfileContractPage`). |
| **Informasi Dasar** | Menampilkan data dasar profil (e.g. Jenis Kelamin, Tanggal Lahir). | `Icons.account_circle_rounded` | Direct: Halaman Info Dasar Karyawan (`ProfileBasicPage`). |
| **Informasi Pribadi** | Menampilkan alamat lengkap, data keluarga, status pernikahan. | `Icons.contact_page_rounded` | Direct: Halaman Rincian Data Pribadi (`ProfilePersonalPage`). |
| **Rekening Bank** | Menampilkan info rekening untuk payroll (e.g. Bank BCA, Mandiri). | `Icons.account_balance_rounded` | Direct: Halaman Data Rekening Karyawan (`ProfileBankPage`). |

---

### C. Halaman Absensi (`AttendancePage`)
Khusus untuk staff/karyawan untuk melacak histori kehadiran bulanan:

| Nama Item / Komponen | Deskripsi Konten | Logo / Ikon | Target Aksi / Direct |
| :--- | :--- | :--- | :--- |
| **Navigasi Bulan** | Judul bulan aktif (e.g. "Juni 2026") dan tombol navigasi panah kiri/kanan. | `Icons.chevron_left` / `Icons.chevron_right` | Bergeser ke data absensi bulan sebelumnya/berikutnya. |
| **Ringkasan Kehadiran** | Kartu ringkasan jumlah kehadiran bulanan: Hadir, Terlambat, Absen, Pulang Cepat, Total Istirahat. | Indikator titik warna (Hijau, Jingga, Merah, Biru, Ungu) | Expand/Collapse untuk melihat statistik lengkap. |
| **Grid Kalender** | Kotak tanggal tanggal dalam bulan berjalan. Setiap tanggal memiliki titik hijau (hadir tepat waktu) atau jingga (terlambat) di bawah angka tanggal. Hari libur/akhir pekan berwarna merah. | Titik warna hijau/jingga di bawah tanggal | Diketuk membuka Bottom Sheet detail kehadiran hari tersebut. |
| **Detail Kehadiran Harian** | Jam Clock In, jam Clock Out, status kehadiran, catatan keterlambatan atau pulang cepat, dan status hari libur. | `Icons.access_time_rounded` | Ditampilkan dalam modal bottom sheet saat tanggal kalender diketuk. |

---

### D. Halaman Payroll (`PayrollPage`)
Halaman pelaporan dan pembayaran gaji (Staff). Terbagi menjadi dua tab jika pengguna memiliki akses manajemen pembayaran:

| Nama Item / Komponen | Deskripsi Konten | Logo / Ikon | Target Aksi / Direct |
| :--- | :--- | :--- | :--- |
| **Bilah Laporan Gaji** | Menampilkan total pengeluaran gaji keseluruhan & pengeluaran gaji bulan ini. | Teks nominal gaji (IDR) warna ungu tebal | Informasi statistik keuangan gaji. |
| **Tab: Buat Pembayaran** | Digunakan oleh manager/admin untuk memilih karyawan, memilih bulan gaji, melihat preview perhitungan gaji (gaji pokok, tunjangan, potongan, pajak, gaji bersih), memilih rekening sumber, menambahkan catatan, dan melakukan transfer. | `Icons.payments_rounded` | Membuka preview kalkulasi gaji & memproses pembayaran gaji karyawan. |
| **Tab: Riwayat Gaji** | Daftar struk gaji bulanan yang telah dibayarkan. Menampilkan Bulan Gaji (e.g. "Juni 2026") dan Nominal Gaji Bersih. | `Icons.receipt_long` (Ungu) | Diketuk untuk membuka Bottom Sheet detail payslip (rincian slip gaji). |

---

## 🛠️ 6. Modul Aplikasi Lainnya (All Menus Grid)
Modul-modul ERP lainnya yang dapat diintegrasikan ke dalam Bento Grid utama atau diakses melalui halaman **Semua Menu**:

1.  **Rent Plan (`RentPlanPage`):** `Icons.house_rounded` -> Manajemen rencana sewa laptop aktif (Staff/Customer).
2.  **Todo List (`TodoListPage`):** `Icons.assignment_rounded` -> Daftar tugas harian personal karyawan.
3.  **Work Log (`WorkLogPage`):** `Icons.assignment_turned_in_rounded` -> Catatan aktivitas kerja harian yang disubmit karyawan.
4.  **QuickSend (`QuickSendPage`):** `Icons.send_rounded` -> Layanan pengiriman notifikasi/template pesan cepat WhatsApp.
5.  **Finance (`FinancePage`):** `Icons.account_balance_wallet_rounded` -> Modul kelola transaksi dan kas keuangan perusahaan.
6.  **My Wallet (`PersonalFinancePage`):** `Icons.payments_rounded` -> Keuangan personal karyawan, dompet saldo internal.
7.  **Job Desk (`JobDeskPage`):** `Icons.assignment_ind_rounded` -> Rincian tugas pokok & uraian tanggung jawab pekerjaan karyawan.
8.  **Employees (`EmployeesPage`):** `Icons.people_alt_rounded` -> Daftar direktori kontak dan info karyawan lain dalam perusahaan.
9.  **Ide Kreatif (`CreativeIdeaPage`):** `Icons.lightbulb_rounded` -> Wadah pengumpulan aspirasi & ide inovasi karyawan.
10. **AI Bot (`AiBotPage`):** `Icons.smart_toy_rounded` -> Bot asisten AI pintar terintegrasi untuk tanya jawab operasional.
11. **Helpdesk (`HelpdeskListPage`):** `Icons.support_agent_rounded` -> Pengajuan tiket keluhan dan bantuan teknis sistem.
12. **Intercom (`IntercomPage`):** `Icons.volume_up_rounded` -> Layanan siaran pengumuman suara/audio intercom antar divisi.
13. **Laporan (`ReportsPage`):** `Icons.analytics_rounded` -> Rangkuman laporan kinerja dan analitik operasional divisi.
14. **Proyek (`ProjectListPage`):** `Icons.folder_copy_rounded` -> Daftar proyek aktif beserta tim yang terlibat.
15. **Tugas (`TaskListPage`):** `Icons.task_alt_rounded` -> Task tracker pekerjaan/sub-task yang ditugaskan ke karyawan.

---

*Catatan Tambahan untuk Sketching Figma:*
*   *Gunakan bayangan sangat tipis (soft shadow) pada setiap bento card.*
*   *Gunakan border radius 24px untuk kartu utama dan 16px untuk kartu kecil.*
*   *Terapkan warna dasar latar belakang aplikasi abu-abu sangat muda/biru muda (`#F8FAFF`) untuk mode terang dan abu-abu gelap (`#1E1E1E` / `#121212`) untuk mode gelap.*
*   *Warna aksen utama menggunakan Ungu (`#7E57C2`) dan hijau daun muda untuk aksen sukses (`#2ECC71`).*
