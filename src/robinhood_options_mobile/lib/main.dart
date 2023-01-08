import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';
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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // await
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
      ColorScheme colorScheme = const ColorScheme.light();
      ColorScheme darkColorScheme = const ColorScheme.dark();
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
          ThemeData(colorScheme: colorScheme); //, useMaterial3: true
      ThemeData darkTheme =
          ThemeData(colorScheme: darkColorScheme); //, useMaterial3: true
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
            title: 'Robinhood Options',
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
            home: const NavigationStatefulWidget(),
            //HomePage(title: 'Robinhood Options'),
          ));
    });
  }
}
