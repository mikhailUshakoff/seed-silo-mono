import 'package:flutter/foundation.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/services/network_service.dart';
import 'package:seed_silo/services/token_service.dart';

class NetworkProvider extends ChangeNotifier {
  final NetworkService _networkService = NetworkService();

  List<Network> _networks = [];
  Network? _currentNetwork;
  bool _isLoading = false;

  List<Network> get networks => _networks;
  Network? get currentNetwork => _currentNetwork;
  bool get isLoading => _isLoading;

  /// Initialize the provider by loading networks
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _networks = await _networkService.getNetworks();
      _currentNetwork = await _networkService.getCurrentNetwork();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new network
  Future<void> addNetwork(Network network) async {
    if (_networks.any((n) => n.chainId == network.chainId)) {
      return;
    }

    _networks.add(network);
    await _networkService.saveNetworks(_networks);
    notifyListeners();
  }

  /// Remove a network by ID
  Future<void> removeNetwork(int networkId) async {
    _networks.removeWhere((n) => n.chainId == networkId);
    await _networkService.saveNetworks(_networks);

    // If current network was removed, switch to first available
    if (_currentNetwork?.chainId == networkId) {
      _currentNetwork = null;

      if (_networks.isNotEmpty) {
        await setCurrentNetwork(_networks.first.chainId);
      } else {
        await _networkService.clearCurrentNetwork();
      }
    }

    // Remove tokens for this network
    await TokenService.removeTokensForNetwork(networkId);
    notifyListeners();
  }

  /// Set the active network
  Future<void> setCurrentNetwork(int networkId) async {
    final network = _networks.firstWhere((n) => n.chainId == networkId);
    _currentNetwork = network;

    await _networkService.setCurrentNetwork(networkId);

    // Clear token cache when switching networks
    TokenService().clearCache();

    notifyListeners();
  }

  /// Check if a network exists by chain ID
  bool networkExistsByChainId(int chainId) {
    return _networks.any((n) => n.chainId == chainId);
  }

  /// Clear all state (useful for testing or logout)
  void clearCache() {
    _networks.clear();
    _currentNetwork = null;
    notifyListeners();
  }
}
