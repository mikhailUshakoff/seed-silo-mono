import 'package:flutter/material.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/services/eth_wallet_service.dart';

class TokenManageScreen extends StatefulWidget {
  const TokenManageScreen({super.key});

  @override
  State<TokenManageScreen> createState() => _TokenManageScreenState();
}

class _TokenManageScreenState extends State<TokenManageScreen> {
  final _addressController = TextEditingController();
  final _walletService = EthWalletService();

  List<Token> _tokens = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    final tokens = await _walletService.getTokens();
    setState(() {
      _tokens = tokens;
    });
  }

  Future<void> _addToken() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;

    setState(() => _isLoading = true);

    final beforeCount = _tokens.length;
    await _walletService.addToken(address);
    final tokens = await _walletService.getTokens();

    if (!mounted) return;

    setState(() {
      _tokens = tokens;
      _isLoading = false;
      _addressController.clear();
    });

    if (tokens.length == beforeCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Token already exists or failed to fetch.')),
      );
    }
  }

  Future<void> _removeToken(Token token) async {
    await _walletService.removeToken(token.address);
    final tokens = await _walletService.getTokens();
    setState(() => _tokens = tokens);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Tokens')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Token address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _addToken,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _tokens.length,
              itemBuilder: (context, index) {
                final token = _tokens[index];
                return ListTile(
                  title: Text(token.symbol),
                  subtitle: Text(token.address),
                  trailing: token.symbol != 'ETH'
                      ? IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeToken(token),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
