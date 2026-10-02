import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'auth_controller.dart';
import 'location_service.dart';
import 'network_health.dart';

class ManageComplaintsScreen extends StatefulWidget {
  const ManageComplaintsScreen({super.key});

  @override
  State<ManageComplaintsScreen> createState() =>
      _ManageComplaintsScreenState();
}

class _ManageComplaintsScreenState extends State<ManageComplaintsScreen> {
  static const statuses = [
    'Submitted',
    'Reviewed',
    'Assigned',
    'In Progress',
    'Resolved',
  ];

  static const types = [
    'No Internet',
    'Slow Internet',
    'High Ping',
    'Frequent Disconnection',
    'Weak Signal',
    'Website / Service Unavailable',
    'Other',
  ];

  static const dates = ['Today', 'Last 7 days'];

  final AuthController auth = Get.find();
  final _db = FirebaseFirestore.instance;

  List<String> locations = [];
  String filterLocation = 'All';
  String filterStatus = 'All';
  String filterType = 'All';
  String filterDate = 'All';
  String staffName = 'Staff';

  @override
  void initState() {
    super.initState();
    LocationService.names().then((l) {
      if (mounted) setState(() => locations = l);
    });
    auth.getName().then((n) {
      if (mounted) setState(() => staffName = n);
    });
  }

  // ---------- helpers ----------

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

  DateTime _created(Map<String, dynamic> c) =>
      (c['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

  bool _matchesDate(Map<String, dynamic> c) {
    if (filterDate == 'All') return true;
    final d = _created(c);
    final now = DateTime.now();
    if (filterDate == 'Today') {
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }
    return now.difference(d).inDays < 7;
  }

  Future<void> _log(String action, String complaintId, String details) async {
    await _db.collection('activity_logs').add({
      'staff': staffName,
      'action': action,
      'complaintId': complaintId,
      'details': details,
      'at': FieldValue.serverTimestamp(),
    });
  }

  // ---------- actions ----------

  Future<void> _setStatus(
      DocumentSnapshot d, Map<String, dynamic> c, String status) async {
    await d.reference.update({
      'status': status,
      if (status == 'Assigned' && c['assignedStaff'] == null)
        'assignedStaff': staffName,
      if (status == 'Resolved') 'resolvedAt': FieldValue.serverTimestamp(),
    });
    await _log('Status changed', d.id,
        '${c['type']} • ${c['location']} → $status');
  }

  Future<void> _assignToMe(DocumentSnapshot d, Map<String, dynamic> c) async {
    final st = c['status'];
    await d.reference.update({
      'assignedStaff': staffName,
      if (st == 'Submitted' || st == 'Reviewed') 'status': 'Assigned',
    });
    await _log('Assigned', d.id,
        '${c['type']} • ${c['location']} assigned to $staffName');
  }

  Future<void> _addNote(DocumentSnapshot d, Map<String, dynamic> c) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Maintenance Note'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Note'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;

    await d.reference.update({
      'notes': FieldValue.arrayUnion([
        {'text': text, 'by': staffName, 'at': Timestamp.now()}
      ]),
    });
    await _log('Note added', d.id, '${c['location']}: $text');
  }

  // ---------- UI ----------

  Widget _card(DocumentSnapshot d) {
    final c = d.data() as Map<String, dynamic>;
    final notes = (c['notes'] as List?) ?? [];
    final status = statuses.contains(c['status']) ? c['status'] : 'Submitted';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${c['type']} • ${c['location']}',
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(NetworkHealth.formatTime(_created(c)),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            Text(c['description'] ?? ''),
            if (c['download'] != null && c['ping'] != null)
              Text(
                'Speed: ${(c['download'] as num).toStringAsFixed(1)} Mbps, '
                    'Ping: ${(c['ping'] as num).round()} ms',
                style: const TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 6),
            Text(
              c['assignedStaff'] != null
                  ? 'Assigned to: ${c['assignedStaff']}'
                  : 'Not assigned yet',
              style: TextStyle(
                  color: c['assignedStaff'] != null
                      ? Colors.green
                      : Colors.orange),
            ),
            if (notes.isNotEmpty) ...[
              const Divider(height: 20),
              const Text('Maintenance notes',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...notes.map((n) {
                final m = Map<String, dynamic>.from(n as Map);
                final at = (m['at'] as Timestamp?)?.toDate();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${m['text']}  — ${m['by']}'
                        '${at != null ? ' (${NetworkHealth.formatTime(at)})' : ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: status,
                    isExpanded: true,
                    items: statuses
                        .map((s) =>
                        DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null && v != status) _setStatus(d, c, v);
                    },
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                if (c['assignedStaff'] != staffName)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.person_add_alt, size: 18),
                    label: const Text('Assign to me'),
                    onPressed: () => _assignToMe(d, c),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.note_add_outlined, size: 18),
                  label: const Text('Add note'),
                  onPressed: () => _addNote(d, c),
                ),
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
        title: const Text('Complaints'),
        actions: [
          IconButton(
            tooltip: 'Activity log',
            icon: const Icon(Icons.history),
            onPressed: () => Get.to(() => const _ActivityLogScreen()),
          ),
        ],
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
                    _filter('Status', filterStatus, statuses,
                            (v) => setState(() => filterStatus = v)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _filter('Type', filterType, types,
                            (v) => setState(() => filterType = v)),
                    const SizedBox(width: 8),
                    _filter('Date', filterDate, dates,
                            (v) => setState(() => filterDate = v)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('complaints')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                      child: Text('Could not load complaints.'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs.where((d) {
                  final c = d.data() as Map<String, dynamic>;
                  return (filterLocation == 'All' ||
                      c['location'] == filterLocation) &&
                      (filterStatus == 'All' ||
                          c['status'] == filterStatus) &&
                      (filterType == 'All' || c['type'] == filterType) &&
                      _matchesDate(c);
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('No complaints found'));
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: docs.map(_card).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent IT staff actions (status changes, assignments, notes).
class _ActivityLogScreen extends StatelessWidget {
  const _ActivityLogScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IT Activity Log')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('activity_logs')
            .orderBy('at', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load activity log.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No activity yet'));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: docs.map((d) {
              final l = d.data() as Map<String, dynamic>;
              final at = (l['at'] as Timestamp?)?.toDate();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: Text('${l['action']} • ${l['staff']}'),
                  subtitle: Text(l['details'] ?? ''),
                  trailing: Text(
                    at == null ? '' : NetworkHealth.formatTime(at),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
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