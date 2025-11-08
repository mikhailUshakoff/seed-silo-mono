import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/providers/network_provider.dart';

class NetworkSelectorSheet extends StatefulWidget {
  final VoidCallback onNetworkChanged;
  final VoidCallback onManageNetworks;

  const NetworkSelectorSheet({
    super.key,
    required this.onNetworkChanged,
    required this.onManageNetworks,
  });

  @override
  State<NetworkSelectorSheet> createState() => _NetworkSelectorSheetState();
}

class _NetworkSelectorSheetState extends State<NetworkSelectorSheet> {
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
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: networks.map((network) {
                    final isActive = network == currentNetwork;
                    return ListTile(
                      leading: Radio<Network>(
                        value: network,
                        groupValue: currentNetwork,
                        onChanged: (value) async {
                          if (value != null) {
                            await networkProvider.setCurrentNetwork(value.chainId);
                            widget.onNetworkChanged();
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          }
                        },
                      ),
                      title: Text(network.name),
                      subtitle: Text('Chain ID: ${network.chainId}'),
                      trailing: isActive
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: isActive
                          ? null
                          : () async {
                              await networkProvider
                                  .setCurrentNetwork(network.chainId);
                              widget.onNetworkChanged();
                              if (mounted) {
                                Navigator.pop(context);
                              }
                            },
                    );
                  }).toList(),
                ),
              ),
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
