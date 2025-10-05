import 'package:flutter/foundation.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/services/token_service.dart';
import 'package:seed_silo/providers/network_provider.dart';

class TokenProvider with ChangeNotifier {
  final NetworkProvider _networkProvider;

  TokenProvider(this._networkProvider) {
    _networkProvider.addListener(_onNetworkChanged);
    _initialize();
  }

  List<Token> _tokens = [];
  bool _isLoading = false;
  int? _currentNetworkId;

  List<Token> get tokens => _tokens;
  bool get isLoading => _isLoading;

  void _onNetworkChanged() {
    final newNetworkId = _networkProvider.currentNetwork.chainId;
    if (_currentNetworkId != newNetworkId) {
      loadTokens(newNetworkId);
    }
  }

  Future<void> _initialize() async {
    if (!_networkProvider.isLoading) {
      await loadTokens(_networkProvider.currentNetwork.chainId);
    }
  }

  Future<void> loadTokens(int networkId) async {
    if (_currentNetworkId == networkId && _tokens.isNotEmpty) {
      return; // Already loaded for this network
    }

    _setLoading(true);
    _currentNetworkId = networkId;

    try {
      _tokens = await TokenService().getTokens(networkId);
    } catch (e) {
      _tokens = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addToken(Network network, String address) async {
    _setLoading(true);

    try {
      final success = await TokenService().addToken(network, address);
      if (success) {
        _tokens = await TokenService().getTokens(network.chainId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> removeToken(int networkId, String address) async {
    _setLoading(true);

    try {
      await TokenService().removeToken(networkId, address);
      _tokens = await TokenService().getTokens(networkId);
      notifyListeners();
    } catch (e) {
      // Handle error silently
    } finally {
      _setLoading(false);
    }
  }

  void clearTokens() {
    _tokens = [];
    _currentNetworkId = null;
    TokenService().clearCache();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _networkProvider.removeListener(_onNetworkChanged);
    super.dispose();
  }

  /// Initialize the provider by loading tokens for the current network
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await loadTokens(_networkProvider.currentNetwork.chainId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
