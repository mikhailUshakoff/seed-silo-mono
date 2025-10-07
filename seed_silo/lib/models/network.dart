class Network {
  final String name;
  final String rpcUrl;
  final int chainId;

  Network({
    required this.name,
    required this.rpcUrl,
    required this.chainId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'rpcUrl': rpcUrl,
        'chainId': chainId,
      };

  factory Network.fromJson(Map<String, dynamic> json) => Network(
        name: json['name'] as String,
        rpcUrl: json['rpcUrl'] as String,
        chainId: json['chainId'] as int,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Network &&
          runtimeType == other.runtimeType &&
          chainId == other.chainId;

  @override
  int get hashCode => chainId.hashCode;
}
