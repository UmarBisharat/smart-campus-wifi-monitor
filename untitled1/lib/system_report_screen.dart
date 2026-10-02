import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'network_health.dart';
import 'permission_service.dart';

typedef _Section = MapEntry<String, List<MapEntry<String, String>>>;

class SystemReportScreen extends StatefulWidget {
  const SystemReportScreen({super.key});

  @override
  State<SystemReportScreen> createState() => _SystemReportScreenState();
}

class _SystemReportScreenState extends State<SystemReportScreen> {
  late Future<List<_Section>> future = _load();

  static MapEntry<String, String> _r(String k, Object v) =>
      MapEntry(k, v.toString());

  Future<List<_Section>> _load() async {
    final db = FirebaseFirestore.instance;
    final res = await Future.wait([
      db.collection('users').get(),
      db.collection('speed_tests').get(),
      db.collection('complaints').get(),
      db.collection('locations').get(),
    ]);

    List<Map<String, dynamic>> m(QuerySnapshot s) =>
        s.docs.map((d) => d.data() as Map<String, dynamic>).toList();

    final users = m(res[0]);
    final tests = m(res[1]).where((t) => t['healthScore'] is num).toList();
    final comps = m(res[2]);
    final locs = m(res[3]);

    double avgOf(List<Map<String, dynamic>> l, String k) =>
        NetworkHealth.avg(l.map((t) => t[k]).whereType<num>());

    // ---- users ----
    final byRole = {for (final r in PermissionService.roles) r: 0};
    for (final u in users) {
      final r = byRole.containsKey(u['role']) ? u['role'] as String : 'student';
      byRole[r] = byRole[r]! + 1;
    }

    // ---- tests ----
    final statusCount = <String, int>{
      'Excellent': 0,
      'Good': 0,
      'Fair': 0,
      'Poor': 0,
      'Critical': 0,
    };
    for (final t in tests) {
      final s = NetworkHealth.status((t['healthScore'] as num).toDouble());
      statusCount[s] = statusCount[s]! + 1;
    }

    // ---- complaints ----
    final open = comps.where((c) => c['status'] != 'Resolved').length;
    final resolved = comps.length - open;
    final hours = <double>[];
    for (final c in comps) {
      final a = c['createdAt'];
      final b = c['resolvedAt'];
      if (a is Timestamp && b is Timestamp) {
        hours.add(b.toDate().difference(a.toDate()).inMinutes / 60);
      }
    }
    final byType = <String, int>{};
    for (final c in comps) {
      final t = (c['type'] ?? 'Other').toString();
      byType[t] = (byType[t] ?? 0) + 1;
    }
    final typeList = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final outages = NetworkHealth.outages(comps);

    // ---- weakest locations ----
    final byLoc = <String, List<Map<String, dynamic>>>{};
    for (final t in tests) {
      if (t['location'] == null) continue;
      byLoc.putIfAbsent(t['location'].toString(), () => []).add(t);
    }
    final ranked = byLoc.entries
        .map((e) => MapEntry(e.key, avgOf(e.value, 'healthScore')))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return [
      MapEntry('Users', [
        _r('Total users', users.length),
        ...byRole.entries.map((e) => _r(e.key, e.value)),
      ]),
      MapEntry('Network', [
        _r('Locations', locs.length),
        _r('Total speed tests', tests.length),
        _r('Avg download', '${avgOf(tests, 'download').toStringAsFixed(1)} Mbps'),
        _r('Avg upload', '${avgOf(tests, 'upload').toStringAsFixed(1)} Mbps'),
        _r('Avg ping', '${avgOf(tests, 'ping').round()} ms'),
        _r('Avg packet loss', '${avgOf(tests, 'packetLoss').toStringAsFixed(1)}%'),
        _r('Avg health score', '${avgOf(tests, 'healthScore').round()}/100'),
      ]),
      MapEntry('Test results by status',
          statusCount.entries.map((e) => _r(e.key, e.value)).toList()),
      MapEntry('Complaints', [
        _r('Total', comps.length),
        _r('Open', open),
        _r('Resolved', resolved),
        _r('Resolution rate',
            comps.isEmpty ? '-' : '${(resolved / comps.length * 100).round()}%'),
        _r('Avg resolution time',
            hours.isEmpty ? '-' : '${NetworkHealth.avg(hours).toStringAsFixed(1)} h'),
        _r('Current outages',
            outages.isEmpty ? '0' : '${outages.length} (${outages.keys.join(', ')})'),
      ]),
      MapEntry(
          'Complaints by type',
          typeList.isEmpty
              ? [_r('None', '-')]
              : typeList.map((e) => _r(e.key, e.value)).toList()),
      MapEntry(
          'Weakest locations',
          ranked.isEmpty
              ? [_r('No data', '-')]
              : ranked
              .take(5)
              .map((e) => _r(e.key, '${e.value.round()}/100'))
              .toList()),
      MapEntry('Thresholds in use', [
        _r('Excellent ≥', NetworkHealth.excellent),
        _r('Good ≥', NetworkHealth.good),
        _r('Fair ≥', NetworkHealth.fair),
        _r('Poor ≥', NetworkHealth.poor),
        _r('Outage complaints', NetworkHealth.outageThreshold),
      ]),
    ];
  }

  String _asText(List<_Section> s) {
    final b = StringBuffer('SYSTEM-WIDE REPORT\n');
    b.writeln('Generated: ${NetworkHealth.formatTime(DateTime.now())}\n');
    for (final sec in s) {
      b.writeln(sec.key.toUpperCase());
      for (final r in sec.value) {
        b.writeln('- ${r.key}: ${r.value}');
      }
      b.writeln();
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Report'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => future = _load()),
          ),
        ],
      ),
      body: FutureBuilder<List<_Section>>(
        future: future,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load report.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sections = snap.data!;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Report'),
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: _asText(sections)));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report copied')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              ...sections.map((s) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.key,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...s.value.map((r) => Padding(
                        padding:
                        const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text(r.key)),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(r.value,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              )),
            ],
          );
        },
      ),
    );
  }
}