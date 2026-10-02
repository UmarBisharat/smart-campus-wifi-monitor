import 'package:cloud_firestore/cloud_firestore.dart';

/// Role -> permission mapping, stored in Firestore at
/// role_permissions/{role} -> { permissions: [ 'key', ... ] }.
///
/// If a role has no document yet, the defaults below are used.
/// The admin role always has every permission (so the admin can never
/// lock themselves out).
class PermissionService {
  static const roles = ['student', 'it_staff', 'manager', 'admin'];

  static const roleLabels = {
    'student': 'Student / Staff',
    'it_staff': 'IT Support Staff',
    'manager': 'Network / IT Manager',
    'admin': 'Administrator',
  };

  /// key -> label (permissions the admin can grant or withdraw).
  static const grantable = <String, String>{
    'run_speed_test': 'Run speed tests',
    'submit_complaint': 'Submit complaints',
    'view_history': 'View own history',
    'view_network_health': 'View network health & outages',
    'view_dashboard': 'View full dashboard statistics',
    'view_test_results': 'View all test results',
    'manage_complaints': 'Manage complaints (assign / update / resolve)',
    'view_analytics': 'View analytics & reports',
    'manage_locations': 'Manage campus locations',
    'manager_dashboard': 'Open IT Manager dashboard',
  };

  static const defaults = <String, Set<String>>{
    'student': {
      'run_speed_test',
      'submit_complaint',
      'view_history',
      'view_network_health',
    },
    'it_staff': {
      'run_speed_test',
      'submit_complaint',
      'view_network_health',
      'view_dashboard',
      'view_test_results',
      'manage_complaints',
    },
    'manager': {
      'view_network_health',
      'view_dashboard',
      'view_test_results',
      'view_analytics',
      'manage_locations',
      'manage_complaints',
      'manager_dashboard',
    },
  };

  static Set<String> get all => grantable.keys.toSet();

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('role_permissions');

  /// Permissions for [role] (defaults if nothing saved or on error).
  static Future<Set<String>> forRole(String role) async {
    if (role == 'admin') return all;
    try {
      final d = await _col.doc(role).get();
      final list = d.data()?['permissions'];
      if (list is List) {
        return list.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    return Set.of(defaults[role] ?? defaults['student']!);
  }

  /// Parse a role_permissions snapshot (used by the admin screen stream).
  static Set<String> fromData(String role, Map<String, dynamic>? data) {
    final list = data?['permissions'];
    if (list is List) return list.map((e) => e.toString()).toSet();
    return Set.of(defaults[role] ?? <String>{});
  }

  static Future<void> save(String role, Set<String> perms) =>
      _col.doc(role).set({
        'permissions': perms.toList()..sort(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> reset(String role) => _col.doc(role).delete();
}