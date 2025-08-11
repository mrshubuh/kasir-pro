import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kasir_pro/database/database_helper.dart';
import 'package:kasir_pro/models/kategori.dart';
import 'package:kasir_pro/models/produk.dart';
import 'package:kasir_pro/models/transaksi.dart';
import 'package:kasir_pro/utils/printer_service.dart';

class TransaksiScreen extends StatefulWidget {
  const TransaksiScreen({super.key});

  @override
  State<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends State<TransaksiScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final PrinterService _printer = PrinterService();
  
  List<Kategori> _kategoriList = [];
  List<Produk> _produkList = [];
  final List<ItemKeranjang> _keranjang = [];
  Map<String, String> _pengaturan = {};

  Kategori? _selectedKategori;
  double _total = 0;
  bool _isLoading = true;

  final TextEditingController _bayarController = TextEditingController();
  final TextEditingController _diskonController = TextEditingController(text: '0');
  final TextEditingController _pajakController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final pengaturan = await _db.getPengaturan();
      final kategori = await _db.getKategori();
      final produk = await _db.getProduk();
      setState(() {
        _pengaturan = pengaturan;
        _diskonController.text = pengaturan['diskon_default'] ?? '0';
        _pajakController.text = pengaturan['pajak_default'] ?? '0';
        _kategoriList = kategori.map((e) => Kategori.fromMap(e)).toList();
        _produkList = produk.map((e) => Produk.fromMap(e)).toList();
      });
    } catch (e) {
      _showErrorSnackbar("Gagal memuat data awal: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterProdukByKategori(Kategori? kategori) async {
    setState(() {
      _selectedKategori = kategori;
      _isLoading = true;
    });
    final produk = await _db.getProduk(kategoriId: kategori?.id);
    setState(() {
      _produkList = produk.map((e) => Produk.fromMap(e)).toList();
      _isLoading = false;
    });
  }

  void _tambahKeKeranjang(Produk produk) {
    bool izinkanStokKosong = (_pengaturan['izinkan_stok_kosong'] ?? 'false') == 'true';
    if (!izinkanStokKosong && produk.stok <= 0) {
      _showErrorSnackbar('Stok produk habis!');
      return;
    }

    setState(() {
      final index = _keranjang.indexWhere((item) => item.produkId == produk.id);
      if (index != -1) {
        if (!izinkanStokKosong && _keranjang[index].jumlah >= produk.stok) {
           _showErrorSnackbar('Stok tidak mencukupi!');
        } else {
          _keranjang[index].jumlah++;
        }
      } else {
        _keranjang.add(ItemKeranjang(
          produkId: produk.id,
          namaProduk: produk.nama,
          harga: produk.harga,
          stokTersedia: produk.stok,
        ));
      }
      _hitungTotal();
    });
  }

  void _quickSale() {
    final namaController = TextEditingController();
    final hargaController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Sale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: namaController, decoration: const InputDecoration(labelText: 'Nama Item', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: hargaController, decoration: const InputDecoration(labelText: 'Harga', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              final nama = namaController.text;
              final harga = double.tryParse(hargaController.text) ?? 0;
              if (nama.isNotEmpty && harga > 0) {
                setState(() {
                  _keranjang.add(ItemKeranjang(namaProduk: nama, harga: harga, isQuickSale: true));
                  _hitungTotal();
                });
                Navigator.pop(context);
              } else {
                _showErrorSnackbar('Nama dan harga harus diisi.');
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _hitungTotal() {
    double subtotal = _keranjang.fold(0, (sum, item) => sum + (item.harga * item.jumlah));
    double diskon = double.tryParse(_diskonController.text) ?? 0;
    double pajakPercent = double.tryParse(_pajakController.text) ?? 0;
    
    double nilaiPajak = (subtotal - diskon) * (pajakPercent / 100);
    if (nilaiPajak < 0) nilaiPajak = 0;

    setState(() {
      _total = subtotal - diskon + nilaiPajak;
    });
  }

  void _showDialogPembayaran() {
    if (_keranjang.isEmpty) {
      _showErrorSnackbar('Keranjang masih kosong.');
      return;
    }
    _bayarController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        double kembalian = 0;
        String metodePembayaran = 'Tunai';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void hitungKembalian() {
              final bayar = double.tryParse(_bayarController.text) ?? 0;
              setDialogState(() {
                kembalian = bayar - _total;
              });
            }

            return AlertDialog(
              title: const Text('Proses Pembayaran'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Belanja: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(_total)}', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: metodePembayaran,
                      decoration: const InputDecoration(labelText: 'Metode Pembayaran', border: OutlineInputBorder()),
                      items: ['Tunai', 'Transfer'].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          metodePembayaran = newValue!;
                           if (metodePembayaran == 'Transfer') {
                            _bayarController.text = _total.toStringAsFixed(0);
                          }
                          hitungKembalian();
                        });
                      },
                    ),
                    if (metodePembayaran == 'Tunai') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _bayarController,
                        decoration: const InputDecoration(labelText: 'Jumlah Bayar', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => hitungKembalian(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Kembalian: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(kembalian < 0 ? 0 : kembalian)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                FilledButton(
                  onPressed: () {
                    final bayar = double.tryParse(_bayarController.text) ?? 0;
                    if (metodePembayaran == 'Transfer' || (metodePembayaran == 'Tunai' && bayar >= _total)) {
                      _simpanTransaksi(metodePembayaran, bayar);
                      Navigator.pop(context);
                    } else {
                       _showErrorSnackbar('Jumlah bayar kurang!');
                    }
                  },
                  child: const Text('Selesaikan & Cetak'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _simpanTransaksi(String metodePembayaran, double bayar) async {
    final transaksiData = {
      'timestamp': DateTime.now().toIso8601String(),
      'total': _total,
      'metode_pembayaran': metodePembayaran,
      'diskon': double.tryParse(_diskonController.text) ?? 0,
      'pajak': double.tryParse(_pajakController.text) ?? 0,
    };

    final itemsData = _keranjang.map((item) => item.toMapForDb()).toList();

    try {
      final transaksiId = await _db.simpanTransaksi(transaksiData, itemsData);
      _showSuccessSnackbar('Transaksi berhasil disimpan');

      // --- BAGIAN YANG DIPERBAIKI ---
      // Sekarang mengirim seluruh map pengaturan ke fungsi cetak
      await _printer.cetakStruk(
        infoToko: _pengaturan,
        transaksiId: transaksiId,
        total: _total,
        diskon: double.tryParse(_diskonController.text) ?? 0,
        pajak: double.tryParse(_pajakController.text) ?? 0,
        bayar: bayar,
        metodePembayaran: metodePembayaran,
        items: _keranjang,
      );
      
      setState(() {
        _keranjang.clear();
        _hitungTotal();
      });
      _loadInitialData();
    } catch (e) {
      _showErrorSnackbar('Gagal menyimpan atau mencetak: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (Sisa kode UI tidak berubah, biarkan seperti sebelumnya) ...
    return Scaffold(
      appBar: AppBar(title: const Text('Mesin Kasir')),
      body: Row(
        children: [
          // Kolom Kiri: Daftar Produk
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildKategoriFilter(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _produkList.isEmpty
                          ? const Center(child: Text('Tidak ada produk. Silakan tambah di menu Stok Opname.'))
                          : GridView.builder(
                              padding: const EdgeInsets.all(8),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 160,
                                childAspectRatio: 3 / 2.8,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: _produkList.length,
                              itemBuilder: (context, index) {
                                final produk = _produkList[index];
                                return Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () => _tambahKeKeranjang(produk),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(produk.nama, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          const Spacer(),
                                          Text(NumberFormat.currency(locale: 'id_ID', decimalDigits: 0, symbol: 'Rp').format(produk.harga)),
                                          Text('Stok: ${produk.stok}', style: TextStyle(color: produk.stok > 5 ? Colors.green.shade700 : Colors.orange.shade700, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          // Kolom Kanan: Keranjang Belanja
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Keranjang', style: Theme.of(context).textTheme.headlineSmall),
                  const Divider(),
                  Expanded(
                    child: _keranjang.isEmpty
                        ? const Center(child: Text('Keranjang kosong'))
                        : ListView.builder(
                            itemCount: _keranjang.length,
                            itemBuilder: (context, index) {
                              final item = _keranjang[index];
                              return ListTile(
                                title: Text(item.namaProduk),
                                subtitle: Text('${item.jumlah} x ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(item.harga)}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () {
                                        setState(() {
                                          if (item.jumlah > 1) {
                                            item.jumlah--;
                                          } else {
                                            _keranjang.removeAt(index);
                                          }
                                          _hitungTotal();
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () {
                                        bool izinkanStokKosong = (_pengaturan['izinkan_stok_kosong'] ?? 'false') == 'true';
                                        if (!izinkanStokKosong && !item.isQuickSale && item.jumlah >= item.stokTersedia) {
                                          _showErrorSnackbar('Stok tidak mencukupi!');
                                        } else {
                                          setState(() {
                                            item.jumlah++;
                                            _hitungTotal();
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(),
                  _buildTotalSection(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _quickSale,
                          child: const Text('Quick Sale'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _showDialogPembayaran,
                          child: const Text('Bayar'),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildKategoriFilter() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('Semua'),
              selected: _selectedKategori == null,
              onSelected: (selected) {
                if (selected) _filterProdukByKategori(null);
              },
            ),
            const SizedBox(width: 8),
            ..._kategoriList.map((k) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(k.nama),
                    selected: _selectedKategori?.id == k.id,
                    onSelected: (selected) {
                      if (selected) _filterProdukByKategori(k);
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSection() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Text('Diskon (Rp)')),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _diskonController,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true, prefixText: 'Rp '),
                onChanged: (_) => _hitungTotal(),
              ),
            )
          ],
        ),
        Row(
          children: [
            const Expanded(child: Text('Pajak (%)')),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _pajakController,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true, suffixText: '%'),
                onChanged: (_) => _hitungTotal(),
              ),
            )
          ],
        ),
        const Divider(height: 20),
        DefaultTextStyle(
          style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total'),
              Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(_total)),
            ],
          ),
        ),
      ],
    );
  }
}
