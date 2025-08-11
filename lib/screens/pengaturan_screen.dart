import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kasir_pro/database/database_helper.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_usb_printer/flutter_usb_printer.dart';

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
  String _printerType = 'none'; // 'none', 'bluetooth', 'usb'

  // State untuk Printer Bluetooth
  BluetoothDevice? _selectedBtDevice;
  String _selectedBtDeviceName = '';
  List<ScanResult> _scanResults = [];
  bool _isScanningBt = false;

  // State untuk Printer USB
  List<Map<String, dynamic>> _usbDevices = [];
  Map<String, dynamic>? _selectedUsbDevice;
  bool _isScanningUsb = false;

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
      _printerType = pengaturan['printer_type'] ?? 'none';

      final btAddress = pengaturan['bt_printer_address'] ?? '';
      if (btAddress.isNotEmpty) {
        _selectedBtDevice = BluetoothDevice.fromId(btAddress);
        _selectedBtDeviceName = pengaturan['bt_printer_name'] ?? 'Perangkat BT Tersimpan';
      }

      final vendorId = pengaturan['usb_vendor_id'] ?? '';
      if (vendorId.isNotEmpty) {
        _selectedUsbDevice = {
          'vendorId': vendorId,
          'productId': pengaturan['usb_product_id'] ?? '',
          'deviceName': pengaturan['usb_printer_name'] ?? 'Perangkat USB Tersimpan',
        };
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
    
    await _db.updatePengaturan('printer_type', _printerType);

    if (_selectedBtDevice != null) {
      await _db.updatePengaturan('bt_printer_address', _selectedBtDevice!.remoteId.toString());
      await _db.updatePengaturan('bt_printer_name', _selectedBtDevice!.platformName.isNotEmpty ? _selectedBtDevice!.platformName : 'Unknown BT Device');
    }
    if (_selectedUsbDevice != null) {
      await _db.updatePengaturan('usb_vendor_id', _selectedUsbDevice!['vendorId'].toString());
      await _db.updatePengaturan('usb_product_id', _selectedUsbDevice!['productId'].toString());
      await _db.updatePengaturan('usb_printer_name', _selectedUsbDevice!['deviceName'].toString());
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

  void _scanBtPrinters() async {
    setState(() => _isScanningBt = true);
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      FlutterBluePlus.scanResults.listen((results) {
        setState(() => _scanResults = results);
      });
    } finally {
      Future.delayed(const Duration(seconds: 5), () {
        FlutterBluePlus.stopScan();
        setState(() => _isScanningBt = false);
      });
    }
  }

  void _scanUsbPrinters() async {
    setState(() => _isScanningUsb = true);
    try {
      var devices = await FlutterUsbPrinter.getUSBDeviceList();
      setState(() {
        _usbDevices = devices;
        _isScanningUsb = false;
      });
    } catch (e) {
      setState(() => _isScanningUsb = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mencari printer USB: $e'), backgroundColor: Colors.red),
      );
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
                ),

                const Divider(height: 40),

                _buildSectionTitle('Pengaturan Printer Thermal'),
                const SizedBox(height: 16),
                _buildPrinterTypeSelector(),
                if (_printerType == 'bluetooth') _buildBluetoothPrinterSelector(),
                if (_printerType == 'usb') _buildUsbPrinterSelector(),

                const SizedBox(height: 40),
                FilledButton(
                  onPressed: _simpanPengaturan,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
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

  Widget _buildPrinterTypeSelector() {
    return SegmentedButton<String>(
      segments: const <ButtonSegment<String>>[
        ButtonSegment<String>(value: 'none', label: Text('Tidak Ada'),),
        ButtonSegment<String>(value: 'bluetooth', label: Text('Bluetooth'),),
        ButtonSegment<String>(value: 'usb', label: Text('USB'),),
      ],
      selected: {_printerType},
      onSelectionChanged: (Set<String> newSelection) {
        setState(() {
          _printerType = newSelection.first;
        });
      },
    );
  }

  Widget _buildBluetoothPrinterSelector() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
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
                  onPressed: _isScanningBt ? null : _scanBtPrinters,
                  child: _isScanningBt ? const Text('Mencari...') : const Text('Cari Perangkat'),
                ),
              ],
            ),
            if (_selectedBtDevice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('Terpilih: $_selectedBtDeviceName', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            if (_isScanningBt) const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
            if (_scanResults.isNotEmpty && !_isScanningBt)
              SizedBox(
                height: 150,
                child: ListView.builder(
                  itemCount: _scanResults.length,
                  itemBuilder: (context, index) {
                    final result = _scanResults[index];
                    final deviceName = result.device.platformName;
                    if (deviceName.isEmpty) return const SizedBox.shrink();
                    return ListTile(
                      title: Text(deviceName),
                      onTap: () {
                        setState(() {
                          _selectedBtDevice = result.device;
                          _selectedBtDeviceName = deviceName;
                          _scanResults.clear();
                        });
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

  Widget _buildUsbPrinterSelector() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Printer USB:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: _isScanningUsb ? null : _scanUsbPrinters,
                  child: _isScanningUsb ? const Text('Mencari...') : const Text('Cari Perangkat'),
                ),
              ],
            ),
            if (_selectedUsbDevice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('Terpilih: ${_selectedUsbDevice!['deviceName']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            if (_isScanningUsb) const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
            if (_usbDevices.isNotEmpty && !_isScanningUsb)
              SizedBox(
                height: 150,
                child: ListView.builder(
                  itemCount: _usbDevices.length,
                  itemBuilder: (context, index) {
                    final device = _usbDevices[index];
                    return ListTile(
                      title: Text(device['deviceName'] ?? 'Unknown USB Device'),
                      subtitle: Text('Vendor ID: ${device['vendorId']} | Product ID: ${device['productId']}'),
                      onTap: () {
                        setState(() {
                          _selectedUsbDevice = device;
                          _usbDevices.clear();
                        });
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
