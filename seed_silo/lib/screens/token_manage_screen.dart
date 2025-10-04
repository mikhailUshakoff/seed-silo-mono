import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/screens/network_manage_screen.dart';
import 'package:seed_silo/providers/token_provider.dart';

class TokenManageScreen extends StatefulWidget {
  final Network currentNetwork;

  const TokenManageScreen({super.key, required this.currentNetwork});

  @override
  State<TokenManageScreen> createState() => _TokenManageScreenState();
}

class _TokenManageScreenState extends State<TokenManageScreen> {
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await context.read<TokenProvider>().loadTokens(widget.currentNetwork.chainId);
  }

  Future<void> _addToken() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;

    final tokenProvider = context.read<TokenProvider>();
    final beforeCount = tokenProvider.tokens.length;

    final success = await tokenProvider.addToken(widget.currentNetwork, address);

    if (!mounted) return;

    _addressController.clear();

    if (!success || tokenProvider.tokens.length == beforeCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Token already exists or failed to fetch.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token added successfully')),
      );
    }
  }

  Future<void> _removeToken(Token token) async {
    await context.read<TokenProvider>().removeToken(widget.currentNetwork.chainId, token.address);
  }

  Future<void> _navigateToNetworkSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NetworkManageScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage tokens'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Network: ${widget.currentNetwork.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Switch'),
                  onPressed: _navigateToNetworkSettings,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Consumer<TokenProvider>(
              builder: (context, tokenProvider, child) {
                return Row(
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
                      onPressed: tokenProvider.isLoading ? null : _addToken,
                      child: tokenProvider.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Add'),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: Consumer<TokenProvider>(
              builder: (context, tokenProvider, child) {
                if (tokenProvider.isLoading && tokenProvider.tokens.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (tokenProvider.tokens.isEmpty) {
                  return const Center(
                    child: Text('No tokens added yet'),
                  );
                }

                return ListView.builder(
                  itemCount: tokenProvider.tokens.length,
                  itemBuilder: (context, index) {
                    final token = tokenProvider.tokens[index];
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}