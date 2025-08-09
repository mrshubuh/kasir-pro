import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kasir_pro/database/database_helper.dart';
import 'package:kasir_pro/models/kategori.dart';
import 'package:kasir_pro/models/produk.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';


class StokOpnameScreen extends StatefulWidget {
  const StokOpnameScreen({super.key});

  @override
  State<StokOpnameScreen> createState() => _StokOpnameScreenState();
}

class _StokOpnameScreenState extends State<StokOpnameScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Produk> _produkList = [];
  List<Kategori> _kategoriList = [];
  bool _isLoading = true;

  final _namaController = TextEditingController();
  final _hargaController = TextEditingController();
  final _stokController = TextEditingController();
  int? _selectedKategoriId;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() async {
    setState(() => _isLoading = true);
    final produk = await _db.getProduk();
    final kategori = await _db.getKategori();
    setState(() {
      _produkList = produk.map((e) => Produk.fromMap(e)).toList();
      _kategoriList = kategori.map((e) => Kategori.fromMap(e)).toList();
      _isLoading = false;
    });
  }

  void _showForm([Produk? produk]) {
    if (produk != null) {
      _namaController.text = produk.nama;
      _hargaController.text = produk.harga.toStringAsFixed(0);
      _stokController.text = produk.stok.toString();
      _selectedKategoriId = produk.kategoriId;
    } else {
      _namaController.clear();
      _hargaController.clear();
      _stokController.clear();
      _selectedKategoriId = null;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(produk == null ? 'Tambah Produk Baru' : 'Edit Produk'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _namaController, decoration: const InputDecoration(labelText: 'Nama Produk', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _hargaController, decoration: const InputDecoration(labelText: 'Harga', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(controller: _stokController, decoration: const InputDecoration(labelText: 'Stok Awal', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: _selectedKategoriId,
                hint: const Text('Pilih Kategori'),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _kategoriList.map((kategori) {
                  return DropdownMenuItem<int>(value: kategori.id, child: Text(kategori.nama));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedKategoriId = value;
                  });
                },
              )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              _simpanProduk(produk?.id);
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
  
  void _showKategoriDialog() {
    final kategoriController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kelola Kategori'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: kategoriController, decoration: const InputDecoration(labelText: 'Nama Kategori Baru', border: OutlineInputBorder())),
              const SizedBox(height: 20),
              const Text('Daftar Kategori', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: _kategoriList.isEmpty 
                ? const Center(child: Text('Belum ada kategori.'))
                : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _kategoriList.length,
                  itemBuilder: (context, index) {
                    final kategori = _kategoriList[index];
                    return ListTile(
                      title: Text(kategori.nama),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          await _db.deleteKategori(kategori.id!);
                          Navigator.pop(context); // close current dialog
                          _refreshData();
                          _showKategoriDialog(); // reopen dialog to reflect changes
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
          FilledButton(
            onPressed: () async {
              if (kategoriController.text.isNotEmpty) {
                await _db.insertKategori({'nama': kategoriController.text});
                Navigator.pop(context);
                _refreshData();
                _showKategoriDialog();
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _simpanProduk(int? id) async {
    final nama = _namaController.text;
    final harga = double.tryParse(_hargaController.text) ?? 0;
    final stok = int.tryParse(_stokController.text) ?? 0;

    if (nama.isNotEmpty && harga > 0) {
      final produk = Produk(id: id, nama: nama, harga: harga, stok: stok, kategoriId: _selectedKategoriId);
      if (id == null) {
        await _db.insertProduk(produk.toMap());
      } else {
        await _db.updateProduk(produk.toMap());
      }
      _refreshData();
    }
  }
  
  void _updateStok(Produk produk, int amount) async {
    final newStok = produk.stok + amount;
    final updatedProduk = Produk(
      id: produk.id,
      nama: produk.nama,
      harga: produk.harga,
      stok: newStok < 0 ? 0 : newStok, // Mencegah stok negatif
      kategoriId: produk.kategoriId
    );
    await _db.updateProduk(updatedProduk.toMap());
    _refreshData();
  }

  Future<void> _exportToCsv() async {
    try {
      List<List<dynamic>> rows = [];
      // Header CSV
      rows.add(["id_produk", "nama_produk", "harga", "stok", "id_kategori"]); 
      for (var produk in _produkList) {
        rows.add([produk.id, produk.nama, produk.harga, produk.stok, produk.kategoriId ?? '']);
      }

      String csvData = const ListToCsvConverter().convert(rows);

      final directory = await getApplicationDocumentsDirectory();
      final time = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final path = "${directory.path}/stok_produk_$time.csv";
      final file = File(path);
      await file.writeAsString(csvData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data berhasil diekspor ke: $path')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ekspor CSV: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _importFromCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final path = result.files.single.path;
        if (path == null) return;
        final file = File(path);
        final csvString = await file.readAsString();
        // Menggunakan CsvToListConverter dengan eol (end of line) yang lebih fleksibel
        final List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(csvString);

        if (rows.length < 2) {
          throw Exception('File CSV kosong atau hanya berisi header.');
        }

        int successCount = 0;
        // Mulai dari baris kedua (index 1) untuk mengabaikan header
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          // Validasi jumlah kolom
          if (row.length < 5) continue; 
          
          final produk = {
            'nama': row[1].toString(),
            'harga': double.tryParse(row[2].toString()) ?? 0,
            'stok': int.tryParse(row[3].toString()) ?? 0,
            'kategori_id': int.tryParse(row[4].toString()),
          };
          await _db.insertProduk(produk);
          successCount++;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import berhasil: $successCount produk ditambahkan.'), backgroundColor: Colors.green),
        );
        _refreshData();
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal import CSV: $e'), backgroundColor: Colors.red),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Stok & Produk'),
        actions: [
          TextButton(onPressed: _importFromCsv, child: const Text('Import CSV', style: TextStyle(color: Colors.white))),
          TextButton(onPressed: _exportToCsv, child: const Text('Export CSV', style: TextStyle(color: Colors.white))),
          TextButton(onPressed: _showKategoriDialog, child: const Text('Kelola Kategori', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _produkList.isEmpty 
          ? const Center(child: Text('Tidak ada produk. Silakan tambah produk baru.'))
          : ListView.builder(
              itemCount: _produkList.length,
              itemBuilder: (context, index) {
                final produk = _produkList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    title: Text(produk.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(produk.harga)),
                    trailing: SizedBox(
                      width: 250,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(icon: const Icon(Icons.remove), onPressed: () => _updateStok(produk, -1)),
                          Text(produk.stok.toString(), style: Theme.of(context).textTheme.titleMedium),
                          IconButton(icon: const Icon(Icons.add), onPressed: () => _updateStok(produk, 1)),
                          const VerticalDivider(),
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showForm(produk)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              await _db.deleteProduk(produk.id!);
                              _refreshData();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
        tooltip: 'Tambah Produk Baru',
      ),
    );
  }
}
