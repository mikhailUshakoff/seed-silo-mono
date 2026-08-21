import 'package:flutter/material.dart';
import 'package:seed_silo/services/hardware_wallet_service.dart';
import 'package:seed_silo/screens/main_screen.dart';
import 'package:seed_silo/theme/app_theme.dart';

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

    if (true || version != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      setState(() => _clickCount++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attemptsExhausted = _clickCount >= _maxClickAttempts && !_isLoading;

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: _handleLogoTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLogo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: _isLoading ? 0.6 : 1,
      child: Container(
        width: 150,
        height: 150,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: BrandColors.tan,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF3A2B18), width: 1),
        ),
        child: Image.asset(
          'assets/icon/seed_silo_mark.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
