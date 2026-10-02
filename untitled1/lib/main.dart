import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_controller.dart';
import 'home_screen.dart';
import 'login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();
  await Hive.openBox('chatsBox');

  final authController = Get.put(AuthController());
  final themeController = Get.put(ThemeController());

  await themeController.loadSettings();

  final loggedIn = await authController.isLoggedIn();

  runApp(MyApp(loggedIn: loggedIn));
}

// ============================================================
// THEME CONTROLLER (light / dark only)
// ============================================================

class ThemeController extends GetxController {
  final isDarkMode = false.obs;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode.value = prefs.getBool('isDarkMode') ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    isDarkMode.value = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);

    Get.changeTheme(AppThemes.getTheme(value));
  }
}

// ============================================================
// APP THEMES
// ============================================================

class AppThemes {
  static const Color primary = Color(0xFF1E3A5F);
  static const Color secondary = Color(0xFFE8F1FA);

  static ThemeData getTheme(bool darkMode) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );

    OutlineInputBorder border() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    );

    final bg = darkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surface = darkMode ? const Color(0xFF111827) : Colors.white;
    final card = darkMode ? const Color(0xFF1E293B) : Colors.white;
    final text = darkMode ? Colors.white : const Color(0xFF1F2937);

    return ThemeData(
      useMaterial3: true,
      brightness: darkMode ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,

      colorScheme: (darkMode ? const ColorScheme.dark() : const ColorScheme.light())
          .copyWith(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: darkMode ? const Color(0xFFEF4444) : const Color(0xFFDC2626),
        onPrimary: Colors.white,
        // secondary is always a light tint, so text on it stays dark
        onSecondary: darkMode ? const Color(0xFF1F2937) : Colors.black,
        onSurface: text,
        onError: Colors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),

      drawerTheme: DrawerThemeData(backgroundColor: surface),

      cardTheme: CardThemeData(color: card, elevation: 2),

      listTileTheme: ListTileThemeData(
        textColor: text,
        iconColor: primary,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkMode ? card : secondary,
        border: border(),
        enabledBorder: border(),
        focusedBorder: border(),
        prefixIconColor: primary,
        suffixIconColor: primary,
        labelStyle: darkMode ? const TextStyle(color: Colors.white70) : null,
        hintStyle: darkMode ? const TextStyle(color: Colors.white54) : null,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: shape,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: shape,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: primary,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),

      dividerTheme: DividerThemeData(
        color: darkMode ? Colors.white24 : Colors.black12,
      ),

      dialogTheme: darkMode
          ? const DialogThemeData(
        backgroundColor: Color(0xFF1E293B),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: Colors.white70,
          fontSize: 15,
        ),
      )
          : null,
    );
  }
}

// ============================================================
// MY APP
// ============================================================

class MyApp extends StatelessWidget {
  final bool loggedIn;

  const MyApp({super.key, required this.loggedIn});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Obx(() {
      final currentTheme = AppThemes.getTheme(themeController.isDarkMode.value);

      return GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Smart Campus Wi-Fi',
        theme: currentTheme,
        builder: (context, child) {
          return AnimatedTheme(
            data: currentTheme,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            // Keeps every screen clear of the Android navigation buttons.
            // The colour fills the strip behind them with the theme background.
            child: Container(
              color: currentTheme.scaffoldBackgroundColor,
              child: SafeArea(
                top: false, // AppBars already handle the top
                child: child ?? const SizedBox(),
              ),
            ),
          );
        },
        defaultTransition: Transition.fadeIn,
        transitionDuration: const Duration(milliseconds: 300),
        home: loggedIn ? const HomeScreen() : const LoginScreen(),
      );
    });
  }
}