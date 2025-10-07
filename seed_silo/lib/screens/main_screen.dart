import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/screens/transfer_screen.dart';
import 'package:seed_silo/screens/token_manage_screen.dart';
import 'package:seed_silo/screens/network_manage_screen.dart';
import 'package:seed_silo/providers/network_provider.dart';
import 'package:seed_silo/providers/token_provider.dart';
import 'package:seed_silo/widgets/network_selector_sheet.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  void _navigateToManageTokens(Network currentNetwork) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => TokenManageScreen(currentNetwork: currentNetwork)),
    );
  }

  void _navigateToNetworkSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NetworkManageScreen()),
    );
  }

  void _showNetworkMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => NetworkSelectorSheet(
        onNetworkChanged: () async {},
        onManageNetworks: _navigateToNetworkSettings,
      ),
    );
  }

  void _onTokenTap(Token token, Network network) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransferScreen(token: token, network: network),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<NetworkProvider, TokenProvider>(
      builder: (context, networkProvider, tokenProvider, child) {
        final currentNetwork = networkProvider.currentNetwork;
        final tokens = tokenProvider.tokens;
        final isLoading = tokenProvider.isLoading;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text('Tokens'),
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Flexible(
                  child: GestureDetector(
                    onTap: _showNetworkMenu,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha((0.2 * 255).toInt()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.green.withAlpha((0.5 * 255).toInt())),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle,
                              size: 8, color: Colors.green),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              currentNetwork.name,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Manage Tokens',
                onPressed: () => _navigateToManageTokens(currentNetwork),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              final tokenProvider =
                  Provider.of<TokenProvider>(context, listen: false);
              final networkProvider =
                  Provider.of<NetworkProvider>(context, listen: false);
              await tokenProvider
                  .loadTokens(networkProvider.currentNetwork.chainId);
            },
            child: isLoading && tokens.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : tokens.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.token,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No tokens found',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Add Token'),
                              onPressed: () =>
                                  _navigateToManageTokens(currentNetwork),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: tokens.length,
                        itemBuilder: (context, index) {
                          final token = tokens[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                token.symbol.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              token.symbol,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              '${token.address.substring(0, 6)}...${token.address.substring(token.address.length - 4)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _onTokenTap(token, currentNetwork),
                          );
                        },
                      ),
          ),
        );
      },
    );
  }
}
