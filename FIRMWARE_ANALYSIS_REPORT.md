# Analisis firmware MSI MS-7C95: PRO-DASH 3.7 vs PRO-VDH 2.93

Tanggal analisis: 28 Oktober 2026. Analisis ini bersifat statis/read-only atas image yang diunggah; tidak ada firmware atau variabel NVRAM yang ditulis.

## 1. Executive summary

**Keputusan: CONDITIONAL GO untuk investigasi non-flash; NO-GO untuk cross-flash saat ini.**

Kedua image adalah firmware AMI/UEFI 32 MiB untuk keluarga `E7C95AMS`, dengan layout volume, GUID utama, NVRAM AMI NVAR, driver AMD AGESA/AM4, SIO/Nuvoton, serta mekanisme M-Flash/SPI-protection yang sama. Ini adalah bukti kuat bahwa keduanya berbagi basis platform, tetapi **bukan** bukti bahwa konfigurasi papan identik.

Penemuan utama: IFR `AodSetupDxe` pada **kedua** image memuat form *Onboard Voltage Controls*. Form itu mendefinisikan `VDDIO Voltage Control` / `Adjust MEM VDDIO Value` dengan 3 mV per langkah dari 1,20 V. Pada PRO-DASH, tautan menuju form tersebut dikendalikan oleh `SuppressIf`; jadi ada jalur firmware asli yang tersembunyi. Ini membuktikan keberadaan UI/variabel, bukan bahwa regulator papan pasti akan menerapkan setiap nilai.

PRO-VDH menambahkan UI/fan-monitor yang substansial (`ClickBiosUi`, `ClickBiosUiEx`, `HardwareMonitorDxeTenFan`, `HardwareMonitorDiagram`). Sebaliknya, PRO-DASH membawa komponen khusus DASH/MCTP (`DashManagement`, `Mctp`, plus NVAR terkait) yang tidak terdapat dalam VDH. Perbedaan ini adalah alasan teknis untuk tidak menganggap cross-flash aman hanya karena prefix ROM sama.

## 2. Firmware identification

| Properti | PRO-DASH | PRO-VDH |
|---|---|---|
| Arsip | `7C95v37.zip` | `7C95v293.zip` |
| SHA-256 arsip | `479217944835fbe1504985dba748a9157f9a45faa13df23c2ca906c7070be6e8` | `8ce2b886f31e5ad3d8f5c9f773e169c2acdf88d6743315e9f17f20f4f7b5cb4b` |
| Image | `E7C95AMS.370` | `E7C95AMS.293` |
| Ukuran | 33,554,432 B (32 MiB) | 33,554,432 B (32 MiB) |
| SHA-256 image | `bd13fb9f6395dd49e11998572191ba7b15c394202b09a00fc81e41dbb396e592` | `15933b10e350093d7054f4dfbefe3933e788e560c505e13cd04f3dfc9bc95b79` |
| Identitas/prefix yang ditemukan | `E7C95AMS` | `E7C95AMS` |
| AGESA menurut release note | ComboAM4v2PI 1.2.0.5 | ComboAM4v2PI 1.2.0.3c |

Kedua image diparse sebagai UEFI dengan FFSv2. Keduanya memiliki NVAR store `CEF5B9A3-476D-497F-9FDC-E98143E0422C`, GUID store yang sama, dan volume utama `4F1C52D3-D824-4D2A-A2F0-EC40C23C5916` dengan ukuran 0x801000. Ada dua set region firmware dalam masing-masing image; struktur itu konsisten di antara keduanya.

## 3. UEFI architecture comparison

Komponen inti yang sama (GUID yang sama, sering dengan isi/CRC berbeda karena versi atau project configuration berbeda): `Setup`, `AMITSE`, `AmdPbsSetupDxe`, `CbsSetupDxeRV/ZP`, `AodSetupDxe`, `AmdMemAm4Dxe`, `AmdMemRestoreDxe`, `AmiAgesaDxe/Pei`, `FanPolicyDxe`, `SioDxeInit`, `NuvEUPDxe`, `ProjectConfig_{PEI,DXE,SMI}`, `MFlashDxe`, `FlashSmiDxe`, `SmiFlashDxe`, dan `AmdSpiRomProtectDxe`.

Contoh pembeda yang terverifikasi:

