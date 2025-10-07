import 'package:flutter/foundation.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/models/network_add_result.dart';
import 'package:seed_silo/models/network_remove_result.dart';
import 'package:seed_silo/services/network_service.dart';
import 'package:seed_silo/services/token_service.dart';

class NetworkProvider extends ChangeNotifier {
  final NetworkService _networkService = NetworkService();

  List<Network> _networks = [];
  late Network _currentNetwork = NetworkService.defaultNetwork;
  bool _isLoading = true;

  List<Network> get networks => _networks;
  Network get currentNetwork => _currentNetwork;
  bool get isLoading => _isLoading;

  /// Initialize the provider by loading networks
  Future<void> initialize() async {
    _setLoading(true);

    try {
      _networks = await _networkService.getNetworks();
      _currentNetwork = await _networkService.getCurrentNetwork();
    } finally {
      _setLoading(false);
    }
  }

  /// Add a new network from RPC URL
  Future<NetworkAddResult> addNetwork(String rpcUrl) async {
    _setLoading(true);

    try {
      final result = await _networkService.addNetwork(rpcUrl, _networks);

      if (result.success && result.networks != null) {
        _networks = result.networks!;
        return NetworkAddResult.success(_networks);
      } else {
        return NetworkAddResult.error(result.error ?? 'Unknown error occurred');
      }
    } catch (e) {
      return NetworkAddResult.error('Error adding network: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Remove a network by ID
  Future<NetworkRemoveResult> removeNetwork(int networkId) async {
    _setLoading(true);

    try {
      final result = await _networkService.removeNetwork(
          networkId, _networks, _currentNetwork.chainId);

      if (result.success && result.networks != null) {
        _networks = result.networks!;
        // Remove tokens for this network
        await TokenService.removeTokensForNetwork(networkId);
        return NetworkRemoveResult.success(_networks);
      } else {
        return NetworkRemoveResult.error(
            result.error ?? 'Unknown error occurred');
      }
    } catch (e) {
      return NetworkRemoveResult.error(
          'Error removing network: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Set the active network
  Future<void> setCurrentNetwork(int networkId) async {
    final network = _networks.firstWhere((n) => n.chainId == networkId);
    _currentNetwork = network;

    await _networkService.setCurrentNetwork(networkId);

    // TokenProvider will automatically handle token reloading via listener
    notifyListeners();
  }

  /// Check if a network exists by chain ID
  bool networkExistsByChainId(int chainId) {
    return _networks.any((n) => n.chainId == chainId);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Clear all state (useful for testing or logout)
  void clearCache() {
    _networks.clear();
    notifyListeners();
  }
}
