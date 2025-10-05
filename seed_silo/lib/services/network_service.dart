import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_silo/models/network.dart';

class NetworkService {
  static const String _networksKey = 'networks';
  static const String _currentNetworkKey = 'current_network';

  static final Network defaultNetwork = Network(
    name: 'Ethereum Holesky',
    rpcUrl: 'https://ethereum-holesky-rpc.publicnode.com',
    chainId: 17000,
  );

  /// Get all configured networks from storage
  /// If none exist, return a list with the default network
  /// Should always return at least one network
  Future<List<Network>> getNetworks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_networksKey);

    if (jsonString == null) {
      // Default network
      final defaultNetworks = [defaultNetwork];
      await saveNetworks(defaultNetworks);
      return defaultNetworks;
    } else {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((e) => Network.fromJson(e)).toList();
    }
  }

  /// Get the currently active network from storage
  Future<Network> getCurrentNetwork() async {
    final prefs = await SharedPreferences.getInstance();
    final networkId = prefs.getInt(_currentNetworkKey);
    final networks = await getNetworks();

    if (networkId != null) {
      try {
        // Find and return the network with the stored ID
        return networks.firstWhere((n) => n.chainId == networkId);
      } catch (e) {
        // Network not found, fall through to return first available
      }
    }

    // Return first available network and set it as current
    await setCurrentNetwork(networks.first.chainId);
    return networks.first;
  }

  /// Set the active network in storage
  Future<void> setCurrentNetwork(int networkId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentNetworkKey, networkId);
  }

/*
  /// Clear current network from storage
  Future<void> clearCurrentNetwork() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentNetworkKey);
  }
*/
  /// Save networks to persistent storage
  Future<void> saveNetworks(List<Network> networks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = networks.map((n) => n.toJson()).toList();
    await prefs.setString(_networksKey, json.encode(jsonList));
  }
}
