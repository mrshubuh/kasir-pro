class Produk {
  final int? id;
  final String nama;
  final double harga;
  final int stok;
  final int? kategoriId;

  Produk({this.id, required this.nama, required this.harga, required this.stok, this.kategoriId});

  Map<String, dynamic> toMap() {
    return {'id': id, 'nama': nama, 'harga': harga, 'stok': stok, 'kategori_id': kategoriId};
  }

  factory Produk.fromMap(Map<String, dynamic> map) {
    return Produk(
      id: map['id'],
      nama: map['nama'],
      harga: map['harga']?.toDouble() ?? 0.0,
      stok: map['stok']?.toInt() ?? 0,
      kategoriId: map['kategori_id'],
    );
  }
}