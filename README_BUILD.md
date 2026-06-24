# Panduan Build & Deploy - Toko Pintar POS Multiplatform

Dokumen ini menjelaskan langkah-langkah untuk melakukan build dan deploy aplikasi Toko Pintar POS pada platform Android, Windows, Linux, dan Web.

---

## 1. Persyaratan Awal (Prerequisites)

Pastikan Anda memiliki Flutter SDK terinstal (versi minimal 3.3.0) dan environment path sudah terkonfigurasi. Jalankan command berikut untuk mengecek kesiapan environment Anda:

```bash
flutter doctor
```

---

## 2. Panduan Build Android

### Persyaratan
* **Java Development Kit (JDK)**: JDK 17 terinstal.
* **Android SDK**: Terinstal via Android Studio (SDK Tools, Build Tools).

### Langkah-langkah
1. Hubungkan Firebase: download file `google-services.json` dari Firebase Console Anda dan taruh di folder `android/app/`.
2. Generate Keystore untuk penandatanganan aplikasi (Signing):
   ```bash
   keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
3. Konfigurasi `android/key.properties` untuk memuat path keystore dan password Anda.
4. Jalankan perintah build berikut:
   * **Build APK (Release)**:
     ```bash
     flutter build apk --release
     ```
     *Hasil output file:* `build/app/outputs/flutter-apk/app-release.apk`
   * **Build Android App Bundle (AAB - Untuk Google Play Store)**:
     ```bash
     flutter build appbundle --release
     ```
     *Hasil output file:* `build/app/outputs/bundle/release/app-release.aab`

---

## 3. Panduan Build Windows Desktop

### Persyaratan
* **Visual Studio 2022**: Instal Visual Studio dengan workload **Desktop development with C++** diaktifkan.
* Platform Windows SDK yang kompatibel.

### Langkah-langkah
1. Pastikan target platform Windows sudah aktif di project Anda:
   ```bash
   flutter config --enable-windows-desktop
   ```
2. Jalankan perintah build untuk Windows:
   ```bash
   flutter build windows --release
   ```
   *Hasil output folder:* `build/windows/x64/runner/Release/`
3. Distribusi:
   * Anda bisa mem-pack folder `Release` di atas menjadi file installer menggunakan aplikasi pihak ketiga seperti **Inno Setup** atau **Advanced Installer**.
   * Pastikan menyertakan semua file `.dll` yang ada di dalam folder output agar aplikasi berjalan lancar di komputer client.

---

## 4. Panduan Build Linux Desktop

### Persyaratan
* Kompiler C++ (clang) dan build tools (cmake, ninja-build).
* GTK 3 development headers (`libgtk-3-dev`).
* Library pendukung: `pkg-config`, `liblzma-dev`, `libsecret-1-dev`.

Instal dependency pada Ubuntu/Debian dengan perintah:
```bash
sudo apt-get update
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev
```

### Langkah-langkah
1. Pastikan platform Linux diaktifkan:
   ```bash
   flutter config --enable-linux-desktop
   ```
2. Jalankan perintah build untuk Linux:
   ```bash
   flutter build linux --release
   ```
   *Hasil output folder:* `build/linux/x64/release/bundle/`
3. Distribusi:
   * Anda dapat mem-compress folder bundle tersebut menjadi `.tar.gz` atau membuatnya menjadi package `.deb` / Flatpak.

---

## 5. Panduan Deploy Web Browser

### Persyaratan
Aplikasi web dapat dideploy ke web server mana saja seperti Nginx, Apache, Firebase Hosting, Netlify, Vercel, dll.

### Langkah-langkah
1. Jalankan perintah build untuk Web:
   ```bash
   flutter build web --release --web-renderer canvaskit
   ```
   *Note:* Parameter `--web-renderer canvaskit` direkomendasikan untuk performa rendering grafis chart (fl_chart) dan barcode scanning yang optimal di browser.
   
   *Hasil output folder:* `build/web/`

2. **Deploy menggunakan Firebase Hosting (Rekomendasi)**:
   * Instal Firebase CLI: `npm install -g firebase-tools`
   * Login ke Firebase: `firebase login`
   * Inisialisasi project di folder root: `firebase init hosting`
     * Pilih project Firebase Anda.
     * Tentukan public directory ke `build/web`.
     * Pilih "Configure as a single-page app" -> **Yes**.
   * Lakukan deployment:
     ```bash
     firebase deploy --only hosting
     ```

3. **Deploy menggunakan Nginx**:
   Salin semua isi folder `build/web/` ke folder public root server Nginx Anda (misalnya `/var/www/html/`). Berikut contoh konfigurasi `/etc/nginx/sites-available/default` untuk Single Page App:
   ```nginx
   server {
       listen 80;
       server_name pos.tokopintar.id;

       location / {
           root /var/www/html;
           index index.html;
           try_files $uri $uri/ /index.html;
       }
   }
   ```

---

## 6. Tips Performa & Troubleshooting
* **Kamera Web**: Pada platform Web, fitur scan kamera membutuhkan protokol HTTPS agar browser mengizinkan akses ke kamera device (webcam). Pastikan URL deploy web menggunakan sertifikat SSL (HTTPS).
* **Shortcut F2/F3/F4**: Berjalan secara global. Pastikan tidak ada konflik shortcut dengan aplikasi bawaan Windows / Linux / browser extensions.
