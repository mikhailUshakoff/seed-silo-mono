import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/services/wallet_service.dart';

class NetworkService {
  static const String _networksKey = 'networks';
  static const String _currentNetworkKey = 'current_network';

  /// Get all configured networks from storage
  Future<List<Network>> getNetworks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_networksKey);

    if (jsonString == null) {
      // Default network
      final defaultNetworks = [
        Network(
          id: 'holesky',
          name: 'Ethereum Holesky',
          rpcUrl: 'https://ethereum-holesky-rpc.publicnode.com',
          chainId: 17000,
        ),
      ];
      await saveNetworks(defaultNetworks);
      return defaultNetworks;
    } else {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((e) => Network.fromJson(e)).toList();
    }
  }

  /// Get the currently active network from storage
  Future<Network?> getCurrentNetwork() async {
    final prefs = await SharedPreferences.getInstance();
    final networkId = prefs.getString(_currentNetworkKey);

    if (networkId != null) {
      final networks = await getNetworks();
      try {
        return networks.firstWhere((n) => n.id == networkId);
      } catch (e) {
        // Network not found, return first available
        if (networks.isNotEmpty) {
          await setCurrentNetwork(networks.first.id);
          return networks.first;
        }
      }
    } else {
      final networks = await getNetworks();
      if (networks.isNotEmpty) {
        await setCurrentNetwork(networks.first.id);
        return networks.first;
      }
    }

    return null;
  }

  /// Get the wallet service for the current network
  Future<WalletService?> getCurrentWallet() async {
    return WalletService();
  }

  /// Set the active network in storage
  Future<void> setCurrentNetwork(String networkId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentNetworkKey, networkId);
  }

  /// Clear current network from storage
  Future<void> clearCurrentNetwork() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentNetworkKey);
  }

  /// Save networks to persistent storage
  Future<void> saveNetworks(List<Network> networks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = networks.map((n) => n.toJson()).toList();
    await prefs.setString(_networksKey, json.encode(jsonList));
  }
}