import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kasir_pro/screens/home_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Fungsi main sekarang menjadi async untuk memastikan inisialisasi selesai
Future<void> main() async {
  // Wajib dipanggil sebelum menjalankan aplikasi untuk memastikan binding Flutter siap
  WidgetsFlutterBinding.ensureInitialized();

  // Memeriksa apakah platform adalah desktop (Windows, Linux, atau MacOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Inisialisasi FFI untuk sqflite
    sqfliteFfiInit();
    // Mengubah factory database default ke versi FFI yang kompatibel dengan desktop
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const KasirProApp());
}

class KasirProApp extends StatelessWidget {
  const KasirProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kasir Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.deepPurple.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
            )
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        scaffoldBackgroundColor: Colors.grey.shade100,
        // --- BAGIAN YANG DIPERBAIKI ---
        // Menggunakan CardThemeData, bukan CardTheme
        cardTheme: CardTheme(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300)
          )
        )
      ),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
