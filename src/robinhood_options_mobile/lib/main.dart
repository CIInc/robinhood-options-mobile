import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/drawer_provider.dart';
import 'package:robinhood_options_mobile/model/logo_provider.dart';
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
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
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

  // AdMob - web not supported
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }

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
  const MyApp({super.key});

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
    return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      // Platform.isAndroid
      ColorScheme colorScheme = defaultTargetPlatform == TargetPlatform.iOS
          ? const ColorScheme.light(
              primary: Colors.purple, secondary: Colors.indigoAccent)
          : lightDynamic ?? const ColorScheme.light();
      // primary: Color.fromRGBO(156, 39, 176, 0.7),
      // secondary: Color.fromRGBO(83, 109, 254, 0.7))
      ColorScheme darkColorScheme = defaultTargetPlatform == TargetPlatform.iOS
          ? const ColorScheme.dark(
              primary: Colors.purple, secondary: Colors.indigoAccent)
          : darkDynamic ?? const ColorScheme.dark();
      ThemeData lightTheme = ThemeData(
          colorScheme: colorScheme
          // , textTheme: Typography.blackCupertino);
          ,
          useMaterial3: true,
          appBarTheme: AppBarTheme(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white));
      ThemeData darkTheme = ThemeData(
          colorScheme: darkColorScheme
          // , textTheme: Typography.whiteHelsinki,
          ,
          useMaterial3: true
          // , appBarTheme: AppBarTheme(backgroundColor: colorScheme.primary)
          );
      return MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (context) => BrokerageUserStore(),
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
              create: (context) => InstrumentPositionStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => InstrumentOrderStore(),
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
            ),
            ChangeNotifierProvider(
              create: (context) => DrawerProvider(),
            ),
            ChangeNotifierProvider(
              create: (context) => LogoProvider(),
            ),
          ],
          child: MaterialApp(
            title: Constants.appTitle,
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
