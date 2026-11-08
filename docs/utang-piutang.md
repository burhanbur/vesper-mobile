# Utang, piutang, dan kartu kredit

- **Utang saya:** saya meminjam uang dan harus mengembalikannya.
- **Piutang saya:** saya meminjamkan uang dan akan menerima pembayaran kembali.
- Catat setiap pinjaman per orang di **Lainnya > Utang & Piutang**. Akun gabungan baru tidak diperlukan.

## Mencatat pinjaman

Pilih jenis, nama orang, jumlah, dan rekening. Untuk utang baru uang masuk ke rekening; untuk piutang baru uang keluar dari rekening. Aktifkan **Pinjaman lama** jika uang sudah berpindah sebelumnya: saldo rekening tidak digerakkan lagi. Jika sudah ada akun pinjaman lama, hubungkan akun tersebut agar tidak dihitung dua kali. Saldo lama harus negatif untuk utang, positif untuk piutang, dan sama dengan sisa pokok.

Gunakan **Bayar / cicil** atau **Terima pembayaran** pada catatan pinjaman. Isi bagian pokok yang dikembalikan. Bunga dan biaya tersedia melalui pilihan tambahan dan memakai kategori masing-masing. Pokok tidak masuk laporan pemasukan/pengeluaran; bunga dan biaya dicatat terpisah.

Jatuh tempo opsional. Editor jadwal cicilan teks mentah sudah dihapus dari formulir; jadwal lama dan riwayat tetap tersimpan. Mobile menyimpan perubahan ke database lokal dan antrean sync terlebih dahulu.

## Kartu kredit

Buka **Akun > Tambah > Kartu kredit**, isi nama dan limit. Nominal otomatis memakai format Rupiah; limit sembilan juta tampil sebagai **Rp 9.000.000**. Kartu mulai dengan tagihan nol. Limit bukan saldo uang dan tidak menambah kekayaan.

Belanja dicatat sebagai pengeluaran dengan akun kartu. Pembayaran tagihan dicatat sebagai transfer dari rekening ke kartu, sehingga belanja tidak dihitung dua kali. Pencatatan tidak membayar bank secara otomatis. Tagihan awal kartu lama belum dapat diisi melalui form pembuatan; jangan memasukkan limit sebagai saldo awal.

## Kompatibilitas

Tidak ada perubahan skema atau penghapusan data pengguna. Jenis gabungan lama tetap dapat dibaca dan dihubungkan; label saldo membedakan utang, piutang, dan lunas. Rilis backend dengan dukungan metadata kartu dan endpoint pinjaman sebelum memperbarui klien. Panduan web: halaman **Utang & Piutang** pada menu utama.

## Koreksi akun yang salah

Kartu selalu ditampilkan sebagai **Kartu Kredit**, meskipun metadata penyimpanannya memakai kategori kas. Buka pengaturan akun untuk mengubah nama atau menghapus akun kosong. Jenis kartu dapat dikoreksi sebelum ada riwayat transaksi, dengan saldo nol, tanpa sharing atau kantong. Setelah ada riwayat, jenis dikunci agar aturan transaksi tidak berubah; nama dan limit tetap dapat diubah. Akun bersaldo atau bertransaksi aktif tidak dihapus sekaligus: koreksi transaksi yang salah terlebih dahulu. Penghapusan akun tersinkronisasi memakai tombstone.
