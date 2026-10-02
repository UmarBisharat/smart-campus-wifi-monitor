import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'location_service.dart';
import 'network_health.dart';

// full = true  -> stats + outages + locations (IT, manager, admin)
// full = false -> outages + locations only (students)
class DashboardBody extends StatelessWidget {
  final bool full;
  const DashboardBody({super.key, this.full = true});

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

  DateTime _time(Map<String, dynamic> t) =>
      (t['testedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

  void _showOutage(BuildContext context, String loc, int n) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Wi-Fi Outage'),
        content: Text(
          'Possible Wi-Fi outage detected in $loc.\n\n'
              '$n unresolved complaints have been reported for this location. '
              'The IT team has been notified and is investigating.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
  }

  void _showLocation(BuildContext context, String name,
      List<Map<String, dynamic>> tests, int nComp, bool outage) {
    final sorted = [...tests]..sort((a, b) => _time(b).compareTo(_time(a)));
    final latest = sorted.isEmpty ? null : sorted.first;
    final score = NetworkHealth.avg(tests.map((t) => t['healthScore'] as num));

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (tests.isEmpty)
              const Text('No tests recorded for this location yet.')
            else ...[
              Row(children: [
                CircleAvatar(
                    radius: 8, backgroundColor: NetworkHealth.color(score)),
                const SizedBox(width: 8),
                Text(
                    'Status: ${NetworkHealth.status(score)} (${score.round()}/100)',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 12),
              Text(
                  'Latest test: ${(latest!['download'] as num).toStringAsFixed(1)} Mbps down, '
                      '${(latest['upload'] as num).toStringAsFixed(1)} Mbps up, '
                      '${(latest['ping'] as num).round()} ms'),
              Text('Tested at: ${NetworkHealth.formatTime(_time(latest))}',
                  style: const TextStyle(color: Colors.grey)),
              const Divider(height: 24),
              Text(
                  'Avg download: ${NetworkHealth.avg(tests.map((t) => t['download'] as num)).toStringAsFixed(1)} Mbps'),
              Text(
                  'Avg upload: ${NetworkHealth.avg(tests.map((t) => t['upload'] as num)).toStringAsFixed(1)} Mbps'),
              Text(
                  'Avg ping: ${NetworkHealth.avg(tests.map((t) => t['ping'] as num)).round()} ms'),
              Text('Number of tests: ${tests.length}'),
              Text('Complaints: $nComp'),
            ],
            if (outage) ...[
              const SizedBox(height: 12),
              const Row(children: [
                Icon(Icons.warning, color: Colors.red, size: 18),
                SizedBox(width: 6),
                Text('Possible outage in this location',
                    style: TextStyle(color: Colors.red)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('speed_tests').snapshots(),
      builder: (context, testSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: db.collection('complaints').snapshots(),
          builder: (context, compSnap) {
            if (testSnap.hasError || compSnap.hasError) {
              return const Center(
                  child: Text('Could not load network data.'));
            }
            if (!testSnap.hasData || !compSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final tests = testSnap.data!.docs
                .map((d) => d.data() as Map<String, dynamic>)
                .where((t) => t['location'] != null)
                .toList();
            final comps = compSnap.data!.docs
                .map((d) => d.data() as Map<String, dynamic>)
                .toList();

            final now = DateTime.now();
            final today = tests.where((t) {
              final d = (t['testedAt'] as Timestamp?)?.toDate();
              return d != null &&
                  d.year == now.year &&
                  d.month == now.month &&
                  d.day == now.day;
            }).length;

            final byLoc = <String, List<Map<String, dynamic>>>{};
            for (final t in tests) {
              byLoc.putIfAbsent(t['location'].toString(), () => []).add(t);
            }

            final poor = byLoc.values
                .where((l) =>
            NetworkHealth.avg(l.map((t) => t['healthScore'] as num)) <
                50)
                .length;
            final open = comps.where((c) => c['status'] != 'Resolved').length;
            final resolved = comps.length - open;

            final outages = NetworkHealth.outages(comps);

            // All known locations (even those with no tests yet)
            return FutureBuilder<List<String>>(
              future: LocationService.names(),
              builder: (context, locSnap) {
                final names = <String>{
                  ...(locSnap.data ?? const <String>[]),
                  ...byLoc.keys,
                }.toList()
                  ..sort();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ---------- OUTAGES ----------
                    Text('Current Outages',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (outages.isEmpty)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.check_circle,
                              color: Colors.green),
                          title: const Text('No outages detected'),
                          subtitle: const Text('Campus Wi-Fi looks normal'),
                        ),
                      )
                    else
                      ...outages.entries.map(
                            (e) => Card(
                          color: Colors.red.shade100,
                          child: ListTile(
                            leading:
                            const Icon(Icons.warning, color: Colors.red),
                            title: Text(
                              'Possible Wi-Fi outage detected in ${e.key}',
                              style: const TextStyle(color: Colors.black),
                            ),
                            subtitle: Text(
                                '${e.value} open complaints • tap for details',
                                style: const TextStyle(color: Colors.black54)),
                            onTap: () =>
                                _showOutage(context, e.key, e.value),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // ---------- STATS (staff only) ----------
                    if (full) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _stat('Tests today', '$today'),
                          _stat('Avg download',
                              '${NetworkHealth.avg(tests.map((t) => t['download'] as num)).toStringAsFixed(1)} Mbps'),
                          _stat('Avg upload',
                              '${NetworkHealth.avg(tests.map((t) => t['upload'] as num)).toStringAsFixed(1)} Mbps'),
                          _stat('Avg ping',
                              '${NetworkHealth.avg(tests.map((t) => t['ping'] as num)).round()} ms'),
                          _stat('Poor locations', '$poor'),
                          _stat('Open complaints', '$open'),
                          _stat('Resolved', '$resolved'),
                          _stat('Current outages', '${outages.length}'),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ---------- LOCATIONS ----------
                    Text(full ? 'Locations' : 'Network Health by Location',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Tap a location for details',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 8),
                    if (names.isEmpty) const Text('No locations yet'),
                    ...names.map((name) {
                      final lt = byLoc[name] ?? [];
                      final nComp =
                          comps.where((c) => c['location'] == name).length;
                      final hasTests = lt.isNotEmpty;
                      final score = hasTests
                          ? NetworkHealth.avg(
                          lt.map((t) => t['healthScore'] as num))
                          : 0.0;
                      final dl = NetworkHealth.avg(
                          lt.map((t) => t['download'] as num));
                      final ping =
                      NetworkHealth.avg(lt.map((t) => t['ping'] as num));
                      final isOutage = outages.containsKey(name);

                      return Card(
                        child: ListTile(
                          onTap: () => _showLocation(
                              context, name, lt, nComp, isOutage),
                          leading: CircleAvatar(
                            radius: 8,
                            backgroundColor: hasTests
                                ? NetworkHealth.color(score)
                                : Colors.grey,
                          ),
                          title: Text(name),
                          subtitle: Text(!hasTests
                              ? 'No tests yet'
                              : full
                              ? '${dl.toStringAsFixed(1)} Mbps • ${ping.round()} ms • $nComp complaints'
                              : '${dl.toStringAsFixed(1)} Mbps • ${ping.round()} ms'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isOutage)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(Icons.warning,
                                      color: Colors.red, size: 18),
                                ),
                              Text(hasTests
                                  ? NetworkHealth.status(score)
                                  : 'N/A'),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}