import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_screen.dart';
import 'analytics_screen.dart';
import 'auth_controller.dart';
import 'chatbot_screen.dart';
import 'complaint_screen.dart';
import 'credits_screen.dart';
import 'dashboard_screen.dart';
import 'exit_app_helper.dart';
import 'health_thresholds_screen.dart';
import 'history_screen.dart';
import 'manage_complaints_screen.dart';
import 'manage_locations_screen.dart';
import 'manage_users_screen.dart';
import 'manager_screen.dart';
import 'network_health.dart';
import 'network_health_screen.dart';
import 'permission_service.dart';
import 'role_permissions_screen.dart';
import 'settings_screen.dart';
import 'speed_test_screen.dart';
import 'system_report_screen.dart';
import 'test_results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthController authController = Get.find();

  String? profileImagePath;
  String? role;
  String name = '';
  Set<String> perms = {};

  static const titles = {
    'student': 'Smart Campus Wi-Fi',
    'it_staff': 'IT Support',
    'manager': 'Network Manager',
    'admin': 'Admin Panel',
  };

  @override
  void initState() {
    super.initState();
    loadProfileImage();
    loadUser();
  }

  Future<void> loadUser() async {
    final r = await authController.getRole();
    final n = await authController.getName();
    final p = await PermissionService.forRole(r);
    NetworkHealth.listen(); // keeps admin-configured thresholds in sync
    if (mounted) {
      setState(() {
        role = r;
        name = n;
        perms = p;
      });
    }
  }

  Future<void> loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('profileImage');
    if (mounted) setState(() => profileImagePath = savedPath);
  }

  bool get hasProfileImage =>
      profileImagePath != null &&
          profileImagePath!.isNotEmpty &&
          File(profileImagePath!).existsSync();

  Widget _btn(IconData icon, String label, Widget page,
      {bool filled = false}) {
    final child = Text(label, textAlign: TextAlign.center);
    return Expanded(
      child: SizedBox(
        height: 48,
        child: filled
            ? ElevatedButton.icon(
          icon: Icon(icon),
          label: child,
          onPressed: () => Get.to(() => page),
        )
            : OutlinedButton.icon(
          icon: Icon(icon),
          label: child,
          onPressed: () => Get.to(() => page),
        ),
      ),
    );
  }

  Widget _actions() {
    final buttons = <Widget>[];

    void add(String perm, IconData icon, String label, Widget page,
        {bool filled = false}) {
      if (perms.contains(perm)) {
        buttons.add(_btn(icon, label, page, filled: filled));
      }
    }

    // Permission-based buttons (admin can grant/revoke these per role)
    add('run_speed_test', Icons.speed, 'Speed Test', const SpeedTestScreen(),
        filled: true);
    add('submit_complaint', Icons.report_problem_outlined, 'Report',
        const ComplaintScreen());
    add('view_network_health', Icons.network_check, 'Network Health',
        const NetworkHealthScreen());
    add('manage_complaints', Icons.support_agent, 'Complaints',
        const ManageComplaintsScreen());
    add('view_test_results', Icons.speed, 'Test Results',
        const TestResultsScreen());
    add('manager_dashboard', Icons.admin_panel_settings_outlined,
        'Manager Dashboard', const ManagerScreen());
    add('view_analytics', Icons.analytics_outlined, 'Analytics',
        const AnalyticsScreen());
    add('manage_locations', Icons.location_on_outlined, 'Locations',
        const ManageLocationsScreen());

    // Admin-only buttons
    if (role == 'admin') {
      buttons.addAll([
        _btn(Icons.people, 'Users', const ManageUsersScreen()),
        _btn(Icons.lock_person_outlined, 'Permissions',
            const RolePermissionsScreen()),
        _btn(Icons.summarize_outlined, 'System Report',
            const SystemReportScreen()),
        _btn(Icons.tune, 'Thresholds', const HealthThresholdsScreen()),
      ]);
    }

    if (buttons.isEmpty) return const SizedBox();

    final rows = <Widget>[];
    for (int i = 0; i < buttons.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(Row(children: [
        buttons[i],
        if (i + 1 < buttons.length) ...[
          const SizedBox(width: 8),
          buttons[i + 1],
        ],
      ]));
    }
    return Column(children: rows);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await ExitAppHelper.handleBackPress(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            titles[role] ?? 'Smart Campus Wi-Fi',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        // DRAWER
        drawer: Drawer(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(
                  name.isEmpty ? 'Loading...' : name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(role ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: hasProfileImage
                      ? FileImage(File(profileImagePath!))
                      : null,
                  child: !hasProfileImage
                      ? Icon(Icons.person,
                      size: 40, color: colorScheme.primary)
                      : null,
                ),
                decoration: BoxDecoration(color: colorScheme.primary),
              ),
              ListTile(
                leading: Icon(Icons.home, color: colorScheme.primary),
                title: const Text('Home',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                tileColor: colorScheme.secondary.withOpacity(0.3),
                onTap: () => Get.back(),
              ),
              ListTile(
                leading: Icon(Icons.person, color: colorScheme.primary),
                title: const Text('My Account'),
                onTap: () async {
                  Get.back();
                  await Get.to(() => const AccountScreen());
                  await loadProfileImage();
                },
              ),
              if (perms.contains('view_history'))
                ListTile(
                  leading: Icon(Icons.history, color: colorScheme.primary),
                  title: const Text('My History'),
                  onTap: () {
                    Get.back();
                    Get.to(() => const HistoryScreen());
                  },
                ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () {
                  Get.back();
                  Get.to(() => const SettingsScreen());
                },
              ),
              ListTile(
                leading:
                Icon(Icons.groups_outlined, color: colorScheme.primary),
                title: const Text('Credits'),
                onTap: () {
                  Get.back();
                  Get.to(() => const CreditsScreen());
                },
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(bottom: 15),
                child: Text('Smart Campus Wi-Fi v1.0.0',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
          ),
        ),

        // BODY (buttons depend on role permissions)
        body: role == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Welcome, $name',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _actions(),
                ],
              ),
            ),
            Expanded(child: DashboardBody(full: role != 'student')),
          ],
        ),

        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.chat),
          onPressed: () => Get.to(() => const ChatbotScreen()),
        ),
      ),
    );
  }
}