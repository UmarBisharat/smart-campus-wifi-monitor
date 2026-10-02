import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Shared helpers for health colour/status, averages and outage detection.
/// Thresholds are configurable by the admin (Firestore: config/thresholds).
class NetworkHealth {
  static int outageThreshold = 3;
  static int excellent = 85;
  static int good = 70;
  static int fair = 50;
  static int poor = 30;

  static StreamSubscription? _sub;

  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('config').doc('thresholds');

  /// Call once after login. Keeps thresholds in sync live.
  static void listen() {
    _sub?.cancel();
    _sub = _doc.snapshots().listen((s) => _apply(s.data()), onError: (_) {});
  }

  static void _apply(Map<String, dynamic>? m) {
    if (m == null) return;
    excellent = (m['excellent'] as num?)?.toInt() ?? excellent;
    good = (m['good'] as num?)?.toInt() ?? good;
    fair = (m['fair'] as num?)?.toInt() ?? fair;
    poor = (m['poor'] as num?)?.toInt() ?? poor;
    outageThreshold =
        (m['outageThreshold'] as num?)?.toInt() ?? outageThreshold;
  }

  static Future<void> save(int e, int g, int f, int p, int outage) async {
    await _doc.set({
      'excellent': e,
      'good': g,
      'fair': f,
      'poor': p,
      'outageThreshold': outage,
    });
    _apply({
      'excellent': e,
      'good': g,
      'fair': f,
      'poor': p,
      'outageThreshold': outage,
    });
  }

  /// Average of a list of numbers (works for int, double or mixed lists).
  static double avg(Iterable<num> v) {
    if (v.isEmpty) return 0;
    double sum = 0;
    for (final n in v) {
      sum += n.toDouble();
    }
    return sum / v.length;
  }

  static Color color(double score) => score >= good
      ? Colors.green
      : score >= fair
      ? Colors.orange
      : Colors.red;

  static String status(double s) => s >= excellent
      ? 'Excellent'
      : s >= good
      ? 'Good'
      : s >= fair
      ? 'Fair'
      : s >= poor
      ? 'Poor'
      : 'Critical';

  /// location -> number of unresolved complaints (only locations with
  /// [outageThreshold] or more are returned).
  static Map<String, int> outages(Iterable<Map<String, dynamic>> complaints) {
    final out = <String, int>{};
    for (final c in complaints) {
      if (c['status'] == 'Resolved' || c['location'] == null) continue;
      final loc = c['location'].toString();
      out[loc] = (out[loc] ?? 0) + 1;
    }
    out.removeWhere((_, n) => n < outageThreshold);
    return out;
  }

  static String formatTime(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}