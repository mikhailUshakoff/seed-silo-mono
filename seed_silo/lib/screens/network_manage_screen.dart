import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/providers/network_provider.dart';

class NetworkManageScreen extends StatefulWidget {
  const NetworkManageScreen({super.key});

  @override
  State<NetworkManageScreen> createState() => _NetworkManageScreenState();
}

class _NetworkManageScreenState extends State<NetworkManageScreen> {
  final _rpcUrlController = TextEditingController();

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

    final networkProvider = context.read<NetworkProvider>();
    final result = await networkProvider.addNetwork(rpcUrl);

    if (!mounted) return;

    _rpcUrlController.clear();

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to add network')),
      );
    }
  }

  Future<void> _switchNetwork(Network network) async {
    final networkProvider = context.read<NetworkProvider>();
    await networkProvider.setCurrentNetwork(network.chainId);
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
      if (!mounted) return;
      final networkProvider = context.read<NetworkProvider>();
      final result = await networkProvider.removeNetwork(network.chainId);

      if (!mounted) return;

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to remove network')),
        );
      }
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
          final isLoading = networkProvider.isLoading;

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
                      onPressed: isLoading ? null : _addNetwork,
                      child: isLoading
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
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
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
                            onTap:
                                isActive ? null : () => _switchNetwork(network),
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
