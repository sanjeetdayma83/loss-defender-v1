import "package:flutter/material.dart";
import "../../core/network/api_client.dart";

class _ItemRow {
  final skuCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: "1");
}

class OrderCreateScreen extends StatefulWidget {
  const OrderCreateScreen({super.key});
  @override
  State<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends State<OrderCreateScreen> {
  final _marketplaceOrderIdCtrl = TextEditingController();
  final _warehouseIdCtrl = TextEditingController();
  String _marketplace = "manual";
  final List<_ItemRow> _items = [_ItemRow()];
  bool _saving = false;
  String? _error;

  static const _marketplaces = ["manual", "amazon", "flipkart", "meesho", "shopify", "woocommerce"];

  Future<void> _submit() async {
    final items = _items
        .where((r) => r.skuCtrl.text.trim().isNotEmpty)
        .map((r) => {
              "sku": r.skuCtrl.text.trim(),
              "qty": int.tryParse(r.qtyCtrl.text.trim()) ?? 1,
            })
        .toList();
    if (items.isEmpty) {
      setState(() => _error = "Add at least one item with a SKU");
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ApiClient.instance.dio.post("/orders", data: {
        "marketplace": _marketplace,
        if (_marketplaceOrderIdCtrl.text.trim().isNotEmpty)
          "marketplaceOrderId": _marketplaceOrderIdCtrl.text.trim(),
        if (_warehouseIdCtrl.text.trim().isNotEmpty)
          "warehouseId": _warehouseIdCtrl.text.trim(),
        "items": items,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = ApiClient.instance.friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Order")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _marketplace,
            decoration: const InputDecoration(labelText: "Marketplace"),
            items: _marketplaces
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _marketplace = v ?? "manual"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _marketplaceOrderIdCtrl,
            decoration: const InputDecoration(labelText: "Marketplace order ID (optional)"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _warehouseIdCtrl,
            decoration: const InputDecoration(labelText: "Warehouse ID (optional)"),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Items", style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => setState(() => _items.add(_ItemRow())),
                icon: const Icon(Icons.add),
                label: const Text("Add item"),
              ),
            ],
          ),
          for (final row in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: row.skuCtrl,
                      decoration: const InputDecoration(labelText: "SKU"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Qty"),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Create order"),
          ),
        ],
      ),
    );
  }
}