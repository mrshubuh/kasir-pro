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
    setState(() => _isLoading = true);

    final tglAwal = DateTime(_tanggalAwal.year, _tanggalAwal.month, _tanggalAwal.day, 0, 0, 0);
    final tglAkhir = DateTime(_tanggalAkhir.year, _tanggalAkhir.month, _tanggalAkhir.day, 23, 59, 59);
    
    final tglAwalIso = tglAwal.toIso8601String();
    final tglAkhirIso = tglAkhir.toIso8601String();
    
    final data = await _db.getLaporan(tglAwalIso, tglAkhirIso);

    double total = 0;
    double tunai = 0;
    double transfer = 0;
    
    final Set<int> processedTxIds = {};

    for (var row in data) {
      final int transaksiId = row['transaksi_id'];
      if (!processedTxIds.contains(transaksiId)) {
        final double txTotal = row['total'];
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
      _isLoading = false;
    });
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
          // --- BAGIAN YANG DIPERBAIKI ---
          // Mengganti SingleChildScrollView dengan widget yang benar untuk tabel
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _laporanData.isEmpty
                    ? const Center(child: Text('Tidak ada data untuk rentang tanggal ini.'))
                    : InteractiveViewer( // Membuat tabel bisa di-zoom dan di-geser
                        constrained: false,
                        scaleEnabled: false,
                        child: _buildDataTable(),
                      ),
          ),
        ],
      ),
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

  Widget _buildDataTable() {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', decimalDigits: 0, symbol: 'Rp');
    return DataTable(
      columnSpacing: 20,
      columns: const [
        DataColumn(label: Text('Waktu')),
        DataColumn(label: Text('ID Trans.')),
        DataColumn(label: Text('Item')),
        DataColumn(label: Text('Kategori')),
        DataColumn(label: Text('Qty')),
        DataColumn(label: Text('Harga Item')),
        DataColumn(label: Text('Total Trans.')),
        DataColumn(label: Text('Metode')),
      ],
      rows: _laporanData.map((row) {
        final timestamp = DateTime.parse(row['timestamp']);
        return DataRow(cells: [
          DataCell(Text(DateFormat('dd-MM-yy HH:mm').format(timestamp))),
          DataCell(Text(row['transaksi_id'].toString())),
          DataCell(Text(row['nama_produk'].toString())),
          DataCell(Text(row['nama_kategori']?.toString() ?? (row['is_quick_sale'] == 1 ? 'Quick Sale' : '-'))),
          DataCell(Text(row['jumlah'].toString())),
          DataCell(Text(currencyFormat.format(row['harga_item']))),
          DataCell(Text(currencyFormat.format(row['total']))),
          DataCell(Text(row['metode_pembayaran'].toString())),
        ]);
      }).toList(),
    );
  }
}
