import "package:flutter/material.dart";
import "../../core/network/api_client.dart";

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<dynamic> _users = [];
  bool _loading = true;
  String? _error;

  static const _roles = [
    "company_admin", "warehouse_manager", "supervisor", "packing_operator",
    "qc_operator", "claims_executive", "marketplace_manager", "viewer", "auditor",
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.get("/users");
      setState(() => _users = ApiClient.instance.unwrap<List<dynamic>>(res));
    } catch (e) {
      setState(() => _error = ApiClient.instance.friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _inviteDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = "packing_operator";
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Invite user"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
              DropdownButtonFormField<String>(
                initialValue: role,
                items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setDialogState(() => role = v ?? role),
                decoration: const InputDecoration(labelText: "Role"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Invite")),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final res = await ApiClient.instance.dio.post("/users/invite", data: {
        "name": nameCtrl.text.trim(),
        "email": emailCtrl.text.trim(),
        "role": role,
      });
      final data = ApiClient.instance.unwrap<Map<String, dynamic>>(res);
      _load();
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Invite created"),
            content: SelectableText(
              "Share this invite token with the user:\n\n${data["inviteToken"]}",
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiClient.instance.friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Users")),
      floatingActionButton: FloatingActionButton(
        onPressed: _inviteDialog,
        child: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final u = _users[i];
                      return ListTile(
                        title: Text(u["name"] ?? u["email"]),
                        subtitle: Text("${u["email"]} · ${u["role"]}"),
                        trailing: Text(u["status"] ?? ""),
                      );
                    },
                  ),
                ),
    );
  }
}