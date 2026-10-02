import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExitAppHelper {
  static DateTime? _lastBackPressTime;

  static Future<bool> handleBackPress(BuildContext context) async {
    final now = DateTime.now();

    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit the app'),
          duration: Duration(seconds: 2),
        ),
      );

      return false;
    }

    await SystemNavigator.pop();
    return true;
  }
}
