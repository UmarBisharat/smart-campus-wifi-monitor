import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'analytics_screen.dart';
import 'manage_locations_screen.dart';
import 'location_service.dart';
import 'network_health.dart';

/// IT Manager dashboard.
/// Tabs: Overview, Compare, Trends, Recurring, Activity, Reports.
/// Locations added/deleted in "Manage Locations" are the same ones
/// students see in the Speed Test / Complaint dropdowns.
class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

// ===========================================================
// DATA HELPERS
// ===========================================================
DateTime? _dt(Map<String, dynamic> m, String field) {
  final v = m[field];
  return v is Timestamp ? v.toDate() : null;
}

double _avgField(List<Map<String, dynamic>> tests, String key) =>
    NetworkHealth.avg(tests.map((t) => t[key]).whereType<num>());

String _f1(double v) => v.toStringAsFixed(1);

class _Log {
  final DateTime time;
  final String who;
  final String action;
  final String location;
  final bool derived;
  _Log(this.time, this.who, this.action, this.location, this.derived);
}

class _Data {
  final List<Map<String, dynamic>> tests;
  final List<Map<String, dynamic>> comps;
  final List<Map<String, dynamic>> logs;
  final Map<String, String> buildingOf;
  final List<String> names;
  final Map<String, List<Map<String, dynamic>>> byLoc;
  final Map<String, int> outages;

  _Data(this.tests, this.comps, this.logs, this.buildingOf, this.names,
      this.byLoc, this.outages);

  double scoreOf(String n) => NetworkHealth.avg(
      (byLoc[n] ?? []).map((t) => t['healthScore']).whereType<num>());

  bool hasTests(String n) => (byLoc[n] ?? []).isNotEmpty;

  int openOf(String n) => comps
      .where((c) => c['location'] == n && c['status'] != 'Resolved')
      .length;

  int totalComplaintsOf(String n) =>
      comps.where((c) => c['location'] == n).length;

  int get openTotal => comps.where((c) => c['status'] != 'Resolved').length;

  double get overall {
    final scored = names.where(hasTests).toList();
    if (scored.isEmpty) return 0;
    return NetworkHealth.avg(scored.map(scoreOf));
  }
}

// ===========================================================
// SMALL UI HELPERS
// ===========================================================
Widget _card(String title, Widget child, {String? subtitle}) => Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
            const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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

Widget _stat(String label, String value) => SizedBox(
  width: 160,
  child: Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    ),
  ),
);

