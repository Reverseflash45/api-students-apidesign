# Pengujian Tugas 7

1. Jalankan migration 005 (lihat README).
2. Terminal 1: `go run .`
3. Terminal 2: `powershell -ExecutionPolicy Bypass -File .\uji_tugas7.ps1`

Skrip menguji Spesifikasi Penerimaan Bagian C: cursor pagination (termasuk bukti tanpa duplikasi
setelah penyisipan baris baru), validasi deklaratif, content negotiation, keseragaman response
kegagalan, kegagalan server yang tidak membocorkan detail, dan tingkat log. Ia juga menjalankan
`EXPLAIN ANALYZE` atas 20.000 baris beban uji, lalu menghapus beban uji itu kembali.

Hasil lengkapnya ditulis ke `hasil_uji_tugas7.md`.

Catatan: login dibatasi 5x per menit, jadi tunggu satu menit sebelum menjalankan ulang.
