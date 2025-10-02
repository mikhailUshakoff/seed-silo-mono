import 'package:seed_silo/models/network_type.dart';

class Network {
  final String id;
  final String name;
  final String rpcUrl;
  final int chainId;
  final NetworkType type;

  Network({
    required this.id,
    required this.name,
    required this.rpcUrl,
    required this.chainId,
    this.type = NetworkType.ethereum,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rpcUrl': rpcUrl,
        'chainId': chainId,
        'type': type.name,
      };

  factory Network.fromJson(Map<String, dynamic> json) => Network(
        id: json['id'] as String,
        name: json['name'] as String,
        rpcUrl: json['rpcUrl'] as String,
        chainId: json['chainId'] as int,
        type: json['type'] != null
            ? NetworkType.fromString(json['type'] as String)
            : NetworkType.ethereum,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Network && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}