import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _kyc;
  Map<String, dynamic>? _points;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) return;
    final api = ApiService(auth.token!);
    try {
      final results = await Future.wait([
        api.getMyProfile(),
        api.getKycStatus(),
        api.getMyPoints(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0];
        _kyc     = results[1];
        _points  = results[2];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return Scaffold(
      backgroundColor: MyrabaColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: MyrabaColors.green))
          : RefreshIndicator(
              onRefresh: _load,
              color: MyrabaColors.green,
              backgroundColor: MyrabaColors.surface,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                children: [
                  _buildHeader(auth),
                  const SizedBox(height: 24),
                  _buildAccountInfo(),
                  const SizedBox(height: 16),
                  _buildKycSection(),
                  const SizedBox(height: 16),
                  _buildPointsSection(),
                  const SizedBox(height: 24),
                  _buildMenuSection(auth),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(AuthService auth) {
    return Padding(
      padding: const EdgeInsets.only(top: 60, bottom: 8),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: MyrabaColors.greenGlow,
              shape: BoxShape.circle,
              border: Border.all(color: MyrabaColors.green.withValues(alpha: 0.5), width: 2),
            ),
            child: Center(
              child: Text(
                (auth.fullName ?? 'U').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w800, color: MyrabaColors.green),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(auth.fullName ?? 'User',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                color: MyrabaColors.textPrimary)),
          const SizedBox(height: 4),
          Text('v\u20a6${auth.myrabaHandle ?? ''}',
            style: const TextStyle(fontSize: 15, color: MyrabaColors.green,
                fontWeight: FontWeight.w600)),
          if (auth.myrabaTag != null && auth.myrabaTag!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(auth.myrabaTag!,
              style: const TextStyle(fontSize: 12, color: MyrabaColors.textHint)),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountInfo() {
    final accountNumber = _profile?['accountNumber'] ?? '──────────';
    final customId      = _profile?['customAccountId'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: myrabaCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account Details',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: MyrabaColors.textPrimary)),
          const SizedBox(height: 16),
          _infoRow(Icons.account_balance_outlined, 'Account Number', accountNumber,
            copyable: true),
          if (customId != null) ...[
            const Divider(height: 24, color: MyrabaColors.surfaceLine),
            _infoRow(Icons.tag_rounded, 'Custom ID', customId, copyable: true),
          ],
          const Divider(height: 24, color: MyrabaColors.surfaceLine),
          _infoRow(Icons.email_outlined, 'Email', _profile?['email'] ?? '—'),
          const Divider(height: 24, color: MyrabaColors.surfaceLine),
          _infoRow(Icons.phone_outlined, 'Phone', _profile?['phone'] ?? '—'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool copyable = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: MyrabaColors.textHint),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                style: const TextStyle(fontSize: 11, color: MyrabaColors.textHint)),
              const SizedBox(height: 2),
              Text(value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: MyrabaColors.textPrimary)),
            ],
          ),
        ),
        if (copyable)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied!'),
                    backgroundColor: MyrabaColors.green, duration: Duration(seconds: 1)),
              );
            },
            child: const Icon(Icons.copy_rounded, size: 16, color: MyrabaColors.textHint),
          ),
      ],
    );
  }

  Widget _buildKycSection() {
    final status = _kyc?['status'] as String? ?? 'NOT_STARTED';
    final isVerified = status == 'APPROVED';
    final isPending  = status == 'PENDING';
    final color = isVerified ? MyrabaColors.green : isPending ? MyrabaColors.gold : MyrabaColors.red;
    final label = isVerified ? 'Verified' : isPending ? 'Pending' : 'Not Verified';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: myrabaCard(),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isVerified ? Icons.verified_rounded : Icons.shield_outlined,
              color: color, size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('KYC Verification',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: MyrabaColors.textPrimary)),
                Text(label, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
          if (!isVerified)
            TextButton(
              onPressed: () => _showKycSheet(),
              child: const Text('Verify Now', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildPointsSection() {
    final pts = _points?['points'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: myrabaCard(),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: MyrabaColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.star_rounded, color: MyrabaColors.gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Myraba Points',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: MyrabaColors.textPrimary)),
                Text('$pts pts accumulated',
                  style: const TextStyle(fontSize: 12, color: MyrabaColors.textHint)),
              ],
            ),
          ),
          Text('$pts',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                color: MyrabaColors.gold)),
        ],
      ),
    );
  }

  Widget _buildMenuSection(AuthService auth) {
    return Column(
      children: [
        _menuItem(Icons.history_rounded, 'Year in Review (Wrapped)',
          MyrabaColors.purple, () {}),
        const SizedBox(height: 10),
        _menuItem(Icons.security_rounded, 'Security Settings',
          MyrabaColors.blue, () {}),
        const SizedBox(height: 10),
        _menuItem(Icons.help_outline_rounded, 'Help & Support',
          MyrabaColors.textSecond, () {}),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _confirmLogout(auth),
          icon: const Icon(Icons.logout_rounded, color: MyrabaColors.red),
          label: const Text('Log Out', style: TextStyle(color: MyrabaColors.red)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: MyrabaColors.red),
          ),
        ),
      ],
    );
  }

  Widget _menuItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: myrabaCard(),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: MyrabaColors.textPrimary)),
            ),
            const Icon(Icons.chevron_right_rounded, color: MyrabaColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  void _showKycSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MyrabaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => _KycSheet(
        onDone: () { Navigator.pop(context); _load(); },
      ),
    );
  }

  void _confirmLogout(AuthService auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MyrabaColors.surface,
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?',
          style: TextStyle(color: MyrabaColors.textSecond)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: MyrabaColors.textSecond)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              auth.logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: MyrabaColors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

