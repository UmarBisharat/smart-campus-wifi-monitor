import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'location_service.dart';
import 'speed_test_service.dart';

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final types = [
    'No Internet',
    'Slow Internet',
    'High Ping',
    'Frequent Disconnection',
    'Weak Signal',
    'Website / Service Unavailable',
    'Other',
  ];

  List<String> locations = [];
  String? location;
  String type = 'Slow Internet';
  bool attach = true;
  bool loading = false;
  final desc = TextEditingController();

  @override
  void initState() {
    super.initState();
    LocationService.names().then((l) {
      if (!mounted) return;
      setState(() {
        locations = l;
        location = l.isNotEmpty ? l.first : null;
      });
    });
  }

  Future<void> submit() async {
    if (location == null) {
      Get.snackbar('Error', 'No location selected');
      return;
    }
    if (desc.text.trim().isEmpty) {
      Get.snackbar('Error', 'Please describe the problem');
      return;
    }
    setState(() => loading = true);

    final r = SpeedTestService.last;
    await FirebaseFirestore.instance.collection('complaints').add({
      'userId': FirebaseAuth.instance.currentUser!.uid,
      'location': location,
      'type': type,
      'description': desc.text.trim(),
      'status': 'Submitted',
      if (attach && r != null) 'download': r.download,
      if (attach && r != null) 'ping': r.ping,
      'createdAt': FieldValue.serverTimestamp(),
    });

    Get.back();
    Get.snackbar('Done', 'Complaint submitted');
  }

  @override
  Widget build(BuildContext context) {
    final r = SpeedTestService.last;
    return Scaffold(
      appBar: AppBar(title: const Text('Report a Problem')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (locations.isEmpty)
            const Text('No locations yet. Ask the admin to add locations.')
          else
            DropdownButtonFormField<String>(
              value: location,
              items: locations
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => location = v),
              decoration: const InputDecoration(labelText: 'Location'),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: type,
            items: types
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => type = v!),
            decoration: const InputDecoration(labelText: 'Problem type'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: desc,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          if (r != null)
            CheckboxListTile(
              value: attach,
              onChanged: (v) => setState(() => attach = v!),
              title: Text(
                'Attach last speed test (${r.download.toStringAsFixed(1)} Mbps, ${r.ping.round()} ms)',
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: loading ? null : submit,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }
}