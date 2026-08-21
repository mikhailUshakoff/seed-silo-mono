import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/providers/network_provider.dart';
import 'package:seed_silo/theme/app_theme.dart';

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
  final Map<Network, GlobalKey> _networkKeys = {};

  @override
  void initState() {
    super.initState();

    // Scroll to selected network after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedNetwork();
    });
  }

  void _scrollToSelectedNetwork() {
    final networkProvider = Provider.of<NetworkProvider>(context, listen: false);
    final currentNetwork = networkProvider.currentNetwork;

    if (mounted) {
      final key = _networkKeys[currentNetwork];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Consumer<NetworkProvider>(
        builder: (context, networkProvider, child) {
          final networks = networkProvider.networks;
          final currentNetwork = networkProvider.currentNetwork;
          final isLoading = networkProvider.isLoading;

          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Create keys for networks if not already created
          for (final network in networks) {
            _networkKeys.putIfAbsent(network, () => GlobalKey());
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: BrandColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select Network',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.cream,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shrinkWrap: true,
                  children: networks.map((network) {
                    final isActive = network == currentNetwork;
                    return ListTile(
                      key: _networkKeys[network],
                      leading: CircleAvatar(
                        backgroundColor: BrandColors.sageBright
                            .withAlpha((0.16 * 255).toInt()),
                        child: const Icon(Icons.hub,
                            size: 18, color: BrandColors.sageBright),
                      ),
                      title: Text(
                        network.name,
                        style: TextStyle(
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'Chain ID: ${network.chainId}',
                        style: BrandColors.mono.copyWith(
                          fontSize: 12,
                          color: BrandColors.tan,
                        ),
                      ),
                      trailing: isActive
                          ? const Icon(Icons.check_circle,
                              color: BrandColors.verified)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.settings, color: BrandColors.tan),
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
