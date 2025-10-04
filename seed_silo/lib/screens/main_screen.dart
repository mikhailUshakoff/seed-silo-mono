import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/screens/transfer_screen.dart';
import 'package:seed_silo/screens/token_manage_screen.dart';
import 'package:seed_silo/screens/network_manage_screen.dart';
import 'package:seed_silo/providers/network_provider.dart';
import 'package:seed_silo/services/token_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<Token> _tokens = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final networkProvider = Provider.of<NetworkProvider>(context, listen: false);
    final currentNetwork = networkProvider.currentNetwork;
    final tokens = await TokenService().getTokens(currentNetwork.chainId);

    if (!mounted) return;

    setState(() {
      _tokens = tokens;
      _isLoading = false;
    });
  }

  void _navigateToManageTokens(Network currentNetwork) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TokenManageScreen(currentNetwork: currentNetwork)),
    );
    await _loadData(); // Reload after returning
  }

  void _navigateToNetworkSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NetworkManageScreen()),
    );
    await _loadData(); // Reload after returning
  }

  void _showNetworkMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _NetworkSelectorSheet(
        onNetworkChanged: () async {
          await _loadData();
        },
        onManageNetworks: _navigateToNetworkSettings,
      ),
    );
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
    return Consumer<NetworkProvider>(
      builder: (context, networkProvider, child) {
        final currentNetwork = networkProvider.currentNetwork;

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
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.circle, size: 8, color: Colors.green),
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
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _tokens.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.token, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No tokens found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Token'),
                            onPressed: () => _navigateToManageTokens(currentNetwork),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        itemCount: _tokens.length,
                        itemBuilder: (context, index) {
                          final token = _tokens[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                token.symbol.substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              token.symbol,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              '${token.address.substring(0, 6)}...${token.address.substring(token.address.length - 4)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _onTokenTap(token),
                          );
                        },
                      ),
                    ),
        );
      },
    );
  }
}

class _NetworkSelectorSheet extends StatefulWidget {
  final VoidCallback onNetworkChanged;
  final VoidCallback onManageNetworks;

  const _NetworkSelectorSheet({
    required this.onNetworkChanged,
    required this.onManageNetworks,
  });

  @override
  State<_NetworkSelectorSheet> createState() => _NetworkSelectorSheetState();
}

class _NetworkSelectorSheetState extends State<_NetworkSelectorSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Consumer<NetworkProvider>(
        builder: (context, networkProvider, child) {
          final networks = networkProvider.networks;
          final currentNetwork = networkProvider.currentNetwork;
          final isLoading = networkProvider.isLoading;

          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Network',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...networks.map((network) {
                final isActive = network == currentNetwork;
                return ListTile(
                  leading: Radio<Network>(
                    value: network,
                    groupValue: currentNetwork,
                    onChanged: (value) async {
                      if (value != null) {
                        await networkProvider.setCurrentNetwork(value.chainId);
                        widget.onNetworkChanged();
                        Navigator.pop(context);
                      }
                    },
                  ),
                  title: Text(network.name),
                  subtitle: Text('Chain ID: ${network.chainId}'),
                  trailing: isActive ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: isActive ? null : () async {
                    await networkProvider.setCurrentNetwork(network.chainId);
                    widget.onNetworkChanged();
                    Navigator.pop(context);
                  },
                );
              }).toList(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Manage Networks'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onManageNetworks();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}