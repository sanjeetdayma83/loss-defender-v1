import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../core/network/api_client.dart";

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});
  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;

  static const _statuses = [
    "synced", "queued", "packing", "recording", "scanned", "evidence_ready",
    "dispatched", "shipped", "claimed", "returned", "closed",
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.get("/orders", queryParameters: {
        if (_statusFilter != null) "status": _statusFilter,
        "limit": 50,
      });
      final data = ApiClient.instance.unwrap<List<dynamic>>(res);
      setState(() => _orders = data);
    } catch (e) {
      setState(() => _error = ApiClient.instance.friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Orders")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push("/orders/new").then((_) => _load()),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: const Text("All"),
                    selected: _statusFilter == null,
                    onSelected: (_) { _statusFilter = null; _load(); },
                  ),
                ),
                for (final s in _statuses)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(s),
                      selected: _statusFilter == s,
                      onSelected: (_) { _statusFilter = s; _load(); },
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _orders.isEmpty
                            ? ListView(children: const [
                                Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(child: Text("No orders found")),
                                ),
                              ])
                            : ListView.separated(
                                itemCount: _orders.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final o = _orders[i];
                                  return ListTile(
                                    title: Text(o["marketplaceOrderId"] ?? o["id"]),
                                    subtitle: Text("${o["marketplace"]} · ${o["status"]}"),
                                    trailing: Text(o["awb"] ?? ""),
                                    onTap: () => context
                                        .push("/orders/${o["id"]}")
                                        .then((_) => _load()),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}