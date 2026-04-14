# Dokumentasi API

Seluruh komunikasi data pada aplikasi My-ISN dilakukan melalui antarmuka RESTful API yang melayani respons dalam format JSON.

## Konfigurasi Dasar
Seluruh URL API dibangun di atas `AppConstants.baseUrl` yang dapat dikonfigurasi secara terpusat untuk kemudahan migrasi lingkungan (Development/Staging/Production).

## Autentikasi
Sebagian besar endpoint memerlukan identifikasi pengguna melalui `user_id` atau token akses yang valid guna memastikan operasional berada dalam lingkup izin (permissions) yang tepat.

## Modul Utama
- **Finance**: GET/POST transaksi, saldo, dan kategori keuangan.
- **Todo List**: Manajemen tugas, pendelegasian, dan status progres.
- **Job Desk**: Pengelolaan daftar pekerjaan berdasarkan jabatan (Designation).
- **Asset**: Sinkronisasi data persewaan laptop dan status inventaris.

## Penanganan Keamanan
Aplikasi mengadopsi sistem enkripsi standar industri untuk data sensitif serta validasi sisi server (Server-side validation) untuk setiap input data dari mobile.