| Modul | PRO-DASH 3.7 | PRO-VDH 2.93 | Makna |
|---|---:|---:|---|
| Setup FFS | 0xFEE9A | 0x11601A | UI/setup VDH lebih besar |
| AMITSE FFS | 0x39CFB | 0xA1526 | Perbedaan UI/setup besar |
| ClickBiosUi / Ex | tidak ada | ada: 0x3FF8E / 0x4A2A | UI VDH tambahan |
| HardwareMonitorDxeTenFan | tidak ada | ada: 0x2428E | Dukungan monitor/fan VDH tambahan |
| DashManagement + Mctp | ada: 0xF06 + 0x5C92 | tidak ada | Fitur khusus DASH hilang bila seluruh image diganti |
| `DashSetupVariable`, `MctpSetupVariable` | ada | tidak ada | Skema default NVRAM berbeda |

Driver AMD yang sama menunjukkan arsitektur AM4/B550 sekeluarga, tetapi `ProjectConfig`, AGESA wrapper, SIO protocol, fan policy, setup, dan modul flash tidak identik. Jadi image bukan pertukaran UI yang bersih.

## 4. DRAM-voltage investigation

Fakta IFR dari `AodSetupDxe` PRO-DASH 3.7 (FormSet `E39AC631-48ED-445E-9042-55B34F405843`, VarStore `AOD_SETUP`, GUID `5ED15DC0-EDEF-4161-9151-6014C4CC630C`, ukuran 0x3FC):

* Form `0x0C` (*AMD Overclocking*) memiliki `Ref` ke form `0x21`, *Onboard Voltage Controls*, tetapi dibungkus `SuppressIf` yang bergantung pada QuestionId `0xEF`.
* Form `0x21` menyediakan `VDDIO Voltage Control` pada offset `0xC2` dan `Adjust MEM VDDIO Value` pada offset `0xC3`.
* Bantuan IFR menyatakan: `VddIo = 1.2V +/- N * 3 mV`, dengan `N` 0–127 dan arah increase/decrease pada offset `0xC2`. Secara aritmetika 1,35 V adalah +50 langkah, tetapi **ini bukan rekomendasi untuk menulis nilai itu**.
* Nilai penyesuaian disembunyikan saat control = Disabled; ada VTT dan VDDP terpisah. VDDP bukan VDDIO/DRAM rail.

IFR yang sama juga ada pada VDH 2.93, dengan offset VDDIO yang sama. Dengan demikian, tidak ada bukti dari IFR bahwa VDH menghadirkan kemampuan VDDIO yang sepenuhnya tidak ada pada PRO-DASH; bukti justru menunjuk pada visibilitas/menu policy. String `VDIMM` yang ditemukan dalam image adalah log SMBIOS (`VDIMM SLOTx_FWREV`), **bukan** bukti kontrol tegangan.

Tidak ditemukan string/form A-XMP langsung pada modul IFR yang dianalisis. Karena UI VDH proprietary berada pada ClickBiosUi, tidak dapat dinyatakan dari analisis ini bahwa A-XMP di VDH adalah implementasi rail-control baru. Validasi hardware tetap membutuhkan pembacaan tegangan pada titik ukur atau telemetry yang diketahui akurat—bukan hanya nilai BIOS/HWiNFO.

## 5. Cross-flash compatibility assessment

Kesamaan yang mendukung kompatibilitas parsial: ukuran SPI image penuh 32 MiB, nama/prefix image yang sama, FV layout inti yang sama, GUID modul utama yang sama, serta AMD AM4 stack yang sekeluarga. Ini menjelaskan mengapa laporan boot lintas firmware mungkin terjadi.

Namun, hasil ini tidak mendukung klaim “identik”: AGESA berbeda (VDH 1.2.0.3c lebih lama daripada DASH 1.2.0.5); DASH memiliki stack management MCTP/DASH yang VDH tidak miliki; dan VDH memiliki UI/monitor/fan tambahan. Selain itu, `ProjectConfig` dan driver SIO/fan berbeda hash/CRC. Konfigurasi GPIO, mapping fan header, sensor, board-ID policy, dan regulator tidak dapat disimpulkan aman dari image saja.

## 6. Risk assessment

| Risiko | Bukti | Dampak | Mitigasi |
|---|---|---|---|
| Kehilangan fungsi DASH/MCTP | Terverifikasi: modul/NVAR DASH hanya di image DASH | Sedang–tinggi | Jangan cross-flash bila fitur DASH diperlukan |
| Fan/sensor/GPIO salah | Module monitor/fan/SIO berbeda | Tinggi | Perlakukan sebagai risiko nyata; uji hanya dengan recovery eksternal siap |
| NVRAM/default incompatibility | Ukuran/default Setup serta variabel berbeda | Sedang–tinggi | Jangan pertahankan NVRAM lama; backup penuh terlebih dahulu |
| POST/memory-training failure | AGESA/ProjectConfig berbeda | Tinggi | Recovery SPI eksternal, bukan hanya clear CMOS |
| Kehilangan serial/UUID/DMI/aktivasi | Image distribusi berisi default NVAR, bukan dump chip spesifik | Sedang | Cadangkan seluruh chip dan data DMI sebelum tindakan apa pun |
| Flash BIOS Button gagal memulihkan | Tidak dapat dibuktikan dari image yang dianalisis | Tinggi | Anggap tidak terjamin; siapkan programmer SPI |

