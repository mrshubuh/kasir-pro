class ItemKeranjang {
  final int? produkId;
  String namaProduk;
  double harga;
  int jumlah;
  final bool isQuickSale;
  final int stokTersedia;

  ItemKeranjang({
    this.produkId,
    required this.namaProduk,
    required this.harga,
    this.jumlah = 1,
    this.isQuickSale = false,
    this.stokTersedia = 0,
  });

  Map<String, dynamic> toMapForDb() {
    return {
      'produk_id': produkId,
      'nama_produk': namaProduk,
      'harga': harga,
      'jumlah': jumlah,
      'is_quick_sale': isQuickSale ? 1 : 0,
    };
  }
}