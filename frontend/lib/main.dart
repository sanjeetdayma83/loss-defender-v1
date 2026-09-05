import "dart:io";
import "package:clerk_auth/clerk_auth.dart";
import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "core/theme/app_theme.dart";
import "presentation/auth/auth_screens_01_04.dart";
import "presentation/auth/auth_screens_05_10.dart";
import "presentation/shell/app_shell.dart";
import "presentation/dashboard/admin_dashboard_page.dart";
import "presentation/orders/orders_list_page.dart";
import "presentation/operator/operator_shell.dart";
import "presentation/operator/scan/scan_flow_pages.dart";

class Env {
  static const apiBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "http://127.0.0.1:3000/api/v1",
  );
  static const clerkPk = String.fromEnvironment(
    "CLERK_PUBLISHABLE_KEY",
    defaultValue: "",
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LossDefenderApp());
}

class LossDefenderApp extends StatelessWidget {
  const LossDefenderApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "LOSS DEFENDER",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const RootApp(),
    );
  }
}

class RootApp extends StatefulWidget {
  const RootApp({super.key});
  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  Auth? _auth;
  String? _bootErr;
  bool _booting = true;
  String? _jwt;
  Map<String, dynamic>? _user;
  String? _email;
  bool _need2fa = false;

  // navigation after login
  String _adminPage = "dashboard";
  String _opPage = "scan";
  // operator scan state
  Map<String, dynamic>? _scanOrder;
  String _scanPhase = "home"; // home | loaded | items | recording | done

  List<dynamic> _orders = [];
  List<dynamic> _plans = [];
  bool _loadingOrders = false;

