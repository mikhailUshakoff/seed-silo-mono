import 'package:flutter/foundation.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/services/network_service.dart';
import 'package:seed_silo/services/token_service.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NetworkAddResult {
  final bool success;
  final Network? network;
  final String? error;

  NetworkAddResult.success(this.network)
      : success = true,
        error = null;
  NetworkAddResult.error(this.error)
      : success = false,
        network = null;
}

class NetworkProvider extends ChangeNotifier {
  final NetworkService _networkService = NetworkService();

  List<Network> _networks = [];
  late Network _currentNetwork;
  bool _isLoading = false;

  List<Network> get networks => _networks;
  Network get currentNetwork => _currentNetwork;
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

  /// Add a new network from RPC URL
  Future<NetworkAddResult> addNetworkFromRpc(String rpcUrl) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get chain ID from RPC
      final client = Web3Client(rpcUrl, http.Client());
      final chainId = (await client.getChainId()).toInt();

      // Check if network already exists
      if (networkExistsByChainId(chainId)) {
        _isLoading = false;
        notifyListeners();
        return NetworkAddResult.error('Network already exists');
      }

      // Fetch network name from chainid.network
      final networkName = await _fetchNetworkName(chainId);

      // Create network with fetched data
      final network = Network(
        name: networkName ?? 'Chain $chainId',
        rpcUrl: rpcUrl,
        chainId: chainId,
      );

      await addNetwork(network);

      _isLoading = false;
      notifyListeners();
      return NetworkAddResult.success(network);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return NetworkAddResult.error('Failed to add network: ${e.toString()}');
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

  /// Remove a network by ID
  Future<void> removeNetwork(int networkId) async {
    // No-op if trying to remove the current network
    if (_currentNetwork.chainId == networkId) {
      return;
    }

    _networks.removeWhere((n) => n.chainId == networkId);
    await _networkService.saveNetworks(_networks);

    // Remove tokens for this network
    await TokenService.removeTokensForNetwork(networkId);
    notifyListeners();
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

  /// Clear all state (useful for testing or logout)
  void clearCache() {
    _networks.clear();
    notifyListeners();
  }
}
