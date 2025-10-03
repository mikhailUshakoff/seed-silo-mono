import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_silo/models/token.dart';

class TokenService {
  static const String _tokensKeyPrefix = 'tokens_';

  /// Load tokens for a specific network
  static Future<List<Token>> loadTokensForNetwork(String networkId, Token defaultNativeToken) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_tokensKeyPrefix$networkId');

    if (jsonString == null) {
      // Return default native token
      return [defaultNativeToken];
    } else {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((e) => Token.fromJson(e)).toList();
    }
  }

  /// Save a single token for a specific network
  static Future<void> saveTokenForNetwork(String networkId, String tokenAddress, Token token) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_tokensKeyPrefix}${networkId}_$tokenAddress';
    await prefs.setString(key, json.encode(token.toJson()));
  }

  /// Load a single token for a specific network and address
  static Future<Token?> loadTokenForNetwork(String networkId, String tokenAddress) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_tokensKeyPrefix}${networkId}_$tokenAddress';
    final jsonString = prefs.getString(key);

    if (jsonString == null) return null;

    final jsonData = json.decode(jsonString);
    return Token.fromJson(jsonData);
  }

  /// Remove a single token for a specific network and address
  static Future<void> removeTokenForNetwork(String networkId, String tokenAddress) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_tokensKeyPrefix}${networkId}_$tokenAddress';
    await prefs.remove(key);
  }

  /// Get all token keys for a network
  static Future<List<String>> getTokenKeysForNetwork(String networkId) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '${_tokensKeyPrefix}$networkId';
    return prefs.getKeys()
        .where((key) => key.startsWith(prefix))
        .map((key) => key.replaceFirst('${prefix}_', ''))
        .toList();
  }

  /// Remove all tokens for a specific network (called when network is deleted)
  static Future<void> removeTokensForNetwork(String networkId) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '${_tokensKeyPrefix}$networkId';
    final keysToRemove = prefs.getKeys().where((key) => key.startsWith(prefix));
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }
}