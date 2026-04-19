import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/theme_provider.dart';
import '../stats/monthly_review_screen.dart';
import '../wallet/transaction_history_screen.dart';
import '../support/support_chat_screen.dart';

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
  void initState() {
    super.initState();
    _load();
  }

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
        _kyc = results[1];
        _points = results[2];
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
      backgroundColor: context.mc.bg,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: MyrabaColors.green))
          : RefreshIndicator(
              onRefresh: _load,
              color: MyrabaColors.green,
              backgroundColor: context.mc.surface,
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
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: MyrabaColors.greenGlow,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: MyrabaColors.green.withValues(alpha: 0.5),
                      width: 2),
                ),
                child: Center(
                  child: Text(
                    (auth.fullName ?? 'U').substring(0, 1).toUpperCase(),
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: MyrabaColors.green),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showEditProfileSheet(),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: MyrabaColors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.mc.bg, width: 2),
                  ),
                  child: Icon(Icons.edit_rounded,
                      color: Colors.white, size: 13),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Text(auth.fullName ?? 'User',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.mc.textPrimary)),
          const SizedBox(height: 4),
          Text('m₦${auth.myrabaHandle ?? ''}',
              style: TextStyle(
                  fontSize: 15,
                  color: MyrabaColors.green,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAccountInfo() {
    final accountNumber = _profile?['accountNumber'] ?? '──────────';
    final customId = _profile?['customAccountId'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.mc.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Account Details',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.mc.textPrimary)),
              GestureDetector(
                onTap: () => _showEditProfileSheet(),
                child: Text('Edit',
                    style: TextStyle(
                        fontSize: 12,
                        color: MyrabaColors.green,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          SizedBox(height: 16),
          _infoRow(
              Icons.account_balance_outlined, 'Account Number', accountNumber,
              copyable: true),
          if (customId != null) ...[
            Divider(height: 24, color: context.mc.surfaceLine),
            _infoRow(Icons.tag_rounded, 'Custom ID', customId, copyable: true),
          ],
          Divider(height: 24, color: context.mc.surfaceLine),
          _infoRow(Icons.email_outlined, 'Email', _profile?['email'] ?? '—'),
          Divider(height: 24, color: context.mc.surfaceLine),
          _infoRow(Icons.phone_outlined, 'Phone', _profile?['phone'] ?? '—'),
          if ((_profile?['address'] as String?) != null) ...[
            Divider(height: 24, color: context.mc.surfaceLine),
            _infoRow(Icons.location_on_outlined, 'Address',
                _profile!['address'] as String),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {bool copyable = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.mc.textHint),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: context.mc.textHint)),
              SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.mc.textPrimary)),
            ],
          ),
        ),
        if (copyable)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Copied!'),
                    backgroundColor: MyrabaColors.green,
                    duration: Duration(seconds: 1)),
              );
            },
            child: Icon(Icons.copy_rounded,
                size: 16, color: context.mc.textHint),
          ),
      ],
    );
  }

  Widget _buildKycSection() {
    final status = _kyc?['status'] as String? ?? 'NOT_STARTED';
    final isVerified = status == 'APPROVED';
    final isPending = status == 'PENDING';
    final color = isVerified
        ? MyrabaColors.green
        : isPending
            ? MyrabaColors.gold
            : MyrabaColors.red;
    final label = isVerified
        ? 'Verified'
        : isPending
            ? 'Pending review'
            : 'Not verified';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.mc.card(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isVerified ? Icons.verified_rounded : Icons.shield_outlined,
              color: color,
              size: 22,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KYC Verification',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.mc.textPrimary)),
                Text(label, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
          if (!isVerified)
            TextButton(
              onPressed: () => _showKycSheet(),
              child: Text('Verify Now', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildPointsSection() {
    final pts = _points?['points'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.mc.card(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MyrabaColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.star_rounded,
                color: MyrabaColors.gold, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Myraba Points',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.mc.textPrimary)),
                Text('$pts pts accumulated',
                    style: TextStyle(
                        fontSize: 12, color: context.mc.textHint)),
              ],
            ),
          ),
          Text('$pts',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: MyrabaColors.gold)),
        ],
      ),
    );
  }

  Widget _buildMenuSection(AuthService auth) {
    return Column(
      children: [
        _menuItem(Icons.bar_chart_rounded, 'Monthly Review', MyrabaColors.teal,
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => MonthlyReviewScreen()))),
        SizedBox(height: 10),
        _menuItem(Icons.history_rounded, 'Year in Review', MyrabaColors.purple,
            () => _showYearInReview()),
        SizedBox(height: 10),
        _buildThemeToggle(),
        SizedBox(height: 10),
        _menuItem(Icons.history_rounded, 'Transaction History',
            MyrabaColors.teal, () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()))),
        SizedBox(height: 10),
        _menuItem(Icons.security_rounded, 'Security Settings',
            MyrabaColors.blue, () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()))),
        SizedBox(height: 10),
        _menuItem(Icons.help_outline_rounded, 'Help & Support',
            context.mc.textSecond, () => _showHelpSupport()),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _confirmLogout(auth),
          icon: const Icon(Icons.logout_rounded, color: MyrabaColors.red),
          label:
              Text('Log Out', style: TextStyle(color: MyrabaColors.red)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: MyrabaColors.red),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeToggle() {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: context.mc.card(),
      child: Row(
        children: [
          Icon(
            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: isDark ? MyrabaColors.purple : MyrabaColors.gold,
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isDark ? 'Dark Mode' : 'Light Mode',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.mc.textPrimary,
              ),
            ),
          ),
          Switch(
            value: isDark,
            onChanged: (_) => themeProvider.toggle(),
            activeThumbColor: MyrabaColors.purple,
            inactiveThumbColor: MyrabaColors.gold,
            inactiveTrackColor: MyrabaColors.gold.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: context.mc.card(),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.mc.textPrimary)),
            ),
            Icon(Icons.chevron_right_rounded,
                color: context.mc.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  // ─── Edit Profile Sheet ───────────────────────────────────────────

  void _showEditProfileSheet() {
    final nameCtrl = TextEditingController(text: _profile?['fullName'] ?? '');
    final phoneCtrl = TextEditingController(text: _profile?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: _profile?['email'] ?? '');
    final addressCtrl = TextEditingController(text: _profile?['address'] ?? '');
    final customIdCtrl =
        TextEditingController(text: _profile?['customAccountId'] ?? '');
    bool saving = false;
    String? error;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.mc.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: context.mc.surfaceLine,
                          borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 20),
              Text('Edit Profile',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.mc.textPrimary)),
              SizedBox(height: 20),
              Text('Full Name',
                  style:
                      TextStyle(fontSize: 13, color: context.mc.textSecond)),
              SizedBox(height: 8),
              TextField(
                  controller: nameCtrl,
                  decoration:
                      InputDecoration(hintText: 'Your full name')),
              SizedBox(height: 16),
              Text('Phone Number',
                  style:
                      TextStyle(fontSize: 13, color: context.mc.textSecond)),
              SizedBox(height: 8),
              TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(hintText: '08012345678')),
              SizedBox(height: 16),
              Text('Email Address',
                  style:
                      TextStyle(fontSize: 13, color: context.mc.textSecond)),
              SizedBox(height: 8),
              TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      InputDecoration(hintText: 'you@example.com')),
              SizedBox(height: 16),
              Text('Address',
                  style:
                      TextStyle(fontSize: 13, color: context.mc.textSecond)),
              SizedBox(height: 8),
              TextField(
                  controller: addressCtrl,
                  decoration: InputDecoration(
                      hintText: 'e.g. 12 Lagos Street, Abuja')),
              SizedBox(height: 16),
              Text('Custom Account ID',
                  style:
                      TextStyle(fontSize: 13, color: context.mc.textSecond)),
              SizedBox(height: 4),
              Text(
                  'A short ID others can use to send you money (e.g. 5678-smith)',
                  style: TextStyle(fontSize: 11, color: context.mc.textHint)),
              const SizedBox(height: 8),
              TextField(
                  controller: customIdCtrl,
                  decoration:
                      const InputDecoration(hintText: 'e.g. 5678-smith')),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!,
                    style:
                        const TextStyle(color: MyrabaColors.red, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        setLocal(() {
                          saving = true;
                          error = null;
                        });
                        final auth =
                            Provider.of<AuthService>(context, listen: false);
                        final api = ApiService(auth.token!);
                        try {
                          await api.updateMyProfile(
                            fullName: nameCtrl.text.trim().isEmpty
                                ? null
                                : nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim().isEmpty
                                ? null
                                : phoneCtrl.text.trim(),
                            email: emailCtrl.text.trim().isEmpty
                                ? null
                                : emailCtrl.text.trim(),
                            address: addressCtrl.text.trim().isEmpty
                                ? null
                                : addressCtrl.text.trim(),
                            customAccountId: customIdCtrl.text.trim().isEmpty
                                ? null
                                : customIdCtrl.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Profile updated'),
                                    backgroundColor: MyrabaColors.green));
                          }
                        } catch (e) {
                          setLocal(() {
                            saving = false;
                            error =
                                e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Help & Support ───────────────────────────────────────────────

  void _showHelpSupport() {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => const SupportChatScreen()));
  }


  // ─── Year in Review ───────────────────────────────────────────────

  void _showYearInReview() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.mc.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: context.mc.surfaceLine,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 32),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF9333EA), Color(0xFFFF2DAB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 36),
            ),
            SizedBox(height: 20),
            Text('Year in Review',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.mc.textPrimary)),
            SizedBox(height: 8),
            Text(
              'Your ${DateTime.now().year} Myraba story is being prepared.\nCheck back at the end of the year!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: context.mc.textHint, height: 1.5),
            ),
            SizedBox(height: 32),
            Text('Coming soon — we\'ll notify you when it\'s ready.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.mc.textHint)),
          ],
        ),
      ),
    );
  }

  // ─── KYC Sheet ────────────────────────────────────────────────────

  void _showKycSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.mc.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => _KycSheet(onDone: () {
        Navigator.pop(context);
        _load();
      }),
    );
  }

  // ─── Logout ───────────────────────────────────────────────────────

  void _confirmLogout(AuthService auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.mc.surface,
        title: Text('Log Out'),
        content: Text('Are you sure you want to log out?',
            style: TextStyle(color: context.mc.textSecond)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: context.mc.textSecond)),
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

