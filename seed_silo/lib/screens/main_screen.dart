// main_screen.dart
import 'package:flutter/material.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/screens/transfer_screen.dart';
import 'package:seed_silo/screens/token_manage_screen.dart';
import 'package:seed_silo/services/eth_wallet_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<Token> _tokens = [];

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    final tokens = await EthWalletService().getTokens();
    setState(() {
      _tokens = tokens;
    });
  }

  void _navigateToManageTokens() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TokenManageScreen()),
    );
    await _loadTokens(); // Reload after returning
  }

  void _onTokenTap(Token token) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransferScreen(token: token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tokens'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToManageTokens,
          ),
          SizedBox(width: 58),
        ],
      ),
      body: ListView.builder(
        itemCount: _tokens.length,
        itemBuilder: (context, index) {
          final token = _tokens[index];
          return ListTile(
            title: Text(token.symbol),
            subtitle: Text(token.address),
            onTap: () => _onTokenTap(token),
          );
        },
      ),
    );
  }
}
