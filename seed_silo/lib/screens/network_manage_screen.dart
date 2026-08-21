import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/providers/network_provider.dart';
import 'package:seed_silo/theme/app_theme.dart';

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
            style: TextButton.styleFrom(foregroundColor: BrandColors.rust),
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
              Card(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Custom Network',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: BrandColors.cream,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _rpcUrlController,
                              style: BrandColors.mono.copyWith(fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: 'RPC URL',
                                hintText: 'https://...',
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
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Text('Add'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: networks.isEmpty
                    ? const Center(
                        child: Text(
                          'No networks configured',
                          style: TextStyle(color: BrandColors.tan),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                        itemCount: networks.length,
                        itemBuilder: (context, index) {
                          final network = networks[index];
                          final isActive = network == currentNetwork;

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: BrandColors.sageBright
                                    .withAlpha((0.16 * 255).toInt()),
                                child: const Icon(Icons.hub,
                                    size: 18, color: BrandColors.sageBright),
                              ),
                              title: Text(
                                network.name,
                                style: TextStyle(
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                'Chain ID: ${network.chainId}\n${network.rpcUrl}',
                                style: BrandColors.mono.copyWith(
                                  fontSize: 12,
                                  color: BrandColors.tan,
                                ),
                              ),
                              isThreeLine: true,
                              trailing: isActive
                                  ? const Chip(
                                      label: Text('Active'),
                                      backgroundColor: BrandColors.verified,
                                      labelStyle: TextStyle(
                                          color: BrandColors.espressoDeep,
                                          fontWeight: FontWeight.w600),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: BrandColors.rust),
                                      onPressed: () => _removeNetwork(network),
                                    ),
                              onTap: isActive
                                  ? null
                                  : () => _switchNetwork(network),
                            ),
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
