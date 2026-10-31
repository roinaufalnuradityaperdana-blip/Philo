# Suoro - Kirim File & Teks P2P Tanpa Internet

Aplikasi transfer file dan teks langsung antara komputer **Windows** dan HP **Android** lewat jaringan Wi-Fi / Hotspot lokal tanpa kuota internet dan tanpa server cloud.

---

## Cara Pakai (Untuk Orang Awam)

1. **Sambungkan ke Wi-Fi yang Sama**  
   Pastikan PC Windows dan HP Android terhubung ke Wi-Fi atau Hotspot yang sama.
2. **Buka Aplikasi Suoro** di PC dan HP.  
   Nama perangkat akan otomatis muncul di layar ("Perangkat Sekitar").
3. **Kirim File**:
   - Di PC: Tarik & lepas file ke aplikasi Suoro, atau klik tombol **"Kirim"** di sebelah nama HP Android.
   - Di HP: Tekan tombol **"Terima"** saat notifikasi muncul. File langsung tersimpan di folder Download/Galeri!
4. **Kirim Teks / Link**:
   - Ketik atau tempel link di kotak teks, lalu klik **"Kirim"**. Teks langsung terkirim dan tersalin ke HP.

---

## Cara Mendapatkan File `.exe` dan `.apk`

### Opsi 1: Otomatis via GitHub (Tanpa Perlu Install Flutter di PC)
1. Push project ini ke GitHub.
2. Buka tab **Actions** di GitHub repository.
3. Download hasil build:
   - **`Suoro-Windows-exe`** (untuk Windows).
   - **`Suoro-Android-apk`** (untuk Android).

### Opsi 2: Build Manual di Komputer
Jika komputer memiliki Flutter SDK:
- **Build Windows (`Suoro.exe`)**: Klik ganda `build_windows_exe.bat`.
- **Build Android (`Suoro.apk`)**: Klik ganda `build_android_apk.bat`.
- File hasil build otomatis tersimpan di folder `dist/`.

---

## Lokasi Penyimpanan File Diterima
- **Windows**: `Downloads\Suoro\`
- **Android**: `Download/Suoro/` (foto & video otomatis masuk Galeri HP).
