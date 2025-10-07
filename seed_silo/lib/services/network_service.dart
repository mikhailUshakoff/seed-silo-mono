import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/models/network_add_result.dart';
import 'package:seed_silo/models/network_remove_result.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';

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

  /// Save networks to persistent storage
  Future<void> saveNetworks(List<Network> networks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = networks.map((n) => n.toJson()).toList();
    await prefs.setString(_networksKey, json.encode(jsonList));
  }

  /// Add a new network from RPC URL
  Future<NetworkAddResult> addNetwork(
      String rpcUrl, List<Network> currentNetworks) async {
    try {
      // Get chain ID from RPC
      final client = Web3Client(rpcUrl, http.Client());
      final chainId = (await client.getChainId()).toInt();

      // Check if network already exists
      if (currentNetworks.any((n) => n.chainId == chainId)) {
        return NetworkAddResult.error('Network already exists');
      }

      // Fetch network name from chainid.network
      final networkName = await fetchNetworkName(chainId);

      // Create network with fetched data
      final network = Network(
        name: networkName ?? 'Chain $chainId',
        rpcUrl: rpcUrl,
        chainId: chainId,
      );

      // Add the new network
      final updatedNetworks = List<Network>.from(currentNetworks)..add(network);

      // Save the updated network list
      await saveNetworks(updatedNetworks);

      return NetworkAddResult.success(updatedNetworks);
    } catch (e) {
      return NetworkAddResult.error('Failed to add network: ${e.toString()}');
    }
  }

  /// Remove a network by ID
  Future<NetworkRemoveResult> removeNetwork(int networkId,
      List<Network> currentNetworks, int currentNetworkId) async {
    try {
      // No-op if trying to remove the current network
      if (currentNetworkId == networkId) {
        return NetworkRemoveResult.error('Cannot remove the active network');
      }

      final initialLength = currentNetworks.length;
      final updatedNetworks =
          currentNetworks.where((n) => n.chainId != networkId).toList();

      if (updatedNetworks.length == initialLength) {
        return NetworkRemoveResult.error('Network not found');
      }

      await saveNetworks(updatedNetworks);
      return NetworkRemoveResult.success(updatedNetworks);
    } catch (e) {
      return NetworkRemoveResult.error(
          'Error removing network: ${e.toString()}');
    }
  }

  /// Fetch network name from chainid.network API
  Future<String?> fetchNetworkName(int chainId) async {
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
}
