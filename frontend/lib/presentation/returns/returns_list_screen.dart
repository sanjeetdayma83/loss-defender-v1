import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../core/network/api_client.dart";

class ReturnsListScreen extends StatefulWidget {
  const ReturnsListScreen({super.key});
  @override
  State<ReturnsListScreen> createState() => _ReturnsListScreenState();
}

class _ReturnsListScreenState extends State<ReturnsListScreen> {
  List<dynamic> _returns = [];
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
      final res = await ApiClient.instance.dio.get("/returns", queryParameters: {"limit": 50});
      setState(() => _returns = ApiClient.instance.unwrap<List<dynamic>>(res));
    } catch (e) {
      setState(() => _error = ApiClient.instance.friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createDialog() async {
    final orderIdCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New return"),
        content: TextField(
          controller: orderIdCtrl,
          decoration: const InputDecoration(labelText: "Order ID"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Create")),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.instance.dio.post("/returns", data: {"orderId": orderIdCtrl.text.trim()});
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
      appBar: AppBar(title: const Text("Returns")),
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
                    itemCount: _returns.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final r = _returns[i];
                      return ListTile(
                        title: Text("Order ${r["orderId"]}"),
                        subtitle: Text(r["decision"] ?? "pending decision"),
                        onTap: () =>
                            context.push("/returns/${r["id"]}").then((_) => _load()),
                      );
                    },
                  ),
                ),
    );
  }
}