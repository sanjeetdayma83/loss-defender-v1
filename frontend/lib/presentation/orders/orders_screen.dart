import "package:flutter/material.dart";
import "../../core/network/api_client.dart";

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _api = ApiClient();
  List<dynamic> _orders = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.dio.get("/orders");
      final data = res.data["data"];
      setState(() {
        _orders = data is List ? data : [];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Orders"),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  itemCount: _orders.length,
                  itemBuilder: (_, i) {
                    final o = _orders[i] as Map<String, dynamic>;
                    return ListTile(
                      title: Text(o["marketplaceOrderId"]?.toString() ?? o["id"]?.toString() ?? ""),
                      subtitle: Text("Status: ${o["status"]}"),
                      trailing: Text(o["marketplace"]?.toString() ?? ""),
                    );
                  },
                ),
    );
  }
}