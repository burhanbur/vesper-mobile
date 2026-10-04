# PRD — Vesper Mobile App (Flutter)

## 1. Ringkasan Produk

Vesper adalah aplikasi pencatatan keuangan harian + wealth management (termasuk investasi: saham, reksadana, crypto, emas) dengan arsitektur **offline-first** — aplikasi harus tetap bisa dipakai penuh tanpa koneksi internet (input transaksi, lihat saldo, dsb), lalu sync ke server ExpressJS saat online. Mendukung fitur **grup** untuk pasutri/keluarga berbagi visibilitas akun tertentu.

Dokumen ini adalah PRD untuk sisi mobile app (Flutter). Untuk kontrak API & business rules sisi server, lihat `vesper_prd_backend.md` — PRD ini mengasumsikan backend tersebut sebagai API yang dikonsumsi.

## 2. Tech Stack & Keputusan Arsitektur

- **Framework**: Flutter
- **Local database (offline storage)**: **Drift** (dibangun di atas SQLite). Alasan: skema Vesper sangat relational (banyak foreign key antar tabel — `transactions → accounts → account_types`, `investment_transactions → instruments`, dst), dan Drift menyediakan type-safety + reactive streams (`watch()` query otomatis memicu rebuild UI saat data lokal berubah) — krusial untuk UX offline-first di mana UI harus langsung mencerminkan write lokal sebelum sync selesai. Struktur tabel lokal mengikuti entity yang di-sync: `accounts`, `account_types`, `categories`, `transactions`, `user_profiles`, plus tabel lokal khusus `sync_queue` (lihat `erd.dbml`, komentar: "KHUSUS UNTUK DATABASE LOCAL FLUTTER BUKAN UNTUK POSTGRESQL"). Definisikan skema Drift (`.drift` file atau Dart table classes) agar 1:1 dengan kolom-kolom di `erd.dbml` untuk entity yang masuk scope sync.
- **State management**: **Riverpod** (`flutter_riverpod` + code generation `riverpod_generator`). Alasan: reactive stream dari Drift gampang di-expose lewat `StreamProvider`, compile-safe (error ketauan saat development), dan cocok untuk app dengan banyak provider saling bergantung (auth state, status sync, data per modul). Struktur yang disarankan: 1 provider per repository (AccountsRepository, TransactionsRepository, dst) yang membungkus Drift DAO, dikonsumsi oleh provider UI-level per screen.
- **HTTP client**: **Dio**. Base URL dikonfigurasi via environment (dev/staging/prod). Wajib pakai interceptor untuk: (1) inject JWT `Authorization: Bearer` header dari `flutter_secure_storage`, (2) auto-refresh token saat 401 (pakai `QueuedInterceptor` custom), (3) log request/response di debug mode.
- **Auth token storage**: **`flutter_secure_storage`** — jangan simpan token di `SharedPreferences` atau local DB (tidak aman).
- **Routing**: **go_router** — deklaratif, support deep link, guard auth via `redirect`.
- **Code generation**: **`build_runner`** dipakai untuk Riverpod (`riverpod_generator`), Drift (`drift_dev`), dan Freezed (`freezed`/`json_serializable`). Jalankan `dart run build_runner build --delete-conflicting-outputs` setiap kali model atau provider berubah.

## 3. Prinsip Arsitektur Offline-First (WAJIB dipegang)

1. **Local-first write**: setiap aksi user (tambah transaksi, edit akun, dll) langsung ditulis ke database lokal dan **langsung terlihat di UI** (optimistic update), TANPA menunggu respons server.
2. **`sync_queue` sebagai outbox**: setiap write lokal juga insert row ke `sync_queue` lokal (`entity_type`, `entity_id`, `operation`, `payload`, `client_version`, `status = PENDING`).
3. **Background sync service**: jalan berkala (atau dipicu saat koneksi kembali / app resume) — proses `sync_queue` yang `PENDING`:
   - Push ke `POST /sync/push` (lihat PRD backend 5.10)
   - Kalau sukses → `status = SYNCED`, hapus/arsipkan dari queue
   - Kalau conflict (409 dari server, version mismatch) → `status = FAILED`, simpan error, **tampilkan ke user** untuk resolusi (lihat bagian 6)
   - Kalau network error → retry dengan `retry_count` naik, exponential backoff (contoh: 30s, 2m, 10m, max 1h)
