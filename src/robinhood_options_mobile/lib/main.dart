import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
// import 'package:robinhood_options_mobile/model/drawer_provider.dart';
import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/copy_trading_provider.dart';
import 'package:robinhood_options_mobile/model/trade_signal_notifications_store.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/model/backtesting_provider.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/model/logo_provider.dart';
import 'package:robinhood_options_mobile/model/investor_group_store.dart';
import 'package:robinhood_options_mobile/model/options_flow_store.dart';
import 'package:robinhood_options_mobile/model/order_template_store.dart';
import 'package:robinhood_options_mobile/services/remote_config_service.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';
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

/// Requires that a Firestore emulator is running locally.
/// See https://firebase.flutter.dev/docs/firestore/usage#emulator-usage
bool shouldUseFirestoreEmulator =
    const bool.fromEnvironment('USE_FIRESTORE_EMULATOR', defaultValue: false);

late final FirebaseApp app;
late final FirebaseAuth auth;
late final AuthUtil authUtil;
late UserRole userRole;

void main() async {
  // Needed for Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await RemoteConfigService.initialize();

  auth = FirebaseAuth.instanceFor(app: app);

  authUtil = AuthUtil(auth);
  userRole = await authUtil.userRole();

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  if (shouldUseFirestoreEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  }

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
      // ColorScheme colorScheme = defaultTargetPlatform == TargetPlatform.iOS
      //     ? const ColorScheme.light(
      //         primary: Colors.indigo,
      //         secondary:
      //             // CupertinoColors.systemMint
      //             CupertinoColors.systemGrey4
      //         // Colors.indigoAccent
      //         )
      //     : lightDynamic ?? const ColorScheme.light();
      // primary: Color.fromRGBO(156, 39, 176, 0.7),
      // secondary: Color.fromRGBO(83, 109, 254, 0.7))
      // ColorScheme darkColorScheme = defaultTargetPlatform == TargetPlatform.iOS
      //     ? const ColorScheme.dark(
      //         primary: Colors.indigo, secondary: CupertinoColors.systemGrey
      //         // CupertinoColors.systemMint
      //         // Colors.indigoAccent
      //         )
      //     : darkDynamic ?? const ColorScheme.dark();
      ThemeData lightTheme = ThemeData(
        // colorScheme: colorScheme,
        colorScheme: ColorScheme.fromSeed(
          // seedColor: Color.fromARGB(255, 86, 136, 247), // Colors.lightBlue,
          // seedColor: const Color(0xFF003366), // RealizeAlpha Blue
          seedColor: const Color(0xFF002147), // RealizeAlpha Dark Blue
          // seedColor: const Color(0xFF00C805), // RealizeAlpha Green
          brightness: Brightness.light,
        ),
        // , textTheme: Typography.blackCupertino);
        useMaterial3: true,
        // appBarTheme: AppBarTheme(
        //     backgroundColor: colorScheme.primary,
        //     foregroundColor: Colors.white),
        // tabBarTheme: TabBarThemeData(
        //   dividerColor: Colors.transparent,
        //   labelColor: Colors.white,
        //   unselectedLabelColor: Colors.white70,
        // ),
        // chipTheme: ChipThemeData(
        //   side: BorderSide.none,
        //   // shape: LinearBorder()
        //   // StadiumBorder(side: BorderSide.none)
        // ),
        navigationBarTheme: const NavigationBarThemeData(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      );
      ThemeData darkTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          // seedColor: Color.fromARGB(255, 86, 136, 247), // Colors.lightBlue,
          // seedColor: const Color(0xFF003366), // RealizeAlpha Blue
          seedColor: const Color(0xFF002147), // RealizeAlpha Dark Blue
          // seedColor: const Color(0xFF00C805), // RealizeAlpha Green
          brightness: Brightness.dark,
        ),
        // colorScheme: darkColorScheme,
        // , textTheme: Typography.whiteHelsinki,
        useMaterial3: true,
        // , appBarTheme: AppBarTheme(backgroundColor: colorScheme.primary)
        // chipTheme: ChipThemeData(
        //   side: BorderSide.none,
        //   // shape: LinearBorder()
        //   // StadiumBorder(side: BorderSide.none)
        // ),
        navigationBarTheme: const NavigationBarThemeData(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      );
      return MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (context) => TradeSignalNotificationsStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => TradeSignalsProvider(),
            ),
            ChangeNotifierProvider(
              create: (context) => CopyTradingProvider(),
            ),
            ChangeNotifierProvider(
              create: (context) => BrokerageUserStore([], 0),
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
              create: (context) => DividendStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => InterestStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => ChartSelectionStore(),
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
            // ChangeNotifierProvider(
            //   create: (context) => DrawerProvider(),
            // ),
            ChangeNotifierProvider(
              create: (context) => LogoProvider(),
            ),
            ChangeNotifierProvider(
              create: (context) => GenerativeProvider(),
            ),
            ChangeNotifierProvider(
              create: (context) => AgenticTradingProvider(),
            ),
            ChangeNotifierProvider(
              create: (context) => BacktestingProvider(),
            ),
            ChangeNotifierProvider(
              create: (context) => InvestorGroupStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => OptionsFlowStore(),
            ),
            ChangeNotifierProvider(
              create: (context) => OrderTemplateStore(),
            ),
          ],
          child: MaterialApp(
            title: Constants.appTitle,
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: ThemeMode.system,
            routes: {
              '/': (context) => NavigationStatefulWidget(
                  analytics: analytics, observer: observer),
              // '/link': (context) => NavigationStatefulWidget(
              //     analytics: analytics, observer: observer)
              /*
                  '/login-callback': (context) => SearchWidget(
                      new RobinhoodUser(null, null, null, null), null,
                      analytics: analytics, observer: observer)
                      */
            },
            onGenerateRoute: (settings) {
              return null;
              // final args = settings.arguments as Map<String, String>;
              // /link?deep_link_id=https://realizealpha.firebaseapp.com/__/auth/callback?authType=verifyApp&recaptchaToken=03AFcWeA6KyGiTs1n0lQt0PyNjrOMK4qGOpSem0xif1zvWh1V4XkRqs9UKYJGHhm6_ohUE-5pHaEK-oQwSNKI72Efm8z9iXWEfOwCQriqEjZnahocnY34Et8--N6UK2z7Xhfje3yxHX7rYjXtcXkn7ROX-Z1vAmRuHdzEhqYN-4bG097MiGSZ5-mcmw0EtG-MTPjEytk3SCLENZ-xPaLGqRUpFUFYlCbE34wlCwK1S4xBOnAEwYv_i1Z1xAc3JvUdZGv_y4EnSLc7eHVNxES5RvSvIeV6DcdwYGMhVF2zgO0Tg348G5kFl5I2G1PInAdrS017RQlTbbVluA9uFc4llASHCxS63yf8i4oXF3XZUFrHOUeXEr4fyeJbprfHPXCaOEf_lpvNjcSRY0-SG6veDIYRdlDqL6mPB5phMoDBqqGa3xoGkQ6EgE45fugWFCzO3yQrG76Wel9Rg9NJXCqa9D3VwQ58doD7HUby2uNJzWh4gxtlX540CyVpzn-FftkB_gphIzep-NNd8MGnvEmKVkMY6_LRPolpf_usvglOsI5zLhtm8ToT-pQcpfKTCcePhZxj8uNVmTW5sdCUDHRbyqjDamavpZCfEQfTtEvmedt3cpjICv0ylJHruSo2CWrU7ZNvzH6eIYsE88Emkn_W0rxtI9ZqqfZvslYOu50P9TCCY1opWLIZIeLq65AmEcAwXwgxNqZS1PEr0LXNr8H-srNOg3-D1NadlF8i_QqwHilsZeBrdFE3WqFHqgjuf_PlgbLKLKar4gTgq9ZO5hMuGgK5iVDidcl97SXPb5-ar1BslBDEkx1NTLcYOfiUP3vgmlvsIwewP3-0yYf6ia3ub8bsMmdBt--N6cTW_LI0rgESX_Q-msVZBpiM97Lmo9tHNbvXgM_KRnRDjhUvEsyYvtE5gS7N77lPqwMzDvHWlIYOrXcPTFdRBqbfw1gpx7VjQJkWN8qZ2jKnx&eventId=WELJGKPZAM
              // return MaterialPageRoute(
              //     builder: (context) => NavigationStatefulWidget(
              //         analytics: analytics, observer: observer));
            },
            //home: NavigationStatefulWidget(analytics: analytics, observer: observer),
          ));
    });
  }
}
