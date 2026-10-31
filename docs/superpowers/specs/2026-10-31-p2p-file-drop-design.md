# Spesifikasi Desain: Suoro (P2P Zero-Cloud File & Text Drop)

**Tanggal**: 2026-10-31  
**Status**: Approved (Desain Disetujui)  
**Target Platform**: Windows (Desktop) + Android (Mobile)  
**Teknologi Utama**: Flutter (Dart) Single Codebase, mDNS, Shelf HTTP/TLS, Android Foreground Service, Windows System Tray  

---

## 1. Ringkasan & Tujuan Produk

Suoro adalah aplikasi sinkronisasi dan transfer file/teks peer-to-peer (P2P) lokal tanpa perantara server cloud (Zero-Cloud). Aplikasi ini menghubungkan komputer Windows dan ponsel Android yang berada dalam jaringan lokal yang sama (Wi-Fi, Ethernet, atau Hotspot tethering portabel).

### Masalah yang Diselesaikan
- Mengirim file atau teks dari PC ke HP (atau sebaliknya) sering membutuhkan koneksi internet, akun cloud (Google Drive, Telegram Saved Messages, WhatsApp), atau kabel USB.
- Zero-Cloud memastikan kecepatan maksimal (dibatasi hanya oleh router Wi-Fi lokal), privasi penuh (data tidak pernah keluar ke internet), dan transfer instan tanpa login akun.

---

## 2. Arsitektur Sistem

### 2.1 Topologi Jaringan & Penemuan Perangkat (Discovery)
- **Protokol Discovery**: Multicast DNS (mDNS / Zeroconf) dengan service type `_suoro._tcp`.
- **Informasi yang Ditayangkan (TXT Record)**:
  - `name`: Nama perangkat yang dapat diidentifikasi manusia (contoh: "Roi-PC", "Galaxy-S24").
  - `os`: `windows` atau `android`.
  - `port`: Port TCP HTTPS lokal (default 53317, fallback ke port acak jika bentrok).
  - `fingerprint`: SHA-256 fingerprint dari sertifikat TLS ephemeral.
- **Daftar Peer**: Tiap node menjalankan mDNS browser. Jika sebuah node tidak lagi merespons mDNS query atau disconnect dalam 5 detik, node tersebut dihapus dari daftar peer aktif di UI.

### 2.2 Enkripsi & Keamanan Jaringan
- Setiap instance Suoro membuat pasangan kunci RSA/ECDSA dan sertifikat X.509 self-signed ephemeral saat aplikasi berjalan.
- Semua transfer data (handshake, file stream, dan teks) menggunakan HTTPS/TLS 1.3 langsung antar-IP lokal.
- Mencegah packet sniffing di jaringan Wi-Fi publik/kantor.

---

## 3. Protokol & Alur Transfer Data

### 3.1 Handshake Persetujuan (Transfer Request)
Sebelum aliran data byte dikirim, pengirim (Sender) wajib meminta izin kepada penerima (Receiver).

- **Endpoint**: `POST https://<receiver-ip>:<port>/api/v1/transfer/request`
- **Payload Request**:
  ```json
  {
    "sessionId": "b47c0b89-f509-4c3c-83b6-96b589a19d5f",
    "sender": {
      "name": "Roi-Windows-PC",
      "os": "windows"
    },
    "type": "file",
    "totalSize": 157286400,
    "items": [
      {
        "id": "item-0",
        "name": "proyek-presentasi.zip",
        "size": 157286400,
        "mime": "application/zip"
      }
    ],
    "text": null
  }
  ```
- **Pengecekan di Receiver**:
  1. Cek ketersediaan ruang penyimpanan disk: `freeDiskSpace >= totalSize`. Jika tidak cukup, langsung tolak dengan status `rejected` dan reason `"Penyimpanan disk tidak cukup"`.
  2. Tampilkan dialog prompt atau notifikasi sistem di UI:  
     `"Terima proyek-presentasi.zip (150 MB) dari Roi-Windows-PC? [Tolak] [Terima]"`
- **Response**:
  ```json
  {
    "sessionId": "b47c0b89-f509-4c3c-83b6-96b589a19d5f",
    "status": "accepted"
  }
  ```
  *(Jika ditolak atau timeout 30 detik: `"status": "rejected"`)*.

### 3.2 Aliran File (File Streaming)
- **Endpoint**: `POST https://<receiver-ip>:<port>/api/v1/transfer/stream?sessionId=<sessionId>&itemId=item-0`
- **Mekanisme**:
  - Sender membaca file dari disk lokal dan mengalirkannya sebagai chunked HTTP stream.
  - Receiver membaca `request.read()` secara langsung dan mengalirkannya ke `IOSink` pada file sementara: `Downloads/Suoro/<filename>.part`.
  - Tidak ada buffering seluruh file di memori RAM (`principle-laziness-protocol`), mendukung file berukuran gigabyte tanpa memory leak.
  - Saat stream selesai, receiver memverifikasi ukuran file, menghapus ekstensi `.part`, dan memicu MediaScanner di Android.

