import 'package:flutter/material.dart';
import 'package:seed_silo/screens/preload_screen.dart';

void main() {
  runApp(SeedSiloApp());
}

class SeedSiloApp extends StatelessWidget {
  const SeedSiloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seed Silo',
      theme: ThemeData.dark(),
      home: PreloadScreen(),
    );
  }
}
