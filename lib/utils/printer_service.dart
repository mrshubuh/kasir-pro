import 'dart:io';
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_usb_printer/flutter_usb_printer.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:kasir_pro/models/transaksi.dart';

class PrinterService {
  Future<void> cetakStruk({
    required Map<String, String> infoToko,
    required int transaksiId,
    required double total,
    required double diskon,
    required double pajak,
    required double bayar,
    required String metodePembayaran,
    required List<ItemKeranjang> items,
  }) async {
    final String printerType = infoToko['printer_type'] ?? 'none';
    if (printerType == 'none') {
      print("Tidak ada printer yang dikonfigurasi. Pencetakan dilewati.");
      return;
    }

    // 1. Siapkan data struk
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    final String logoPath = infoToko['logo_path'] ?? '';
    if (logoPath.isNotEmpty && File(logoPath).existsSync()) {
      try {
        final Uint8List logoBytes = await File(logoPath).readAsBytes();
        final img.Image? image = img.decodeImage(logoBytes);
        if (image != null) {
          bytes += generator.image(image);
        }
      } catch (e) {
        print("Gagal memuat atau memproses logo: $e");
      }
    }

    bytes += generator.text(infoToko['nama_toko'] ?? 'Toko Anda', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    bytes += generator.text(infoToko['alamat_toko'] ?? '', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'No: $transaksiId', width: 6),
      PosColumn(text: DateFormat('dd/MM/yy HH:mm').format(DateTime.now()), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.hr();
    for (var item in items) {
      bytes += generator.row([
        PosColumn(text: '${item.jumlah}x ${item.namaProduk}', width: 8, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: NumberFormat.simpleCurrency(locale: 'id_ID', decimalDigits: 0).format(item.harga * item.jumlah), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr();
    double subtotal = items.fold(0, (sum, item) => sum + (item.harga * item.jumlah));
    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: NumberFormat.simpleCurrency(locale: 'id_ID', decimalDigits: 0).format(subtotal), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    if (diskon > 0) {
      bytes += generator.row([
        PosColumn(text: 'Diskon', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: '- ${NumberFormat.simpleCurrency(locale: 'id_ID', decimalDigits: 0).format(diskon)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    if (pajak > 0) {
      final double nilaiPajak = (subtotal - diskon) * (pajak / 100);
      bytes += generator.row([
        PosColumn(text: 'Pajak (${pajak.toStringAsFixed(0)}%)', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: NumberFormat.simpleCurrency(locale: 'id_ID', decimalDigits: 0).format(nilaiPajak), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, align: PosAlign.left)),
      PosColumn(text: NumberFormat.simpleCurrency(locale: 'id_ID', decimalDigits: 0).format(total), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += generator.row([
      PosColumn(text: metodePembayaran, width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: NumberFormat.simpleCurrency(locale: 'id_ID', decimalDigits: 0).format(bayar), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    if (metodePembayaran == 'Tunai' && bayar >= total) {
      bytes += generator.row([
        PosColumn(text: 'Kembali', width: 6, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: NumberFormat.simpleCurrency(locale: 'id_ID', decimalDigits: 0).format(bayar - total), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr();
    bytes += generator.text('Terima kasih!', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.feed(2);
    bytes += generator.cut();

    // 2. Kirim data ke printer sesuai tipenya
    try {
      if (printerType == 'bluetooth') {
        final address = infoToko['bt_printer_address'];
        if (address == null || address.isEmpty) throw Exception('Alamat printer Bluetooth tidak ditemukan.');
        await _printViaBluetooth(address, bytes);
      } else if (printerType == 'usb') {
        final vendorId = infoToko['usb_vendor_id'];
        final productId = infoToko['usb_product_id'];
        if (vendorId == null || vendorId.isEmpty || productId == null || productId.isEmpty) {
          throw Exception('Detail printer USB tidak ditemukan.');
        }
        await _printViaUsb(vendorId, productId, bytes);
      }
    } catch (e) {
      throw Exception('Gagal mencetak: $e');
    }
  }

  Future<void> _printViaBluetooth(String address, List<int> bytes) async {
    final device = BluetoothDevice.fromId(address);
    try {
      await device.connect(timeout: const Duration(seconds: 5));
      final services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.writeWithoutResponse) {
            await characteristic.write(Uint8List.fromList(bytes), withoutResponse: true);
            await device.disconnect();
            return;
          }
        }
      }
      throw Exception("Characteristic untuk mencetak tidak ditemukan.");
    } finally {
      await device.disconnect();
    }
  }

  // --- BAGIAN YANG DIPERBAIKI ---
  Future<void> _printViaUsb(String vendorId, String productId, List<int> bytes) async {
    // 1. Buat objek dari kelas FlutterUsbPrinter
    var flutterUsbPrinter = FlutterUsbPrinter();

    // 2. Hubungkan ke printer menggunakan objek tersebut
    bool? connected = await flutterUsbPrinter.connect(int.parse(vendorId), int.parse(productId));

    // 3. Jika berhasil terhubung, kirim data
    if (connected == true) {
      await flutterUsbPrinter.write(Uint8List.fromList(bytes));
    } else {
      throw Exception('Gagal terhubung ke printer USB.');
    }
  }
}
