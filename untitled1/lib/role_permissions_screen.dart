import 'package:flutter/material.dart';
import 'permission_service.dart';

class RolePermissionsScreen extends StatefulWidget {
  const RolePermissionsScreen({super.key});

  @override
  State<RolePermissionsScreen> createState() => _RolePermissionsScreenState();
}

class _RolePermissionsScreenState extends State<RolePermissionsScreen> {
  String role = PermissionService.roles.first;
  Set<String> perms = {};
  bool loading = true;
  bool saving = false;

  bool get isAdminRole => role == 'admin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _load() async {
    setState(() => loading = true);
    final p = await PermissionService.forRole(role);
    if (!mounted) return;
    setState(() {
      perms = {...p};
      loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await PermissionService.save(role, perms);
      _msg('Permissions saved');
    } catch (_) {
      _msg('Could not save permissions');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _reset() async {
    try {
      await PermissionService.reset(role);
      await _load();
      _msg('Reset to defaults');
    } catch (_) {
      _msg('Could not reset permissions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Permissions'),
        actions: [
          if (!isAdminRole)
            IconButton(
              tooltip: 'Reset to defaults',
              icon: const Icon(Icons.restore),
              onPressed: loading ? null : _reset,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: DropdownButtonFormField<String>(
              value: role,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Role'),
              items: PermissionService.roles
                  .map((r) => DropdownMenuItem(
                value: r,
                child: Text(PermissionService.roleLabels[r] ?? r),
              ))
                  .toList(),
              onChanged: (v) {
                if (v == null || v == role) return;
                setState(() => role = v);
                _load();
              },
            ),
          ),
          if (isAdminRole)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Admin always has every permission.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              padding: const EdgeInsets.all(12),
              children: PermissionService.grantable.entries.map((e) {
                return Card(
                  child: SwitchListTile(
                    title: Text(e.value),
                    value: perms.contains(e.key),
                    onChanged: isAdminRole
                        ? null
                        : (on) => setState(() {
                      if (on) {
                        perms.add(e.key);
                      } else {
                        perms.remove(e.key);
                      }
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
          if (!isAdminRole)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: saving || loading ? null : _save,
                  child: saving
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3),
                  )
                      : const Text('Save Permissions'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}