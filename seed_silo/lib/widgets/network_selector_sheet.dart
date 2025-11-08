import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/providers/network_provider.dart';

class NetworkSelectorSheet extends StatelessWidget {
  final VoidCallback onNetworkChanged;
  final VoidCallback onManageNetworks;

  const NetworkSelectorSheet({
    super.key,
    required this.onNetworkChanged,
    required this.onManageNetworks,
  });

  void _scrollToSelectedNetwork(ScrollController controller, List<Network> networks, Network? currentNetwork) {
    if (currentNetwork != null) {
      final index = networks.indexOf(currentNetwork);
      if (index != -1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.hasClients) {
            // Each ListTile is approximately 72 pixels high
            final position = index * 72.0;
            controller.animateTo(
              position,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();

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

          _scrollToSelectedNetwork(scrollController, networks, currentNetwork);

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
                  controller: scrollController,
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
                            onNetworkChanged();
                            Navigator.pop(context);
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
                              onNetworkChanged();
                              Navigator.pop(context);
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
                  onManageNetworks();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
