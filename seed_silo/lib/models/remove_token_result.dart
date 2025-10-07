import 'package:seed_silo/models/token.dart';

class RemoveTokenResult {
  final List<Token>? tokens;
  final String? error;
  final bool success;

  RemoveTokenResult.success(this.tokens)
      : error = null,
        success = true;
  RemoveTokenResult.error(this.error)
      : tokens = null,
        success = false;
}
