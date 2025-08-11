import 'package:flutter/material.dart';
import 'package:kasir_pro/screens/laporan/laporan_penjualan_screen.dart';
import 'package:kasir_pro/screens/pengaturan/pengaturan_screen.dart';
import 'package:kasir_pro/screens/stok/stok_opname_screen.dart';
import 'package:kasir_pro/screens/transaksi/transaksi_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir Pro - Menu Utama'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Wrap(
            spacing: 20.0,
            runSpacing: 20.0,
            alignment: WrapAlignment.center,
            children: [
              _buildMenuButton(context, 'Transaksi', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TransaksiScreen()));
              }),
              _buildMenuButton(context, 'Stok Opname', () {
                 Navigator.push(context, MaterialPageRoute(builder: (context) => const StokOpnameScreen()));
              }),
              _buildMenuButton(context, 'Laporan Penjualan', () {
                 Navigator.push(context, MaterialPageRoute(builder: (context) => const LaporanPenjualanScreen()));
              }),
              _buildMenuButton(context, 'Pengaturan', () {
                 Navigator.push(context, MaterialPageRoute(builder: (context) => const PengaturanScreen()));
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String title, VoidCallback onPressed) {
    return SizedBox(
      width: 200,
      height: 120,
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}