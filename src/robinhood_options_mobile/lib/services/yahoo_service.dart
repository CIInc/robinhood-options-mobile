import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class YahooService {
  final http.Client httpClient = http.Client();

  // YahooService({required this.httpClient});
  /*
{
  "chart": {
    "result": [
      {
        "meta": {
          "currency": "USD",
          "symbol": "^IXIC",
          "exchangeName": "NIM",
          "fullExchangeName": "Nasdaq GIDS",
          "instrumentType": "INDEX",
          "firstTradeDate": 34612200,
          "regularMarketTime": 1740176159,
          "hasPrePostMarketData": false,
          "gmtoffset": -18000,
          "timezone": "EST",
          "exchangeTimezoneName": "America/New_York",
          "regularMarketPrice": 19524.006,
          "fiftyTwoWeekHigh": 20204.58,
          "fiftyTwoWeekLow": 15222.78,
          "regularMarketDayHigh": 20016.662,
          "regularMarketDayLow": 19510.908,
          "regularMarketVolume": 7873054000,
          "longName": "NASDAQ Composite",
          "shortName": "NASDAQ Composite",
          "chartPreviousClose": 19310.79,
          "priceHint": 2,
          "currentTradingPeriod": {
            "pre": {
              "timezone": "EST",
              "end": 1740148200,
              "start": 1740128400,
              "gmtoffset": -18000
            },
            "regular": {
              "timezone": "EST",
              "end": 1740171600,
              "start": 1740148200,
              "gmtoffset": -18000
            },
            "post": {
              "timezone": "EST",
              "end": 1740186000,
              "start": 1740171600,
              "gmtoffset": -18000
            }
          },
          "dataGranularity": "1d",
          "range": "ytd",
          "validRanges": [
            "1d",
            "5d",
            "1mo",
            "3mo",
            "6mo",
            "1y",
            "2y",
            "5y",
            "10y",
            "ytd",
            "max"
          ]
        },
        "timestamp": [
          1735828200,
          1735914600,
          1736173800,
          1736260200,
          1736346600,
          1736519400,
          1736778600,
          1736865000,
          1736951400,
          1737037800,
          1737124200,
          1737469800,
          1737556200,
          1737642600,
          1737729000,
          1737988200,
          1738074600,
          1738161000,
          1738247400,
          1738333800,
          1738593000,
          1738679400,
          1738765800,
          1738852200,
          1738938600,
          1739197800,
          1739284200,
          1739370600,
          1739457000,
          1739543400,
          1739889000,
          1739975400,
          1740061800,
          1740176159
        ],
        "indicators": {
          "quote": [
            {
              "high": [
                19517.869140625,
                19638.66015625,
                20007.94921875,
                19940.2109375,
                19544.509765625,
                19315.109375,
                19099.970703125,
                19273.140625,
                19548.900390625,
                19579.849609375,
                19709.640625,
                19789.630859375,
                20068.51953125,
                20053.6796875,
                20118.609375,
                19514.349609375,
                19759.4296875,
                19699.8203125,
                19785.7890625,
                19969.169921875,
                19502.130859375,
                19666.439453125,
                19696.939453125,
                19793.359375,
                19862.5390625,
                19772.0390625,
                19731.9296875,
                19682.509765625,
                19952.169921875,
                20045.759765625,
                20110.119140625,
                20099.390625,
                20041.150390625,
                20016.662109375
              ],
              "open": [
                19403.900390625,
                19395.509765625,
                19851.990234375,
                19938.080078125,
                19469.369140625,
                19312.259765625,
                18903.66015625,
                19207.75,
                19350.310546875,
                19573.869140625,
                19655.55078125,
                19734.390625,
                19903.05078125,
                19906.990234375,
                20087.109375,
                19234.0390625,
                19418.220703125,
                19695.6796875,
                19697.529296875,
                19832.330078125,
                19215.380859375,
                19422.169921875,
                19533.05078125,
                19725.830078125,
                19774.869140625,
                19668.1796875,
                19602.109375,
                19436.509765625,
                19696.919921875,
                19956.8203125,
                20090.55078125,
                19994.5,
                20029.189453125,
                20006.69921875
              ],
              "low": [
                19117.58984375,
                19379.5703125,
                19785.0,
                19421.01953125,
                19308.5390625,
                19018.75,
                18831.91015625,
                18926.599609375,
                19299.3203125,
                19335.6796875,
                19543.3203125,
                19551.169921875,
                19903.05078125,
                19892.55078125,
                19897.130859375,
                19204.94921875,
                19294.619140625,
                19479.509765625,
                19483.830078125,
                19575.2109375,
                19141.150390625,
                19408.1796875,
                19498.900390625,
                19654.109375,
                19489.359375,
                19650.7890625,
                19579.76953125,
                19415.48046875,
                19675.869140625,
                19932.150390625,
                19909.740234375,
                19928.890625,
                19795.01953125,
                19510.908203125
              ],
              "close": [
                19280.7890625,
                19621.6796875,
                19864.98046875,
                19489.6796875,
                19478.880859375,
                19161.630859375,
                19088.099609375,
                19044.390625,
                19511.23046875,
                19338.2890625,
                19630.19921875,
                19756.779296875,
                20009.33984375,
                20053.6796875,
                19954.30078125,
                19341.830078125,
                19733.58984375,
                19632.3203125,
                19681.75,
                19627.439453125,
                19391.9609375,
                19654.01953125,
                19692.330078125,
                19791.990234375,
                19523.400390625,
                19714.26953125,
                19643.859375,
                19649.94921875,
                19945.640625,
                20026.76953125,
                20041.259765625,
                20056.25,
                19962.359375,
                19524.005859375
              ],
              "volume": [
                8737550000,
                8214050000,
                9586840000,
                13371130000,
                8851720000,
                8608880000,
                7830760000,
                7168110000,
                7260250000,
                7085990000,
                7996360000,
                8015780000,
                7219060000,
                6837700000,
                7708150000,
                8870200000,
                7121740000,
                6497710000,
                6679500000,
                7947370000,
                8272460000,
                6477050000,
                6712220000,
                6642100000,
                7748940000,
                9535440000,
                9269380000,
                7946550000,
                8414510000,
                7995720000,
                8683170000,
                8171530000,
                7329270000,
                7873054000
              ]
            }
          ],
          "adjclose": [
            {
              "adjclose": [
                19280.7890625,
                19621.6796875,
                19864.98046875,
                19489.6796875,
                19478.880859375,
                19161.630859375,
                19088.099609375,
                19044.390625,
                19511.23046875,
                19338.2890625,
                19630.19921875,
                19756.779296875,
                20009.33984375,
                20053.6796875,
                19954.30078125,
                19341.830078125,
                19733.58984375,
                19632.3203125,
                19681.75,
                19627.439453125,
                19391.9609375,
                19654.01953125,
                19692.330078125,
                19791.990234375,
                19523.400390625,
                19714.26953125,
                19643.859375,
                19649.94921875,
                19945.640625,
                20026.76953125,
                20041.259765625,
                20056.25,
                19962.359375,
                19524.005859375
              ]
            }
          ]
        }
      }
    ],
    "error": null
  }
}  */
  Future<dynamic> getMarketIndexHistoricals(
      {String symbol = "^GSP",
      String range = "ytd", // 1y
      String interval = "1d"}) async {
    var url =
        "https://query1.finance.yahoo.com/v8/finance/chart/${Uri.encodeFull(symbol)}?events=capitalGain%7Cdiv%7Csplit&formatted=true&includeAdjustedClose=true&interval=$interval&range=$range&symbol=${Uri.encodeFull(symbol)}&userYfid=true&lang=en-US&region=US";
    var entryJson = await getJson(url);
    return entryJson;
  }

  Future<dynamic> getStockScreener({
    int count = 25,
    String scrIds = 'most_actives',
    int start = 0,
    String lang = 'en-US',
    String region = 'US',
    String sortField = '',
    String sortType = '',
    bool formatted = true,
    bool useRecordsResponse = true,
    bool betaFeatureFlag = true,
  }) async {
    final url = Uri.parse(
        'https://query1.finance.yahoo.com/v1/finance/screener/predefined/saved'
        '?count=$count'
        '&formatted=$formatted'
        '&scrIds=$scrIds'
        '&sortField=$sortField'
        '&sortType=$sortType'
        '&start=$start'
        '&useRecordsResponse=$useRecordsResponse'
        '&betaFeatureFlag=$betaFeatureFlag'
        '&lang=$lang'
        '&region=$region');
    var responseJson = await getJson(url.toString());
    return responseJson;
  }

  Future<dynamic> getJson(String url) async {
    // debugPrint(url);
    Stopwatch stopwatch = Stopwatch();
    stopwatch.start();
    String responseStr = await httpClient.read(Uri.parse(url));
    debugPrint(
        "${(responseStr.length / 1000)}K in ${stopwatch.elapsed.inMilliseconds}ms $url");
    dynamic responseJson = jsonDecode(responseStr);
    return responseJson;
  }
}

class MarketIndicesModel extends ValueNotifier<dynamic> {
  MarketIndicesModel(super.initialValue);

  void set(dynamic newValue) {
    value = newValue;
  }
}
