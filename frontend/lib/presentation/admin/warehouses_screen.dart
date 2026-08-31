import "package:flutter/material.dart";
import "../../core/network/api_client.dart";

class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({super.key});
  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  List<dynamic> _warehouses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.get("/warehouses");
      setState(() => _warehouses = ApiClient.instance.unwrap<List<dynamic>>(res));
    } catch (e) {
      setState(() => _error = ApiClient.instance.friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createDialog() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final tzCtrl = TextEditingController(text: "Asia/Kolkata");
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New warehouse"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: "Code")),
              TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: "City")),
              TextField(controller: stateCtrl, decoration: const InputDecoration(labelText: "State")),
              TextField(controller: tzCtrl, decoration: const InputDecoration(labelText: "Timezone")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Create")),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.instance.dio.post("/warehouses", data: {
        "name": nameCtrl.text.trim(),
        "code": codeCtrl.text.trim(),
        "address": {},
        "city": cityCtrl.text.trim(),
        "state": stateCtrl.text.trim(),
        "timezone": tzCtrl.text.trim(),
      });
      _load();
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
      appBar: AppBar(title: const Text("Warehouses")),
      floatingActionButton: FloatingActionButton(
        onPressed: _createDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _warehouses.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final w = _warehouses[i];
                      final stations = (w["stations"] as List?) ?? [];
                      return ListTile(
                        title: Text("${w["name"]} (${w["code"]})"),
                        subtitle: Text("${w["city"]}, ${w["state"]} · ${stations.length} stations"),
                        trailing: Text(w["status"] ?? ""),
                      );
                    },
                  ),
                ),
    );
  }
}