import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'location_service.dart';
import 'network_health.dart';

/// Analytics for IT staff / managers / admins:
/// heatmap, problematic locations, performance by hour & day,
/// complaints by building and simple insights.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _hourLabel(int h) => h == 0
      ? '12 AM'
      : h < 12
      ? '$h AM'
      : h == 12
      ? '12 PM'
      : '${h - 12} PM';

  Widget _section(String title, Widget child, {String? subtitle}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );

  Widget _barRow(String label, double fraction, Color color, String trailing,
      {double labelWidth = 56}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: labelWidth,
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0).toDouble(),
                minHeight: 14,
                color: color,
                backgroundColor: color.withOpacity(0.15),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
              width: 70,
              child: Text(trailing,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(radius: 6, backgroundColor: c),
      const SizedBox(width: 4),
      Text(t, style: const TextStyle(fontSize: 12)),
      const SizedBox(width: 12),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('speed_tests').snapshots(),
        builder: (context, tSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: db.collection('complaints').snapshots(),
            builder: (context, cSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: db.collection('locations').snapshots(),
                builder: (context, lSnap) {
                  if (tSnap.hasError || cSnap.hasError) {
                    return const Center(
                        child: Text('Could not load analytics data.'));
                  }
                  if (!tSnap.hasData || !cSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final tests = tSnap.data!.docs
                      .map((d) => d.data() as Map<String, dynamic>)
                      .where((t) =>
                  t['location'] != null && t['healthScore'] is num)
                      .toList();
                  final comps = cSnap.data!.docs
                      .map((d) => d.data() as Map<String, dynamic>)
                      .where((c) => c['location'] != null)
                      .toList();

                  // location -> building
                  final buildingOf = <String, String>{};
                  final locNames = <String>{};
                  if (lSnap.hasData) {
                    for (final d in lSnap.data!.docs) {
                      final l = d.data() as Map<String, dynamic>;
                      final n = (l['name'] ?? '').toString();
                      if (n.isEmpty) continue;
                      locNames.add(n);
                      final b = (l['building'] ?? '').toString().trim();
                      buildingOf[n] = b.isEmpty ? 'Unassigned' : b;
                    }
                  }
                  if (locNames.isEmpty) locNames.addAll(LocationService.defaults);

                  final byLoc = <String, List<Map<String, dynamic>>>{};
                  for (final t in tests) {
                    byLoc.putIfAbsent(t['location'].toString(), () => []).add(t);
                  }
                  locNames.addAll(byLoc.keys);
                  final names = locNames.toList()..sort();

                  final openByLoc = <String, int>{};
                  for (final c in comps) {
                    if (c['status'] == 'Resolved') continue;
                    final k = c['location'].toString();
                    openByLoc[k] = (openByLoc[k] ?? 0) + 1;
                  }

                  double scoreOf(String n) => NetworkHealth.avg(
                      (byLoc[n] ?? []).map((t) => t['healthScore'] as num));

                  // ---------- by hour / by day ----------
                  final hourScores = <int, List<num>>{};
                  final dayScores = <int, List<num>>{};
                  for (final t in tests) {
                    final d = (t['testedAt'] as Timestamp?)?.toDate();
                    if (d == null) continue;
                    hourScores
                        .putIfAbsent(d.hour, () => [])
                        .add(t['healthScore'] as num);
                    dayScores
                        .putIfAbsent(d.weekday, () => [])
                        .add(t['healthScore'] as num);
                  }

                  // ---------- problematic ranking ----------
                  final ranked = names
                      .where((n) => byLoc.containsKey(n))
                      .map((n) {
                    final s = scoreOf(n);
                    final open = openByLoc[n] ?? 0;
                    return (name: n, score: s, open: open,
                    problem: (100 - s) + open * 5);
                  })
                      .toList()
                    ..sort((a, b) => b.problem.compareTo(a.problem));
                  final top = ranked.take(5).toList();

                  // ---------- complaints by building ----------
                  final byBuilding = <String, int>{};
                  for (final c in comps) {
                    final b = buildingOf[c['location'].toString()] ??
                        'Unassigned';
                    byBuilding[b] = (byBuilding[b] ?? 0) + 1;
                  }
                  final buildingList = byBuilding.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  final maxB =
                  buildingList.isEmpty ? 1 : buildingList.first.value;

                  // ---------- insights ----------
                  final insights = <String>[];
                  if (hourScores.isNotEmpty) {
                    final worst = hourScores.entries.reduce((a, b) =>
                    NetworkHealth.avg(a.value) <= NetworkHealth.avg(b.value)
                        ? a
                        : b);
                    insights.add(
                        'Peak problem time: around ${_hourLabel(worst.key)} '
                            '(avg health ${NetworkHealth.avg(worst.value).round()}/100).');
                  }
                  if (dayScores.isNotEmpty) {
                    final worst = dayScores.entries.reduce((a, b) =>
                    NetworkHealth.avg(a.value) <= NetworkHealth.avg(b.value)
                        ? a
                        : b);
                    insights.add(
                        'Weakest day: ${_days[worst.key - 1]} '
                            '(avg health ${NetworkHealth.avg(worst.value).round()}/100).');
                  }
                  if (top.isNotEmpty) {
                    insights.add(
                        'Inspect first: ${top.first.name} '
                            '(health ${top.first.score.round()}/100, '
                            '${top.first.open} open complaints).');
                  }
                  final outageLocs = NetworkHealth.outages(comps);
                  if (outageLocs.isNotEmpty) {
                    insights.add(
                        'Possible outage in: ${outageLocs.keys.join(', ')}.');
                  }

                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // ---------- INSIGHTS ----------
                      if (insights.isNotEmpty)
                        _section(
                          'Network Insights',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: insights
                                .map((i) => Padding(
                              padding:
                              const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lightbulb_outline,
                                      size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(i)),
                                ],
                              ),
                            ))
                                .toList(),
                          ),
                        ),

                      // ---------- HEATMAP ----------
                      _section(
                        'Campus Heatmap',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: names.map((n) {
                                final has = byLoc.containsKey(n);
                                final s = scoreOf(n);
                                final c = has
                                    ? NetworkHealth.color(s)
                                    : Colors.grey;
                                return Container(
                                  width: 105,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: c,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(n,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                      const SizedBox(height: 6),
                                      Text(
                                          has
                                              ? '${s.round()}/100'
                                              : 'No data',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Wrap(children: [
                              _legendDot(Colors.green, 'Good'),
                              _legendDot(Colors.orange, 'Fair'),
                              _legendDot(Colors.red, 'Poor'),
                              _legendDot(Colors.grey, 'No data'),
                            ]),
                          ],
                        ),
                      ),

                      // ---------- MOST PROBLEMATIC ----------
                      _section(
                        'Most Problematic Locations',
                        top.isEmpty
                            ? const Text('No test data yet.')
                            : Column(
                          children: top
                              .map((r) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: CircleAvatar(
                                radius: 8,
                                backgroundColor:
                                NetworkHealth.color(
                                    r.score)),
                            title: Text(r.name),
                            subtitle: Text(
                                'Health ${r.score.round()}/100 • ${r.open} open complaints'),
                            trailing: Text(
                                NetworkHealth.status(r.score)),
                          ))
                              .toList(),
                        ),
                        subtitle: 'Ranked by low health score + open complaints',
                      ),

                      // ---------- BY HOUR ----------
                      _section(
                        'Performance by Hour',
                        hourScores.isEmpty
                            ? const Text('No test data yet.')
                            : Column(
                          children: (hourScores.keys.toList()..sort())
                              .map((h) {
                            final s = NetworkHealth.avg(hourScores[h]!);
                            return _barRow(
                                _hourLabel(h),
                                s / 100,
                                NetworkHealth.color(s),
                                '${s.round()} (${hourScores[h]!.length})');
                          }).toList(),
                        ),
                        subtitle: 'Average health score (number of tests)',
                      ),

                      // ---------- BY DAY ----------
                      _section(
                        'Performance by Day',
                        dayScores.isEmpty
                            ? const Text('No test data yet.')
                            : Column(
                          children: (dayScores.keys.toList()..sort())
                              .map((d) {
                            final s = NetworkHealth.avg(dayScores[d]!);
                            return _barRow(
                                _days[d - 1],
                                s / 100,
                                NetworkHealth.color(s),
                                '${s.round()} (${dayScores[d]!.length})');
                          }).toList(),
                        ),
                        subtitle: 'Average health score (number of tests)',
                      ),

                      // ---------- COMPLAINTS BY BUILDING ----------
                      _section(
                        'Complaints by Building',
                        buildingList.isEmpty
                            ? const Text('No complaints yet.')
                            : Column(
                          children: buildingList
                              .map((e) => _barRow(
                              e.key,
                              e.value / maxB,
                              Theme.of(context).colorScheme.primary,
                              '${e.value}',
                              labelWidth: 90))
                              .toList(),
                        ),
                        subtitle:
                        'Set a Building when adding locations to group them',
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}