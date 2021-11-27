import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robinhood_options_mobile/widgets/navigation_widget.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

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
    /*
    ThemeData lightTheme, darkTheme;
    lightTheme =
        ThemeData(primarySwatch: Colors.teal, brightness: Brightness.light);
    darkTheme =
        ThemeData(primarySwatch: Colors.teal, brightness: Brightness.dark);
    */
    return DynamicColorBuilder(
        //future: DynamicColorPlugin.getCorePalette(),
        builder: (CorePalette? corePalette) {
      ColorScheme colorScheme = const ColorScheme.light();
      ColorScheme darkColorScheme = const ColorScheme.dark();
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
          ThemeData(colorScheme: colorScheme, useMaterial3: true);
      ThemeData darkTheme =
          ThemeData(colorScheme: darkColorScheme, useMaterial3: true);
      //lightTheme = ThemeData(primarySwatch: Colors.teal, brightness: Brightness.light);
      //darkTheme = ThemeData(primarySwatch: Colors.teal, brightness: Brightness.dark);
      return MaterialApp(
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
      );
    });
  }
}
