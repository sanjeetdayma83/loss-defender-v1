import "package:flutter/material.dart";
import "../../core/network/api_client.dart";

class ReturnDetailScreen extends StatefulWidget {
  final String returnId;
  const ReturnDetailScreen({super.key, required this.returnId});
  @override
  State<ReturnDetailScreen> createState() => _ReturnDetailScreenState();
}

class _ReturnDetailScreenState extends State<ReturnDetailScreen> {
  Map<String, dynamic>? _ret;
  bool _loading = true;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.get("/returns/${widget.returnId}");
      setState(() => _ret = ApiClient.instance.unwrap<Map<String, dynamic>>(res));
    } catch (e) {
      setState(() => _error = ApiClient.instance.friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _decide(String decision) async {
    setState(() => _acting = true);
    try {
      await ApiClient.instance.dio.post("/returns/${widget.returnId}/decide", data: {
        "decision": decision,
      });
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiClient.instance.friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Return detail")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text("Order: ${_ret?["orderId"]}"),
                    Text("Condition: ${_ret?["condition"] ?? "-"}"),
                    Text("Decision: ${_ret?["decision"] ?? "pending"}"),
                    const SizedBox(height: 20),
                    if (_ret?["decision"] == null)
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _acting ? null : () => _decide("accepted"),
                            child: const Text("Accept"),
                          ),
                          OutlinedButton(
                            onPressed: _acting ? null : () => _decide("rejected"),
                            child: const Text("Reject"),
                          ),
                          OutlinedButton(
                            onPressed: _acting ? null : () => _decide("partial"),
                            child: const Text("Partial"),
                          ),
                        ],
                      ),
                  ],
                ),
    );
  }
}