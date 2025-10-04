const String nativeTokenAddress = '0x0000000000000000000000000000000000000000';

const Token defaultNativeToken = Token(
  symbol: 'ETH',
  address: nativeTokenAddress,
  decimals: 18,
);

class Token {
  final String symbol;
  final String address;
  final int decimals;

  const Token({required this.symbol, required this.address, required this.decimals});

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