### 3.3 Pengiriman Teks & Clipboard
- Untuk teks pendek atau teks panjang (catatan, tautan URL, kode sumber):
  - Dikirim via `POST https://<receiver-ip>:<port>/api/v1/transfer/text` dengan isi payload teks UTF-8.
  - Receiver langsung menampilkan dialog teks, menyalin ke clipboard (opsional), dan menyimpan riwayat teks di log lokal.

---

## 4. State Machine Sesi Transfer (`TransferSessionState`)

State machine terpusat (`principle-model-the-domain`) untuk mengontrol siklus transfer:
1. `idle`: Menunggu tindakan pengguna.
2. `requestSent`: Sender menunggu konfirmasi receiver (timeout 30 detik).
3. `requestReceived`: Receiver menampilkan konfirmasi penerimaan.
4. `transferring`: Aliran data byte aktif. Memancarkan stream progress: `bytesTransferred`, `totalBytes`, `speedMBps`, `etaSeconds`.
5. `completed`: Seluruh file berhasil diterima dan disimpan.
6. `rejected`: Permintaan ditolak penerima atau kedaluwarsa.
7. `failed`: Kesalahan jaringan, socket terputus, atau disk penuh. File `.part` dihapus.
8. `cancelled`: Dibatalkan secara sengaja oleh pengirim atau penerima.

---

## 5. Integrasi Platform Spesifik

### 5.1 Windows Desktop
- **Dropzone UI**: Mendukung drag-and-drop file langsung dari File Explorer Windows ke jendela aplikasi Suoro.
- **System Tray**: Menutup jendela (tombol X) akan meminimalkan aplikasi ke System Tray (taskbar notification area) agar Suoro tetap bisa menerima kiriman di latar belakang.
- **Folder Default**: File disimpan di `%USERPROFILE%\Downloads\Suoro\`. Terdapat tombol "Buka Folder" di UI.

### 5.2 Android Mobile
- **Foreground Service**: Menggunakan notifikasi persisten bertingkat rendah ("Suoro aktif mendengarkan transfer...") agar sistem operasi Android tidak membunuh socket listener saat layar terkunci atau aplikasi berada di latar belakang.
- **Share Sheet Intent**: Terdaftar di Android Manifest untuk menangkap `android.intent.action.SEND` dan `SEND_MULTIPLE`. Pengguna dapat menekan tombol "Share" di aplikasi galeri/file manager apa pun di Android dan memilih Suoro untuk langsung mengirim ke Windows.
- **Penyimpanan & Galeri**: File disimpan di direktori publik `Download/Suoro/`. File foto/video dipindai otomatis via `MediaScannerConnection` agar langsung tampil di Google Photos / Galeri ponsel.

---

## 6. Penanganan Kesalahan & Edge Cases

| Kasus | Solusi Desain |
|---|---|
| Nama file sudah ada di folder tujuan | Tambahkan sufiks penomoran: `file (1).ext`, `file (2).ext`. Jangan menimpa file yang sudah ada. |
| Koneksi terputus saat streaming | Hapus file `.part` yang tidak lengkap agar tidak meninggalkan sampah di disk. Tampilkan status gagal dengan tombol Retry. |
| Disk penuh | Cek sisa kuota penyimpanan sebelum menerima transfer pada fase handshake. Tolak lebih awal jika ruang tidak mencukupi. |
| Multi-IP / Hotspot | Bind socket HTTP ke `0.0.0.0` (semua interface IPv4). Umumkan mDNS di seluruh network adapter aktif. |
| Android Doze Mode | Tampilkan panduan sekali klik untuk meminta pengguna menonaktifkan Battery Optimization pada Suoro. |

---

## 7. Rencana Pengujian & Verifikasi

1. **Unit Test**:
   - `TransferStateMachine`: Menjamin transisi state valid dan menolak transisi ilegal.
   - `FilenameResolver`: Memastikan duplikasi nama file ditangani secara benar (`foo.txt` -> `foo (1).txt`).
2. **Loopback Integration Test**:
   - Menjalankan 2 node Suoro secara lokal di dua port berbeda pada mesin pengembangan.
   - Mengirim file 10 MB dan payload teks panjang (10.000 karakter).
   - Memvalidasi kecocokan hash SHA-256 dan isi teks 100%.
3. **Manual Cross-Platform Test**:
   - Menjalankan aplikasi di Windows (`flutter run -d windows`) dan perangkat Android fisik.
   - Drag-and-drop file dari Windows ke kartu Android -> Konfirmasi di Android -> File tersimpan di `Download/Suoro/`.
   - Salin teks di Android -> Kirim ke Windows -> Teks muncul di jendela Suoro Windows dan tersalin ke clipboard.
