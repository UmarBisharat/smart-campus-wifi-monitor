import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Obx(
            () => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Appearance',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                secondary: Icon(
                  themeController.isDarkMode.value
                      ? Icons.dark_mode
                      : Icons.light_mode,
                ),
                title: const Text('Dark Mode'),
                value: themeController.isDarkMode.value,
                onChanged: themeController.setDarkMode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}