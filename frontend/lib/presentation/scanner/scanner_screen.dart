import "package:flutter/material.dart";
import "../../core/network/api_client.dart";

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _api = ApiClient();
  final _orderCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  String _result = "";
  bool _busy = false;

  Future<void> _scan() async {
    setState(() { _busy = true; _result = ""; });
    try {
      final res = await _api.dio.post("/scanner/validate", data: {
        "orderId": _orderCtrl.text.trim(),
        "barcode": _barcodeCtrl.text.trim(),
      });
      setState(() => _result = res.data.toString());
    } catch (e) {
      setState(() => _result = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scanner")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _orderCtrl, decoration: const InputDecoration(labelText: "Order ID")),
            TextField(controller: _barcodeCtrl, decoration: const InputDecoration(labelText: "Barcode / SKU")),
            const SizedBox(height: 12),
            FilledButton(onPressed: _busy ? null : _scan, child: Text(_busy ? "..." : "Validate")),
            const SizedBox(height: 16),
            Expanded(child: SingleChildScrollView(child: Text(_result))),
          ],
        ),
      ),
    );
  }
}