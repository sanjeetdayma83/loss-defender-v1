import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../core/network/api_client.dart";

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  String? _error;
  final _awb = TextEditingController();
  final _courier = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.dio.get("/orders/${widget.orderId}");
      setState(() => _order = Map<String, dynamic>.from(res.data["data"] as Map));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _dispatch() async {
    try {
      await ApiClient.instance.dio.post("/orders/${widget.orderId}/dispatch", data: {
        "awb": _awb.text.trim(),
        "courier": _courier.text.trim(),
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dispatched")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (_order?["items"] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(_order?["marketplaceOrderId"]?.toString() ?? "Order"),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go("/orders")),
      ),
      body: _order == null
          ? Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text("Status: ${_order!["status"]}"),
                const SizedBox(height: 12),
                const Text("Items", style: TextStyle(fontWeight: FontWeight.bold)),
                ...items.map((it) {
                  final m = it as Map<String, dynamic>;
                  return ListTile(
                    dense: true,
                    title: Text("${m["sku"]} × ${m["qty"]}"),
                    subtitle: Text("scanned: ${m["scannedQty"] ?? 0}"),
                  );
                }),
                const Divider(),
                FilledButton.icon(
                  onPressed: () => context.go("/scanner/${widget.orderId}"),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text("Open Scanner"),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go("/recording/${widget.orderId}"),
                  icon: const Icon(Icons.videocam),
                  label: const Text("Start Recording"),
                ),
                const SizedBox(height: 16),
                const Text("Dispatch", style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: _awb, decoration: const InputDecoration(labelText: "AWB")),
                TextField(controller: _courier, decoration: const InputDecoration(labelText: "Courier")),
                const SizedBox(height: 8),
                FilledButton(onPressed: _dispatch, child: const Text("Confirm Dispatch")),
              ],
            ),
    );
  }
}