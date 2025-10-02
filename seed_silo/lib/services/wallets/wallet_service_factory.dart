import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/models/network_type.dart';
import 'package:seed_silo/services/wallets/base_wallet_service.dart';
import 'package:seed_silo/services/wallets/ethereum_wallet_service.dart';
// Import future implementations:
// import 'package:seed_silo/services/wallets/bitcoin_wallet_service.dart';
// import 'package:seed_silo/services/wallets/solana_wallet_service.dart';
// import 'package:seed_silo/services/wallets/cosmos_wallet_service.dart';

/// Factory to create the appropriate wallet service based on network type
class WalletServiceFactory {
  static final Map<NetworkType, BaseWalletService> _instances = {};

  /// Get wallet service for a specific network
  static BaseWalletService getWalletService(Network network) {
    // Return cached instance if exists
    if (_instances.containsKey(network.type)) {
      return _instances[network.type]!;
    }

    // Create new instance based on network type
    BaseWalletService service;
    switch (network.type) {
      case NetworkType.ethereum:
        service = EthereumWalletService();
        break;
      case NetworkType.bitcoin:
        // service = BitcoinWalletService();
        throw UnimplementedError('Bitcoin support coming soon');
      case NetworkType.solana:
        // service = SolanaWalletService();
        throw UnimplementedError('Solana support coming soon');
      case NetworkType.cosmos:
        // service = CosmosWalletService();
        throw UnimplementedError('Cosmos support coming soon');
    }

    _instances[network.type] = service;
    return service;
  }

  /// Clear all cached instances
  static void clearCache() {
    _instances.clear();
  }
}