import 'package:seed_silo/models/network.dart';

class NetworkRemoveResult {
  final bool success;
  final List<Network>? networks;
  final String? error;

  NetworkRemoveResult.success(this.networks)
      : success = true,
        error = null;

  NetworkRemoveResult.error(this.error)
      : success = false,
        networks = null;
}
