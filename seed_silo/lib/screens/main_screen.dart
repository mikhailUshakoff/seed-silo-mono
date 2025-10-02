import 'package:flutter/material.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/screens/transfer_screen.dart';
import 'package:seed_silo/screens/token_manage_screen.dart';
import 'package:seed_silo/screens/network_manage_screen.dart';
import 'package:seed_silo/services/network_service.dart';
import 'package:seed_silo/services/token_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _networkService = NetworkService();
  final _tokenService = TokenService();

  List<Token> _tokens = [];
  Network? _currentNetwork;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final network = await _networkService.getCurrentNetwork();
    final tokens = await _tokenService.getTokens();

    if (!mounted) return;

    setState(() {
      _currentNetwork = network;
      _tokens = tokens;
      _isLoading = false;
    });
  }

  void _navigateToManageTokens() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TokenManageScreen()),
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
        currentNetwork: _currentNetwork,
        onNetworkChanged: () async {
          Navigator.pop(context);
          await _loadData();
        },
        onManageNetworks: () {
          Navigator.pop(context);
          _navigateToNetworkSettings();
        },
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Tokens'),
            if (_currentNetwork != null) ...[
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
                            _currentNetwork!.name,
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
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Manage Tokens',
            onPressed: _navigateToManageTokens,
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
                        onPressed: _navigateToManageTokens,
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
  }
}

class _NetworkSelectorSheet extends StatefulWidget {
  final Network? currentNetwork;
  final VoidCallback onNetworkChanged;
  final VoidCallback onManageNetworks;

  const _NetworkSelectorSheet({
    required this.currentNetwork,
    required this.onNetworkChanged,
    required this.onManageNetworks,
  });

  @override
  State<_NetworkSelectorSheet> createState() => _NetworkSelectorSheetState();
}

class _NetworkSelectorSheetState extends State<_NetworkSelectorSheet> {
  final _networkService = NetworkService();
  List<Network> _networks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  Future<void> _loadNetworks() async {
    final networks = await _networkService.getNetworks();
    if (!mounted) return;
    setState(() {
      _networks = networks;
      _isLoading = false;
    });
  }

  Future<void> _switchNetwork(Network network) async {
    await _networkService.setCurrentNetwork(network.id);
    widget.onNetworkChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Network',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: widget.onManageNetworks,
                  tooltip: 'Manage Networks',
                ),
              ],
            ),
          ),
          const Divider(),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _networks.length,
                itemBuilder: (context, index) {
                  final network = _networks[index];
                  final isActive = network == widget.currentNetwork;

                  return ListTile(
                    leading: Icon(
                      isActive ? Icons.check_circle : Icons.circle_outlined,
                      color: isActive ? Colors.green : Colors.grey,
                    ),
                    title: Text(
                      network.name,
                      style: TextStyle(
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text('Chain ID: ${network.chainId}'),
                    onTap: isActive ? null : () => _switchNetwork(network),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}