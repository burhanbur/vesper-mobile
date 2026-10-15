class LocalDataFailure implements Exception {
  const LocalDataFailure();

  @override
  String toString() =>
      'Data lokal belum dapat dibuka. Data dan antrean tetap disimpan. Coba lagi setelah membuka kunci perangkat. Jika tetap gagal, hubungi dukungan; jangan hapus data atau instal ulang aplikasi.';
}
