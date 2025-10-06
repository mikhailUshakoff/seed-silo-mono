import 'package:seed_silo/models/network.dart';

class NetworkAddResult {
  final bool success;
  final List<Network>? networks;
  final String? error;

  NetworkAddResult.success(this.networks)
      : success = true,
        error = null;

  NetworkAddResult.error(this.error)
      : success = false,
        networks = null;
}
