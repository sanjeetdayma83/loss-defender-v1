import "dart:io";
import "package:clerk_auth/clerk_auth.dart";
import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "config/env.dart";

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AuthRoot(),
    );
  }
}

class AuthRoot extends StatefulWidget {
  const AuthRoot({super.key});
  @override
  State<AuthRoot> createState() => _AuthRootState();
}

class _AuthRootState extends State<AuthRoot> {
  Auth? _auth;
  String? _bootError;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final pk = Env.clerkPublishableKey;
    if (pk.isEmpty) {
      setState(() {
        _booting = false;
        _bootError = "CLERK_PUBLISHABLE_KEY missing";
      });
      return;
    }
    try {
      final auth = Auth(
        config: AuthConfig(
          publishableKey: pk,
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
    } catch (e) {
      setState(() {
        _booting = false;
        _bootError = "Clerk init failed: $e";
      });
    }
  }

  @override
  void dispose() {
    _auth?.terminate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_bootError != null || _auth == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_bootError ?? "No auth", textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (_auth!.isSignedIn) {
      return HomePage(auth: _auth!);
    }
    return SignInPage(
      auth: _auth!,
      onSignedIn: () => setState(() {}),
    );
  }
}

class SignInPage extends StatefulWidget {
  final Auth auth;
  final VoidCallback onSignedIn;
  const SignInPage({super.key, required this.auth, required this.onSignedIn});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _email = TextEditingController(text: "sanjeetdayma83@gmail.com");
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _needCode = false;
  String _status = "Email + password se sign in";

  Future<void> _submitPassword() async {
    setState(() {
      _busy = true;
      _status = "Signing in…";
    });
    try {
      await widget.auth.attemptSignIn(
        strategy: Strategy.password,
        identifier: _email.text.trim(),
        password: _password.text,
      );
      if (widget.auth.isSignedIn) {
        widget.onSignedIn();
        return;
      }
      final status = widget.auth.signIn?.status;
      debugPrint("After password: status=$status");
      if (status?.name == "needs_second_factor" ||
          status.toString().contains("needs_second_factor") ||
          status.toString().contains("needsSecondFactor")) {
        // Prepare second factor (email/phone code)
        try {
          await widget.auth.attemptSignIn(strategy: Strategy.emailCode);
        } catch (_) {
          try {
            await widget.auth.attemptSignIn(strategy: Strategy.phoneCode);
          } catch (e2) {
            debugPrint("prepare 2FA: $e2");
          }
        }
        setState(() {
          _needCode = true;
          _status = "2FA required — check email/SMS for code";
        });
      } else {
        setState(() => _status = "Status: $status");
      }
    } catch (e) {
      debugPrint("SIGNIN ERROR: $e");
      setState(() => _status = "ERROR: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitCode() async {
    setState(() {
      _busy = true;
      _status = "Verifying code…";
    });
    try {
      // Try email code first, then phone
      try {
        await widget.auth.attemptSignIn(
          strategy: Strategy.emailCode,
          code: _code.text.trim(),
        );
      } catch (_) {
        await widget.auth.attemptSignIn(
          strategy: Strategy.phoneCode,
          code: _code.text.trim(),
        );
      }
      if (widget.auth.isSignedIn) {
        widget.onSignedIn();
      } else {
        setState(() =>
            _status = "Code submitted. Status: ${widget.auth.signIn?.status}");
      }
    } catch (e) {
      debugPrint("CODE ERROR: $e");
      setState(() => _status = "ERROR: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("LOSS DEFENDER",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  _needCode ? "Enter verification code" : "Sign in",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (!_needCode) ...[
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    onSubmitted: (_) => _busy ? null : _submitPassword(),
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _busy ? null : _submitCode(),
                    decoration: const InputDecoration(
                      labelText: "Verification code",
                      border: OutlineInputBorder(),
                      hintText: "6-digit code from email/SMS",
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _status.startsWith("ERROR") ? Colors.red : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : (_needCode ? _submitCode : _submitPassword),
                  child: Text(_busy
                      ? "Please wait…"
                      : (_needCode ? "Verify code" : "Sign in")),
                ),
                if (_needCode) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _needCode = false;
                              _status = "Email + password se sign in";
                            }),
                    child: const Text("Back"),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final Auth auth;
  const HomePage({super.key, required this.auth});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
  ));
  String _log = "Loading…";
  bool _busy = false;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  Future<String?> _jwt() async {
    try {
      final t = await widget.auth.sessionToken();
      return t.jwt;
    } catch (e) {
      return widget.auth.session?.lastActiveToken?.jwt;
    }
  }

  Future<void> _withAuth(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      final jwt = await _jwt();
      if (jwt == null || jwt.isEmpty) {
        setState(() => _log = "No JWT");
        return;
      }
      _dio.options.headers["Authorization"] = "Bearer $jwt";
      await fn();
    } catch (e) {
      setState(() => _log = "Error: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    await _withAuth(() async {
      final r = await _dio.get("/auth/sync");
      final body = Map<String, dynamic>.from(r.data as Map);
      final data = body["data"];
      setState(() {
        _user = data is Map ? Map<String, dynamic>.from(data) : null;
        _log = "SYNC OK\n$body";
      });
    });
  }

  Future<void> _health() async {
    setState(() => _busy = true);
    try {
      final r = await _dio.get("/health");
      setState(() => _log = "HEALTH OK\n${r.data}");
    } catch (e) {
      setState(() => _log = "HEALTH FAIL: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _company() async {
    await _withAuth(() async {
      final r = await _dio.get("/companies/me");
      setState(() => _log = "COMPANY OK\n${r.data}");
    });
  }

  Future<void> _orders() async {
    await _withAuth(() async {
      final r = await _dio.get("/orders");
      setState(() => _log = "ORDERS OK\n${r.data}");
    });
  }

  Future<void> _signOut() async {
    await widget.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthRoot()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("LOSS DEFENDER"),
        actions: [
          TextButton(
            onPressed: _signOut,
            child: const Text("Sign out", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_user != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text("${_user!["email"] ?? ""} · ${_user!["role"] ?? ""}"),
                  subtitle: Text(
                      "Company: ${_user!["companyId"] ?? "-"}\nUser: ${_user!["id"] ?? "-"}"),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(onPressed: _busy ? null : _health, child: const Text("Health")),
                FilledButton(onPressed: _busy ? null : _sync, child: const Text("Sync")),
                FilledButton(onPressed: _busy ? null : _company, child: const Text("Company")),
                FilledButton(onPressed: _busy ? null : _orders, child: const Text("Orders")),
              ],
            ),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: Container(
                color: Colors.black87,
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: Text(
                    _log,
                    style: const TextStyle(
                      color: Colors.lightGreenAccent,
                      fontFamily: "Consolas",
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}