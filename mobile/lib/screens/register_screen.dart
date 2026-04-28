import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'main_screen.dart';
import 'login_screen.dart';
import 'profile/privacy_policy_screen.dart';

class _TermsLink extends StatelessWidget {
  const _TermsLink();
  @override
  Widget build(BuildContext context) => const TermsScreen();
}
class _PrivacyLink extends StatelessWidget {
  const _PrivacyLink();
  @override
  Widget build(BuildContext context) => const PrivacyPolicyScreen();
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _phoneCtrl    = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _otpEmailCtrl = TextEditingController(); // email used for OTP (US testers)
  final _otpCtrl      = TextEditingController();
  final _handleCtrl   = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _customIdCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();

  bool _otpSent      = false;
  bool _useEmailOtp  = false; // true = send OTP to email instead of phone
  bool _passVisible  = false;
  bool _loading      = false;
  String? _error;
  String? _gender;

  int _step = 1; // 1 = phone + OTP, 2 = profile details

  // The contact the OTP was actually sent to (phone or email)
  String get _otpContact => _useEmailOtp
      ? _otpEmailCtrl.text.trim()
      : _phoneCtrl.text.trim();

  @override
  void dispose() {
    _phoneCtrl.dispose(); _emailCtrl.dispose(); _otpEmailCtrl.dispose(); _otpCtrl.dispose();
    _handleCtrl.dispose(); _nameCtrl.dispose(); _passCtrl.dispose();
    _confirmCtrl.dispose(); _customIdCtrl.dispose(); _referralCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter your phone number');
      return;
    }
    if (_useEmailOtp && _otpEmailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter the email address to receive your OTP');
      return;
    }
    final auth = Provider.of<AuthService>(context, listen: false);
    setState(() { _loading = true; _error = null; });
    final err = await auth.sendOtp(_otpContact);
    if (!mounted) return;
    setState(() { _loading = false; });
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
    setState(() { _step = 2; _error = null; });
  }

  Future<void> _register() async {
    final handle   = _handleCtrl.text.trim();
    final name     = _nameCtrl.text.trim();
    final password = _passCtrl.text;
    final confirm  = _confirmCtrl.text;
    final phone    = _phoneCtrl.text.trim();

    if (handle.isEmpty || name.isEmpty || password.isEmpty) {
      setState(() => _error = 'Fill in all required fields');
      return;
    }
    final handleRegex = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_]{1,18}[a-zA-Z0-9]$|^[a-zA-Z0-9]{3}$');
    if (!handleRegex.hasMatch(handle)) {
      setState(() => _error = 'MyrabaTag must be 3–20 characters, letters/numbers/underscores only');
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

    final customId = _customIdCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final referral = _referralCtrl.text.trim();

    final auth = Provider.of<AuthService>(context, listen: false);
    setState(() { _loading = true; _error = null; });

    final err = await auth.register(
      myrabaHandle: handle,
      password: password,
      fullName: name,
      phone: phone,
      email: email.isEmpty ? null : email,
      otpCode: _otpCtrl.text.trim(),
      otpContact: _useEmailOtp ? _otpEmailCtrl.text.trim() : null,
      customAccountId: customId.isEmpty ? null : customId,
      referralCode: referral.isEmpty ? null : referral,
      gender: _gender,
    );

    if (!mounted) return;
    if (err != null) {
      setState(() { _error = err; _loading = false; });
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => MainScreen()),
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
        title: Text('Step $_step of 2',
            style: TextStyle(fontSize: 14, color: context.mc.textHint)),
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
        Text('Create your account',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                color: context.mc.textPrimary)),
        const SizedBox(height: 6),
        Text("Enter your phone number — it becomes your account number",
            style: TextStyle(fontSize: 14, color: context.mc.textSecond)),
        const SizedBox(height: 32),

        Text('Phone Number',
            style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() => _otpSent = false),
          decoration: InputDecoration(
            hintText: '08012345678',
            prefixIcon: Icon(Icons.phone_outlined, color: context.mc.textHint, size: 20),
            suffixIcon: TextButton(
              onPressed: _loading ? null : _sendOtp,
              child: Text(_otpSent ? 'Resend' : 'Send OTP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _loading ? context.mc.textHint : MyrabaColors.green,
                  )),
            ),
          ),
        ),

        const SizedBox(height: 12),
        // ── "No Nigerian number?" toggle ───────────────────────────
        GestureDetector(
          onTap: () => setState(() { _useEmailOtp = !_useEmailOtp; _otpSent = false; }),
          child: Row(children: [
            Icon(
              _useEmailOtp ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              color: _useEmailOtp ? MyrabaColors.green : context.mc.textHint,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text("I don't have a Nigerian number — send OTP to email",
                style: TextStyle(fontSize: 12, color: context.mc.textSecond)),
          ]),
        ),

        if (_useEmailOtp) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _otpEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() => _otpSent = false),
            decoration: InputDecoration(
              hintText: 'your@email.com',
              prefixIcon: Icon(Icons.email_outlined, color: context.mc.textHint, size: 20),
            ),
          ),
        ],

        if (_otpSent) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MyrabaColors.greenGlow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MyrabaColors.green.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline_rounded, color: MyrabaColors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('OTP sent to $_otpContact',
                    style: const TextStyle(fontSize: 12, color: MyrabaColors.green)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Text('Enter OTP',
              style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
          const SizedBox(height: 8),
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8),
            decoration: const InputDecoration(hintText: '• • • • • •', counterText: ''),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: MyrabaColors.red, fontSize: 13)),
        ],
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _loading ? null
              : !_otpSent ? _sendOtp : _verifyAndNext,
          child: _loading
              ? const SizedBox(height: 22, width: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(_otpSent ? 'Continue' : 'Send OTP'),
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => LoginScreen())),
            child: RichText(
              text: TextSpan(
                text: 'Already have an account? ',
                style: TextStyle(color: context.mc.textHint, fontSize: 13),
                children: [
                  TextSpan(text: 'Log in',
                      style: TextStyle(color: MyrabaColors.green, fontWeight: FontWeight.w600)),
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
        Text('Set up your profile',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                color: context.mc.textPrimary)),
        const SizedBox(height: 6),
        Text('Your phone number ${_phoneCtrl.text.trim()} is your account number',
            style: TextStyle(fontSize: 13, color: MyrabaColors.green,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 28),

        // ── Full Name ──────────────────────────────────────────────
        Text('Full Name', style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Davinci Okafor',
            prefixIcon: Icon(Icons.person_outline_rounded, color: context.mc.textHint, size: 20),
          ),
        ),
        const SizedBox(height: 20),

        // ── Gender ─────────────────────────────────────────────────
        Text('Gender (optional)', style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(height: 8),
        Row(children: [
          _genderChip('MALE', Icons.male_rounded),
          const SizedBox(width: 10),
          _genderChip('FEMALE', Icons.female_rounded),
        ]),
        const SizedBox(height: 20),

        // ── MyrabaTag ──────────────────────────────────────────────
        Text('MyrabaTag (your unique ID)',
            style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _handleCtrl,
          decoration: const InputDecoration(
            hintText: 'e.g. Davinci96',
            prefixText: 'm₦ ',
            prefixStyle: TextStyle(color: MyrabaColors.green, fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        const SizedBox(height: 20),

        // ── Custom ID (optional) ───────────────────────────────────
        Text('Custom ID (optional)', style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(height: 4),
        Text('A short memorable ID others can use to send you money (e.g. john-pay)',
            style: TextStyle(fontSize: 11, color: context.mc.textHint, height: 1.3)),
        const SizedBox(height: 8),
        TextField(
          controller: _customIdCtrl,
          decoration: InputDecoration(
            hintText: 'e.g. john-pay or davinci96',
            prefixIcon: Icon(Icons.tag_rounded, color: context.mc.textHint, size: 20),
          ),
        ),
        const SizedBox(height: 20),

        // ── Email (optional) ───────────────────────────────────────
        Text('Email Address (optional)',
            style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'you@example.com',
            prefixIcon: Icon(Icons.email_outlined, color: context.mc.textHint, size: 20),
          ),
        ),
        const SizedBox(height: 20),

        // ── Password ───────────────────────────────────────────────
        Text('Password', style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _passCtrl,
          obscureText: !_passVisible,
          decoration: InputDecoration(
            hintText: 'At least 8 characters',
            prefixIcon: Icon(Icons.lock_outline_rounded, color: context.mc.textHint, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_passVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: context.mc.textHint, size: 20),
              onPressed: () => setState(() => _passVisible = !_passVisible),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Confirm Password ───────────────────────────────────────
        Text('Confirm Password', style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmCtrl,
          obscureText: !_passVisible,
          decoration: InputDecoration(
            hintText: 'Repeat your password',
            prefixIcon: Icon(Icons.lock_outline_rounded, color: context.mc.textHint, size: 20),
          ),
        ),
        const SizedBox(height: 20),

        // ── Referral Code ──────────────────────────────────────────
        Text('Referral Code (optional)',
            style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _referralCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'e.g. ABC12345',
            prefixIcon: Icon(Icons.card_giftcard_rounded, color: context.mc.textHint, size: 20),
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
              ? const SizedBox(height: 22, width: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Create Account'),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => setState(() { _step = 1; _error = null; }),
          child: const Text('Back'),
        ),
        const SizedBox(height: 20),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              Text('By creating an account you agree to our ',
                  style: TextStyle(fontSize: 11, color: context.mc.textHint)),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _TermsLink())),
                child: const Text('Terms & Conditions',
                    style: TextStyle(fontSize: 11, color: MyrabaColors.green,
                        decoration: TextDecoration.underline)),
              ),
              Text(' and ', style: TextStyle(fontSize: 11, color: context.mc.textHint)),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const _PrivacyLink())),
                child: const Text('Privacy Policy',
                    style: TextStyle(fontSize: 11, color: MyrabaColors.green,
                        decoration: TextDecoration.underline)),
              ),
              Text('.', style: TextStyle(fontSize: 11, color: context.mc.textHint)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _genderChip(String value, IconData icon) {
    final selected = _gender == value;
    final color = value == 'MALE' ? const Color(0xFF1565C0) : const Color(0xFFAD1457);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = selected ? null : value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : context.mc.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : context.mc.surfaceLine,
                width: selected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? color : context.mc.textHint),
              const SizedBox(width: 6),
              Text(value == 'MALE' ? 'Male' : 'Female',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: selected ? color : context.mc.textSecond)),
            ],
          ),
        ),
      ),
    );
  }
}
