import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kasir_pro/database/database_helper.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';


class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key});

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  final _db = DatabaseHelper();
  final _namaTokoController = TextEditingController();
  final _alamatTokoController = TextEditingController();
  final _diskonController = TextEditingController();
  final _pajakController = TextEditingController();

  String _logoPath = '';
  bool _izinkanStokKosong = false;

  // State untuk Printer Bluetooth
  BluetoothDevice? _selectedDevice;
  String _selectedDeviceName = '';
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;


  @override
  void initState() {
    super.initState();
    _loadPengaturan();
  }

  Future<void> _loadPengaturan() async {
    final pengaturan = await _db.getPengaturan();
    setState(() {
      _namaTokoController.text = pengaturan['nama_toko'] ?? '';
      _alamatTokoController.text = pengaturan['alamat_toko'] ?? '';
      _logoPath = pengaturan['logo_path'] ?? '';
      _diskonController.text = pengaturan['diskon_default'] ?? '0';
      _pajakController.text = pengaturan['pajak_default'] ?? '0';
      _izinkanStokKosong = (pengaturan['izinkan_stok_kosong'] ?? 'false') == 'true';
      
      // Muat info printer yang tersimpan
      final address = pengaturan['printer_address'] ?? '';
      if(address.isNotEmpty) {
        _selectedDevice = BluetoothDevice.fromId(address);
        _selectedDeviceName = pengaturan['printer_name'] ?? 'Perangkat Tersimpan';
      }
    });
  }

  Future<void> _simpanPengaturan() async {
    await _db.updatePengaturan('nama_toko', _namaTokoController.text);
    await _db.updatePengaturan('alamat_toko', _alamatTokoController.text);
    await _db.updatePengaturan('logo_path', _logoPath);
    await _db.updatePengaturan('diskon_default', _diskonController.text);
    await _db.updatePengaturan('pajak_default', _pajakController.text);
    await _db.updatePengaturan('izinkan_stok_kosong', _izinkanStokKosong.toString());
    
    if (_selectedDevice != null) {
      await _db.updatePengaturan('printer_address', _selectedDevice!.remoteId.toString());
      await _db.updatePengaturan('printer_name', _selectedDevice!.platformName.isNotEmpty ? _selectedDevice!.platformName : 'Unknown Device');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengaturan berhasil disimpan'), backgroundColor: Colors.green),
    );
  }

  Future<void> _pilihLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _logoPath = pickedFile.path;
      });
    }
  }

  void _scanForPrinters() async {
    setState(() => _isScanning = true);
    try {
        // Mulai scan selama 5 detik
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
        
        // Dengarkan hasil scan
        FlutterBluePlus.scanResults.listen((results) {
            setState(() {
                _scanResults = results;
            });
        });
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error scanning: $e'), backgroundColor: Colors.red),
        );
    } finally {
        // Hentikan loading indicator setelah scan selesai
        Future.delayed(const Duration(seconds: 5), () {
            setState(() => _isScanning = false);
        });
    }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Aplikasi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle('Informasi Toko'),
                const SizedBox(height: 16),
                TextField(controller: _namaTokoController, decoration: const InputDecoration(labelText: 'Nama Toko', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: _alamatTokoController, decoration: const InputDecoration(labelText: 'Alamat Toko', border: OutlineInputBorder()), maxLines: 3),
                const SizedBox(height: 16),
                _buildLogoPicker(),
                const Divider(height: 40),

                _buildSectionTitle('Pengaturan Transaksi'),
                const SizedBox(height: 16),
                TextField(controller: _diskonController, decoration: const InputDecoration(labelText: 'Diskon Default (Rp)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextField(controller: _pajakController, decoration: const InputDecoration(labelText: 'Pajak Default (%)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Izinkan transaksi jika stok kosong'),
                  value: _izinkanStokKosong,
                  onChanged: (bool value) {
                    setState(() {
                      _izinkanStokKosong = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  tileColor: Colors.grey.shade200,
                ),
                const Divider(height: 40),

                _buildSectionTitle('Pengaturan Printer Thermal'),
                const SizedBox(height: 16),
                _buildPrinterSelector(),

                const SizedBox(height: 40),
                FilledButton(
                  onPressed: _simpanPengaturan,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Simpan Semua Pengaturan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold));
  }

  Widget _buildLogoPicker() {
    return Row(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _logoPath.isNotEmpty
              ? Image.file(File(_logoPath), fit: BoxFit.cover, errorBuilder: (c, e, s) => const Center(child: Text('Error')))
              : const Center(child: Text('Logo')),
        ),
        const SizedBox(width: 16),
        TextButton(onPressed: _pilihLogo, child: const Text('Pilih Logo Toko')),
      ],
    );
  }

  Widget _buildPrinterSelector() {
    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Printer Bluetooth:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: _isScanning ? null : _scanForPrinters, 
                  child: _isScanning ? const Text('Mencari...') : const Text('Cari Perangkat')
                ),
              ],
            ),
            const SizedBox(height: 8),
             if (_selectedDevice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('Terpilih: ${_selectedDeviceName.isNotEmpty ? _selectedDeviceName : _selectedDevice!.remoteId}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            if (_isScanning) const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
            if (_scanResults.isNotEmpty && !_isScanning)
              SizedBox(
                height: 150,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _scanResults.length,
                  itemBuilder: (context, index) {
                    final result = _scanResults[index];
                    final deviceName = result.device.platformName;
                    if (deviceName.isEmpty) return const SizedBox.shrink(); // Sembunyikan perangkat tanpa nama
                    return ListTile(
                      title: Text(deviceName),
                      subtitle: Text(result.device.remoteId.toString()),
                      onTap: () {
                        setState(() {
                          _selectedDevice = result.device;
                          _selectedDeviceName = deviceName;
                          _scanResults.clear(); // Sembunyikan daftar setelah memilih
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$deviceName dipilih.')),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
