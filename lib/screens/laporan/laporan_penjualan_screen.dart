import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kasir_pro/database/database_helper.dart';

class LaporanPenjualanScreen extends StatefulWidget {
  const LaporanPenjualanScreen({super.key});

  @override
  State<LaporanPenjualanScreen> createState() => _LaporanPenjualanScreenState();
}

class _LaporanPenjualanScreenState extends State<LaporanPenjualanScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Map<String, dynamic>> _laporanData = [];
  DateTime _tanggalAwal = DateTime.now();
  DateTime _tanggalAkhir = DateTime.now();

  double _totalPenjualan = 0;
  double _totalTunai = 0;
  double _totalTransfer = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLaporan();
  }

  Future<void> _pilihTanggal(BuildContext context, bool isAwal) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isAwal ? _tanggalAwal : _tanggalAkhir,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isAwal) {
          _tanggalAwal = picked;
        } else {
          _tanggalAkhir = picked;
        }
      });
      _fetchLaporan();
    }
  }

  void _fetchLaporan() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // ---!!!--- TES DIAGNOSTIK ---!!!---
      // Menunggu 2 detik untuk simulasi loading, lalu menyediakan data palsu.
      // Panggilan ke database dinonaktifkan sementara.
      await Future.delayed(const Duration(seconds: 2));

      final List<Map<String, dynamic>> fakeData = [
        {
          'transaksi_id': 101,
          'timestamp': DateTime.now().toIso8601String(),
          'total': 50000.0,
          'metode_pembayaran': 'Tunai',
          'nama_produk': 'Produk Tes 1 (Data Palsu)',
          'harga_item': 25000.0,
          'jumlah': 2,
        },
        {
          'transaksi_id': 102,
          'timestamp': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          'total': 30000.0,
          'metode_pembayaran': 'Transfer',
          'nama_produk': 'Produk Tes 2 (Data Palsu)',
          'harga_item': 30000.0,
          'jumlah': 1,
        },
      ];
      
      final data = fakeData; // Menggunakan data palsu
      // final data = await _db.getLaporan(tglAwalIso, tglAkhirIso); // Panggilan asli dinonaktifkan
      // ---!!!--- AKHIR DARI TES DIAGNOSTIK ---!!!---


      double total = 0;
      double tunai = 0;
      double transfer = 0;
      
      final Set<int> processedTxIds = {};

      for (var row in data) {
        final int transaksiId = row['transaksi_id'];
        if (!processedTxIds.contains(transaksiId)) {
          final double txTotal = (row['total'] as num?)?.toDouble() ?? 0.0;
          total += txTotal;
          if (row['metode_pembayaran'] == 'Tunai') {
              tunai += txTotal;
          } else if (row['metode_pembayaran'] == 'Transfer') {
              transfer += txTotal;
          }
          processedTxIds.add(transaksiId);
        }
      }

      setState(() {
        _laporanData = data;
        _totalPenjualan = total;
        _totalTunai = tunai;
        _totalTransfer = transfer;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Terjadi kesalahan: ${e.toString()}";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Penjualan')),
      body: Column(
        children: [
          _buildFilterSection(),
          _buildSummarySection(),
          const Divider(thickness: 2),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_laporanData.isEmpty) {
      return const Center(child: Text('Tidak ada data untuk rentang tanggal ini.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _laporanData.length,
      itemBuilder: (context, index) {
        final row = _laporanData[index];
        final timestamp = DateTime.tryParse(row['timestamp'].toString()) ?? DateTime.now();
        final currencyFormat = NumberFormat.currency(locale: 'id_ID', decimalDigits: 0, symbol: 'Rp');
        final harga = (row['harga_item'] as num?)?.toDouble() ?? 0.0;
        final jumlah = (row['jumlah'] as num?)?.toInt() ?? 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(row['transaksi_id'].toString()),
            ),
            title: Text(row['nama_produk'].toString()),
            subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(timestamp)),
            trailing: Text(
              currencyFormat.format(harga * jumlah),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterSection() {
    final DateFormat formatter = DateFormat('dd MMMM yyyy', 'id_ID');
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(onPressed: () => _pilihTanggal(context, true), child: Text('Dari: ${formatter.format(_tanggalAwal)}')),
          const SizedBox(width: 20),
          TextButton(onPressed: () => _pilihTanggal(context, false), child: Text('Sampai: ${formatter.format(_tanggalAkhir)}')),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildSummaryRow('Total Penjualan:', currencyFormat.format(_totalPenjualan), isHeader: true),
              const Divider(),
              _buildSummaryRow('Total Tunai:', currencyFormat.format(_totalTunai)),
              _buildSummaryRow('Total Transfer:', currencyFormat.format(_totalTransfer)),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSummaryRow(String title, String value, {bool isHeader = false}) {
      final style = isHeader 
          ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
          : Theme.of(context).textTheme.titleMedium;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: style),
            Text(value, style: style),
          ],
        ),
      );
  }
}
