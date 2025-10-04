class Network {
  final String id;
  final String name;
  final String rpcUrl;
  final int chainId;

  Network({
    required this.id,
    required this.name,
    required this.rpcUrl,
    required this.chainId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rpcUrl': rpcUrl,
        'chainId': chainId,
      };

  factory Network.fromJson(Map<String, dynamic> json) => Network(
        id: json['id'] as String,
        name: json['name'] as String,
        rpcUrl: json['rpcUrl'] as String,
        chainId: json['chainId'] as int,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Network && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}