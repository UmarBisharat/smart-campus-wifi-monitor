import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'complaint_screen.dart';
import 'location_service.dart';
import 'network_health.dart';
import 'speed_test_service.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  List<String> locations = [];
  String? location;
  bool loadingLocations = true;
  bool loading = false;
  SpeedResult? result;
  String? testedLocation;
  String? error;

  @override
  void initState() {
    super.initState();
    LocationService.names().then((l) {
      if (!mounted) return;
      setState(() {
        locations = l;
        location = l.isNotEmpty ? l.first : null;
        loadingLocations = false;
      });
    });
  }

  Future<void> runTest() async {
    final loc = location;
    if (loc == null) return;
    setState(() {
      loading = true;
      error = null;
      result = null;
    });
    try {
      final r = await SpeedTestService.run();
      SpeedTestService.last = r;
      await FirebaseFirestore.instance.collection('speed_tests').add({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'location': loc,
        'download': r.download,
        'upload': r.upload,
        'ping': r.ping,
        'packetLoss': r.packetLoss,
        'healthScore': r.score,
        'healthStatus': r.status,
        'testedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() {
          result = r;
          testedLocation = loc;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error =
        'Speed test could not be completed. Please check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _metric(IconData icon, String label, String value) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value,
            style:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    ),
  );

  Widget _resultCard(SpeedResult r) {
    final c = NetworkHealth.color(r.score.toDouble());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current Test Result',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Location: $testedLocation',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Row(children: [
              _metric(Icons.download, 'Download',
                  '${r.download.toStringAsFixed(1)} Mbps'),
              _metric(Icons.upload, 'Upload',
                  '${r.upload.toStringAsFixed(1)} Mbps'),
              _metric(Icons.timer_outlined, 'Ping', '${r.ping.round()} ms'),
              _metric(Icons.signal_wifi_bad_outlined, 'Packet Loss',
                  '${r.packetLoss.round()}%'),
            ]),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Network Health: ${r.status} (${r.score}/100)',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: c),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ComplaintScreen()),
                ),
                child: const Text('Report a Problem'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Scaffold(
      appBar: AppBar(title: const Text('Speed Test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (loadingLocations)
            const Center(child: CircularProgressIndicator())
          else
            DropdownButtonFormField<String>(
              value: location,
              isExpanded: true,
              items: locations
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: loading ? null : (v) => setState(() => location = v),
              decoration: const InputDecoration(
                labelText: 'Select your current location',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              icon: loading
                  ? const SizedBox.shrink()
                  : const Icon(Icons.speed),
              onPressed: loading || location == null ? null : runTest,
              label: loading
                  ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3),
              )
                  : const Text('Run Speed Test'),
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Testing... this may take a few seconds',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            ),
          const SizedBox(height: 20),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if (r != null) _resultCard(r),
          if (location != null) ...[
            const SizedBox(height: 12),
            _LocationStatusCard(location: location!),
          ],
        ],
      ),
    );
  }
}

/// Live status for the selected location: averages, health, complaints and
/// outage warning.
class _LocationStatusCard extends StatelessWidget {
  final String location;
  const _LocationStatusCard({required this.location});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('speed_tests')
          .where('location', isEqualTo: location)
          .snapshots(),
      builder: (context, tSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: db
              .collection('complaints')
              .where('location', isEqualTo: location)
              .snapshots(),
          builder: (context, cSnap) {
            if (!tSnap.hasData || !cSnap.hasData) {
              return const SizedBox.shrink();
            }
            final tests = tSnap.data!.docs
                .map((d) => d.data() as Map<String, dynamic>)
                .toList();
            final comps = cSnap.data!.docs
                .map((d) => d.data() as Map<String, dynamic>)
                .toList();
            final open = comps.where((c) => c['status'] != 'Resolved').length;
            final outage = open >= NetworkHealth.outageThreshold;

            Widget body;
            if (tests.isEmpty) {
              body = const Text('No tests recorded here yet.',
                  style: TextStyle(color: Colors.grey));
            } else {
              final score =
              NetworkHealth.avg(tests.map((t) => t['healthScore'] as num));
              final dl =
              NetworkHealth.avg(tests.map((t) => t['download'] as num));
              final ul =
              NetworkHealth.avg(tests.map((t) => t['upload'] as num));
              final ping =
              NetworkHealth.avg(tests.map((t) => t['ping'] as num));
              final c = NetworkHealth.color(score);
              body = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(radius: 8, backgroundColor: c),
                    const SizedBox(width: 8),
                    Text(NetworkHealth.status(score),
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: c)),
                  ]),
                  const SizedBox(height: 8),
                  Text('Avg download: ${dl.toStringAsFixed(1)} Mbps'),
                  Text('Avg upload: ${ul.toStringAsFixed(1)} Mbps'),
                  Text('Avg ping: ${ping.round()} ms'),
                  Text('Tests: ${tests.length} • Open complaints: $open'),
                ],
              );
            }

            return Column(
              children: [
                if (outage)
                  Card(
                    color: Colors.red.shade100,
                    child: ListTile(
                      leading: const Icon(Icons.warning, color: Colors.red),
                      title: Text(
                        'Possible Wi-Fi outage detected in $location',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current status of $location',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        body,
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}