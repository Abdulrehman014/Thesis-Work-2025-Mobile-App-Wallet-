// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/provider.dart';
import 'views/login_view.dart';
import 'views/credential_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // White status bar icons on your green status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    // statusBarColor: Color(0xFF0A63C9),
    statusBarColor: Color(0xFF1E315A),
    statusBarIconBrightness: Brightness.light,
  ));

  // Check for existing token
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final isLoggedIn = token != null && token.isNotEmpty;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DataProviders>(create: (_) => DataProviders()),
      ],
      child: MyApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WaltID',
        theme: ThemeData(
          primaryColor: const Color(0xFF1E315A),
          scaffoldBackgroundColor: const Color(0xFF0F2E66),
          colorScheme: ColorScheme.fromSwatch().copyWith(
            secondary: const Color(0xFF0A63C9),
          ),
        ),
        // Show home or login based on presence of token
        home: isLoggedIn ? const CredentialView() : const LoginView(),
      ),
    );
  }
}

// lib/main.dart

/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'utils/provider.dart';
import 'views/login_view.dart';
import 'views/credential_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // White status bar icons on your dark header
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF1E315A),
    statusBarIconBrightness: Brightness.light,
  ));

  // Check for existing token to decide initial route
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final isLoggedIn = token != null && token.isNotEmpty;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DataProviders()),
      ],
      child: MyApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<DataProviders>().isDark;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WaltID',

        // Light theme
        theme: ThemeData(
          brightness: Brightness.light,
          primaryColor: const Color(0xFF0A63C9),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0A63C9),
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
          ),
          cardColor: Colors.white,
          colorScheme: ColorScheme.fromSwatch()
              .copyWith(secondary: const Color(0xFF1E315A)),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade200,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        // Dark theme (your existing green/blue look)
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF1B5E20),
          scaffoldBackgroundColor: const Color(0xFF0F2E66),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1B5E20),
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
          ),
          cardColor: const Color(0xFF1E315A),
          colorScheme: ColorScheme.fromSwatch()
              .copyWith(secondary: const Color(0xFF0A63C9)),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white24,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        // Switch based on your provider flag
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

        // Start screen
        home: isLoggedIn ? const CredentialView() : const LoginView(),
      ),
    );
  }
}*/
