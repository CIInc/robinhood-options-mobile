import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:robinhood_options_mobile/services/fidelity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FidelityService quotes', () {
    test('parses Fidelity fastquote Map response correctly', () async {
      const mockResponse = '''
(
{
  "STATUS": {
    "ERROR_CODE": "0",
    "ERROR_TEXT": ""
  },
  "QUOTES": {
    "CRWD": {
      "SYMBOL": "CRWD",
      "REQUEST_SYMBOL": "CRWD",
      "BID_PRICE": "267.0000",
      "BID_SIZE": "80",
      "ASK_PRICE": "267.9800",
      "ASK_SIZE": "40",
      "LAST_PRICE": "268.5000",
      "PREV_CLOSE_PRICE": "265.10",
      "PREV_CLOSE_DATE": "10/01/2026",
      "TRADING_HALT_CODE": "N",
      "CUSIP": "22788C105"
    },
    "AMZN": {
      "SYMBOL": "AMZN",
      "REQUEST_SYMBOL": "AMZN",
      "BID_PRICE": "249.6800",
      "BID_SIZE": "100",
      "ASK_PRICE": "249.7900",
      "ASK_SIZE": "300",
      "LAST_PRICE": "1,248.2300",
      "PREV_CLOSE_PRICE": "1,245.00",
      "PREV_CLOSE_DATE": "10/01/2026",
      "TRADING_HALT_CODE": "N"
    }
  }
}
)
''';

      final client = MockClient((request) async {
        return http.Response(mockResponse, 200);
      });

      final service = FidelityService(httpClient: client);
      final quotes = await service.getQuotesFromFidelity(['CRWD', 'AMZN']);

      expect(quotes.length, 2);

      final crwd = quotes.firstWhere((q) => q.symbol == 'CRWD');
      expect(crwd.symbol, 'CRWD');
      expect(crwd.bidPrice, 267.0);
      expect(crwd.bidSize, 80);
      expect(crwd.askPrice, 267.98);
      expect(crwd.askSize, 40);
      expect(crwd.lastTradePrice, 268.5);
      expect(crwd.previousClose, 265.10);
      expect(crwd.instrumentId, '22788C105');
      expect(crwd.tradingHalted, isFalse);

      final amzn = quotes.firstWhere((q) => q.symbol == 'AMZN');
      expect(amzn.symbol, 'AMZN');
      expect(amzn.bidPrice, 249.68);
      expect(amzn.bidSize, 100);
      expect(amzn.askPrice, 249.79);
      expect(amzn.askSize, 300);
      // Tests string with comma parsing: "1,248.2300"
      expect(amzn.lastTradePrice, 1248.23);
      expect(amzn.previousClose, 1245.00);
    });

    test('preserves requested symbol mapping like ^GSPC to .SPX', () async {
      const mockResponse = '''
(
{
  "STATUS": {
    "ERROR_CODE": "0",
    "ERROR_TEXT": ""
  },
  "QUOTES": {
    ".SPX": {
      "SYMBOL": ".SPX",
      "REQUEST_SYMBOL": ".SPX",
      "LAST_PRICE": "7,666.45",
      "OPEN_PRICE": "7666.47",
      "PREV_CLOSE_PRICE": "7,666.45"
    }
  }
}
)
''';

      final client = MockClient((request) async {
        expect(request.url.queryParameters['symbols'], contains('.SPX'));
        return http.Response(mockResponse, 200);
      });

      final service = FidelityService(httpClient: client);
      final quotes = await service.getQuotesFromFidelity(['^GSPC']);

      expect(quotes.length, 1);
      final spx = quotes.first;
      expect(spx.symbol, '^GSPC');
      expect(spx.lastTradePrice, 7666.45);
    });
  });
}
