import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _contactCtrl  = TextEditingController();
  final _otpCtrl      = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  int _step = 1; // 1=contact, 2=OTP+new password
  bool _loading = false;
  bool _passVisible = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _contactCtrl.dispose(); _otpCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final contact = _contactCtrl.text.trim();
    if (contact.isEmpty) {
      setState(() => _error = 'Enter your phone number or email');
      return;
    }
    final auth = Provider.of<AuthService>(context, listen: false);
    setState(() { _loading = true; _error = null; });
    final err = await auth.sendOtp(contact, purpose: 'PASSWORD_RESET');
    if (!mounted) return;
    setState(() { _loading = false; });
    if (err != null) {
      setState(() => _error = err);
    } else {
      setState(() => _step = 2);
    }
  }

  Future<void> _resetPassword() async {
    final otp  = _otpCtrl.text.trim();
    final pass = _passCtrl.text;
    final conf = _confirmCtrl.text;

    if (otp.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Fill in all fields');
      return;
    }
    if (pass != conf) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (pass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }

    final auth = Provider.of<AuthService>(context, listen: false);
    setState(() { _loading = true; _error = null; });
    final err = await auth.resetPassword(
      contact: _contactCtrl.text.trim(),
      otpCode: otp,
      newPassword: pass,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      setState(() => _success = 'Password reset! You can now log in.');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: BackButton(color: context.mc.textSecond),
        title: Text('Reset Password',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                color: context.mc.textPrimary)),
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
        Text('Forgot your password?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                color: context.mc.textPrimary)),
        const SizedBox(height: 8),
        Text("Enter the phone number or email linked to your account and we'll send a reset code.",
            style: TextStyle(fontSize: 14, color: context.mc.textSecond)),
        const SizedBox(height: 32),

        Text('Phone or Email',
            style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _contactCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: '08012345678 or you@email.com',
            prefixIcon: Icon(Icons.person_outline_rounded,
                color: context.mc.textHint, size: 20),
          ),
        ),

        _errorWidget(),
        const SizedBox(height: 32),

        ElevatedButton(
          onPressed: _loading ? null : _sendOtp,
          child: _loading
              ? const SizedBox(height: 22, width: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Send Reset Code'),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter reset code',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                color: context.mc.textPrimary)),
        const SizedBox(height: 8),
        Text('Code sent to ${_contactCtrl.text.trim()}',
            style: TextStyle(fontSize: 14, color: context.mc.textSecond)),
        const SizedBox(height: 32),

        Text('Reset Code', style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '6-digit code',
            prefixIcon: Icon(Icons.pin_outlined, color: context.mc.textHint, size: 20),
            suffixIcon: TextButton(
              onPressed: _loading ? null : _sendOtp,
              child: const Text('Resend', style: TextStyle(color: MyrabaColors.green, fontSize: 13)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Text('New Password', style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
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

        Text('Confirm Password', style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmCtrl,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Repeat your new password',
            prefixIcon: Icon(Icons.lock_outline_rounded, color: context.mc.textHint, size: 20),
          ),
        ),

        if (_success != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MyrabaColors.green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MyrabaColors.green.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: MyrabaColors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_success!,
                  style: const TextStyle(color: MyrabaColors.green, fontSize: 13))),
            ]),
          ),
        ],

        _errorWidget(),
        const SizedBox(height: 32),

        ElevatedButton(
          onPressed: _loading ? null : _resetPassword,
          child: _loading
              ? const SizedBox(height: 22, width: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Reset Password'),
        ),
      ],
    );
  }

  Widget _errorWidget() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MyrabaColors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: MyrabaColors.red.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: MyrabaColors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!,
              style: const TextStyle(color: MyrabaColors.red, fontSize: 13))),
        ]),
      ),
    );
  }
}
