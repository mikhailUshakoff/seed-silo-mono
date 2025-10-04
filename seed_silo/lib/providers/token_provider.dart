import 'package:flutter/foundation.dart';
import 'package:seed_silo/models/token.dart';
import 'package:seed_silo/models/network.dart';
import 'package:seed_silo/services/token_service.dart';

class TokenProvider with ChangeNotifier {
  static final TokenProvider _instance = TokenProvider._internal();
  factory TokenProvider() => _instance;
  TokenProvider._internal();

  List<Token> _tokens = [];
  bool _isLoading = false;
  int? _currentNetworkId;

  List<Token> get tokens => _tokens;
  bool get isLoading => _isLoading;

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
}
