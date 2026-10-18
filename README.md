# Skyroot — The Last Archer

Game Android menjalankan platformer asli dari `game js/game/game.js`. Flutter menyediakan menu; Android WebView menjalankan JavaScript, canvas, kontrol sentuh, dan audio asli. Semua gambar, metadata frame, dan program runtime disertakan dalam APK, tanpa server Playabl.

## Menjalankan

```powershell
npm.cmd ci
npm.cmd run build:game
flutter pub get
flutter run -d emulator-5554
```

Setelah mengubah JavaScript atau aset, jalankan `npm.cmd run build:game` sebelum build Flutter. Hasil bundel berada di `assets/game/` dan ikut disertakan dalam APK. Tidak ada proses Node/server yang diperlukan saat bermain.

```powershell
npm.cmd run test:game
flutter analyze
flutter test
flutter build apk --release
```

Uji browser memakai Microsoft Edge melalui Playwright (`channel: msedge`). APK: `build/app/outputs/flutter-apk/app-release.apk`. Konfigurasi signing yang diwarisi proyek masih memakai debug key; APK ini untuk pengujian lokal.

## Kontrol dan aturan asli

- Joystick: bergerak, memanjat sulur, naik/turun lift, turun melalui platform satu arah.
- Memanjat dari bawah: dekati sulur hijau dan tahan joystick ke atas (W/panah atas). Bila ujungnya menggantung, lompat sambil menahan atas. Netral untuk berhenti, bawah untuk turun, lompat + samping untuk berpindah ke platform. Deteksi sulur menjangkau kepala/tubuh, dengan jeda sebelum boleh menempel kembali setelah melompat; karakter tidak lagi tersangkut berulang di ujung atas.
- Lompat: tahan untuk lompatan penuh, lepas untuk lompatan pendek.
- Busur: tahan dan geser untuk membidik, lepas untuk menembak; ketukan cepat memakai bantuan bidik.
- Semua 11 wilayah/tema dan 11 skin tersedia di menu utama, peta, dan lemari skin, termasuk save lama dan setelah reset. Lemari bisa dibuka di mana saja. Skill mengikuti skin asli.
- Dash dan panah pijakan diperoleh dari relik di Akar Berkabut. Memilih wilayah lanjutan langsung menyediakan keduanya karena peta-peta tersebut tidak memiliki relik itu. Membuka pilihan tidak menandai boss sebagai sudah dikalahkan.
- Pertarungan, checkpoint, rahasia, dan gerbang tetap mengikuti progres permainan.
- Keyboard: A/D atau panah kiri/kanan, W/S untuk naik/turun, Spasi lompat, J busur, Shift dash, Q/E ganti panah, R skill, M peta.

Progres platformer asli disimpan terpisah dari progres prototipe Flutter sebelumnya; koordinat dan persentase prototipe tidak mewakili checkpoint game asli. Tombol reset menghapus progres game asli hanya ketika pengguna menekannya.

## Aset dan frame

Sumber tetap `game js/assets.json` dan gambar dalam `assets/images/`. Ada 74 kunci aset: 60 sheet (1.250 frame), 12 gambar tunggal, dan 2 kit terrain yang referensi lokalnya memakai satu `atlas.png`. Sheet wilayah dan skin dimuat ketika dibutuhkan, sesuai loader asli, agar semua tekstur tidak memenuhi RAM sekaligus.

Metadata `.frames.json` asli dan renderer surface-kit tidak ada di salinan proyek ini. URL sumber mengembalikan HTTP 503 saat diperiksa. `tools/build-game.mjs` memulihkan nama/urutan animasi dari recipe dan batas sprite dari alpha gambar; tidak menggambar ulang gambar. Jarak antar-frame ternyata tidak selalu seragam, sehingga pemotongan berdasarkan lebar gambar dibagi jumlah frame menghasilkan sprite tercampur/terpotong.

Cabang memakai kontrak asli renderer: cap 224 px, center 672 px, cap 224 px, dengan permukaan moss pada y=256. Sulur dipotong vertikal. Terrain memakai 47 tile dalam atlas asli; susunan mask tetangga telah diperiksa terhadap alpha setiap tepi. Karena atlas softwood terpisah tidak tersedia (dua URL bernama `atlas.png` dipetakan ke satu file), softwood memakai atlas yang tersisa dengan warna dari recipe asli. Pemulihan ini belum dapat menjamin identik dengan sidecar yang hilang, terutama frame yang gambarnya saling bertumpuk.

