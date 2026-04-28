import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'main_screen.dart';
import 'admin_dashboard_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _passVisible = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final identifier = _identifierCtrl.text.trim();
    final password = _passCtrl.text;
    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your phone/email and password');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = Provider.of<AuthService>(context, listen: false);
    final err = await auth.login(identifier, password);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _error = err;
        _loading = false;
      });
    } else {
      final dest =
          auth.isAdmin ? const AdminDashboardScreen() : const MainScreen();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => dest),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: BackButton(color: context.mc.textSecond),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: context.mc.textPrimary)),
              SizedBox(height: 6),
              Text('Log in to your Myraba account',
                  style:
                      TextStyle(fontSize: 14, color: context.mc.textSecond)),
              SizedBox(height: 40),
              Text('Phone number or Email',
                  style:
                      TextStyle(fontSize: 13, color: context.mc.textSecond)),
              SizedBox(height: 8),
              TextField(
                controller: _identifierCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'e.g. 08012345678 or you@email.com',
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: context.mc.textHint, size: 20),
                ),
              ),
              SizedBox(height: 20),
              Text('Password',
                  style:
                      TextStyle(fontSize: 13, color: context.mc.textSecond)),
              SizedBox(height: 8),
              TextField(
                controller: _passCtrl,
                obscureText: !_passVisible,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: 'Your password',
                  prefixIcon: Icon(Icons.lock_outline_rounded,
                      color: context.mc.textHint, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: context.mc.textHint,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _passVisible = !_passVisible),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                  child: const Text('Forgot password?',
                      style: TextStyle(color: MyrabaColors.green, fontSize: 13)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MyrabaColors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: MyrabaColors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: MyrabaColors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: MyrabaColors.red, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Log In'),
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => RegisterScreen())),
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style:
                          TextStyle(color: context.mc.textHint, fontSize: 13),
                      children: [
                        TextSpan(
                            text: 'Create one',
                            style: TextStyle(
                                color: MyrabaColors.green,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
