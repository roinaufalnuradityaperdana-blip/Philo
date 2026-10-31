# CONTEXT.md

## Domain: Suoro (P2P Zero-Cloud File & Text Drop)

Suoro adalah aplikasi sinkronisasi & transfer file/teks peer-to-peer tanpa server cloud, menghubungkan perangkat Windows dan Android dalam satu jaringan lokal (LAN / Wi-Fi / Hotspot).

### Core Entities & Terminology

- **Peer**: Perangkat (Windows PC atau Android Phone) yang menjalankan Suoro dan siap mengirim/menerima data.
- **Discovery**: Mekanisme mendeteksi Peer lain di subnet lokal menggunakan Multicast DNS (mDNS / Zeroconf `_suoro._tcp`).
- **TransferSession**: State machine sesi transfer antara Sender dan Receiver (`Idle` -> `RequestPending` -> `Approved` -> `Streaming` -> `Completed` / `Failed`).
- **Payload**: Konten yang ditransfer, berupa **FilePayload** (satu atau banyak file/folder dengan streaming chunked binary) atau **TextPayload** (teks pendek atau panjang / clipboard dump).
- **ReceiverConfirmation**: Prompt persetujuan eksplisit di sisi penerima sebelum payload mulai ditransfer.
