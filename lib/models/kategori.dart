// lib/models/kategori.dart
class Kategori {
  final int? id;
  final String nama;

  Kategori({this.id, required this.nama});

  Map<String, dynamic> toMap() {
    return {'id': id, 'nama': nama};
  }

  factory Kategori.fromMap(Map<String, dynamic> map) {
    return Kategori(id: map['id'], nama: map['nama']);
  }
}

