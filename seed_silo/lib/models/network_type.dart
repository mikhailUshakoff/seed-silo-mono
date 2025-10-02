enum NetworkType {
  ethereum('Ethereum', 'EVM-compatible networks'),
  bitcoin('Bitcoin', 'Bitcoin and forks'),
  solana('Solana', 'Solana network'),
  cosmos('Cosmos', 'Cosmos SDK chains');

  final String displayName;
  final String description;

  const NetworkType(this.displayName, this.description);

  static NetworkType fromString(String value) {
    return NetworkType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NetworkType.ethereum,
    );
  }
}