Inventaris hasil build tersedia di `assets/game/audit.json` (semua aset, ukuran, jumlah frame, dan modul yang masuk bundel). Manifest lokal: `assets/game/manifest.json`. Metadata tiap sheet: `assets/game/frames/`.

## Struktur dan hasil audit

- `game js/game/`: gameplay asli—peta, fisika, panah, musuh, boss, objek, renderer, audio, HUD, input, save.
- `game js/android-main.js`: pengganti layanan host Playabl untuk loop, audio context, progres lokal, lifecycle Android.
- `game js/offline-terrain.js`: pembacaan atlas terrain asli tanpa renderer server.
- `lib/game/original_game_screen.dart` dan `android/.../SkyrootGameView.kt`: sambungan Android dengan pemuatan aset APK melalui origin HTTPS lokal. Akses jaringan diblokir pada WebView ini.
- Import peta diperbaiki dari `worldMap.js` yang tidak ada menjadi `worldMaps.js` yang tersedia.
- Program lama `data.js`, `geometry.js`, `hero.js`, dan `sim.js` berisi varian tower-defense dengan kunci `HERO_RANGER_A`/`ENEMY_GOBLIN` yang tidak ada dalam manifest platformer. File tetap dipertahankan, tetapi tidak dicampur ke aturan platformer.
- `main.js` dan `devtools.js` merupakan integrasi host/editor Playabl; Android menggunakan bootstrap lokal.
- Implementasi Flame lama tetap ada untuk platform non-Android; perbaikan runtime lengkap pada pekerjaan ini ditujukan ke Android.

Uji mencakup keberadaan/batas frame, konektivitas 47 tile, rendering semua wilayah dan skin, animasi karakter/boss, pergerakan, lompatan, panah, sentuhan dua jari, pause/resume, serta pemuatan ulang progres. Screenshot pengujian ditulis ke `artifacts/`.

Perbaikan lanjutan: crash Android saat animasi memanjat selesai (`p.ledge` sudah kosong) dan saat terkena damage di tepi platform diperbaiki pada transisi animasi serta renderer. Loading startup, area, dan skin sekarang memakai satu jalur: semua frame harus siap, terrain di sekitar spawn disiapkan, baru simulasi dilanjutkan. Kegagalan memiliki timeout dan bisa dicoba ulang; pesan gagal tidak ditimpa setiap frame. Permintaan lama tidak boleh melanjutkan area yang sudah diganti. Tekstur area/skin lama dilepas dan cache terrain hanya menyimpan warna wilayah aktif. Pergantian skin tidak mengisi nyawa atau menghapus cooldown skill.

Uji regresi juga mensimulasikan kegagalan frame core/boss/skin, retry, frame terlambat, perpindahan area bertumpuk, pemilihan semua konten lewat UI tanpa memalsukan kemenangan boss, serta pemilihan skin/tema setelah reset.

Untuk mengulang pemeriksaan Android, buka layar game pada APK debug lalu jalankan `node tools/emulator-smoke.mjs --all-areas`. Pemeriksaan memakai input sentuh untuk 11 pilihan peta/skin dan mengembalikan save sebelum tur. Hasil: `artifacts/android-all-areas.json`; tangkapan layar perangkat: `artifacts/android-gameplay.png`. Judul peta mengikuti wilayah aktif.

Menu utama memakai latar wilayah yang dipilih, portrait dari atlas asli, kartu wilayah/skin, progres, dan panduan kontrol. Gambar thumbnail didekode pada ukuran tampilan agar tidak memuat tekstur penuh untuk setiap kartu. Mode ringan aktif secara bawaan dan disimpan terpisah dari progres; matikan untuk ketajaman penuh. Mode ringan membatasi kerapatan canvas ke 1,5 (detail: 2), tanpa mengubah simulasi 60 langkah/detik. Pada emulator 1080 × 1920, canvas berubah dari 1080 × 1872 menjadi 810 × 1404, atau 43,75% lebih sedikit piksel.

Glow, kabut, dan vignette memakai cache gambar; peta yang tidak berubah tidak digambar ulang. `node tools/emulator-profile.mjs before` / `after` mengukur 180 frame setelah pemanasan pada WebView debug. Sampel awal berjalan sekitar 60 fps; cache mengurangi pembuatan gradien dari sekitar 12 per frame menjadi 0, tetapi sampel singkat ini tidak menjamin semua adegan bebas lag. Catatan profil berada di `artifacts/performance-*.json`.
