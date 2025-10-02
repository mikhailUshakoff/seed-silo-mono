import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_silo/models/network.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  static const String _networksKey = 'networks';
  static const String _currentNetworkKey = 'current_network';

  List<Network> _networks = [];
  Network? _currentNetwork;

  /// Get all configured networks
  Future<List<Network>> getNetworks() async {
    if (_networks.isNotEmpty) return _networks;

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_networksKey);

    if (jsonString == null) {
      // Default network
      _networks = [
        Network(
          id: 'holesky',
          name: 'Ethereum Holesky',
          rpcUrl: 'https://ethereum-holesky-rpc.publicnode.com',
          chainId: 17000,
        ),
      ];
      await _saveNetworks();
    } else {
      final List<dynamic> jsonList = json.decode(jsonString);
      _networks = jsonList.map((e) => Network.fromJson(e)).toList();
    }

    return _networks;
  }

  /// Add a new network
  Future<void> addNetwork(Network network) async {
    if (_networks.any((n) => n.id == network.id)) {
      return;
    }
    _networks.add(network);
    await _saveNetworks();
  }

  /// Remove a network by ID
  Future<void> removeNetwork(String networkId) async {
    _networks.removeWhere((n) => n.id == networkId);
    await _saveNetworks();

    // If current network was removed, switch to first available
    if (_currentNetwork?.id == networkId && _networks.isNotEmpty) {
      await setCurrentNetwork(_networks.first.id);
    } else if (_networks.isEmpty) {
      _currentNetwork = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentNetworkKey);
    }
  }

  /// Get the currently active network
  Future<Network?> getCurrentNetwork() async {
    if (_currentNetwork != null) return _currentNetwork;

    final prefs = await SharedPreferences.getInstance();
    final networkId = prefs.getString(_currentNetworkKey);

    await getNetworks(); // Ensure networks are loaded

    if (networkId != null) {
      _currentNetwork = _networks.firstWhere(
        (n) => n.id == networkId,
        orElse: () => _networks.first,
      );
    } else if (_networks.isNotEmpty) {
      _currentNetwork = _networks.first;
      await prefs.setString(_currentNetworkKey, _currentNetwork!.id);
    }

    return _currentNetwork;
  }

  /// Set the active network
  Future<void> setCurrentNetwork(String networkId) async {
    final network = _networks.firstWhere((n) => n.id == networkId);
    _currentNetwork = network;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentNetworkKey, networkId);
  }

  /// Check if a network exists by chain ID
  bool networkExistsByChainId(int chainId) {
    return _networks.any((n) => n.chainId == chainId);
  }

  /// Save networks to persistent storage
  Future<void> _saveNetworks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _networks.map((n) => n.toJson()).toList();
    await prefs.setString(_networksKey, json.encode(jsonList));
  }

  /// Clear cache (useful for testing or logout)
  void clearCache() {
    _networks.clear();
    _currentNetwork = null;
  }
}