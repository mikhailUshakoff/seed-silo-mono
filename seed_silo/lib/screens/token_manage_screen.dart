import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/screens/network_manage_screen.dart';
import 'package:seed_silo/providers/token_provider.dart';
import 'package:seed_silo/theme/app_theme.dart';

class TokenManageScreen extends StatefulWidget {
  final Network currentNetwork;

  const TokenManageScreen({super.key, required this.currentNetwork});

  @override
  State<TokenManageScreen> createState() => _TokenManageScreenState();
}

class _TokenManageScreenState extends State<TokenManageScreen> {
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _addToken() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;

    final tokenProvider = context.read<TokenProvider>();

    final result = await tokenProvider.addToken(widget.currentNetwork, address);

    if (!mounted) return;

    _addressController.clear();

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to add token')),
      );
    }
  }

  Future<void> _removeToken(Token token) async {
    final result = await context
        .read<TokenProvider>()
        .removeToken(widget.currentNetwork.chainId, token.address);

    if (!mounted) return;

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to remove token')),
      );
    }
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
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: BrandColors.sageBright
                            .withAlpha((0.16 * 255).toInt()),
                        child: const Icon(Icons.hub,
                            size: 18, color: BrandColors.sageBright),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active network',
                              style: TextStyle(
                                  fontSize: 12, color: BrandColors.tan),
                            ),
                            Text(
                              widget.currentNetwork.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BrandColors.sageBright,
                          side:
                              const BorderSide(color: BrandColors.sageBright),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: const Icon(Icons.swap_horiz, size: 16),
                        label: const Text('Switch'),
                        onPressed: _navigateToNetworkSettings,
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Consumer<TokenProvider>(
                    builder: (context, tokenProvider, child) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _addressController,
                              style: BrandColors.mono.copyWith(fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: 'Token address',
                                hintText: '0x...',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed:
                                tokenProvider.isLoading ? null : _addToken,
                            child: tokenProvider.isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Text('Add'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Consumer<TokenProvider>(
              builder: (context, tokenProvider, child) {
                if (tokenProvider.isLoading && tokenProvider.tokens.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (tokenProvider.tokens.isEmpty) {
                  return const Center(
                    child: Text(
                      'No tokens added yet',
                      style: TextStyle(color: BrandColors.tan),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                  itemCount: tokenProvider.tokens.length,
                  itemBuilder: (context, index) {
                    final token = tokenProvider.tokens[index];
                    final isNative = token.symbol == 'ETH';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: BrandColors.sageBright
                              .withAlpha((0.16 * 255).toInt()),
                          child: Text(
                            token.symbol.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: BrandColors.sageBright,
                            ),
                          ),
                        ),
                        title: Text(
                          token.symbol,
                          style:
                              const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          token.address,
                          style: BrandColors.mono.copyWith(
                            fontSize: 12,
                            color: BrandColors.tan,
                          ),
                        ),
                        trailing: SizedBox(
                          width: 48,
                          height: 48,
                          child: isNative
                              ? const Center(
                                  child: Icon(Icons.lock_outline,
                                      size: 18, color: BrandColors.tan),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: BrandColors.rust),
                                  onPressed: () => _removeToken(token),
                                ),
                        ),
                      ),
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
