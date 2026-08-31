import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../core/network/api_client.dart";

class ClaimsListScreen extends StatefulWidget {
  const ClaimsListScreen({super.key});
  @override
  State<ClaimsListScreen> createState() => _ClaimsListScreenState();
}

class _ClaimsListScreenState extends State<ClaimsListScreen> {
  List<dynamic> _claims = [];
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
      final res = await ApiClient.instance.dio.get("/claims", queryParameters: {"limit": 50});
      setState(() => _claims = ApiClient.instance.unwrap<List<dynamic>>(res));
    } catch (e) {
      setState(() => _error = ApiClient.instance.friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createClaimDialog() async {
    final orderIdCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String marketplace = "manual";
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New claim"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: orderIdCtrl, decoration: const InputDecoration(labelText: "Order ID")),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: "Reason")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Create")),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.instance.dio.post("/claims", data: {
        "orderId": orderIdCtrl.text.trim(),
        "reason": reasonCtrl.text.trim(),
        "marketplace": marketplace,
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
      appBar: AppBar(title: const Text("Claims")),
      floatingActionButton: FloatingActionButton(
        onPressed: _createClaimDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _claims.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = _claims[i];
                      return ListTile(
                        title: Text(c["reason"] ?? ""),
                        subtitle: Text("${c["marketplace"]} · ${c["status"]}"),
                        onTap: () =>
                            context.push("/claims/${c["id"]}").then((_) => _load()),
                      );
                    },
                  ),
                ),
    );
  }
}