import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

/// Student view: current outages + network health of every location.
class NetworkHealthScreen extends StatelessWidget {
  const NetworkHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Network Health',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: const DashboardBody(full: false),
    );
  }
}