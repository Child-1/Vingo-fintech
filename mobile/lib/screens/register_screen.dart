import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'main_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _contactCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _handleCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _useEmail = false; // false = phone, true = email
  bool _otpSent = false;
  bool _passVisible = false;
  bool _loading = false;
  String? _error;

  int _step = 1; // 1 = contact+OTP, 2 = account details

  @override
  void dispose() {
    _contactCtrl.dispose();
    _otpCtrl.dispose();
    _handleCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final contact = _contactCtrl.text.trim();
    if (contact.isEmpty) {
      setState(
          () => _error = 'Enter your ${_useEmail ? 'email' : 'phone number'}');
      return;
    }
    final auth = Provider.of<AuthService>(context, listen: false);
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await auth.sendOtp(contact);
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
    if (err != null) {
      setState(() => _error = err);
    } else {
      setState(() => _otpSent = true);
    }
  }

  Future<void> _verifyAndNext() async {
    if (_otpCtrl.text.trim().length < 4) {
      setState(() => _error = 'Enter the OTP sent to you');
      return;
    }
    setState(() {
      _step = 2;
      _error = null;
    });
  }

  Future<void> _register() async {
    final handle = _handleCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final password = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (handle.isEmpty || name.isEmpty || password.isEmpty) {
      setState(() => _error = 'Fill in all required fields');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }

    final auth = Provider.of<AuthService>(context, listen: false);
    final contact = _contactCtrl.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });

    final err = await auth.register(
      myrabaHandle: handle,
      password: password,
      fullName: name,
      phone: _useEmail ? null : contact,
      email: _useEmail ? contact : null,
      otpCode: _otpCtrl.text.trim(),
    );

    if (!mounted) return;
    if (err != null) {
      setState(() {
        _error = err;
        _loading = false;
      });
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyrabaColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: MyrabaColors.textSecond),
        title: Text('Step $_step of 2',
            style: const TextStyle(fontSize: 14, color: MyrabaColors.textHint)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: _step == 1 ? _buildStep1() : _buildStep2(),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Create your account',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: MyrabaColors.textPrimary)),
        const SizedBox(height: 6),
        const Text("We'll send you a code to verify your identity",
            style: TextStyle(fontSize: 14, color: MyrabaColors.textSecond)),
        const SizedBox(height: 32),
        // Toggle phone / email
        Container(
          decoration: BoxDecoration(
            color: MyrabaColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MyrabaColors.surfaceLine),
          ),
          child: Row(
            children: [
              _tabToggle(
                  'Phone',
                  !_useEmail,
                  () => setState(() {
                        _useEmail = false;
                        _otpSent = false;
                        _contactCtrl.clear();
                      })),
              _tabToggle(
                  'Email',
                  _useEmail,
                  () => setState(() {
                        _useEmail = true;
                        _otpSent = false;
                        _contactCtrl.clear();
                      })),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(_useEmail ? 'Email Address' : 'Phone Number',
            style:
                const TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _contactCtrl,
          keyboardType:
              _useEmail ? TextInputType.emailAddress : TextInputType.phone,
          onChanged: (_) => setState(() => _otpSent = false),
          decoration: InputDecoration(
            hintText: _useEmail ? 'you@example.com' : '08012345678',
            prefixIcon: Icon(
              _useEmail ? Icons.email_outlined : Icons.phone_outlined,
              color: MyrabaColors.textHint,
              size: 20,
            ),
            suffixIcon: TextButton(
              onPressed: _loading ? null : _sendOtp,
              child: Text(_otpSent ? 'Resend' : 'Send OTP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _loading ? MyrabaColors.textHint : MyrabaColors.green,
                  )),
            ),
          ),
        ),
        if (_otpSent) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MyrabaColors.greenGlow,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: MyrabaColors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: MyrabaColors.green, size: 16),
                const SizedBox(width: 8),
                Text('OTP sent to ${_contactCtrl.text.trim()}',
                    style: const TextStyle(
                        fontSize: 12, color: MyrabaColors.green)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Enter OTP',
              style: TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
          const SizedBox(height: 8),
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8),
            decoration: const InputDecoration(
              hintText: '• • • • • •',
              counterText: '',
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!,
              style: const TextStyle(color: MyrabaColors.red, fontSize: 13)),
        ],
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _loading
              ? null
              : !_otpSent
                  ? _sendOtp
                  : _verifyAndNext,
          child: _loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(_otpSent ? 'Continue' : 'Send OTP'),
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: RichText(
              text: const TextSpan(
                text: 'Already have an account? ',
                style: TextStyle(color: MyrabaColors.textHint, fontSize: 13),
                children: [
                  TextSpan(
                      text: 'Log in',
                      style: TextStyle(
                          color: MyrabaColors.green,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Set up your profile',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: MyrabaColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('Choose your MyrabaTag — this is how people find and pay you',
            style: TextStyle(fontSize: 14, color: MyrabaColors.textSecond)),
        const SizedBox(height: 32),
        const Text('Full Name',
            style: TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Davinci Okafor',
            prefixIcon: Icon(Icons.person_outline_rounded,
                color: MyrabaColors.textHint, size: 20),
          ),
        ),
        const SizedBox(height: 20),
        const Text('MyrabaTag (your unique ID)',
            style: TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _handleCtrl,
          decoration: const InputDecoration(
            hintText: 'e.g. Davinci96',
            prefixText: 'm₦ ',
            prefixStyle: TextStyle(
                color: MyrabaColors.green,
                fontWeight: FontWeight.w700,
                fontSize: 16),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Password',
            style: TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _passCtrl,
          obscureText: !_passVisible,
          decoration: InputDecoration(
            hintText: 'At least 8 characters',
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                color: MyrabaColors.textHint, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _passVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: MyrabaColors.textHint,
                size: 20,
              ),
              onPressed: () => setState(() => _passVisible = !_passVisible),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Confirm Password',
            style: TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmCtrl,
          obscureText: !_passVisible,
          decoration: const InputDecoration(
            hintText: 'Repeat your password',
            prefixIcon: Icon(Icons.lock_outline_rounded,
                color: MyrabaColors.textHint, size: 20),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MyrabaColors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MyrabaColors.red.withValues(alpha: 0.3)),
            ),
            child: Text(_error!,
                style: const TextStyle(color: MyrabaColors.red, fontSize: 13)),
          ),
        ],
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _loading ? null : _register,
          child: _loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Create Account'),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => setState(() {
            _step = 1;
            _error = null;
          }),
          child: const Text('Back'),
        ),
      ],
    );
  }

  Widget _tabToggle(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? MyrabaColors.greenGlow : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? MyrabaColors.green : MyrabaColors.textHint,
                )),
          ),
        ),
      ),
    );
  }
}
