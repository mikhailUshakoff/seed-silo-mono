import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seed_silo/services/network_service.dart';

void main() {
  group('NetworkService', () {
    setUp(() {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('getNetworks returns 1 network when SharedPreferences is empty',
        () async {
      final networkService = NetworkService();

      final networks = await networkService.getNetworks();

      expect(networks.length, 1);
      expect(networks.first.name, 'Ethereum Holesky');
      expect(networks.first.chainId, 17000);
      expect(
          networks.first.rpcUrl, 'https://ethereum-holesky-rpc.publicnode.com');
    });
  });
}
