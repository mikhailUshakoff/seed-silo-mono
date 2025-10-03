import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/models/network_type.dart';
import 'package:seed_silo/services/wallets/base_wallet_service.dart';
import 'package:seed_silo/services/wallets/ethereum_wallet.dart';
// Import future implementations:
// import 'package:seed_silo/services/wallets/bitcoin_wallet.dart';
// import 'package:seed_silo/services/wallets/solana_wallet.dart';
// import 'package:seed_silo/services/wallets/cosmos_wallet.dart';

/// Factory to create the appropriate wallet service based on network type
class WalletServiceFactory {
  static final Map<NetworkType, BaseWalletService> _instances = {};

  /// Get wallet service for a specific network
  static BaseWalletService getWalletService(Network network) {
    // Get or create instance for this network type
    BaseWalletService service;

    if (_instances.containsKey(network.type)) {
      service = _instances[network.type]!;
    } else {
      // Create new instance based on network type
      switch (network.type) {
        case NetworkType.ethereum:
          service = EthereumWallet();
          break;
      }

      _instances[network.type] = service;
    }

    // Set network context
    service.rpcUrl = network.rpcUrl;
    service.networkId = network.id;

    // Clear token cache when switching networks
    service.clearTokenCache();

    return service;
  }

  /// Clear all cached instances
  static void clearCache() {
    _instances.clear();
  }
}