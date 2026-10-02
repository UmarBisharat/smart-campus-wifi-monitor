import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  // Used when the admin has not added any locations yet, so students
  // can still pick a location and run a speed test.
  static const defaults = [
    'Computer Lab 1',
    'Computer Lab 2',
    'Library',
    'Cafeteria',
    'Administration Block',
    'Department Building',
    'Hostel Block',
  ];

  static Future<List<String>> names() async {
    try {
      final s = await FirebaseFirestore.instance.collection('locations').get();
      final list = s.docs
          .map((d) => (d.data()['name'] ?? '').toString())
          .where((n) => n.isNotEmpty)
          .toList();
      if (list.isEmpty) return List.of(defaults);
      list.sort();
      return list;
    } catch (_) {
      return List.of(defaults);
    }
  }
}