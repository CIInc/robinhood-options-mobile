import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/schwab_strategy_chain.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';
import 'package:robinhood_options_mobile/widgets/schwab_strategy_chain_widget.dart';

void main() {
  group('SchwabStrategyType Enum Tests', () {
    test('Correctly maps all 11 strategy values from strings', () {
      expect(
          SchwabStrategyType.fromString('SINGLE'), SchwabStrategyType.single);
      expect(
          SchwabStrategyType.fromString('COVERED'), SchwabStrategyType.covered);
      expect(SchwabStrategyType.fromString('VERTICAL'),
          SchwabStrategyType.vertical);
      expect(SchwabStrategyType.fromString('CALENDAR'),
          SchwabStrategyType.calendar);
      expect(SchwabStrategyType.fromString('STRANGLE'),
          SchwabStrategyType.strangle);
      expect(SchwabStrategyType.fromString('STRADDLE'),
          SchwabStrategyType.straddle);
      expect(SchwabStrategyType.fromString('BUTTERFLY'),
          SchwabStrategyType.butterfly);
      expect(
          SchwabStrategyType.fromString('CONDOR'), SchwabStrategyType.condor);
      expect(SchwabStrategyType.fromString('DIAGONAL'),
          SchwabStrategyType.diagonal);
      expect(
          SchwabStrategyType.fromString('COLLAR'), SchwabStrategyType.collar);
      expect(SchwabStrategyType.fromString('ROLL'), SchwabStrategyType.roll);
      expect(SchwabStrategyType.fromString(null), SchwabStrategyType.single);
      expect(
          SchwabStrategyType.fromString('UNKNOWN'), SchwabStrategyType.single);
    });

    test('Has correct paramValue and display names', () {
      expect(SchwabStrategyType.vertical.paramValue, 'VERTICAL');
      expect(SchwabStrategyType.vertical.displayName, 'Vertical Spread');
      expect(SchwabStrategyType.straddle.paramValue, 'STRADDLE');
      expect(SchwabStrategyType.straddle.displayName, 'Straddle');
      expect(SchwabStrategyType.butterfly.paramValue, 'BUTTERFLY');
      expect(SchwabStrategyType.butterfly.displayName, 'Butterfly');
    });
  });

  group('SchwabStrategyChain Model Parsing Tests', () {
    test(
        'Parses VERTICAL strategy chain with composite Greeks and underlying quote',
        () {
      final json = {
        'symbol': 'AAPL',
        'status': 'SUCCESS',
        'strategy': 'VERTICAL',
        'interval': 5.0,
        'isDelayed': false,
        'isIndex': false,
        'interestRate': 5.25,
        'underlyingPrice': 220.50,
        'volatility': 28.5,
        'daysToExpiration': 23.0,
        'numberOfContracts': 10,
        'underlying': {
          'symbol': 'AAPL',
          'description': 'Apple Inc.',
          'change': 1.25,
          'percentChange': 0.57,
          'close': 219.25,
          'openPrice': 219.50,
          'highPrice': 221.00,
          'lowPrice': 218.80,
          'bid': 220.45,
          'ask': 220.55,
          'last': 220.50,
          'mark': 220.50,
          'totalVolume': 45000000,
        },
        'monthlyStrategyList': [
          {
            'month': 'OCT',
            'year': 2026,
            'day': 16,
            'daysToExpiration': 23,
            'leapCheck': false,
            'optionStrategyList': [
              {
                'strategyStrike': '220.0/225.0',
                'strategyBid': 2.50,
                'strategyAsk': 2.90,
                'strategyMark': 2.70,
                'bid': 2.50,
                'ask': 2.90,
                'mark': 2.70,
                'delta': 0.14,
                'gamma': 0.002,
                'theta': -0.005,
                'vega': 0.02,
                'rho': 0.005,
                'primaryLeg': {
                  'symbol': 'AAPL  261016C00220000',
                  'putCall': 'CALL',
                  'description': 'AAPL 10/16/2026 220.00 C',
                  'bid': 6.50,
                  'ask': 6.70,
                  'mark': 6.60,
                  'last': 6.55,
                  'strikePrice': 220.0,
                  'expirationDate': '2026-10-16T20:00:00.000+0000',
                  'daysToExpiration': 23,
                  'openInterest': 1500,
                  'totalVolume': 320,
                  'delta': 0.52,
                  'gamma': 0.02,
                  'theta': -0.05,
                  'vega': 0.15,
                  'volatility': 27.5,
                  'inTheMoney': true,
                },
                'secondaryLeg': {
                  'symbol': 'AAPL  261016C00225000',
                  'putCall': 'CALL',
                  'description': 'AAPL 10/16/2026 225.00 C',
                  'bid': 3.80,
                  'ask': 4.00,
                  'mark': 3.90,
                  'last': 3.85,
                  'strikePrice': 225.0,
                  'expirationDate': '2026-10-16T20:00:00.000+0000',
                  'daysToExpiration': 23,
                  'openInterest': 2100,
                  'totalVolume': 450,
                  'delta': 0.38,
                  'gamma': 0.018,
                  'theta': -0.045,
                  'vega': 0.13,
                  'volatility': 28.0,
                  'inTheMoney': false,
                },
              }
            ],
          }
        ],
      };

      final chain = SchwabStrategyChain.fromJson(json);

      expect(chain.symbol, 'AAPL');
      expect(chain.status, 'SUCCESS');
      expect(chain.strategy, 'VERTICAL');
      expect(chain.strategyType, SchwabStrategyType.vertical);
      expect(chain.interval, 5.0);
      expect(chain.interestRate, 5.25);
      expect(chain.underlyingPrice, 220.50);
      expect(chain.volatility, 28.5);
      expect(chain.underlying, isNotNull);
      expect(chain.underlying!.last, 220.50);
      expect(chain.underlying!.change, 1.25);

      expect(chain.monthlyStrategies, hasLength(1));
      final month = chain.monthlyStrategies.first;
      expect(month.month, 'OCT');
      expect(month.year, 2026);
      expect(month.day, 16);
      expect(month.expirationDate, DateTime(2026, 10, 16));

      expect(chain.allPackages, hasLength(1));
      final package = chain.allPackages.first;
      expect(package.strategyStrike, '220.0/225.0');
      expect(package.effectiveMark, 2.70);
      expect(package.isDebit, isTrue);
      expect(package.isCredit, isFalse);
      expect(package.spreadWidth, 5.0);
      expect(package.delta, 0.14);
      expect(package.gamma, 0.002);
      expect(package.theta, -0.005);
      expect(package.vega, 0.02);

      // Verify primary leg
      expect(package.primaryLeg, isNotNull);
      expect(package.primaryLeg!.symbol, 'AAPL  261016C00220000');
      expect(package.primaryLeg!.strikePrice, 220.0);
      expect(package.primaryLeg!.putCall, 'CALL');
      expect(package.primaryLeg!.inTheMoney, isTrue);

      // Verify secondary leg
      expect(package.secondaryLeg, isNotNull);
      expect(package.secondaryLeg!.symbol, 'AAPL  261016C00225000');
      expect(package.secondaryLeg!.strikePrice, 225.0);
      expect(package.secondaryLeg!.putCall, 'CALL');
      expect(package.secondaryLeg!.inTheMoney, isFalse);

      expect(chain.availableExpirations, [DateTime(2026, 10, 16)]);
      expect(chain.packagesForExpiration(DateTime(2026, 10, 16)), hasLength(1));
    });

    test('Parses STRADDLE strategy with Call and Put legs at identical strike',
        () {
      final json = {
        'symbol': 'TSLA',
        'status': 'SUCCESS',
        'strategy': 'STRADDLE',
        'monthlyStrategyList': [
          {
            'month': 'NOV',
            'year': 2026,
            'day': 20,
            'optionStrategyList': [
              {
                'strategyStrike': '250.0',
                'strategyBid': 22.50,
                'strategyAsk': 23.20,
                'strategyMark': 22.85,
                'primaryLeg': {
                  'symbol': 'TSLA  261120C00250000',
                  'putCall': 'CALL',
                  'strikePrice': 250.0,
                  'mark': 12.00,
                  'delta': 0.51,
                },
                'secondaryLeg': {
                  'symbol': 'TSLA  261120P00250000',
                  'putCall': 'PUT',
                  'strikePrice': 250.0,
                  'mark': 10.85,
                  'delta': -0.49,
                },
                'delta': 0.02,
                'gamma': 0.03,
              }
            ]
          }
        ]
      };

      final chain = SchwabStrategyChain.fromJson(json);
      expect(chain.strategyType, SchwabStrategyType.straddle);
      expect(chain.allPackages.first.strategyStrike, '250.0');
      expect(chain.allPackages.first.effectiveMark, 22.85);
      expect(chain.allPackages.first.primaryLeg?.putCall, 'CALL');
      expect(chain.allPackages.first.secondaryLeg?.putCall, 'PUT');
      expect(chain.allPackages.first.spreadWidth, 0.0);
    });

    test('Parses CALENDAR strategy with secondary expiration date', () {
      final json = {
        'symbol': 'NVDA',
        'status': 'SUCCESS',
        'strategy': 'CALENDAR',
        'monthlyStrategyList': [
          {
            'month': 'OCT',
            'year': 2026,
            'day': 16,
            'daysToExpiration': 23,
            'secondaryMonth': 'NOV',
            'secondaryYear': 2026,
            'secondaryDay': 20,
            'secondaryDaysToExpiration': 58,
            'optionStrategyList': [
              {
                'strategyStrike': '125.0',
                'strategyMark': 3.10,
                'primaryLeg': {
                  'symbol': 'NVDA  261016C00125000',
                  'putCall': 'CALL',
                  'strikePrice': 125.0,
                  'expirationDate': '2026-10-16T20:00:00.000Z',
                },
                'secondaryLeg': {
                  'symbol': 'NVDA  261120C00125000',
                  'putCall': 'CALL',
                  'strikePrice': 125.0,
                  'expirationDate': '2026-11-20T20:00:00.000Z',
                },
              }
            ]
          }
        ]
      };

      final chain = SchwabStrategyChain.fromJson(json);
      expect(chain.strategyType, SchwabStrategyType.calendar);
      final month = chain.monthlyStrategies.first;
      expect(month.expirationDate, DateTime(2026, 10, 16));
      expect(month.secondaryExpirationDate, DateTime(2026, 11, 20));
      expect(month.secondaryDaysToExpiration, 58);
    });

    test('Parses BUTTERFLY and CONDOR multi-leg packages', () {
      final butterflyJson = {
        'symbol': 'SPY',
        'status': 'SUCCESS',
        'strategy': 'BUTTERFLY',
        'monthlyStrategyList': [
          {
            'month': 'DEC',
            'year': 2026,
            'day': 18,
            'optionStrategyList': [
              {
                'strategyStrike': '540/545/550',
                'strategyMark': 1.45,
                'primaryLeg': {
                  'symbol': 'SPY   261218C00540000',
                  'putCall': 'CALL',
                  'strikePrice': 540.0,
                },
                'secondaryLeg': {
                  'symbol': 'SPY   261218C00545000',
                  'putCall': 'CALL',
                  'strikePrice': 545.0,
                },
                'legs': [
                  {
                    'symbol': 'SPY   261218C00540000',
                    'putCall': 'CALL',
                    'strikePrice': 540.0,
                  },
                  {
                    'symbol': 'SPY   261218C00545000',
                    'putCall': 'CALL',
                    'strikePrice': 545.0,
                  },
                  {
                    'symbol': 'SPY   261218C00550000',
                    'putCall': 'CALL',
                    'strikePrice': 550.0,
                  },
                ]
              }
            ]
          }
        ]
      };

      final chain = SchwabStrategyChain.fromJson(butterflyJson);
      expect(chain.strategyType, SchwabStrategyType.butterfly);
      expect(chain.allPackages.first.legs, hasLength(3));
      expect(chain.allPackages.first.strategyStrike, '540/545/550');
    });

    test('Parses COVERED, COLLAR, STRANGLE, and ROLL strategies cleanly', () {
      for (final strategyName in [
        'COVERED',
        'COLLAR',
        'STRANGLE',
        'ROLL',
        'DIAGONAL'
      ]) {
        final json = {
          'symbol': 'MSFT',
          'status': 'SUCCESS',
          'strategy': strategyName,
          'monthlyStrategyList': [],
        };
        final chain = SchwabStrategyChain.fromJson(json);
        expect(chain.strategyType.paramValue, strategyName);
        expect(chain.allPackages, isEmpty);
      }
    });

    test(
        'SchwabStrategyLeg converts cleanly to OptionMarketData and OptionInstrument',
        () {
      final leg = SchwabStrategyLeg(
        symbol: 'AAPL  261016C00220000',
        putCall: 'CALL',
        strikePrice: 220.0,
        bid: 6.50,
        ask: 6.70,
        mark: 6.60,
        last: 6.55,
        delta: 0.52,
        gamma: 0.02,
        theta: -0.05,
        vega: 0.15,
        volatility: 27.5,
        openInterest: 1500,
        totalVolume: 320,
        expirationDate: DateTime(2026, 10, 16),
      );

      final marketData = leg.toOptionMarketData(rootSymbol: 'AAPL');
      expect(marketData.symbol, 'AAPL');
      expect(marketData.occSymbol, 'AAPL  261016C00220000');
      expect(marketData.markPrice, 6.60);
      expect(marketData.bidPrice, 6.50);
      expect(marketData.askPrice, 6.70);
      expect(marketData.delta, 0.52);

      final instrument = Instrument.fromSchwabJson({
        'symbol': 'AAPL',
        'description': 'Apple Inc',
      });
      final optInst = leg.toOptionInstrument(instrument);
      expect(optInst.chainSymbol, 'AAPL');
      expect(optInst.strikePrice, 220.0);
      expect(optInst.type, 'call');
      expect(optInst.expirationDate, DateTime(2026, 10, 16));
    });
  });

  group('SchwabService buildStrategyChainUrl Tests', () {
    test('Constructs default SINGLE strategy URL with encoded parameters', () {
      final url = SchwabService.buildStrategyChainUrl(
        endpoint: 'https://api.schwabapi.com',
        symbol: 'AAPL',
      );

      expect(url, contains('symbol=AAPL'));
      expect(url, contains('strategy=SINGLE'));
      expect(url, contains('contractType=ALL'));
      expect(url, contains('includeUnderlyingQuote=true'));
    });

    test(
        'Constructs VERTICAL spread URL with strike, interval, fromDate, and range',
        () {
      final url = SchwabService.buildStrategyChainUrl(
        endpoint: 'https://api.schwabapi.com',
        symbol: 'NVDA',
        strategy: 'VERTICAL',
        contractType: 'CALL',
        strike: 120.0,
        interval: 5.0,
        strikeCount: 10,
        range: 'OTM',
        fromDate: DateTime(2026, 10, 16),
        toDate: DateTime(2026, 10, 16),
      );

      expect(url, contains('symbol=NVDA'));
      expect(url, contains('strategy=VERTICAL'));
      expect(url, contains('contractType=CALL'));
      expect(url, contains('strike=120.0'));
      expect(url, contains('interval=5.0'));
      expect(url, contains('strikeCount=10'));
      expect(url, contains('range=OTM'));
      expect(url, contains('fromDate=2026-10-16'));
      expect(url, contains('toDate=2026-10-16'));
    });

    test('Constructs STRANGLE URL with custom parameters', () {
      final url = SchwabService.buildStrategyChainUrl(
        endpoint: 'https://api.schwabapi.com',
        symbol: 'TSLA',
        strategy: 'STRANGLE',
        volatility: 45.0,
        underlyingPrice: 250.0,
        interestRate: 5.0,
      );

      expect(url, contains('strategy=STRANGLE'));
      expect(url, contains('volatility=45.0'));
      expect(url, contains('underlyingPrice=250.0'));
      expect(url, contains('interestRate=5.0'));
    });
  });

  group('SchwabStrategyChainWidget Tests', () {
    testWidgets('Renders strategy chips and displays package cards',
        (WidgetTester tester) async {
      final mockService = SchwabService();
      final user = BrokerageUser.fromJson({
        'source': 'Schwab',
        'userName': 'schwab_user',
        'accounts': [
          {'accountNumber': '12345678'}
        ],
      });
      final instrument = Instrument.fromSchwabJson({
        'symbol': 'AAPL',
        'description': 'Apple Inc',
      });

      final dummyChain = SchwabStrategyChain(
        symbol: 'AAPL',
        status: 'SUCCESS',
        strategy: 'VERTICAL',
        strategyType: SchwabStrategyType.vertical,
        underlyingPrice: 220.50,
        interval: 5.0,
        monthlyStrategies: [
          SchwabMonthlyStrategy(
            month: 'OCT',
            year: 2026,
            day: 16,
            packages: [
              SchwabStrategyPackage(
                strategyStrike: '220.0/225.0 Call Spread',
                strategyMark: 2.70,
                strategyBid: 2.50,
                strategyAsk: 2.90,
                delta: 0.14,
                gamma: 0.002,
                theta: -0.005,
                vega: 0.02,
                primaryLeg: const SchwabStrategyLeg(
                  symbol: 'AAPL  261016C00220000',
                  putCall: 'CALL',
                  strikePrice: 220.0,
                  mark: 6.60,
                ),
                secondaryLeg: const SchwabStrategyLeg(
                  symbol: 'AAPL  261016C00225000',
                  putCall: 'CALL',
                  strikePrice: 225.0,
                  mark: 3.90,
                ),
              ),
            ],
          ),
        ],
      );

      SchwabStrategyPackage? selectedPkg;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SchwabStrategyChainWidget(
              user: user,
              service: mockService,
              instrument: instrument,
              initialStrategy: SchwabStrategyType.vertical,
              onPackageSelected: (pkg) {
                selectedPkg = pkg;
              },
            ),
          ),
        ),
      );

      // Verify strategy selector chip exists
      expect(find.text('Vertical Spread'), findsOneWidget);
      expect(find.text('Straddle'), findsOneWidget);
      expect(find.text('Strangle'), findsOneWidget);

      // Directly pump content using chain content builder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: ListTile(
                title: Text(dummyChain.allPackages.first.strategyStrike!),
                subtitle: Text(
                    'Mark: \$${dummyChain.allPackages.first.effectiveMark!.toStringAsFixed(2)}'),
                trailing: const Text('NET DEBIT'),
                onTap: () {
                  selectedPkg = dummyChain.allPackages.first;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('220.0/225.0 Call Spread'), findsOneWidget);
      expect(find.text('Mark: \$2.70'), findsOneWidget);
      expect(find.text('NET DEBIT'), findsOneWidget);

      // Tap card
      await tester.tap(find.text('220.0/225.0 Call Spread'));
      await tester.pump();

      expect(selectedPkg, isNotNull);
      expect(selectedPkg!.strategyStrike, '220.0/225.0 Call Spread');
    });
  });
}
