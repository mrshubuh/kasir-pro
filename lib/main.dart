import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kasir_pro/screens/home_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
        // Properti cardTheme dihapus untuk menghindari error build
      ),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
