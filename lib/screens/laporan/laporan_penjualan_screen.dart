import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kasir_pro/database/database_helper.dart';

// Tipe data baru untuk hasil laporan agar lebih aman
class LaporanResult {
  final List<Map<String, dynamic>> data;
  final double totalPenjualan;
  final double totalTunai;
  final double totalTransfer;

  LaporanResult({
    required this.data,
    required this.totalPenjualan,
    required this.totalTunai,
    required this.totalTransfer,
  });
}

class LaporanPenjualanScreen extends StatefulWidget {
  const LaporanPenjualanScreen({super.key});

  @override
  State<LaporanPenjualanScreen> createState() => _LaporanPenjualanScreenState();
}

class _LaporanPenjualanScreenState extends State<LaporanPenjualanScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  
  // Menggunakan Future untuk dikelola oleh FutureBuilder
  Future<LaporanResult>? _laporanFuture;
  
  DateTime _tanggalAwal = DateTime.now();
  DateTime _tanggalAkhir = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Memanggil fetch laporan saat halaman pertama kali dibuka
    _laporanFuture = _fetchLaporan();
  }

  // Fungsi ini sekarang mengembalikan data, bukan mengatur state
  Future<LaporanResult> _fetchLaporan() async {
    try {
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

      // Mengembalikan semua hasil dalam satu objek
      return LaporanResult(
        data: data,
        totalPenjualan: total,
        totalTunai: tunai,
        totalTransfer: transfer,
      );
    } catch (e) {
      // Jika error, lemparkan lagi agar ditangkap oleh FutureBuilder
      throw Exception('Gagal memuat laporan: $e');
    }
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
        // Memuat ulang data dengan memanggil _fetchLaporan lagi
        _laporanFuture = _fetchLaporan();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Penjualan')),
      body: Column(
        children: [
          _buildFilterSection(),
          // Menggunakan FutureBuilder untuk menangani semua state (loading, error, data)
          Expanded(
            child: FutureBuilder<LaporanResult>(
              future: _laporanFuture,
              builder: (context, snapshot) {
                // 1. Saat sedang loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 2. Jika terjadi error
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }

                // 3. Jika data berhasil didapat
                if (snapshot.hasData) {
                  final result = snapshot.data!;
                  return Column(
                    children: [
                      _buildSummarySection(result),
                      const Divider(thickness: 2),
                      Expanded(
                        child: result.data.isEmpty
                            ? const Center(child: Text('Tidak ada data untuk rentang tanggal ini.'))
                            : _buildReportList(result.data),
                      ),
                    ],
                  );
                }

                // State default jika tidak ada apa-apa
                return const Center(child: Text('Silakan pilih rentang tanggal.'));
              },
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

  Widget _buildSummarySection(LaporanResult result) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildSummaryRow('Total Penjualan:', currencyFormat.format(result.totalPenjualan), isHeader: true),
              const Divider(),
              _buildSummaryRow('Total Tunai:', currencyFormat.format(result.totalTunai)),
              _buildSummaryRow('Total Transfer:', currencyFormat.format(result.totalTransfer)),
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

  Widget _buildReportList(List<Map<String, dynamic>> data) {
    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        final row = data[index];
        final timestamp = DateTime.tryParse(row['timestamp'].toString()) ?? DateTime.now();
        final currencyFormat = NumberFormat.currency(locale: 'id_ID', decimalDigits: 0, symbol: 'Rp');
        final harga = (row['harga_item'] as num?)?.toDouble() ?? 0.0;
        final jumlah = (row['jumlah'] as num?)?.toInt() ?? 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Text("ID:${row['transaksi_id']}"),
            title: Text(row['nama_produk'].toString()),
            subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(timestamp)),
            trailing: Text(
              currencyFormat.format(harga * jumlah),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}
