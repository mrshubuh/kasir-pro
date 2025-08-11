import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kasir_pro/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

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
        _errorMessage = null; // Reset error saat tanggal berubah
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
      // Debug print untuk memastikan tanggal benar
      print('Mengambil laporan dari ${_tanggalAwal} sampai ${_tanggalAkhir}');
      
      final tglAwal = DateTime(_tanggalAwal.year, _tanggalAwal.month, _tanggalAwal.day, 0, 0, 0);
      final tglAkhir = DateTime(_tanggalAkhir.year, _tanggalAkhir.month, _tanggalAkhir.day, 23, 59, 59);
      
      final tglAwalIso = tglAwal.toIso8601String();
      final tglAkhirIso = tglAkhir.toIso8601String();
      
      print('ISO dates: $tglAwalIso to $tglAkhirIso');
      
      // Test database connection terlebih dahulu
      final db = await _db.database;
      print('Database connected: ${db.path}');
      
      // Cek apakah ada transaksi di database sama sekali
      final allTransactions = await db.query('transaksi', limit: 5);
      print('Total transaksi di database: ${allTransactions.length}');
      if (allTransactions.isNotEmpty) {
        print('Sample transaksi: ${allTransactions.first}');
      }
      
      final data = await _db.getLaporan(tglAwalIso, tglAkhirIso);
      print('Data diterima: ${data.length} rows');
      
      if (data.isNotEmpty) {
        print('Sample data: ${data.first}');
      }

      double total = 0;
      double tunai = 0;
      double transfer = 0;
      
      final Set<int> processedTxIds = {};

      for (var row in data) {
        print('Processing row: $row'); // Debug setiap row
        final int transaksiId = row['transaksi_id'] ?? 0;
        if (!processedTxIds.contains(transaksiId)) {
          final double txTotal = (row['total'] as num?)?.toDouble() ?? 0.0;
          total += txTotal;
          
          final metodePembayaran = row['metode_pembayaran']?.toString() ?? '';
          if (metodePembayaran == 'Tunai') {
            tunai += txTotal;
          } else if (metodePembayaran == 'Transfer') {
            transfer += txTotal;
          }
          processedTxIds.add(transaksiId);
        }
      }

      print('Totals calculated - Total: $total, Tunai: $tunai, Transfer: $transfer');

      setState(() {
        _laporanData = data;
        _totalPenjualan = total;
        _totalTunai = tunai;
        _totalTransfer = transfer;
      });
    } catch (e, stackTrace) {
      print('Error fetching laporan: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Gagal memuat laporan: $e';
        _laporanData = [];
        _totalPenjualan = 0;
        _totalTunai = 0;
        _totalTransfer = 0;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal memuat laporan: $e"), 
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addDummyData() async {
    try {
      final db = await _db.database;
      
      // Tambahkan kategori dummy jika belum ada
      await db.insert('kategori', {'nama': 'Makanan'}, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('kategori', {'nama': 'Minuman'}, conflictAlgorithm: ConflictAlgorithm.ignore);
      
      // Tambahkan produk dummy
      await db.insert('produk', {
        'nama': 'Nasi Goreng',
        'harga': 15000,
        'stok': 50,
        'kategori_id': 1
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      
      await db.insert('produk', {
        'nama': 'Es Teh',
        'harga': 5000,
        'stok': 100,
        'kategori_id': 2
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      // Tambahkan transaksi dummy untuk hari ini
      final now = DateTime.now();
      final transaksi1 = {
        'timestamp': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'total': 20000.0,
        'metode_pembayaran': 'Tunai',
        'diskon': 0.0,
        'pajak': 0.0,
      };

      final transaksi2 = {
        'timestamp': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'total': 15000.0,
        'metode_pembayaran': 'Transfer',
        'diskon': 0.0,
        'pajak': 0.0,
      };

      final txId1 = await db.insert('transaksi', transaksi1);
      final txId2 = await db.insert('transaksi', transaksi2);

      // Tambahkan item transaksi
      await db.insert('item_transaksi', {
        'transaksi_id': txId1,
        'produk_id': 1,
        'nama_produk': 'Nasi Goreng',
        'harga': 15000.0,
        'jumlah': 1,
        'is_quick_sale': 0,
      });

      await db.insert('item_transaksi', {
        'transaksi_id': txId1,
        'produk_id': 2,
        'nama_produk': 'Es Teh',
        'harga': 5000.0,
        'jumlah': 1,
        'is_quick_sale': 0,
      });

      await db.insert('item_transaksi', {
        'transaksi_id': txId2,
        'produk_id': 1,
        'nama_produk': 'Nasi Goreng',
        'harga': 15000.0,
        'jumlah': 1,
        'is_quick_sale': 0,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data dummy berhasil ditambahkan!'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh data
      _fetchLaporan();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menambah data dummy: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLaporan,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuat data...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchLaporan,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_laporanData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Tidak ada data penjualan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'untuk rentang tanggal ${DateFormat('dd MMM yyyy').format(_tanggalAwal)} - ${DateFormat('dd MMM yyyy').format(_tanggalAkhir)}',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addDummyData,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Tambah Data Dummy'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _laporanData.length,
      itemBuilder: (context, index) {
        final row = _laporanData[index];
        
        // Parsing data dengan null safety
        final timestamp = DateTime.tryParse(row['timestamp']?.toString() ?? '') ?? DateTime.now();
        final currencyFormat = NumberFormat.currency(locale: 'id_ID', decimalDigits: 0, symbol: 'Rp ');
        final harga = (row['harga_item'] as num?)?.toDouble() ?? 0.0;
        final jumlah = (row['jumlah'] as num?)?.toInt() ?? 0;
        final namaProduk = row['nama_produk']?.toString() ?? 'Produk Tidak Diketahui';
        final transaksiId = row['transaksi_id']?.toString() ?? '0';
        final metodePembayaran = row['metode_pembayaran']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                transaksiId,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            title: Text(namaProduk),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('dd MMM yyyy, HH:mm').format(timestamp)),
                Text(
                  'Qty: $jumlah ${metodePembayaran.isNotEmpty ? '• $metodePembayaran' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: Text(
              currencyFormat.format(harga * jumlah),
              style: const TextStyle(
                fontWeight: FontWeight.bold, 
                color: Colors.green,
                fontSize: 14,
              ),
            ),
            isThreeLine: true,
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
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pilihTanggal(context, true),
              icon: const Icon(Icons.calendar_today),
              label: Text('Dari: ${formatter.format(_tanggalAwal)}'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pilihTanggal(context, false),
              icon: const Icon(Icons.calendar_today),
              label: Text('Sampai: ${formatter.format(_tanggalAkhir)}'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 4,
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildSummaryRow(
                'Total Penjualan:', 
                currencyFormat.format(_totalPenjualan), 
                isHeader: true
              ),
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
        ? Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          )
        : Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          );
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