// ─── Security Settings Screen ─────────────────────────────────────────────────

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});
  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _localAuth   = LocalAuthentication();
  final _secStorage  = const FlutterSecureStorage();
  bool _biometricEnabled = false;
  bool _pinEnabled       = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final canCheck = await _localAuth.canCheckBiometrics;
    final isAvail  = await _localAuth.isDeviceSupported();
    final pinSet   = await _secStorage.read(key: 'txPin');
    if (mounted) {
      setState(() {
        _biometricEnabled   = prefs.getBool('biometricEnabled') ?? false;
        _pinEnabled         = pinSet != null && pinSet.isNotEmpty;
        _biometricAvailable = canCheck && isAvail;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final authed = await _localAuth.authenticate(
        localizedReason: 'Confirm your identity to enable biometrics',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (!authed) return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometricEnabled', value);
    if (mounted) setState(() => _biometricEnabled = value);
  }

  void _changePassword() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.mc.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SecuritySheet(onDone: () => Navigator.pop(context)),
    );
  }

  void _setPin() {
    showDialog(
      context: context,
      builder: (_) => _PinSetupDialog(
        onSet: (pin) async {
          await _secStorage.write(key: 'txPin', value: pin);
          if (!mounted) return;
          setState(() => _pinEnabled = true);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Transaction PIN set successfully'),
            backgroundColor: MyrabaColors.green,
          ));
        },
      ),
    );
  }

  void _removePin() async {
    await _secStorage.delete(key: 'txPin');
    if (mounted) setState(() => _pinEnabled = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(
        backgroundColor: context.mc.bg,
        title: Text('Security Settings',
            style: TextStyle(color: context.mc.textPrimary, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.mc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Password ───────────────────────────────────────────────
          _secTile(
            icon: Icons.lock_outline_rounded,
            color: MyrabaColors.blue,
            title: 'Change Password',
            subtitle: 'Update your account login password',
            trailing: Icon(Icons.chevron_right_rounded, color: context.mc.textHint),
            onTap: _changePassword,
          ),
          const SizedBox(height: 12),

          // ── Biometrics ─────────────────────────────────────────────
          _secTile(
            icon: Icons.fingerprint_rounded,
            color: MyrabaColors.green,
            title: 'Face ID / Biometrics',
            subtitle: _biometricAvailable
                ? 'Use fingerprint or face to unlock'
                : 'Not available on this device',
            trailing: Switch(
              value: _biometricEnabled,
              onChanged: _biometricAvailable ? _toggleBiometric : null,
              activeThumbColor: MyrabaColors.green,
            ),
            onTap: null,
          ),
          const SizedBox(height: 12),

          // ── Transaction PIN ────────────────────────────────────────
          _secTile(
            icon: Icons.dialpad_rounded,
            color: MyrabaColors.orange,
            title: 'Transaction PIN',
            subtitle: _pinEnabled ? 'PIN is set — tap to change' : 'Set a 4-digit PIN for transactions',
            trailing: _pinEnabled
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: MyrabaColors.greenGlow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Active',
                          style: TextStyle(fontSize: 11, color: MyrabaColors.green, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: context.mc.textHint),
                  ])
                : Icon(Icons.chevron_right_rounded, color: context.mc.textHint),
            onTap: _setPin,
          ),
          if (_pinEnabled) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _removePin,
              child: const Text('Remove PIN', style: TextStyle(color: MyrabaColors.red, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _secTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.mc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.mc.surfaceLine),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: context.mc.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(
                      fontSize: 12, color: context.mc.textHint)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ─── PIN Setup Dialog ─────────────────────────────────────────────────────────

class _PinSetupDialog extends StatefulWidget {
  final ValueChanged<String> onSet;
  const _PinSetupDialog({required this.onSet});
  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  String _pin = '';
  String _confirm = '';
  bool _confirming = false;
  String? _error;

  void _onKey(String digit) {
    setState(() {
      _error = null;
      if (!_confirming) {
        if (_pin.length < 4) {
          _pin += digit;
          if (_pin.length == 4) _confirming = true;
        }
      } else {
        if (_confirm.length < 4) {
          _confirm += digit;
          if (_confirm.length == 4) {
            if (_confirm == _pin) {
              widget.onSet(_pin);
            } else {
              _pin = ''; _confirm = ''; _confirming = false;
              _error = 'PINs do not match. Try again.';
            }
          }
        }
      }
    });
  }

  void _onDelete() {
    setState(() {
      _error = null;
      if (_confirming) {
        if (_confirm.isNotEmpty) _confirm = _confirm.substring(0, _confirm.length - 1);
      } else {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = _confirming ? _confirm : _pin;
    return AlertDialog(
      backgroundColor: context.mc.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(_confirming ? 'Confirm PIN' : 'Set PIN',
          style: TextStyle(color: context.mc.textPrimary, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_confirming ? 'Enter your PIN again' : 'Choose a 4-digit transaction PIN',
              style: TextStyle(fontSize: 13, color: context.mc.textHint)),
          const SizedBox(height: 20),
          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < current.length
                    ? MyrabaColors.orange
                    : context.mc.surfaceLine,
              ),
            )),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: MyrabaColors.red, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          // Keypad
          ...List.generate(3, (row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (col) {
                final n = (row * 3 + col + 1).toString();
                return _key(n);
              }),
            ),
          )),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 72),
              _key('0'),
              SizedBox(
                width: 64, height: 48,
                child: TextButton(
                  onPressed: _onDelete,
                  child: Icon(Icons.backspace_outlined, color: context.mc.textSecond, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: context.mc.textHint)),
        ),
      ],
    );
  }

  Widget _key(String digit) {
    return SizedBox(
      width: 64, height: 48,
      child: TextButton(
        onPressed: () => _onKey(digit),
        child: Text(digit, style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600,
            color: context.mc.textPrimary)),
      ),
    );
  }
}

