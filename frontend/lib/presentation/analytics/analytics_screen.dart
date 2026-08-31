import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../core/network/api_client.dart";

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _kpis;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.dio.get("/analytics/kpis");
      setState(() => _kpis = Map<String, dynamic>.from(res.data["data"] as Map));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics"),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go("/dashboard")),
      ),
      body: _kpis == null
          ? Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _kpis!.entries
                  .map((e) => ListTile(title: Text(e.key), trailing: Text("${e.value}")))
                  .toList(),
            ),
    );
  }
}