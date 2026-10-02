import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageLocationsScreen extends StatelessWidget {
  const ManageLocationsScreen({super.key});

  static const defaults = [
    'Computer Lab 1',
    'Computer Lab 2',
    'Library',
    'Cafeteria',
    'Administration Block',
    'Department Building',
    'Hostel Block',
  ];

  CollectionReference get _col =>
      FirebaseFirestore.instance.collection('locations');

  Future<void> _add(BuildContext context) async {
    final name = TextEditingController();
    final building = TextEditingController();
    final floor = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(
                controller: building,
                decoration: const InputDecoration(labelText: 'Building')),
            const SizedBox(height: 8),
            TextField(
                controller: floor,
                decoration: const InputDecoration(labelText: 'Floor')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await _col.add({
                'name': name.text.trim(),
                'building': building.text.trim(),
                'floor': floor.text.trim(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Locations')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _col.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: ElevatedButton(
                onPressed: () {
                  for (final n in defaults) {
                    _col.add({'name': n, 'building': '', 'floor': ''});
                  }
                },
                child: const Text('Add default locations'),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: docs.map((d) {
              final l = d.data() as Map<String, dynamic>;
              final extra = [l['building'], l['floor']]
                  .where((e) => e != null && e.toString().isNotEmpty)
                  .join(' • ');
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(l['name'] ?? ''),
                  subtitle: extra.isEmpty ? null : Text(extra),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => d.reference.delete(),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}