// ─── Security Sheet ───────────────────────────────────────────────────────────

class _SecuritySheet extends StatefulWidget {
  final VoidCallback onDone;
  const _SecuritySheet({required this.onDone});
  @override
  State<_SecuritySheet> createState() => _SecuritySheetState();
}

class _SecuritySheetState extends State<_SecuritySheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _visible = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'New passwords do not match');
      return;
    }
    if (_newCtrl.text.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters');
      return;
    }
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService(auth.token!)
          .changePassword(_currentCtrl.text, _newCtrl.text);
      if (mounted) {
        setState(() {
          _success = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: context.mc.surfaceLine,
                      borderRadius: BorderRadius.circular(2)))),
          SizedBox(height: 20),
          Text('Security Settings',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.mc.textPrimary)),
          SizedBox(height: 6),
          Text('Change your account password',
              style: TextStyle(fontSize: 13, color: context.mc.textHint)),
          const SizedBox(height: 24),
          if (_success) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MyrabaColors.greenGlow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: MyrabaColors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: MyrabaColors.green, size: 20),
                  SizedBox(width: 12),
                  Text('Password changed successfully!',
                      style: TextStyle(
                          color: MyrabaColors.green,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: widget.onDone,
              child: Text('Done'),
            ),
          ] else ...[
            Text('Current Password',
                style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
            SizedBox(height: 8),
            TextField(
              controller: _currentCtrl,
              obscureText: !_visible,
              decoration: InputDecoration(
                hintText: 'Enter current password',
                suffixIcon: IconButton(
                  icon: Icon(
                      _visible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: context.mc.textHint,
                      size: 18),
                  onPressed: () => setState(() => _visible = !_visible),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text('New Password',
                style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
            SizedBox(height: 8),
            TextField(
              controller: _newCtrl,
              obscureText: !_visible,
              decoration:
                  InputDecoration(hintText: 'At least 8 characters'),
            ),
            SizedBox(height: 16),
            Text('Confirm New Password',
                style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmCtrl,
              obscureText: !_visible,
              decoration:
                  const InputDecoration(hintText: 'Repeat new password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style:
                      const TextStyle(color: MyrabaColors.red, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Change Password'),
            ),
          ],
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
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _bvnCtrl.dispose();
    _ninCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_bvnCtrl.text.trim().isEmpty && _ninCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter BVN or NIN');
      return;
    }
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) return;
    final api = ApiService(auth.token!);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_bvnCtrl.text.trim().isNotEmpty) {
        await api.submitBvn(_bvnCtrl.text.trim());
      }
      if (_ninCtrl.text.trim().isNotEmpty) {
        await api.submitNin(_ninCtrl.text.trim());
      }
      if (!mounted) return;
      // Close the sheet first, then show confirmation
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Theme.of(context).extension<MyrabaColorScheme>()?.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.check_circle_rounded, color: MyrabaColors.green, size: 24),
            SizedBox(width: 10),
            Text('Submitted!', style: TextStyle(color: MyrabaColors.green, fontWeight: FontWeight.w700)),
          ]),
          content: Text(
            'Your identity documents have been submitted for review.\n\nVerification typically takes 1–2 business days. You\'ll be able to use all features once approved.',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); widget.onDone(); },
              child: Text('Got it', style: TextStyle(color: MyrabaColors.orange, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().contains('already')
              ? 'KYC already submitted — awaiting review'
              : 'Verification failed. Check your number and try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: context.mc.surfaceLine,
                      borderRadius: BorderRadius.circular(2)))),
          SizedBox(height: 20),
          Text('KYC Verification',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.mc.textPrimary)),
          SizedBox(height: 6),
          Text('Provide your BVN or NIN to verify your identity',
              style: TextStyle(fontSize: 13, color: context.mc.textHint)),
          SizedBox(height: 24),
          Text('BVN (optional)',
              style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
          SizedBox(height: 8),
          TextField(
              controller: _bvnCtrl,
              keyboardType: TextInputType.number,
              maxLength: 11,
              decoration: InputDecoration(
                  hintText: '11-digit BVN', counterText: '')),
          SizedBox(height: 16),
          Text('NIN (optional)',
              style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
          const SizedBox(height: 8),
          TextField(
              controller: _ninCtrl,
              keyboardType: TextInputType.number,
              maxLength: 11,
              decoration: const InputDecoration(
                  hintText: '11-digit NIN', counterText: '')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: MyrabaColors.red, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Submit for Verification'),
          ),
        ],
      ),
    );
  }
}