4. **Pull sync**: setelah push sukses (atau terpisah, berkala), panggil `GET /sync/pull?device_id=X&since_version=devices.last_sync_version` → apply setiap perubahan ke DB lokal secara berurutan → update `last_sync_version` lokal.
5. **Scope entity yang di-sync**: `transactions`, `account_types`, `accounts`, `categories`, `user_profiles`. **Entity investasi (`instruments`, `instrument_prices`, `investment_transactions`, `portfolio_daily_snapshots`) TIDAK masuk scope ini — modul investasi bersifat online-required** (keputusan final, lihat 5.7 dan bagian 9).
6. **Connectivity ≠ reachability**: status koneksi (via `connectivity_plus`) hanya dipakai sebagai **trigger** untuk memulai sync — bukan jaminan API reachable. Sync service harus tetap handle timeout/network error bahkan saat device melaporkan "online".

## 4. Navigasi & Shell Aplikasi

Bottom navigation bar 5 item:

| Tab | Icon | Label |
|-----|------|-------|
| 1 | Home | Beranda |
| 2 | Receipt | Transaksi |
| 3 | — | **(+) FAB — center floating** |
| 4 | Trending Up | Aset |
| 5 | Menu / Grid | Lainnya |

**Center FAB `(+)`** membuka **Quick Action Sheet** (modal bottom sheet) dengan pilihan:
- Catat Pengeluaran
- Catat Pemasukan
- Transfer / Catat Hutang
- Catat Investasi

Tab "Lainnya" berisi sub-menu navigasi ke: Laporan, Budget, Grup/Household, Notifikasi, Pengaturan.

**App Header** (persistent di semua tab utama):
- Avatar user + greeting ("Halo, {first_name}")
- Household/group switcher (dropdown untuk ganti konteks grup aktif)
- Badge offline (muncul saat device offline)
- Icon notifikasi dengan unread dot

## 5. Fitur & Layar (Screens)

### 5.1 Onboarding & Auth

- Register (email, username, password, full name)
- Login (email/username + password)
- Lupa password (request reset via email)
- (Opsional) Biometric lock untuk buka app — pakai `local_auth`, protect dengan flag di `flutter_secure_storage`

### 5.2 Dashboard (Beranda)

**Hero section — Net Worth:**
- Total kekayaan (net worth) — `SUM(accounts.balance WHERE is_include_total = true)`, termasuk investment accounts (`market_value` dari `portfolio_daily_snapshots` terakhir) dan akun hutang (balance hutang negatif otomatis mengurangi total)
- Sparkline chart mini (trend 7 hari atau 30 hari) di belakang angka
- Sub-teks: perubahan nominal & persentase dari bulan lalu

**Neraca bulan berjalan:**
- Ringkasan pemasukan vs pengeluaran bulan ini (dari `transactions WHERE transacted_at` dalam range bulan berjalan)
- Tampilkan surplus/defisit: `+Rp X.XXX.XXX` (hijau) atau `-Rp X.XXX.XXX` (merah)
- Tap → navigasi ke screen Laporan (5.9)

**Daftar akun horizontal (scrollable):**
- Card per akun (name, balance, icon) — hanya tampilkan `is_visible = true`
- Untuk akun parent dengan children: tampilkan total gabungan children
- Tap akun → navigasi ke detail akun / list transaksi per akun

**Transaksi terbaru:**
- 5–10 transaksi terbaru lintas semua akun
- Tap "Lihat Semua" → navigasi ke tab Transaksi

### 5.3 Accounts (Aset)

