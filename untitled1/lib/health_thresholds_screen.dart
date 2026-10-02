import 'package:flutter/material.dart';
import 'network_health.dart';

class HealthThresholdsScreen extends StatefulWidget {
  const HealthThresholdsScreen({super.key});

  @override
  State<HealthThresholdsScreen> createState() => _HealthThresholdsScreenState();
}

class _HealthThresholdsScreenState extends State<HealthThresholdsScreen> {
  final excellent = TextEditingController(text: '${NetworkHealth.excellent}');
  final good = TextEditingController(text: '${NetworkHealth.good}');
  final fair = TextEditingController(text: '${NetworkHealth.fair}');
  final poor = TextEditingController(text: '${NetworkHealth.poor}');
  final outage =
  TextEditingController(text: '${NetworkHealth.outageThreshold}');
  bool saving = false;

  @override
  void dispose() {
    for (final c in [excellent, good, fair, poor, outage]) {
      c.dispose();
    }
    super.dispose();
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  void _fill(int e, int g, int f, int p, int o) {
    excellent.text = '$e';
    good.text = '$g';
    fair.text = '$f';
    poor.text = '$p';
    outage.text = '$o';
  }

  Future<void> _save() async {
    final e = int.tryParse(excellent.text.trim());
    final g = int.tryParse(good.text.trim());
    final f = int.tryParse(fair.text.trim());
    final p = int.tryParse(poor.text.trim());
    final o = int.tryParse(outage.text.trim());

    if (e == null || g == null || f == null || p == null || o == null) {
      _msg('Please enter valid numbers');
      return;
    }
    if (!(e <= 100 && e > g && g > f && f > p && p > 0)) {
      _msg('Must be: Excellent > Good > Fair > Poor > 0 (max 100)');
      return;
    }
    if (o < 1) {
      _msg('Outage complaints must be at least 1');
      return;
    }

    setState(() => saving = true);
    try {
      await NetworkHealth.save(e, g, f, p, o);
      _msg('Thresholds saved');
    } catch (_) {
      _msg('Could not save thresholds');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _field(String label, String hint, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, helperText: hint),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Thresholds'),
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            icon: const Icon(Icons.restore),
            onPressed: () => setState(() => _fill(85, 70, 50, 30, 3)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Minimum health score (out of 100) for each status',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          _field('Excellent', 'Score ≥ this is Excellent', excellent),
          _field('Good', 'Score ≥ this is Good (green on heatmap)', good),
          _field('Fair', 'Score ≥ this is Fair (orange on heatmap)', fair),
          _field('Poor', 'Score ≥ this is Poor, below it is Critical', poor),
          const Divider(height: 28),
          _field('Outage complaints',
              'Open complaints at one location to flag an outage', outage),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3),
              )
                  : const Text('Save Thresholds'),
            ),
          ),
        ],
      ),
    );
  }
}