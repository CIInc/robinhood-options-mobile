import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';

class _YahooFundamentalsFixture extends YahooService {
  @override
  Future<dynamic> getJson(String url) async => {
        'quoteResponse': {
          'result': [
            {
              'symbol': 'AAPL',
              'quoteType': 'EQUITY',
              'longName': 'Apple Inc.',
              'marketCap': 3000000000000,
            },
          ],
        },
      };

  @override
  Future<dynamic> getAssetProfile(String symbol) async => {
        'quoteSummary': {
          'result': [
            {
              'assetProfile': {
                'sector': 'Technology',
                'industry': 'Consumer Electronics',
                'city': 'Cupertino',
                'state': 'CA',
                'fullTimeEmployees': 164000,
                'longBusinessSummary': 'Technology company',
              },
            },
          ],
        },
      };
}

void main() {
  test('enriches Yahoo fundamentals with sector and industry', () async {
    final fundamentals =
        await _YahooFundamentalsFixture().getFundamentals(['AAPL']);

    expect(fundamentals, hasLength(1));
    expect(fundamentals.single.sector, 'Technology');
    expect(fundamentals.single.industry, 'Consumer Electronics');
    expect(fundamentals.single.headquartersCity, 'Cupertino');
  });
}