// ─── KYC Bottom Sheet ─────────────────────────────────────────────────────────

class _KycSheet extends StatefulWidget {
  final VoidCallback onDone;
  const _KycSheet({required this.onDone});

  @override
  State<_KycSheet> createState() => _KycSheetState();
}

class _KycSheetState extends State<_KycSheet> {
  final _bvnCtrl = TextEditingController();
  final _ninCtrl = TextEditingController();
  bool _loading  = false;
  String? _error;

  @override
  void dispose() { _bvnCtrl.dispose(); _ninCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_bvnCtrl.text.trim().isEmpty && _ninCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter BVN or NIN');
      return;
    }
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) return;
    final api = ApiService(auth.token!);
    setState(() { _loading = true; _error = null; });
    try {
      if (_bvnCtrl.text.trim().isNotEmpty) {
        await api.submitBvn(_bvnCtrl.text.trim());
      }
      if (_ninCtrl.text.trim().isNotEmpty) {
        await api.submitNin(_ninCtrl.text.trim());
      }
      if (mounted) widget.onDone();
    } catch (_) {
      if (mounted) setState(() { _error = 'Verification failed'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: MyrabaColors.surfaceLine,
                borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          const Text('KYC Verification',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: MyrabaColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Provide your BVN or NIN to verify your identity',
            style: TextStyle(fontSize: 13, color: MyrabaColors.textHint)),
          const SizedBox(height: 24),
          const Text('BVN (optional)',
            style: TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
          const SizedBox(height: 8),
          TextField(
            controller: _bvnCtrl,
            keyboardType: TextInputType.number,
            maxLength: 11,
            decoration: const InputDecoration(hintText: '11-digit BVN', counterText: ''),
          ),
          const SizedBox(height: 16),
          const Text('NIN (optional)',
            style: TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
          const SizedBox(height: 8),
          TextField(
            controller: _ninCtrl,
            keyboardType: TextInputType.number,
            maxLength: 11,
            decoration: const InputDecoration(hintText: '11-digit NIN', counterText: ''),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: MyrabaColors.red, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(height: 22, width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Submit for Verification'),
          ),
        ],
      ),
    );
  }
}