## 7. AFUWinx64 dan recovery

AFUWin adalah utilitas AMI yang berinteraksi dengan driver kernel untuk mengidentifikasi flash SPI dan melakukan operasi firmware. Perintah sederhana dengan nama image meminta operasi pemrograman sesuai kebijakan tool/OEM; detail region yang ditulis atau dipertahankan bergantung versi AFU, parameter, proteksi flash, dan policy firmware. Karena itu tidak aman mengasumsikan NVRAM, DMI, UUID, serial, atau region khusus papan akan selalu dipertahankan.

AFU biasanya melakukan pemeriksaan identitas/ROM ID, tetapi adanya driver/OEM configuration dapat mengubah atau membatasi perilakunya. Prefix file yang sama tidak membuktikan pemeriksaan tersebut mengesahkan pertukaran model. Backup AFU juga tidak boleh diperlakukan otomatis sebagai dump fisik lengkap yang mencakup setiap protected/PSP/vendor region.

Strategi pemulihan yang kredibel adalah programmer SPI eksternal + clip/socket yang kompatibel, pembacaan chip fisik, verifikasi hash serta pembandingan backup sebelum penulisan. Flash BIOS Button/M-Flash boleh dianggap opsi tambahan hanya setelah model memastikan image/recovery naming yang tepat; analisis ini tidak memverifikasi mekanisme itu.

## 8. Final recommendation

**NO-GO untuk cross-flash PRO-VDH saat ini.** Alasan: tujuan utama—kontrol MEM VDDIO—ternyata sudah didefinisikan oleh IFR PRO-DASH native, sementara cross-flash membawa regresi AGESA dan menghilangkan komponen DASH yang terverifikasi. Perbedaan fan/SIO/project configuration juga belum dibuktikan aman.

Langkah investigasi lanjutan yang proporsional adalah menguji apakah menu *Onboard Voltage Controls* dapat dibuat terlihat melalui perubahan UI yang minimal pada firmware PRO-DASH, hanya setelah pemetaan variable/driver dan recovery SPI diverifikasi. Jangan menulis NVRAM atau patch firmware pada tahap ini. Jika tujuan hanya RAM 2666 CL16 pada 1,20 V, tidak ada bukti teknis bahwa 1,35 V diperlukan; spesifikasi XMP modul yang diberikan juga adalah 1,20 V.

## 9. Pemetaan gate visibilitas (lanjutan read-only)

Pada PRO-DASH, ref *Onboard Voltage Controls* pada form AMD Overclocking (`FormId 0x0C`) menggunakan kondisi berikut:

```
SuppressIf: NOT (QuestionId 0xEF == 1)
```

Artinya menu terlihat hanya bila QuestionId `0xEF` bernilai `1`; nilai lain menyembunyikan menu. QuestionId tersebut adalah field internal tanpa prompt, berada di `AOD_SETUP` (GUID `5ED15DC0-EDEF-4161-9151-6014C4CC630C`) pada offset `0x13D`, satu byte. Field yang sama (offset `0x13D`) juga ada di PRO-VDH, walaupun diberi QuestionId `0xE7` karena susunan question internalnya berbeda. Ini membuktikan bahwa kedua firmware memakai gate konfigurasi AOD yang ekuivalen untuk menu tersebut.

Tidak ada `AOD_SETUP` default yang dapat diekstrak sebagai entri NVAR standar dari image distribusi. Karena itu, nilai runtime dan pihak yang menginisialisasi field (Aod PEI/DXE/SMM atau policy board) belum dapat dipastikan hanya dari static image. Analisis tidak boleh melompat dari gate ini ke penulisan byte NVRAM: field tersebut kemungkinan policy capability, bukan user setting biasa.

Langkah read-only berikutnya—bila dijalankan pada PC target—adalah mengambil salinan variabel UEFI runtime `AOD_SETUP` beserta metadata GUID, lalu membandingkan byte offset `0x13D` dengan state menu. Itu akan menunjukkan apakah firmware membentuk gate pada boot atau data NVRAM persisten, tanpa mengubah nilai apa pun.

Skrip Windows read-only untuk mengambil snapshot tersebut tersedia pada [`scripts/Read-AodSetup.ps1`](scripts/Read-AodSetup.ps1); petunjuknya ada pada [`scripts/README.md`](scripts/README.md).