  final _dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 20),
  ));

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (kIsWeb) {
      setState(() {
        _booting = false;
        _bootErr =
            "Web: use Clerk JS bridge. This build targets Windows (clerk_auth).";
      });
      return;
    }
    if (Env.clerkPk.isEmpty) {
      setState(() {
        _booting = false;
        _bootErr = "CLERK_PUBLISHABLE_KEY missing — pass --dart-define";
      });
      return;
    }
    try {
      final auth = Auth(
        config: AuthConfig(
          publishableKey: Env.clerkPk,
          persistor: DefaultPersistor(
            getCacheDirectory: () => Directory.systemTemp,
          ),
        ),
      );
      await auth.initialize();
      if (!mounted) return;
      setState(() {
        _auth = auth;
        _booting = false;
      });
      if (auth.isSignedIn) await _syncFromSession();
    } catch (e) {
      setState(() {
        _booting = false;
        _bootErr = "Clerk init: $e";
      });
    }
  }

  @override
  void dispose() {
    _auth?.terminate();
    super.dispose();
  }

  Future<String?> _jwtFromAuth() async {
    try {
      return (await _auth!.sessionToken()).jwt;
    } catch (_) {
      return _auth?.session?.lastActiveToken?.jwt;
    }
  }

  Future<void> _syncFromSession() async {
    final jwt = await _jwtFromAuth();
    if (jwt == null || jwt.isEmpty) return;
    _jwt = jwt;
    _dio.options.headers["Authorization"] = "Bearer $jwt";
    final r = await _dio.get("/auth/sync");
    final body = Map<String, dynamic>.from(r.data as Map);
    final data = body["data"];
    if (data is Map) {
      setState(() => _user = Map<String, dynamic>.from(data));
    } else {
      setState(() => _user = {});
    }
  }

  Future<void> _signIn(String email, String password) async {
    _email = email;
    await _auth!.attemptSignIn(
      strategy: Strategy.password,
      identifier: email,
      password: password,
    );
    if (_auth!.isSignedIn) {
      await _syncFromSession();
      setState(() => _need2fa = false);
      return;
    }
    final st = _auth!.signIn?.status.toString() ?? "";
    if (st.contains("second_factor") || st.contains("SecondFactor")) {
      try {
        await _auth!.attemptSignIn(strategy: Strategy.emailCode);
      } catch (_) {
        try {
          await _auth!.attemptSignIn(strategy: Strategy.phoneCode);
        } catch (_) {}
      }
      setState(() => _need2fa = true);
      return;
    }
    throw Exception("Sign-in status: $st");
  }

  Future<void> _verify2fa(String code) async {
    try {
      await _auth!.attemptSignIn(strategy: Strategy.emailCode, code: code);
    } catch (_) {
      await _auth!.attemptSignIn(strategy: Strategy.phoneCode, code: code);
    }
    if (!_auth!.isSignedIn) {
      throw Exception("Status: ${_auth!.signIn?.status}");
    }
    await _syncFromSession();
    setState(() => _need2fa = false);
  }

  Future<void> _signOut() async {
    await _auth?.signOut();
    _jwt = null;
    _user = null;
    _dio.options.headers.remove("Authorization");
    setState(() {
      _need2fa = false;
      _scanOrder = null;
      _scanPhase = "home";
      _adminPage = "dashboard";
    });
  }

  bool get _signedIn => _auth?.isSignedIn == true && _user != null;
  bool get _hasCompany {
    final c = _user?["companyId"]?.toString();
    return c != null && c.isNotEmpty;
  }

  String get _role => _user?["role"]?.toString() ?? "";
  bool get _isOperator =>
      _role == "packing_operator" || _role == "qc_operator";

  Future<void> _loadOrders() async {
    setState(() => _loadingOrders = true);
    try {
      final r = await _dio.get("/orders");
      final body = Map<String, dynamic>.from(r.data as Map);
      setState(() => _orders = (body["data"] as List?) ?? []);
    } catch (e) {
      debugPrint("orders: $e");
    } finally {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  Future<void> _loadPlans() async {
    try {
      final r = await _dio.get("/billing/plans");
      final body = Map<String, dynamic>.from(r.data as Map);
      setState(() => _plans = (body["data"] as List?) ?? []);
    } catch (e) {
      debugPrint("plans: $e");
    }
  }

  Future<void> _openOrderForScan(String idOrAwb) async {
    // Try list match first
    await _loadOrders();
    Map<String, dynamic>? found;
    for (final o in _orders) {
      final m = Map<String, dynamic>.from(o as Map);
      if (m["id"] == idOrAwb ||
          m["marketplaceOrderId"]?.toString() == idOrAwb ||
          m["awb"]?.toString() == idOrAwb) {
        found = m;
        break;
      }
    }
    if (found == null && idOrAwb.length > 10) {
      try {
        final r = await _dio.get("/orders/$idOrAwb");
        final body = Map<String, dynamic>.from(r.data as Map);
        if (body["data"] is Map) {
          found = Map<String, dynamic>.from(body["data"] as Map);
        }
      } catch (_) {}
    }
    if (found == null) {
      // fallback first order for demo
      if (_orders.isNotEmpty) {
        found = Map<String, dynamic>.from(_orders.first as Map);
      } else {
        throw Exception("Order not found: $idOrAwb");
      }
    }
    setState(() {
      _scanOrder = found;
      _scanPhase = "loaded";
    });
  }

  Future<Map<String, dynamic>> _validateSku(String sku) async {
    final oid = _scanOrder?["id"]?.toString();
    if (oid == null) throw Exception("No order");
    try {
      final r = await _dio.post("/scanner/validate", data: {
        "orderId": oid,
        "sku": sku,
        "qty": 1,
      });
      final body = Map<String, dynamic>.from(r.data as Map);
      return {"status": "ok", "data": body["data"], "order": body["data"]};
    } on DioException catch (e) {
      final msg = e.response?.data?.toString() ?? e.message ?? "fail";
      if (msg.toLowerCase().contains("duplicate") ||
          msg.toLowerCase().contains("already")) {
        return {"status": "duplicate", "message": msg};
      }
      return {"status": "wrong", "message": msg};
    }
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_bootErr != null) {
      return Scaffold(body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_bootErr!, textAlign: TextAlign.center),
      )));
    }

    if (!_signedIn) {
      if (_need2fa) {
        return VerificationScreen(
          email: _email ?? "",
          onVerify: _verify2fa,
          onResend: () async {
            try {
              await _auth!.attemptSignIn(strategy: Strategy.emailCode);
            } catch (_) {}
          },
        );
      }
      return SignInScreen(
        onSignIn: _signIn,
        onForgot: () {}, // wire ForgotPasswordScreen route if needed
        onSignUp: () {},
      );
    }

    if (!_hasCompany) {
      return PendingInviteScreen(
        onContactAdmin: () {},
        onSignOut: _signOut,
      );
    }

    // Role home
    if (_isOperator) return _buildOperator();
    return _buildAdmin();
  }

  Widget _buildAdmin() {
    Widget body;
    switch (_adminPage) {
      case "orders":
        body = OrdersListPage(
          orders: _orders,
          loading: _loadingOrders,
          onRefresh: _loadOrders,
          onCreate: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Create Order UI — next polish")),
            );
          },
          onOpen: (id) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Order $id")),
            );
          },
        );
        break;
      case "billing":
        body = _BillingPage(plans: _plans, onRefresh: _loadPlans);
        break;
      case "scan":
        return _buildOperator(); // admin can open scan too
      default:
        body = AdminDashboardPage(recentOrders: _orders);
    }

    return AppShell(
      currentId: _adminPage == "scan" ? "orders" : _adminPage,
      title: _adminPage[0].toUpperCase() + _adminPage.substring(1),
      userName: _user?["email"]?.toString(),
      roleLabel: _role,
      onSignOut: _signOut,
      onNavigate: (id) {
        setState(() => _adminPage = id);
        if (id == "orders") _loadOrders();
        if (id == "billing") _loadPlans();
        if (id == "dashboard") _loadOrders();
      },
      body: body,
    );
  }

  Widget _buildOperator() {
    Widget body;
    switch (_scanPhase) {
      case "loaded":
        body = OrderScannedPage(
          order: _scanOrder!,
          onStartPacking: () => setState(() => _scanPhase = "items"),
        );
        break;
      case "items":
        body = ItemScanPage(
          order: _scanOrder!,
          onValidate: _validateSku,
          onAllDone: () => setState(() => _scanPhase = "recording"),
        );
        break;
      case "recording":
        body = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam, size: 64, color: AppColors.primary),
              const SizedBox(height: 12),
              const Text("Recording screen (UI next)",
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => setState(() => _scanPhase = "done"),
                child: const Text("Mark recording done"),
              ),
            ],
          ),
        );
        break;
      case "done":
        body = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_done, size: 64, color: AppColors.success),
              const Text("Upload / Dispatch placeholder"),
              FilledButton(
                onPressed: () => setState(() {
                  _scanPhase = "home";
                  _scanOrder = null;
                }),
                child: const Text("Back to Scan Home"),
              ),
            ],
          ),
        );
        break;
      default:
        body = ScannerHomePage(onStart: _openOrderForScan);
    }

    return OperatorShell(
      currentId: "scan",
      title: "Scan & Pack",
      userName: _user?["email"]?.toString(),
      onSignOut: _signOut,
      onNavigate: (id) {
        if (id == "scan") {
          setState(() {
            _scanPhase = "home";
            _scanOrder = null;
          });
        }
      },
      body: body,
    );
  }
}

class _BillingPage extends StatelessWidget {
  final List<dynamic> plans;
  final VoidCallback onRefresh;
  const _BillingPage({required this.plans, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text("Billing & Plans",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 12),
        if (plans.isEmpty)
          const Text("Tap refresh to load GET /billing/plans",
              style: TextStyle(color: AppColors.muted))
        else
          ...plans.map((p) {
            final m = Map<String, dynamic>.from(p as Map);
            return Card(
              child: ListTile(
                title: Text("${m["id"]}",
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    "Users: ${m["users"]} · WH: ${m["warehouses"]} · Storage: ${m["storageGb"]} GB"),
                trailing: Text("₹${m["priceInr"]}/mo",
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.primary)),
              ),
            );
          }),
      ],
    );
  }
}