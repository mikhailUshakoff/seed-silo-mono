const String nativeTokenAddress = '0x0000000000000000000000000000000000000000';

// ERC20 ABI for Ethereum-based tokens
const String erc20Abi = '''
      [
        {"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"type":"function"},
        {"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"},
        {"constant":true,"inputs":[{"name":"owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"type":"function"},
        {"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"type":"function"}
      ]
    ''';

const Token defaultNativeToken = Token(
  symbol: 'ETH',
  address: nativeTokenAddress,
  decimals: 18,
);

class Token {
  final String symbol;
  final String address;
  final int decimals;

  const Token(
      {required this.symbol, required this.address, required this.decimals});

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
