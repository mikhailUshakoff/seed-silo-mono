import 'package:seed_silo/models/token.dart';

class AddTokenResult {
  final List<Token>? tokens;
  final String? error;
  final bool success;

  AddTokenResult.success(this.tokens) : error = null, success = true;
  AddTokenResult.error(this.error) : tokens = null, success = false;
}
