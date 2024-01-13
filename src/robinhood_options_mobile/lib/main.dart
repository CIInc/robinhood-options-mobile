import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';

import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_event_store.dart';
import 'package:robinhood_options_mobile/model/option_historicals_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/stock_order_store.dart';
import 'package:robinhood_options_mobile/model/stock_position_store.dart';
import 'package:robinhood_options_mobile/model/user_store.dart';
import 'package:robinhood_options_mobile/widgets/navigation_widget.dart';
import 'package:dynamic_color/dynamic_color.dart';
//import 'package:material_color_utilities/material_color_utilities.dart';

void main() async {
  // Needed for Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // AdMob
  await MobileAds.instance.initialize();
  /*
  // Platform messages may fail, so we use a try/catch PlatformException.
  String? initialLink;
  try {
    initialLink = await getInitialLink();
    // Parse the link and warn the user, if it is not correct,
    // but keep in mind it could be `null`.
  } on PlatformException {
    // Handle exception by warning the user their action did not succeed
    // return?
  }

  // Attach a listener to the stream
  final _sub = linkStream.listen((String? link) async {
    // Parse the link and warn the user, if it is not correct
    debugPrint('newLink:$link');
    String code =
        link!.replaceFirst(RegExp(Constants.initialLinkLoginCallback), '');
    debugPrint('code:$code');
    var user = await TdAmeritradeService.getAccessToken(code);
    debugPrint('result:${jsonEncode(user)}');
    //var store = Provider.of<UserStore>(BuildContext(), listen: false);
    //await user!.save(store);
//    var grant = AuthorizationCodeGrant(Constants.tdClientId,
//        Constants.tdAuthEndpoint, Constants.tdTokenEndpoint);
//    var authorizationUrl =
        grant.getAuthorizationUrl(Uri.parse(Constants.tdRedirectUrl));
//    //var client = await grant.handleAuthorizationCode(code);
//    var parameters = Uri.parse(link).queryParameters;
//    debugPrint(jsonEncode(parameters));
//    var client = await grant.handleAuthorizationResponse(parameters);
//    debugPrint('credential:${jsonEncode(client.credentials)}');
  }, onError: (err) {
    // Handle exception by warning the user their action did not succeed
    debugPrint('linkStreamError:$err');
  });
  */
  /*
  // Add Test Devices:
  // A43B7A3B3E2A53090ACF37DCDA7528C6 = Aymeric Pixel 7
  RequestConfiguration configuration =
      RequestConfiguration(testDeviceIds: ["A43B7A3B3E2A53090ACF37DCDA7528C6"]);
  MobileAds.instance.updateRequestConfiguration(configuration);
  */

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    /*
    ThemeData lightTheme, darkTheme;
    lightTheme =
        ThemeData(primarySwatch: Colors.teal, brightness: Brightness.light);
    darkTheme =
        ThemeData(primarySwatch: Colors.teal, brightness: Brightness.dark);
    */
    return DynamicColorBuilder(
        //future: DynamicColorPlugin.getCorePalette(),
        //builder: (CorePalette? corePalette) {
        builder: (ColorScheme? colorScheme, ColorScheme? darkColorScheme) {
      // Platform.isAndroid
      ColorScheme colorScheme = defaultTargetPlatform == TargetPlatform.iOS ? 
        const ColorScheme.light(
          primary: Colors.purple,
          secondary: Colors.indigoAccent
        ) :
        const ColorScheme.light();
      ColorScheme darkColorScheme = defaultTargetPlatform == TargetPlatform.iOS ? 
        const ColorScheme.dark(
          primary: Colors.purple,
          secondary: Colors.indigoAccent
        ) :
        const ColorScheme.dark();
      /*
      if (corePalette != null) {
        colorScheme = colorScheme.copyWith(
          primary: Color(corePalette.primary.get(40)),
        );
        darkColorScheme = darkColorScheme.copyWith(
          primary: Color(corePalette.primary.get(80)),
        );
        colorScheme = colorScheme.harmonized();
        darkColorScheme = darkColorScheme.harmonized();
      }
      */
      /* else {
        colorScheme = colorScheme.copyWith(
          primary: Colors.teal,
        );
        darkColorScheme = darkColorScheme.copyWith(
          primary: Colors.teal,
        );
      }
      */
      ThemeData lightTheme =
          ThemeData(colorScheme: colorScheme
          // , textTheme: Typography.blackCupertino);
          , useMaterial3: true
          , appBarTheme: AppBarTheme(backgroundColor: colorScheme.primary)
          );
      ThemeData darkTheme =
          ThemeData(colorScheme: darkColorScheme
          // , textTheme: Typography.whiteHelsinki,
          // , useMaterial3: true
          // , appBarTheme: AppBarTheme(backgroundColor: colorScheme.primary)
          );
      //lightTheme = ThemeData(primarySwatch: Colors.teal, brightness: Brightness.light);
      //darkTheme = ThemeData(primarySwatch: Colors.teal, brightness: Brightness.dark);
      return MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (context) => UserStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => AccountStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => PortfolioStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => PortfolioHistoricalsStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => PortfolioHistoricalsSelectionStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => OptionPositionStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => OptionHistoricalsStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => OptionOrderStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => OptionEventStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => OptionInstrumentStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => StockPositionStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => StockOrderStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => ForexHoldingStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => InstrumentStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => InstrumentHistoricalsStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => InstrumentHistoricalsSelectionStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => QuoteStore(),
            )
          ],
          child: MaterialApp(
            title: 'Investing Mobile',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: ThemeMode.system,
            /*
        theme: ThemeData(
          // This is the theme of your application.
          //
          // Try running your application with "flutter run". You'll see the
          // application has a blue toolbar. Then, without quitting the app, try
          // changing the primarySwatch below to Colors.green and then invoke
          // "hot reload" (press "r" in the console where you ran "flutter run",
          // or simply save your changes to "hot reload" in a Flutter IDE).
          // Notice that the counter didn't reset back to zero; the application
          // is not restarted.
          primarySwatch: Colors.blue,
        ), */
            // home: OptionPositionsWidget()
            routes: {
              '/': (context) => NavigationStatefulWidget(
                  analytics: analytics, observer: observer),
              /*
              '/login-callback': (context) => SearchWidget(
                  new RobinhoodUser(null, null, null, null), null,
                  analytics: analytics, observer: observer)
                  */
            },
            //home: NavigationStatefulWidget(analytics: analytics, observer: observer),
          ));
    });
  }
}
