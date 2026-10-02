import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  List<Map<String, dynamic>> _sorted(QuerySnapshot s, String field) {
    final list =
    s.docs.map((d) => d.data() as Map<String, dynamic>).toList();
    list.sort((a, b) {
      final x = (a[field] as Timestamp?)?.toDate() ?? DateTime(2000);
      final y = (b[field] as Timestamp?)?.toDate() ?? DateTime(2000);
      return y.compareTo(x);
    });
    return list;
  }

  Widget _list(String collection, String dateField,
      ListTile Function(Map<String, dynamic>) tile) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = _sorted(snap.data!, dateField);
        if (items.isEmpty) return const Center(child: Text('Nothing yet'));
        return ListView(
          padding: const EdgeInsets.all(12),
          children: items.map((i) => Card(child: tile(i))).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My History'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'Speed Tests'), Tab(text: 'Complaints')],
          ),
        ),
        body: TabBarView(
          children: [
            _list(
              'speed_tests',
              'testedAt',
                  (t) => ListTile(
                title: Text('${t['location']} • ${t['healthStatus']}'),
                subtitle: Text(
                  '${(t['download'] as num).toStringAsFixed(1)} Mbps down, '
                      '${(t['ping'] as num).round()} ms ping',
                ),
                trailing: Text('${t['healthScore']}/100'),
              ),
            ),
            _list(
              'complaints',
              'createdAt',
                  (c) => ListTile(
                title: Text('${c['type']} • ${c['location']}'),
                subtitle: Text(c['description'] ?? ''),
                trailing: Text(c['status'] ?? ''),
              ),
            ),
          ],
        ),
      ),
    );
  }
}