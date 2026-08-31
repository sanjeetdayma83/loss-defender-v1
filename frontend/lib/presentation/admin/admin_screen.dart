import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../core/network/api_client.dart";

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, dynamic>? _company;
  List<dynamic> _warehouses = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await ApiClient.instance.dio.get("/companies/me");
      final w = await ApiClient.instance.dio.get("/warehouses");
      setState(() {
        _company = Map<String, dynamic>.from(c.data["data"] as Map);
        _warehouses = w.data["data"] is List ? w.data["data"] : [];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin"),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go("/dashboard")),
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text("Company: ${_company?["companyName"] ?? "..."}"),
                Text("Plan: ${_company?["plan"] ?? ""}"),
                const Divider(),
                const Text("Warehouses", style: TextStyle(fontWeight: FontWeight.bold)),
                ..._warehouses.map((w) {
                  final m = w as Map<String, dynamic>;
                  return ListTile(title: Text(m["name"]?.toString() ?? ""), subtitle: Text(m["code"]?.toString() ?? ""));
                }),
              ],
            ),
    );
  }
}