- List akun, **support nested** (parent-child via `parent_account_id`) — tampilkan sebagai expandable group (contoh: "Bank Jago" sebagai header collapsible, dengan "Main", "Sandang", "Pangan", dst sebagai children)
- Tab "Pribadi" vs "Keluarga" (filter akun berdasarkan apakah akun masuk `group_accounts` atau tidak)
- Saat akun punya children: tampilkan total gabungan di header parent (dihitung dari sum children's balance), parent sendiri `is_include_total = false` — tidak dobel dihitung di dashboard
- Reorder via drag (update `sequence_order` — write lokal dulu, sync ke server)
- Toggle `is_visible` (swipe action atau menu konteks — sembunyikan dari list tanpa hapus data)
- Form tambah/edit akun: pilih `account_type_id`, nama, icon, currency, optional `parent_account_id`
- Konfirmasi sebelum hapus akun yang punya transaksi (soft delete)

### 5.4 Transaksi

- **List transaksi**: grouped by date, infinite scroll (lazy load — jangan load semua ke memory), filter by kategori/tanggal/tipe
- **Form tambah transaksi**:
  - Pilih tipe: Pengeluaran / Pemasukan
  - Pilih akun, kategori, nominal, tanggal, deskripsi
  - **Logic kategori per pemilik akun**: kalau akun yang dipilih adalah shared account (ada di `group_accounts`) dan `current_user` BUKAN owner-nya, dropdown kategori HARUS menampilkan kategori milik **owner akun tersebut**, bukan kategori milik `current_user`. Fetch kategori berdasarkan `account_types.user_id` dari akun terpilih.
  - **Logic default pocket**: kalau user pilih akun parent yang punya children (misal "Bank Jago"), app otomatis arahkan input ke child default (child dengan `sequence_order` terkecil). UI boleh beri highlight ke child pertama, tapi tidak hardcode nama.
- **Tampilan shared account**: tampilkan nama pelaku (`created_by` → `users.full_name`) di setiap item transaksi — gunakan avatar/badge kecil untuk membedakan siapa yang input
- **Edit/hapus transaksi**: konfirmasi dulu (terutama untuk transaksi yang sudah di-sync / dilihat anggota grup lain). Hapus = soft delete + masuk `sync_queue` dengan `operation = DELETE`.

### 5.5 Transfer & Hutang-Piutang

- **Form transfer**: akun asal, akun tujuan, nominal, deskripsi, tanggal
- Di balik layar: `POST /transfers` → server otomatis buat 2 row `transactions`. Client harus lokal-insert kedua transaksi ini juga (bukan tunggu server) untuk konsistensi offline-first.
- **Shortcut "Catat Utang / Piutang"**: tampil di Quick Action Sheet dan form transfer. Toggle antara:
  - "Gw ngutang" — transfer dari akun `Hutang (Gw Ngutang)` ke akun kas, saldo hutang jadi negatif = kewajiban
  - "Gw ngutangin" — transfer dari akun kas ke akun `Hutang (Gw Ngutangin)`, saldo positif = piutang
  - Ini tetap memanggil endpoint `POST /transfers` biasa, bukan endpoint khusus.
- **Privasi di tampilan grup**: saat menampilkan histori transfer ke member grup lain, kalau salah satu akun bukan milik viewer dan tidak ter-share ke grup, render string `"akun pribadi milik {nama}"` apa adanya dari response server — tidak perlu logic sensor tambahan di client.

### 5.6 Budget

- List budget per kategori, dengan **progress bar** (terpakai vs `budget_amounts.amount` yang berlaku di periode berjalan)
- Progress bar warna: hijau (< 75%), kuning (75–99%), merah (>= 100% / over budget)
- Navigator periode: `< September 2026 >` — user bisa maju/mundur bulan/minggu/tahun sesuai `period_type` budget
- Form tambah/edit budget: pilih kategori, nominal, `period_type` (MONTHLY/WEEKLY/DAILY/ANNUAL), `anchor_date` (default = hari ini)
- Tampilan histori budget per periode — ambil dari `GET /budgets/:id/progress?period=` (bukan hitung manual di client)
- Saat user edit nominal budget: backend meng-handle effective-dated row (`budget_amounts`) — client cukup kirim PATCH dengan nominal baru, tidak perlu tau detail implementasi `effective_from`/`effective_to`.

### 5.7 Investasi (Portfolio)

> **Online-required**: semua aksi tulis (BUY/SELL/DIVIDEND, update harga instrumen) WAJIB koneksi internet — tombol/form terkait di-disable dengan pesan jelas ("Butuh koneksi internet untuk mencatat transaksi investasi") kalau device offline. Alasan: `avg_cost_price`/`realized_pl` sensitif urutan transaksi, dan `instrument_prices` adalah data global lintas user yang tidak cocok dengan pola sync offline yang dirancang untuk data personal/grup (detail di PRD backend bagian 3, prinsip #7).
>
> **Tampilan tetap bisa diakses offline (read-only)**: hasil `GET /accounts/:id/holdings` dan `GET /accounts/:id/portfolio-snapshot` di-cache di local storage sederhana (bukan lewat `sync_queue` — cukup simpan response terakhir sebagai JSON). Tampilkan indikator "Data per {waktu terakhir fetch}" agar user tahu ini bukan real-time.

- **Summary portfolio**: total nilai investasi, total unrealized P/L (Rp + %), breakdown per asset class (Saham, Reksadana, Crypto, Emas, Lainnya)
- **List holding** per akun investasi: instrumen, quantity, avg cost, harga terakhir, floating P/L (hijau/merah)
- **Prompt update harga manual**: untuk setiap instrumen yang dipegang, kalau `instrument_prices` untuk tanggal hari ini kosong, tampilkan prompt ringan "Update harga {instrumen} hari ini?" — quick input nominal, bukan form panjang. Kalau harga sudah ada (dari user mana pun, karena `instrument_prices` global), langsung tampilkan P/L tanpa prompt.
- **Form transaksi investasi**: pilih tipe (BUY/SELL/DIVIDEND), instrumen (search/autocomplete ke `GET /instruments`, opsi "Tambah instrumen baru" kalau belum ada), quantity, harga per unit, fee, akun cash sumber/tujuan dana
  - BUY: `cash_account_id` = akun kas yang berkurang
  - SELL/DIVIDEND: `cash_account_id` = akun kas yang bertambah (opsional untuk dividen reinvest)
- **Detail instrumen**: grafik harga dari waktu ke waktu (dari `portfolio_daily_snapshots`), timeframe switch: 1D / 1W / 1M / 3M / 1Y / ALL
- **Histori transaksi** per instrumen (BUY/SELL/DIVIDEND log)

### 5.8 Groups (Household)

- Buat grup baru → generate kode unik, share ke anggota
- Join via kode
- Kelola anggota: lihat list, badge role (OWNER / MEMBER)
- Kelola akun yang di-share ke grup: toggle per akun milik sendiri (opt-in, bukan default semua)
- Kelola kategori grup (`group_categories`) + mapping kategori personal ke kategori grup (opsional per user, beri opsi skip/nanti)
- Laporan agregat per kategori grup: total pengeluaran/pemasukan gabungan semua member yang kategorinya sudah di-mapping — dari `GET /groups/:id/category-report?period=`
- Feed aktivitas shared account: transaksi terbaru di akun bersama, dengan nama & avatar pelaku

### 5.9 Laporan & Analisis

- **Grafik Pemasukan vs Pengeluaran**: bar chart komparasi 6 bulan terakhir (atau custom range)
- **Breakdown kategori**: top N kategori pengeluaran bulan ini — pie chart atau ranked list dengan nominal & persentase
- **Trend net worth**: line chart perubahan total kekayaan dari waktu ke waktu
- **Filter**: per akun atau semua akun, per bulan/kuartal/tahun
- Data diambil dari transaksi lokal (Drift) — konsisten dengan data yang sudah di-sync dari server. Tidak ada kalkulasi independen yang bisa drift dari server.

### 5.10 Settings & More

- **Edit profil**: `user_profiles` — nama, foto, gender, `base_currency`, `theme`
- **Device terdaftar**: lihat list `devices`, opsi logout device lain
- **Status sync**:
  - Terakhir sync kapan (`devices.last_sync_at`)
  - Jumlah item pending di `sync_queue`
  - Jumlah item failed (konflik) + shortcut ke layar resolusi konflik
- **Notifikasi**: list notifikasi in-app (`GET /notifications`), mark as read, navigasi ke entity terkait
- **Keamanan**: toggle biometric lock, ganti password
- **Logout**: revoke refresh token (`POST /auth/logout`), hapus token dari `flutter_secure_storage`, clear cache investasi

## 6. UX untuk Konflik Sync

Saat `sync_queue` item berstatus `FAILED` karena version conflict (server kembalikan 409):

- **Badge indikator**: tampilkan jumlah item konflik di icon sync / settings (persistent, sampai diselesaikan)
- **Layar resolusi konflik**: tampilkan perbandingan versi lokal vs versi server (minimal field yang berbeda), dengan dua pilihan:
  - **"Pakai Punya Saya"** — overwrite server: kirim ulang perubahan lokal dengan `client_version` diupdate ke versi server terbaru
  - **"Pakai Punya Server"** — discard perubahan lokal: replace data lokal dengan data server, hapus item dari `sync_queue`
- **Strategi MVP**: transaksi baru (INSERT) jarang konflik karena UUID unik per item — prioritaskan UX resolusi untuk `accounts` dan `categories` yang lebih sering di-edit secara bersamaan antar device/anggota grup.
- Setelah resolusi, otomatis trigger sync ulang.

## 7. Non-Functional Requirements

- **Precision**: gunakan `int` (sen/poin terkecil) atau `Decimal` dari package `decimal` untuk semua nominal uang di Dart — **jangan pakai `double`**. Untuk `quantity` instrumen investasi, gunakan `Decimal` dengan presisi 8 desimal (crypto). Di Drift, petakan ke `TextColumn` untuk `decimal` arbitrary-precision, atau gunakan `IntColumn` untuk nilai integer sen.
- **Local DB encryption**: data finansial sensitif — pertimbangkan SQLCipher (via `drift_sqflite` + `sqflite_sqlcipher`) untuk enkripsi local DB. Rekomendasi, bukan hard requirement MVP, tapi arsitektur harus memudahkan penambahan ini tanpa refactor besar.
- **Performance**: list transaksi harus tetap responsif untuk histori ribuan row — wajib gunakan pagination/lazy load Drift (`offset`/`limit` atau cursor-based), jangan load semua transaksi ke memory sekaligus.
- **Konsistensi angka dengan backend**: semua nilai "otoritatif" (`accounts.balance`, floating P/L, budget progress) ditampilkan dari data yang sudah di-sync dari server — client tidak hitung ulang secara independen untuk menghindari drift.
- **Error handling & offline UX**:
  - Saat offline: semua fitur non-investasi tetap berfungsi penuh (write lokal, antri di `sync_queue`)
  - Saat aksi investasi dilakukan offline: tampilkan bottom sheet informatif (bukan toast singkat) yang menjelaskan kenapa aksi tidak bisa dilakukan
  - Error jaringan di Dio: retry otomatis untuk idempotent request (`GET`), tapi **jangan** auto-retry `POST/PATCH/DELETE` — masukkan ke `sync_queue` saja
  - Error 401: auto-refresh token. Kalau refresh juga gagal, paksa logout dan arahkan ke login screen dengan pesan "Sesi berakhir, silakan login kembali"
- **Accessibility**: pastikan semua elemen interaktif punya label semantik (`Semantics` widget), kontras warna minimal WCAG AA.

## 8. Out of Scope (Phase 2)

- Integrasi API harga saham/reksadana/crypto otomatis (MVP: manual input)
- Push notification real-time via FCM/WebSocket
- Multi-currency display & konversi otomatis (kolom `base_currency` sudah disiapkan)
- Dark mode detail styling (kolom `theme` di `user_profiles` sudah disiapkan, implementasi UI menyusul)
- Fitur investasi berjalan offline penuh

## 9. Keputusan Final

| Keputusan | Pilihan | Catatan |
|-----------|---------|---------|
| Local DB engine | Drift | Type-safe, reactive streams, cocok offline-first |
| State management | Riverpod + riverpod_generator | StreamProvider untuk Drift, compile-safe |
| HTTP client | Dio | Interceptor JWT, auto-refresh, retry |
| Routing | go_router | Deklaratif, auth guard via redirect |
| Auth token storage | flutter_secure_storage | Tidak di SharedPreferences / local DB |
| Scope sync offline investasi | Online-required | Tidak lewat Drift/sync_queue, cache read-only saja |
| Money precision (Dart) | int (sen) atau Decimal package | Tidak pakai double |
| Code generation | build_runner | Riverpod + Drift + Freezed |

Tidak ada tabel Drift lokal untuk entity investasi — data investasi di-fetch langsung dari API saat online, dengan cache read-only sederhana untuk tampilan offline.
