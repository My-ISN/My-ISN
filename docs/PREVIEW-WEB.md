# Preview Aplikasi di Browser (tanpa pasang APK)

Dokumen ini menjelaskan cara **melihat** aplikasi My-ISN langsung di browser
sambil mengedit kode. Semua proses build berjalan di GitHub Actions — laptop
tidak perlu Flutter/Android Studio.

## 1. Preview otomatis (GitHub Pages)

Setiap kali kode di-push ke cabang `main`, `feat/preview-web`, atau
`feat/cekupdate-hris`, workflow `.github/workflows/preview-web.yml` akan:

1. menjalankan `flutter build web --release --base-href "/My-ISN/"`,
2. menguji hasilnya (server statis di runner + cek HTTP/tipe konten),
3. menerbitkan hasil ke GitHub Pages.

Tautan preview:

    https://my-isn.github.io/My-ISN/

### Satu setelan yang perlu diklik sekali

GitHub tidak mengizinkan robot mengaktifkan Pages, jadi setelan ini harus
diklik pemilik satu kali:

1. Buka https://github.com/My-ISN/My-ISN/settings/pages
2. Bagian **Build and deployment** → **Source** → pilih **GitHub Actions**
   (jangan pilih "Deploy from a branch")
3. Simpan (tidak ada tombol simpan untuk opsi ini; pilihannya langsung aktif)
4. Jalankan ulang workflow: **Actions** → **Preview Web (GitHub Pages)** →
   **Run workflow** → pilih cabang → **Run workflow**.

Preview akan hidup di tautan di atas. Statusnya bisa dipantau di laporan
(`build_type` harus `workflow`).

Selama setelan itu belum diklik, workflow tetap **hijau** dan hanya melewati
tahap deploy (ada peringatan di ringkasan run).

## 2. Melihat laporan build tanpa login

Log Actions tidak bisa dibaca tanpa login. Karena itu setiap run juga menulis
laporan ke cabang `preview-web-report`:

    https://raw.githubusercontent.com/My-ISN/My-ISN/preview-web-report/REPORT.txt

Isinya: versi Flutter/Dart, potongan log build, hasil smoke test, hasil uji
render, dan catatan bila ada galat. Bukti render ikut disimpan di cabang yang
sama:

- `preview-runtime.png` — screenshot aplikasi yang benar-benar dirender browser
  (Chrome headless di runner, ukuran HP 414x896)
- `dom.html` — DOM hasil render (memuat penanda `flt-glass-pane`/`flutter-view`,
  artinya mesin Flutter benar-benar jalan, bukan halaman kosong)

## 3. Mengedit kode langsung di browser

- Editor ringan (tanpa menjalankan aplikasi): buka repo lalu tekan tombol `.`
  pada keyboard → `github.dev`:
  https://github.dev/My-ISN/My-ISN
- Editor lengkap + bisa menjalankan aplikasi (Codespaces, ada Flutter di
  dalamnya, preview di port 8080 otomatis dibuka):
  https://codespaces.new/My-ISN/My-ISN

  Di Codespaces, `.devcontainer/devcontainer.json` sudah menyiapkan:
  `flutter pub get` lalu `flutter run -d web-server --web-port 8080`.
  Preview muncul di tab **Ports** → ikon globe pada port 8080.

## 4. Alternatif: lihat lewat APK

Bila ingin menguji perilaku khas Android (fingerprint, kamera/scan, notifikasi,
OTA update), pakai workflow APK:

- Actions → **Build APK & AAB** → run terakhir → artifact **apk-aab-hasil**
  (APK debug + AAB release, tersimpan 30 hari).

## 5. Catatan penting soal preview web

Preview web cocok untuk **melihat dan menyusun UI**, bukan pengganti uji di HP.
Fitur berikut tidak bekerja / terbatas di browser:

| Fitur | Plugin | Status di web |
| --- | --- | --- |
| Login fingerprint/biometric | `local_auth` | tidak didukung |
| Update OTA (unduh & pasang APK) | `ota_update` | tidak didukung (Android saja) |
| Notifikasi lokal & push | `flutter_local_notifications`, `firebase_messaging` | terbatas/tidak jalan (butuh konfigurasi web Firebase) |
| Unggah berkas dari galeri/kamera | `image_picker`, `file_picker`, `image_cropper` | UI jalan, tetapi berkas dari browser berupa blob (bukan path) sehingga unggahan berkode `dart:io File` bisa gagal |
| Cache/berkas lokal | `path_provider`, `dart:io` | tidak ada filesystem; sebagian alur dilewati (sudah ada penjaga `kIsWeb`) |

Panggilan API HRIS **tetap jalan** di browser: endpoint
`https://istanakomputer.com/HRIS/mobileapi/login` mengirim
`access-control-allow-origin: *`, dan aplikasi memakai `application/x-www-form-urlencoded`
(body Map tanpa header khusus) sehingga tidak memicu preflight CORS.
