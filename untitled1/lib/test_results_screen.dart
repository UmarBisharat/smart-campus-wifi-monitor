import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'location_service.dart';
import 'network_health.dart';

/// All network speed-test results, with filters.
/// For IT staff, managers and admins.
class TestResultsScreen extends StatefulWidget {
  const TestResultsScreen({super.key});

  @override
  State<TestResultsScreen> createState() => _TestResultsScreenState();
}

class _TestResultsScreenState extends State<TestResultsScreen> {
  static const statuses = ['Excellent', 'Good', 'Fair', 'Poor', 'Critical'];
  static const dates = ['Today', 'Last 7 days'];

  List<String> locations = [];
  String filterLocation = 'All';
  String filterStatus = 'All';
  String filterDate = 'All';

  @override
  void initState() {
    super.initState();
    LocationService.names().then((l) {
      if (mounted) setState(() => locations = l);
    });
  }

  Widget _filter(String label, String value, List<String> options,
      ValueChanged<String> onChanged) {
    return Expanded(
      child: DropdownButtonFormField<String>(
        value: options.contains(value) ? value : 'All',
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: ['All', ...options]
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }

  DateTime _time(Map<String, dynamic> t) =>
      (t['testedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

  bool _matchesDate(Map<String, dynamic> t) {
    if (filterDate == 'All') return true;
    final d = _time(t);
    final now = DateTime.now();
    if (filterDate == 'Today') {
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }
    return now.difference(d).inDays < 7;
  }

  Widget _metric(String label, String value) => Expanded(
    child: Column(
      children: [
        Text(value,
            style:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    ),
  );

  Widget _card(Map<String, dynamic> t) {
    final score = (t['healthScore'] as num?)?.toDouble() ?? 0;
    final c = NetworkHealth.color(score);
    final status = t['healthStatus'] ?? NetworkHealth.status(score);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${t['location']}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$status • ${score.round()}/100',
                      style: TextStyle(
                          color: c,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(NetworkHealth.formatTime(_time(t)),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              children: [
                _metric('Download',
                    '${((t['download'] as num?) ?? 0).toStringAsFixed(1)} Mbps'),
                _metric('Upload',
                    '${((t['upload'] as num?) ?? 0).toStringAsFixed(1)} Mbps'),
                _metric('Ping', '${((t['ping'] as num?) ?? 0).round()} ms'),
                _metric('Loss', '${((t['packetLoss'] as num?) ?? 0).round()}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Test Results',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    _filter('Location', filterLocation, locations,
                            (v) => setState(() => filterLocation = v)),
                    const SizedBox(width: 8),
                    _filter('Network status', filterStatus, statuses,
                            (v) => setState(() => filterStatus = v)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _filter('Date', filterDate, dates,
                            (v) => setState(() => filterDate = v)),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('speed_tests')
                  .orderBy('testedAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Could not load results.'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tests = snap.data!.docs
                    .map((d) => d.data() as Map<String, dynamic>)
                    .where((t) =>
                (filterLocation == 'All' ||
                    t['location'] == filterLocation) &&
                    (filterStatus == 'All' ||
                        t['healthStatus'] == filterStatus) &&
                    _matchesDate(t))
                    .toList();

                if (tests.isEmpty) {
                  return const Center(child: Text('No test results found'));
                }

                final avgDl = NetworkHealth.avg(
                    tests.map((t) => (t['download'] as num?) ?? 0));
                final avgPing = NetworkHealth.avg(
                    tests.map((t) => (t['ping'] as num?) ?? 0));

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${tests.length} tests • Avg ${avgDl.toStringAsFixed(1)} Mbps • ${avgPing.round()} ms',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    ...tests.map(_card),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}