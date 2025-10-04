import 'package:flutter/material.dart';
import 'package:seed_silo/services/hardware_wallet_service.dart';
import 'package:seed_silo/screens/main_screen.dart';
//import 'package:shared_preferences/shared_preferences.dart';

class PreloadScreen extends StatefulWidget {
  const PreloadScreen({super.key});

  @override
  State<PreloadScreen> createState() => _PreloadScreenState();
}

class _PreloadScreenState extends State<PreloadScreen> {
  static const int _maxClickAttempts = 2;

  int _clickCount = 0;
  bool _isLoading = false;

  Future<void> _handleLogoTap() async {
      //final prefs = await SharedPreferences.getInstance();
      //await prefs.clear();
    if (_isLoading || _clickCount >= _maxClickAttempts) return;

    setState(() => _isLoading = true);

    final version = await HardwareWalletService().getVersion();

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (version != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      setState(() => _clickCount++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _handleLogoTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLogo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 150,
      height: 150,
      color: Colors.red,
    );
  }
}
