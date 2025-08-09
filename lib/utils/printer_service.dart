import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:kasir_pro/models/transaksi.dart';

class PrinterService {
  // Fungsi ini adalah kerangka untuk mencetak struk.
  // Anda perlu menyesuaikan detail struk sesuai kebutuhan.
  Future<void> cetakStruk({
    required String printerAddress,
    required Map<String, String> infoToko,
    required int transaksiId,
    required double total,
    required double diskon,
    required double pajak,
    required double bayar,
    required String metodePembayaran,
    required List<ItemKeranjang> items,
  }) async {
    try {
      // 1. Buat koneksi ke printer Bluetooth
      final device = BluetoothDevice.fromId(printerAddress);
      await device.connect();

      // 2. Siapkan data untuk dicetak menggunakan esc_pos_utils
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      // Header
      bytes += generator.text(infoToko['nama_toko'] ?? 'Toko Anda', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
      bytes += generator.text(infoToko['alamat_toko'] ?? '', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();
      
      // Info Transaksi
      bytes += generator.row([
        PosColumn(text: 'No: $transaksiId', width: 6),
        PosColumn(text: DateFormat('dd/MM/yy HH:mm').format(DateTime.now()), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.hr();

      // Daftar Item
      for (var item in items) {
        bytes += generator.row([
          PosColumn(text: '${item.jumlah}x ${item.namaProduk}', width: 8),
          PosColumn(text: NumberFormat.simpleCurrency(locale: 'id_ID').format(item.harga * item.jumlah), width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
      bytes += generator.hr();

      // Total
      bytes += generator.row([
        PosColumn(text: 'Subtotal', width: 6),
        PosColumn(text: NumberFormat.simpleCurrency(locale: 'id_ID').format(total + diskon - (total * (pajak/100))), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Diskon', width: 6),
        PosColumn(text: NumberFormat.simpleCurrency(locale: 'id_ID').format(diskon), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Pajak (${pajak.toStringAsFixed(0)}%)', width: 6),
        PosColumn(text: NumberFormat.simpleCurrency(locale: 'id_ID').format(total * (pajak/100)), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.hr();
      bytes += generator.row([
        PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: NumberFormat.simpleCurrency(locale: 'id_ID').format(total), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      bytes += generator.row([
        PosColumn(text: metodePembayaran, width: 6),
        PosColumn(text: NumberFormat.simpleCurrency(locale: 'id_ID').format(bayar), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
       if (metodePembayaran == 'Tunai') {
        bytes += generator.row([
          PosColumn(text: 'Kembali', width: 6),
          PosColumn(text: NumberFormat.simpleCurrency(locale: 'id_ID').format(bayar - total), width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
      bytes += generator.hr();

      // Footer
      bytes += generator.text('Terima kasih!', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.feed(2);
      bytes += generator.cut();

      // 3. Kirim data ke printer
      // Anda perlu menemukan karakteristik Bluetooth yang tepat untuk printer Anda
      // Biasanya service '00001800-0000-1000-8000-00805f9b34fb' dan characteristic '00002a00-0000-1000-8000-00805f9b34fb'
      // Namun ini bisa berbeda-beda.
      final services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            await characteristic.write(bytes, withoutResponse: true);
          }
        }
      }

      // 4. Putuskan koneksi
      await device.disconnect();
    } catch (e) {
      // Tangani error, misalnya printer tidak ditemukan atau gagal konek
      print('Error saat mencetak: $e');
      throw Exception('Gagal mencetak struk: $e');
    }
  }
}
