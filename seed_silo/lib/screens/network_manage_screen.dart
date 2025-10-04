import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/providers/network_provider.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NetworkManageScreen extends StatefulWidget {
  const NetworkManageScreen({super.key});

  @override
  State<NetworkManageScreen> createState() => _NetworkManageScreenState();
}

class _NetworkManageScreenState extends State<NetworkManageScreen> {
  final _rpcUrlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _rpcUrlController.dispose();
    super.dispose();
  }

  Future<void> _addNetwork() async {
    final rpcUrl = _rpcUrlController.text.trim();
    if (rpcUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter RPC URL')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get chain ID from RPC
      final client = Web3Client(rpcUrl, http.Client());
      final chainId = (await client.getChainId()).toInt();

      // Fetch network name from chainid.network
      final networkName = await _fetchNetworkName(chainId);

      // Check if network already exists
      final networkProvider = context.read<NetworkProvider>();
      if (networkProvider.networkExistsByChainId(chainId)) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network already exists')),
        );
        return;
      }

      // Create network with fetched data
      final network = Network(
        id: 'chain_$chainId',
        name: networkName ?? 'Chain $chainId',
        rpcUrl: rpcUrl,
        chainId: chainId,
      );

      await networkProvider.addNetwork(network);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _rpcUrlController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network "${network.name}" added')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add network: ${e.toString()}')),
      );
    }
  }

  Future<String?> _fetchNetworkName(int chainId) async {
    try {
      final response = await http.get(
        Uri.parse('https://chainid.network/chains.json'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> chains = json.decode(response.body);
        final chain = chains.firstWhere(
          (c) => c['chainId'] == chainId,
          orElse: () => null,
        );

        if (chain != null && chain['name'] != null) {
          return chain['name'] as String;
        }
      }
    } catch (e) {
      // If fetching fails, return null and use default name
      debugPrint('Failed to fetch network name: $e');
    }
    return null;
  }

  Future<void> _switchNetwork(Network network) async {
    final networkProvider = context.read<NetworkProvider>();
    await networkProvider.setCurrentNetwork(network.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Switched to ${network.name}')),
    );
  }

  Future<void> _removeNetwork(Network network) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Network'),
        content: Text(
          'Are you sure you want to remove "${network.name}"?\n\nAll tokens for this network will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final networkProvider = context.read<NetworkProvider>();
      await networkProvider.removeNetwork(network.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network "${network.name}" removed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Networks'),
      ),
      body: Consumer<NetworkProvider>(
        builder: (context, networkProvider, child) {
          final networks = networkProvider.networks;
          final currentNetwork = networkProvider.currentNetwork;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _rpcUrlController,
                        decoration: const InputDecoration(
                          labelText: 'RPC URL',
                          hintText: 'https://...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addNetwork,
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
                child: networks.isEmpty
                    ? const Center(
                        child: Text('No networks configured'),
                      )
                    : ListView.builder(
                        itemCount: networks.length,
                        itemBuilder: (context, index) {
                          final network = networks[index];
                          final isActive = network == currentNetwork;

                          return ListTile(
                            leading: Radio<Network>(
                              value: network,
                              groupValue: currentNetwork,
                              onChanged: (value) {
                                if (value != null) _switchNetwork(value);
                              },
                            ),
                            title: Text(
                              network.name,
                              style: TextStyle(
                                fontWeight:
                                    isActive ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              'Chain ID: ${network.chainId}\n${network.rpcUrl}',
                            ),
                            isThreeLine: true,
                            trailing: isActive
                                ? const Chip(
                                    label: Text('Active'),
                                    backgroundColor: Colors.green,
                                    labelStyle: TextStyle(color: Colors.white),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _removeNetwork(network),
                                  ),
                            onTap: isActive ? null : () => _switchNetwork(network),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}