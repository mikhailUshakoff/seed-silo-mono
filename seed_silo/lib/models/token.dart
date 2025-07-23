class Token {
  final String symbol;
  final String address;
  final int decimals;

  Token({required this.symbol, required this.address, required this.decimals});

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      symbol: json['symbol'],
      address: json['address'],
      decimals: json['decimals'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'address': address,
      'decimals': decimals,
    };
  }
}
