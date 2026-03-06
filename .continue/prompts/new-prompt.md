---
name: Smalka_rules
description: penyimpanan hosting
invokable: true
---

# Instruksi Penempatan File di Hosting

Ringkasan:
- Folder `server/` adalah public_html di hosting Anda.
- Semua file API untuk aplikasi harus ditempatkan di `server/api/` (-> public_html/api).
- Website portal diletakkan langsung di `server/` (root public_html).

Untuk website (bukan flutter) :
- untuk role guru, frontend masukan ke server/web/guru, backend di server/config/web (jika backend khusus untuk role atau page guru mulailah nama file dengan awalan guru_.... php)
- untuk role admin, frontend masukan ke server/web/admin, backend di server/config/web (jika backend khusus untuk role atau page admin mulailah nama file dengan awalan admin_.... php)
- untuk role guru tahfidz, frontend masukan ke server/web/tahfidz, backend di server/config/web (jika backend khusus untuk role atau page guru_tahfidz mulailah nama file dengan awalan guru_tahfidz_.... php)
- gunakan tailwind UI dengan model inspirasi shadcdn UI, gunakan template block yang sesuai dengan shadcdn UI namun sesuai kan dengan color hijau. Hindari warna gradient.