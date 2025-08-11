import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kasir_pro/screens/home_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  // Inisialisasi FFI untuk SQLite di Windows/Desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        // Menggunakan TextButtonTheme untuk menghilangkan highlight berlebihan
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.teal.shade800,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        scaffoldBackgroundColor: Colors.grey.shade50,
      ),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}