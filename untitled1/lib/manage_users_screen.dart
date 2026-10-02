import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'network_health.dart';
import 'permission_service.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final me = FirebaseAuth.instance.currentUser?.uid;
  String query = '';
  String roleFilter = 'All';

  Future<void> _changeRole(DocumentSnapshot d, String role) async {
    await d.reference.update({'role': role});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Role changed to $role')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: ['All', ...PermissionService.roles]
                  .map((r) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(r),
                  selected: roleFilter == r,
                  onSelected: (_) => setState(() => roleFilter = r),
                ),
              ))
                  .toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
              FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Could not load users.'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs.where((d) {
                  final u = d.data() as Map<String, dynamic>;
                  final matchRole =
                      roleFilter == 'All' || u['role'] == roleFilter;
                  final text =
                  '${u['name'] ?? ''} ${u['email'] ?? ''}'.toLowerCase();
                  return matchRole && text.contains(query);
                }).toList()
                  ..sort((a, b) => ((a.data() as Map)['name'] ?? '')
                      .toString()
                      .toLowerCase()
                      .compareTo(((b.data() as Map)['name'] ?? '')
                      .toString()
                      .toLowerCase()));

                if (docs.isEmpty) {
                  return const Center(child: Text('No users found'));
                }

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${docs.length} users',
                          style: const TextStyle(color: Colors.grey)),
                    ),
                    ...docs.map((d) {
                      final u = d.data() as Map<String, dynamic>;
                      final name = (u['name'] ?? 'User').toString();
                      final role = PermissionService.roles.contains(u['role'])
                          ? u['role'] as String
                          : 'student';
                      final created = (u['createdAt'] as Timestamp?)?.toDate();
                      final isMe = d.id == me;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                child: Text(name.isEmpty
                                    ? '?'
                                    : name[0].toUpperCase()),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(isMe ? '$name (You)' : name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text('${u['email'] ?? ''}',
                                        style: const TextStyle(fontSize: 13)),
                                    Text(
                                      'Joined: ${created == null ? '-' : NetworkHealth.formatTime(created)}',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownButton<String>(
                                value: role,
                                underline: const SizedBox(),
                                items: PermissionService.roles
                                    .map((r) => DropdownMenuItem(
                                    value: r, child: Text(r)))
                                    .toList(),
                                // admin can't change their own role
                                onChanged: isMe
                                    ? null
                                    : (v) {
                                  if (v != null && v != role) {
                                    _changeRole(d, v);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
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