Widget _barRow(String label, double fraction, Color color, String trailing,
    {double labelWidth = 110}) {
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
            width: 50,
            child: Text(trailing,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

Widget _dropdown(String label, String? value, List<String> items,
    ValueChanged<String?> onChanged) {
  return DropdownButtonFormField<String>(
    value: items.contains(value) ? value : null,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: items
        .map((o) => DropdownMenuItem(
        value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
        .toList(),
    onChanged: onChanged,
  );
}

// ===========================================================
// SIMPLE LINE CHART
// ===========================================================
class _LinePainter extends CustomPainter {
  final List<double?> values;
  final Color color;
  final Color gridColor;
  final Color textColor;

  _LinePainter(this.values, this.color, this.gridColor, this.textColor);

  @override
  void paint(Canvas canvas, Size size) {
    final nonNull = values.whereType<double>().toList();
    if (nonNull.isEmpty) return;

    var minV = nonNull.reduce((a, b) => a < b ? a : b);
    var maxV = nonNull.reduce((a, b) => a > b ? a : b);
    if (minV == maxV) {
      minV -= 1;
      maxV += 1;
    }
    final pad = (maxV - minV) * 0.1;
    minV -= pad;
    maxV += pad;

    const leftPad = 40.0;
    const topPad = 8.0;
    const bottomPad = 8.0;
    final w = size.width - leftPad - 8;
    final h = size.height - topPad - bottomPad;

    // grid + y labels
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = topPad + h * i / 3;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - 8, y), gridPaint);
      final v = maxV - (maxV - minV) * i / 3;
      final tp = TextPainter(
        text: TextSpan(
            text: v.toStringAsFixed(0),
            style: TextStyle(color: textColor, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    Offset pt(int i, double v) {
      final x = values.length == 1
          ? leftPad + w / 2
          : leftPad + w * i / (values.length - 1);
      final y = topPad + h * (1 - (v - minV) / (maxV - minV));
      return Offset(x, y);
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final dotPaint = Paint()..color = color;

    final path = Path();
    bool started = false;
    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final p = pt(i, v);
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, linePaint);
    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      if (v != null) canvas.drawCircle(pt(i, v), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => true;
}

class _ManagerScreenState extends State<ManagerScreen> {
  static const _statusFlow = [
    'Submitted',
    'Reviewed',
    'Assigned',
    'In Progress',
    'Resolved',
  ];

  String? locA;
  String? locB;
  String trendLoc = 'All campus';
  int trendDays = 14;

  void _openLocations() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageLocationsScreen()),
    );
  }

  void _openAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
    );
  }

  // ===========================================================
  // BUILD
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('IT Manager',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              tooltip: 'Manage locations',
              icon: const Icon(Icons.add_location_alt_outlined),
              onPressed: _openLocations,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Compare'),
              Tab(text: 'Trends'),
              Tab(text: 'Recurring'),
              Tab(text: 'Activity'),
              Tab(text: 'Reports'),
            ],
          ),
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
                    return StreamBuilder<QuerySnapshot>(
                      stream: db.collection('activity_logs').snapshots(),
                      builder: (context, aSnap) {
                        if (tSnap.hasError || cSnap.hasError) {
                          return const Center(
                              child: Text('Could not load network data.'));
                        }
                        if (!tSnap.hasData || !cSnap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final d = _buildData(tSnap, cSnap, lSnap, aSnap);

                        return TabBarView(
                          children: [
                            _overviewTab(d),
                            _compareTab(d),
                            _trendsTab(d),
                            _recurringTab(d),
                            _activityTab(d),
                            _reportsTab(d),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  _Data _buildData(
      AsyncSnapshot<QuerySnapshot> tSnap,
      AsyncSnapshot<QuerySnapshot> cSnap,
      AsyncSnapshot<QuerySnapshot> lSnap,
      AsyncSnapshot<QuerySnapshot> aSnap) {
    final tests = tSnap.data!.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .where((t) => t['location'] != null && t['healthScore'] is num)
        .toList();
    final comps = cSnap.data!.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .where((c) => c['location'] != null)
        .toList();
    final logs = aSnap.hasData
        ? aSnap.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList()
        : <Map<String, dynamic>>[];

    final buildingOf = <String, String>{};
    final nameSet = <String>{};
    if (lSnap.hasData) {
      for (final doc in lSnap.data!.docs) {
        final l = doc.data() as Map<String, dynamic>;
        final n = (l['name'] ?? '').toString();
        if (n.isEmpty) continue;
        nameSet.add(n);
        final b = (l['building'] ?? '').toString().trim();
        buildingOf[n] = b.isEmpty ? 'Unassigned' : b;
      }
    }
    if (nameSet.isEmpty) nameSet.addAll(LocationService.defaults);

    final byLoc = <String, List<Map<String, dynamic>>>{};
    for (final t in tests) {
      byLoc.putIfAbsent(t['location'].toString(), () => []).add(t);
    }
    nameSet.addAll(byLoc.keys);
    final names = nameSet.toList()..sort();

    return _Data(tests, comps, logs, buildingOf, names, byLoc,
        NetworkHealth.outages(comps));
  }

  // ===========================================================
  // TAB 1: OVERVIEW
  // ===========================================================
  Widget _overviewTab(_Data d) {
    final overall = d.overall;
    final anyTests = d.tests.isNotEmpty;
    final now = DateTime.now();
    final today = d.tests.where((t) {
      final x = _dt(t, 'testedAt');
      return x != null &&
          x.year == now.year &&
          x.month == now.month &&
          x.day == now.day;
    }).length;
    final poor =
        d.names.where((n) => d.hasTests(n) && d.scoreOf(n) < 50).length;
    final open = d.openTotal;
    final resolved = d.comps.length - open;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // overall health
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor:
                  anyTests ? NetworkHealth.color(overall) : Colors.grey,
                  child: Text(
                    anyTests ? '${overall.round()}' : '--',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Overall Network Health',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        anyTests
                            ? '${NetworkHealth.status(overall)} • average across ${d.names.where(d.hasTests).length} locations'
                            : 'No tests recorded yet',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // quick actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openLocations,
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('Manage Locations'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openAnalytics,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Full Analytics'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // stats
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _stat('Tests today', '$today'),
            _stat('Total tests', '${d.tests.length}'),
            _stat('Avg download',
                '${_f1(_avgField(d.tests, 'download'))} Mbps'),
            _stat('Avg upload', '${_f1(_avgField(d.tests, 'upload'))} Mbps'),
            _stat('Avg ping', '${_avgField(d.tests, 'ping').round()} ms'),
            _stat('Poor locations', '$poor'),
            _stat('Open complaints', '$open'),
            _stat('Resolved', '$resolved'),
            _stat('Locations', '${d.names.length}'),
            _stat('Current outages', '${d.outages.length}'),
          ],
        ),
        const SizedBox(height: 12),

        // outages
        _card(
          'Current Outages',
          d.outages.isEmpty
              ? const Row(children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('No outages detected'),
          ])
              : Column(
            children: d.outages.entries
                .map((e) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading:
              const Icon(Icons.warning, color: Colors.red),
              title: Text('Possible Wi-Fi outage in ${e.key}'),
              subtitle: Text('${e.value} open complaints'),
            ))
                .toList(),
          ),
        ),

        // locations
        _card(
          'Campus Locations',
          d.names.isEmpty
              ? const Text('No locations yet')
              : Column(
            children: d.names.map((n) {
              final has = d.hasTests(n);
              final s = d.scoreOf(n);
              final lt = d.byLoc[n] ?? [];
              final building = d.buildingOf[n];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  radius: 8,
                  backgroundColor:
                  has ? NetworkHealth.color(s) : Colors.grey,
                ),
                title: Text(n),
                subtitle: Text(
                  has
                      ? '${_f1(_avgField(lt, 'download'))} Mbps • ${_avgField(lt, 'ping').round()} ms • ${d.openOf(n)} open complaints'
                      '${building != null ? ' • $building' : ''}'
                      : 'No tests yet',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (d.outages.containsKey(n))
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.warning,
                            color: Colors.red, size: 18),
                      ),
                    Text(has ? NetworkHealth.status(s) : 'N/A'),
                  ],
                ),
              );
            }).toList(),
          ),
          subtitle: 'Add or delete locations with the button above. '
              'Students see these in their dropdowns.',
        ),
      ],
    );
  }

  // ===========================================================
  // TAB 2: COMPARE TWO LOCATIONS
  // ===========================================================
  Widget _cmpRow(String label, double? a, double? b, String Function(double) f,
      {bool higherBetter = true}) {
    bool aWins = false, bWins = false;
    if (a != null && b != null && a != b) {
      aWins = higherBetter ? a > b : a < b;
      bWins = !aWins;
    }
    TextStyle st(bool w) => TextStyle(
        fontSize: 15,
        fontWeight: w ? FontWeight.bold : FontWeight.normal,
        color: w ? Colors.green : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(a == null ? '–' : f(a),
                  textAlign: TextAlign.center, style: st(aWins))),
          SizedBox(
              width: 110,
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(
              child: Text(b == null ? '–' : f(b),
                  textAlign: TextAlign.center, style: st(bWins))),
        ],
      ),
    );
  }

  Widget _compareTab(_Data d) {
    if (d.names.length < 2) {
      return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Add at least two locations to compare them.'),
          ));
    }
    final a = d.names.contains(locA) ? locA! : d.names.first;
    final b = d.names.contains(locB) ? locB! : d.names[1];

    final ta = d.byLoc[a] ?? <Map<String, dynamic>>[];
    final tb = d.byLoc[b] ?? <Map<String, dynamic>>[];
    final hasA = ta.isNotEmpty, hasB = tb.isNotEmpty;

    double? val(bool has, double v) => has ? v : null;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _card(
          'Compare Two Locations',
          Column(
            children: [
              _dropdown(
                  'Location A', a, d.names, (v) => setState(() => locA = v)),
              const SizedBox(height: 12),
              _dropdown(
                  'Location B', b, d.names, (v) => setState(() => locB = v)),
            ],
          ),
          subtitle: 'The better value in each row is shown in green',
        ),
        if (a == b)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Pick two different locations.',
                style: TextStyle(color: Colors.grey)),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(a,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(width: 110),
                      Expanded(
                        child: Text(b,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _cmpRow('Health score', val(hasA, d.scoreOf(a)),
                      val(hasB, d.scoreOf(b)), (v) => '${v.round()}/100'),
                  _cmpRow(
                      'Download',
                      val(hasA, _avgField(ta, 'download')),
                      val(hasB, _avgField(tb, 'download')),
                          (v) => '${_f1(v)} Mbps'),
                  _cmpRow(
                      'Upload',
                      val(hasA, _avgField(ta, 'upload')),
                      val(hasB, _avgField(tb, 'upload')),
                          (v) => '${_f1(v)} Mbps'),
                  _cmpRow(
                      'Ping',
                      val(hasA, _avgField(ta, 'ping')),
                      val(hasB, _avgField(tb, 'ping')),
                          (v) => '${v.round()} ms',
                      higherBetter: false),
                  _cmpRow(
                      'Packet loss',
                      val(hasA, _avgField(ta, 'packetLoss')),
                      val(hasB, _avgField(tb, 'packetLoss')),
                          (v) => '${_f1(v)}%',
                      higherBetter: false),
                  _cmpRow('Tests', ta.length.toDouble(), tb.length.toDouble(),
                          (v) => '${v.round()}'),
                  _cmpRow('Open complaints', d.openOf(a).toDouble(),
                      d.openOf(b).toDouble(), (v) => '${v.round()}',
                      higherBetter: false),
                  _cmpRow(
                      'All complaints',
                      d.totalComplaintsOf(a).toDouble(),
                      d.totalComplaintsOf(b).toDouble(),
                          (v) => '${v.round()}',
                      higherBetter: false),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasA ? NetworkHealth.status(d.scoreOf(a)) : 'No data',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: hasA
                                  ? NetworkHealth.color(d.scoreOf(a))
                                  : Colors.grey),
                        ),
                      ),
                      const SizedBox(
                          width: 110,
                          child: Text('Status',
                              textAlign: TextAlign.center,
                              style:
                              TextStyle(color: Colors.grey, fontSize: 12))),
                      Expanded(
                        child: Text(
                          hasB ? NetworkHealth.status(d.scoreOf(b)) : 'No data',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: hasB
                                  ? NetworkHealth.color(d.scoreOf(b))
                                  : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (a != b && hasA && hasB)
          _card(
            'Verdict',
            Text(
              d.scoreOf(a) == d.scoreOf(b)
                  ? '$a and $b have the same average health score.'
                  : '${d.scoreOf(a) > d.scoreOf(b) ? a : b} performs better '
                  'by ${(d.scoreOf(a) - d.scoreOf(b)).abs().round()} points. '
                  '${d.scoreOf(a) > d.scoreOf(b) ? b : a} should be inspected first.',
            ),
          ),
      ],
    );
  }

  // ===========================================================
  // TAB 3: SPEED & LATENCY TRENDS
  // ===========================================================
  List<double?> _series(
      List<Map<String, dynamic>> tests, String key, int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final buckets = List.generate(days, (_) => <num>[]);
    for (final t in tests) {
      final dt = _dt(t, 'testedAt');
      final v = t[key];
      if (dt == null || v is! num) continue;
      final day = DateTime(dt.year, dt.month, dt.day);
      final idx = days - 1 - today.difference(day).inDays;
      if (idx < 0 || idx >= days) continue;
      buckets[idx].add(v);
    }
    return buckets
        .map<double?>((b) => b.isEmpty ? null : NetworkHealth.avg(b))
        .toList();
  }

  /// Compares the second half of the series with the first half.
  /// Returns null when there is not enough data.
  double? _changePct(List<double?> s) {
    final mid = s.length ~/ 2;
    final first = s.sublist(0, mid).whereType<double>().toList();
    final second = s.sublist(mid).whereType<double>().toList();
    if (first.isEmpty || second.isEmpty) return null;
    final a = NetworkHealth.avg(first);
    final b = NetworkHealth.avg(second);
    if (a == 0) return null;
    return (b - a) / a * 100;
  }

  Widget _trendChart(
      String title, String unit, List<double?> series, Color color,
      {required bool higherBetter}) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface.withOpacity(0.6);
    final grid = theme.colorScheme.onSurface.withOpacity(0.1);
    final change = _changePct(series);
    final hasData = series.any((v) => v != null);

    Widget summary = const SizedBox.shrink();
    if (change != null) {
      final improved = higherBetter ? change > 0 : change < 0;
      final flat = change.abs() < 1;
      summary = Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(
              flat
                  ? Icons.trending_flat
                  : (change > 0 ? Icons.trending_up : Icons.trending_down),
              color:
              flat ? Colors.grey : (improved ? Colors.green : Colors.red),
              size: 20,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                flat
                    ? 'Stable compared with the earlier half of this period'
                    : '${change.abs().toStringAsFixed(0)}% ${change > 0 ? 'higher' : 'lower'} than the earlier half '
                    '(${improved ? 'improving' : 'getting worse'})',
                style: TextStyle(
                  fontSize: 12,
                  color: flat
                      ? Colors.grey
                      : (improved ? Colors.green : Colors.red),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final start = now.subtract(Duration(days: trendDays - 1));
    String dm(DateTime x) => '${x.day}/${x.month}';

    return _card(
      '$title ($unit)',
      !hasData
          ? const Text('No test data in this period.',
          style: TextStyle(color: Colors.grey))
          : Column(
        children: [
          summary,
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: _LinePainter(series, color, grid, textColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dm(start),
                    style: const TextStyle(
                        fontSize: 10, color: Colors.grey)),
                Text(dm(now),
                    style: const TextStyle(
                        fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
      subtitle: 'Daily average',
    );
  }

  Widget _trendsTab(_Data d) {
    final options = ['All campus', ...d.names];
    final loc = options.contains(trendLoc) ? trendLoc : 'All campus';
    final tests = loc == 'All campus'
        ? d.tests
        : (d.byLoc[loc] ?? <Map<String, dynamic>>[]);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _card(
          'Speed & Latency Trends',
          Column(
            children: [
              _dropdown('Location', loc, options,
                      (v) => setState(() => trendLoc = v ?? 'All campus')),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 days')),
                  ButtonSegment(value: 14, label: Text('14 days')),
                  ButtonSegment(value: 30, label: Text('30 days')),
                ],
                selected: {trendDays},
                onSelectionChanged: (s) => setState(() => trendDays = s.first),
              ),
            ],
          ),
        ),
        _trendChart('Download speed', 'Mbps',
            _series(tests, 'download', trendDays), Colors.blue,
            higherBetter: true),
        _trendChart('Upload speed', 'Mbps',
            _series(tests, 'upload', trendDays), Colors.teal,
            higherBetter: true),
        _trendChart('Latency / ping', 'ms',
            _series(tests, 'ping', trendDays), Colors.orange,
            higherBetter: false),
        _trendChart('Health score', '/100',
            _series(tests, 'healthScore', trendDays), Colors.green,
            higherBetter: true),
      ],
    );
  }

  // ===========================================================
  // TAB 4: RECURRING PROBLEMS
  // ===========================================================
  Widget _recurringTab(_Data d) {
    // location + type -> list of complaints
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final c in d.comps) {
      final key = '${c['location']}|${c['type'] ?? 'Other'}';
      groups.putIfAbsent(key, () => []).add(c);
    }
    final recurring = groups.entries.where((e) => e.value.length >= 2).toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    // complaint types overall
    final byType = <String, int>{};
    for (final c in d.comps) {
      final t = (c['type'] ?? 'Other').toString();
      byType[t] = (byType[t] ?? 0) + 1;
    }
    final typeList = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxType = typeList.isEmpty ? 1 : typeList.first.value;

    // locations that repeatedly test poorly
    final poorRepeat = <MapEntry<String, int>>[];
    d.byLoc.forEach((loc, list) {
      final n = list.where((t) => (t['healthScore'] as num) < 50).length;
      if (n >= 3) poorRepeat.add(MapEntry(loc, n));
    });
    poorRepeat.sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _card(
          'Recurring Complaints',
          recurring.isEmpty
              ? const Text('No recurring problems found yet.')
              : Column(
            children: recurring.map((e) {
              final parts = e.key.split('|');
              final list = e.value;
              final open =
                  list.where((c) => c['status'] != 'Resolved').length;
              DateTime? last;
              for (final c in list) {
                final t = _dt(c, 'createdAt');
                if (t != null && (last == null || t.isAfter(last))) {
                  last = t;
                }
              }
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: open > 0 ? Colors.red : Colors.green,
                  child: Text('${list.length}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                ),
                title: Text('${parts[1]} • ${parts[0]}'),
                subtitle: Text(
                    '$open open • last reported ${last == null ? '-' : NetworkHealth.formatTime(last)}'),
              );
            }).toList(),
          ),
          subtitle: 'Same problem type reported 2+ times at the same location',
        ),
        _card(
          'Repeated Poor Test Results',
          poorRepeat.isEmpty
              ? const Text('No location has 3+ poor tests.')
              : Column(
            children: poorRepeat
                .map((e) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.signal_wifi_bad,
                  color: Colors.red),
              title: Text(e.key),
              subtitle: Text(
                  '${e.value} tests scored below 50/100 '
                      '(out of ${d.byLoc[e.key]!.length})'),
            ))
                .toList(),
          ),
        ),
        _card(
          'Complaints by Type',
          typeList.isEmpty
              ? const Text('No complaints yet.')
              : Column(
            children: typeList
                .map((e) => _barRow(
                e.key,
                e.value / maxType,
                Theme.of(context).colorScheme.primary,
                '${e.value}',
                labelWidth: 150))
                .toList(),
          ),
        ),
      ],
    );
  }

  // ===========================================================
  // TAB 5: IT SUPPORT ACTIVITY
  // ===========================================================
  List<_Log> _buildLogs(_Data d) {
    final out = <_Log>[];

    // real log entries (collection: activity_logs)
    for (final l in d.logs) {
      final t = _dt(l, 'createdAt');
      if (t == null) continue;
      out.add(_Log(
        t,
        (l['staff'] ?? l['staffName'] ?? 'IT staff').toString(),
        (l['action'] ?? '').toString(),
        (l['location'] ?? '').toString(),
        false,
      ));
    }

    // activity derived from complaint status changes
    for (final c in d.comps) {
      final status = (c['status'] ?? 'Submitted').toString();
      if (status == 'Submitted') continue;
      final t =
          _dt(c, 'updatedAt') ?? _dt(c, 'resolvedAt') ?? _dt(c, 'createdAt');
      if (t == null) continue;
      out.add(_Log(
        t,
        (c['assignedStaff'] ?? 'IT staff').toString(),
        '${c['type'] ?? 'Complaint'} marked "$status"',
        (c['location'] ?? '').toString(),
        true,
      ));
    }

    out.sort((a, b) => b.time.compareTo(a.time));
    return out.take(100).toList();
  }

  Widget _activityTab(_Data d) {
    final counts = {for (final s in _statusFlow) s: 0};
    for (final c in d.comps) {
      final s = (c['status'] ?? 'Submitted').toString();
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final maxCount = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b);

    // average resolution time
    final durations = <double>[];
    for (final c in d.comps) {
      final a = _dt(c, 'createdAt');
      final b = _dt(c, 'resolvedAt');
      if (a != null && b != null) {
        durations.add(b.difference(a).inMinutes / 60);
      }
    }

    // workload per staff
    final workload = <String, int>{};
    for (final c in d.comps) {
      final s = c['assignedStaff'];
      if (s != null && s.toString().isNotEmpty) {
        workload[s.toString()] = (workload[s.toString()] ?? 0) + 1;
      }
    }
    final workList = workload.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final logs = _buildLogs(d);
    final rate = d.comps.isEmpty
        ? 0
        : ((counts['Resolved'] ?? 0) / d.comps.length * 100).round();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _stat('Resolution rate', '$rate%'),
            _stat(
                'Avg resolution time',
                durations.isEmpty
                    ? '–'
                    : '${_f1(NetworkHealth.avg(durations))} h'),
          ],
        ),
        const SizedBox(height: 8),
        _card(
          'Complaint Workflow',
          Column(
            children: _statusFlow
                .map((s) => _barRow(
                s,
                (counts[s] ?? 0) / (maxCount == 0 ? 1 : maxCount),
                s == 'Resolved'
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
                '${counts[s] ?? 0}'))
                .toList(),
          ),
          subtitle: 'Submitted → Reviewed → Assigned → In Progress → Resolved',
        ),
        if (workList.isNotEmpty)
          _card(
            'Workload by Staff',
            Column(
              children: workList
                  .map((e) => _barRow(
                  e.key,
                  e.value / workList.first.value,
                  Theme.of(context).colorScheme.primary,
                  '${e.value}',
                  labelWidth: 120))
                  .toList(),
            ),
            subtitle: 'Complaints assigned',
          ),
        _card(
          'IT Support Activity Log',
          logs.isEmpty
              ? const Text('No activity recorded yet.')
              : Column(
            children: logs
                .map((l) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                l.derived
                    ? Icons.sync_alt
                    : Icons.manage_accounts_outlined,
                size: 20,
              ),
              title: Text(l.action),
              subtitle: Text(
                  '${l.who}${l.location.isEmpty ? '' : ' • ${l.location}'}'),
              trailing: Text(NetworkHealth.formatTime(l.time),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ))
                .toList(),
          ),
          subtitle:
          'Latest 100 actions (from activity_logs and complaint updates)',
        ),
      ],
    );
  }

  // ===========================================================
  // TAB 6: REPORTS
  // ===========================================================
  String _buildReport(_Data d) {
    final now = DateTime.now();
    final b = StringBuffer();
    final scored = d.names.where(d.hasTests).toList()
      ..sort((x, y) => d.scoreOf(x).compareTo(d.scoreOf(y)));
    final open = d.openTotal;

    b.writeln('CAMPUS WI-FI NETWORK REPORT');
    b.writeln('Generated: ${NetworkHealth.formatTime(now)}');
    b.writeln('');
    b.writeln('SUMMARY');
    b.writeln(d.tests.isEmpty
        ? '- Overall health: no data'
        : '- Overall health: ${d.overall.round()}/100 (${NetworkHealth.status(d.overall)})');
    b.writeln('- Locations monitored: ${d.names.length}');
    b.writeln('- Total speed tests: ${d.tests.length}');
    b.writeln('- Avg download: ${_f1(_avgField(d.tests, 'download'))} Mbps');
    b.writeln('- Avg upload: ${_f1(_avgField(d.tests, 'upload'))} Mbps');
    b.writeln('- Avg ping: ${_avgField(d.tests, 'ping').round()} ms');
    b.writeln('- Avg packet loss: ${_f1(_avgField(d.tests, 'packetLoss'))}%');
    b.writeln('- Complaints: ${d.comps.length} total, $open open, '
        '${d.comps.length - open} resolved');
    b.writeln('- Current outages: ${d.outages.length}'
        '${d.outages.isEmpty ? '' : ' (${d.outages.keys.join(', ')})'}');
    b.writeln('');

    b.writeln('WEAKEST LOCATIONS');
    if (scored.isEmpty) {
      b.writeln('- No data');
    } else {
      for (final n in scored.take(5)) {
        b.writeln('- $n: ${d.scoreOf(n).round()}/100 '
            '(${NetworkHealth.status(d.scoreOf(n))}), ${d.openOf(n)} open complaints');
      }
    }
    b.writeln('');

    b.writeln('BEST LOCATIONS');
    if (scored.isEmpty) {
      b.writeln('- No data');
    } else {
      for (final n in scored.reversed.take(3)) {
        b.writeln('- $n: ${d.scoreOf(n).round()}/100 '
            '(${NetworkHealth.status(d.scoreOf(n))})');
      }
    }
    b.writeln('');

    final byType = <String, int>{};
    for (final c in d.comps) {
      final t = (c['type'] ?? 'Other').toString();
      byType[t] = (byType[t] ?? 0) + 1;
    }
    final types = byType.entries.toList()
      ..sort((a, c) => c.value.compareTo(a.value));
    b.writeln('TOP COMPLAINT TYPES');
    if (types.isEmpty) {
      b.writeln('- None');
    } else {
      for (final e in types.take(5)) {
        b.writeln('- ${e.key}: ${e.value}');
      }
    }
    b.writeln('');

    // peak problem hour
    final hours = <int, List<num>>{};
    for (final t in d.tests) {
      final x = _dt(t, 'testedAt');
      if (x != null) {
        hours.putIfAbsent(x.hour, () => []).add(t['healthScore'] as num);
      }
    }
    b.writeln('INSIGHTS');
    if (hours.isNotEmpty) {
      final worst = hours.entries.reduce((a, c) =>
      NetworkHealth.avg(a.value) <= NetworkHealth.avg(c.value) ? a : c);
      b.writeln('- Weakest hour: ${worst.key}:00 '
          '(avg health ${NetworkHealth.avg(worst.value).round()}/100)');
    }
    if (scored.isNotEmpty) {
      b.writeln('- Inspect first: ${scored.first}');
    }
    if (hours.isEmpty && scored.isEmpty) b.writeln('- Not enough data yet');

    return b.toString();
  }

  Widget _reportsTab(_Data d) {
    final report = _buildReport(d);

    // building summary
    final buildingScores = <String, List<double>>{};
    final buildingComplaints = <String, int>{};
    for (final n in d.names) {
      final b = d.buildingOf[n] ?? 'Unassigned';
      if (d.hasTests(n)) {
        buildingScores.putIfAbsent(b, () => []).add(d.scoreOf(n));
      }
      buildingComplaints[b] =
          (buildingComplaints[b] ?? 0) + d.totalComplaintsOf(n);
    }
    final buildings = {...buildingScores.keys, ...buildingComplaints.keys}
        .toList()
      ..sort();

    // locations ranked by health
    final ranked = d.names.where(d.hasTests).toList()
      ..sort((a, b) => d.scoreOf(b).compareTo(d.scoreOf(a)));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: report));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report copied')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Report'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openAnalytics,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Full Analytics'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _card(
          'Health Ranking',
          ranked.isEmpty
              ? const Text('No test data yet.')
              : Column(
            children: ranked
                .map((n) => _barRow(
                n,
                d.scoreOf(n) / 100,
                NetworkHealth.color(d.scoreOf(n)),
                '${d.scoreOf(n).round()}',
                labelWidth: 120))
                .toList(),
          ),
          subtitle: 'Average health score per location',
        ),
        _card(
          'Building Summary',
          buildings.isEmpty
              ? const Text('No buildings yet.')
              : Column(
            children: buildings.map((b) {
              final sc = buildingScores[b];
              final avg =
              sc == null || sc.isEmpty ? null : NetworkHealth.avg(sc);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  radius: 8,
                  backgroundColor:
                  avg == null ? Colors.grey : NetworkHealth.color(avg),
                ),
                title: Text(b),
                subtitle: Text('${buildingComplaints[b] ?? 0} complaints'),
                trailing: Text(avg == null ? 'N/A' : '${avg.round()}/100'),
              );
            }).toList(),
          ),
          subtitle: 'Set a Building when adding locations to group them',
        ),
        _card(
          'Written Report',
          SelectableText(report,
              style: const TextStyle(fontSize: 13, height: 1.4)),
          subtitle: 'Use "Copy Report" to paste it into a document or email',
        ),
      ],
    );
  }
}