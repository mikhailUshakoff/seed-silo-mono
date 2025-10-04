import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seed_silo/screens/preload_screen.dart';
import 'package:seed_silo/providers/network_provider.dart';
import 'package:seed_silo/providers/token_provider.dart';

void main() {
  runApp(const SeedSiloApp());
}

class SeedSiloApp extends StatelessWidget {
  const SeedSiloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => NetworkProvider()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (context) => TokenProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Seed Silo',
        theme: ThemeData.dark(),
        home: const PreloadScreen(),
      ),
    );
  }
}
