import "package:flutter/material.dart";
import "../../core/network/api_client.dart";

class ClaimDetailScreen extends StatefulWidget {
  final String claimId;
  const ClaimDetailScreen({super.key, required this.claimId});
  @override
  State<ClaimDetailScreen> createState() => _ClaimDetailScreenState();
}

class _ClaimDetailScreenState extends State<ClaimDetailScreen> {
  Map<String, dynamic>? _claim;
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
      final res = await ApiClient.instance.dio.get("/claims/${widget.claimId}");
      setState(() => _claim = ApiClient.instance.unwrap<Map<String, dynamic>>(res));
    } catch (e) {
      setState(() => _error = ApiClient.instance.friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _decide(String decision) async {
    setState(() => _acting = true);
    try {
      await ApiClient.instance.dio.post("/claims/${widget.claimId}/decide", data: {
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
      appBar: AppBar(title: const Text("Claim detail")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(_claim?["reason"] ?? "",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text("Status: ${_claim?["status"]}"),
                    Text("Marketplace: ${_claim?["marketplace"]}"),
                    if (_claim?["description"] != null) ...[
                      const SizedBox(height: 8),
                      Text(_claim!["description"]),
                    ],
                    const SizedBox(height: 20),
                    if (!["approved", "rejected", "closed"].contains(_claim?["status"]))
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _acting ? null : () => _decide("approved"),
                            child: const Text("Approve"),
                          ),
                          OutlinedButton(
                            onPressed: _acting ? null : () => _decide("rejected"),
                            child: const Text("Reject"),
                          ),
                          OutlinedButton(
                            onPressed: _acting ? null : () => _decide("escalated"),
                            child: const Text("Escalate"),
                          ),
                        ],
                      ),
                  ],
                ),
    );
  }
}