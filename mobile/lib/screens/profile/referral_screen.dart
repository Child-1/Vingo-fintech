import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final api = ApiService(auth.token!);
    try {
      final res = await api.getMyReferrals();
      if (mounted) setState(() { _data = res; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied!'), duration: Duration(seconds: 2)),
    );
  }

  void _share() {
    final code = _data?['myReferralCode'] as String? ?? '';
    final link = _data?['shareLink'] as String? ?? '';
    share_plus.Share.share(
      'Join me on Myraba — Nigeria\'s smartest wallet!\n'
      'Use my referral code $code to sign up and we both earn rewards.\n$link',
      subject: 'Join Myraba',
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = _data?['myReferralCode'] as String? ?? '—';
    final total = (_data?['totalReferrals'] as num?)?.toInt() ?? 0;
    final earned = (_data?['totalEarned'] as num?)?.toInt() ?? 0;
    final points = (_data?['pointsEarned'] as num?)?.toInt() ?? 0;
    final referrals = List<dynamic>.from(_data?['referrals'] as List? ?? []);

    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(title: const Text('Invite Friends')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Hero card ───────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [MyrabaColors.green, MyrabaColors.green.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 32),
                        const SizedBox(height: 12),
                        const Text('Refer & Earn',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 6),
                        const Text('Earn ₦50 + 100 points for every friend who joins using your code.',
                            style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4)),
                        const SizedBox(height: 20),
                        // Code box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(code,
                                    style: const TextStyle(
                                        fontSize: 22, fontWeight: FontWeight.w900,
                                        color: Colors.white, letterSpacing: 4)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                                onPressed: () => _copy(code),
                                tooltip: 'Copy code',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: const Text('Share Invite Link'),
                            onPressed: _share,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Stats row ────────────────────────────────────
                  Row(children: [
                    _stat('Friends Joined', '$total', Icons.people_alt_rounded),
                    const SizedBox(width: 12),
                    _stat('Cash Earned', '₦${NumberFormat('#,##0').format(earned)}', Icons.payments_rounded),
                    const SizedBox(width: 12),
                    _stat('Points Earned', '$points pts', Icons.star_rounded),
                  ]),

                  const SizedBox(height: 24),

                  if (referrals.isNotEmpty) ...[
                    Text('Your Referrals (${referrals.length})',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                            color: context.mc.textPrimary)),
                    const SizedBox(height: 12),
                    ...referrals.map((r) => _referralTile(r)),
                  ] else ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.people_outline_rounded, size: 48, color: context.mc.textHint),
                          const SizedBox(height: 12),
                          Text('No referrals yet.',
                              style: TextStyle(color: context.mc.textSecond)),
                          const SizedBox(height: 6),
                          Text('Share your code to start earning!',
                              style: TextStyle(fontSize: 12, color: context.mc.textHint)),
                        ]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: context.mc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.mc.surfaceLine),
        ),
        child: Column(children: [
          Icon(icon, size: 20, color: MyrabaColors.green),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: context.mc.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 10, color: context.mc.textHint),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _referralTile(dynamic r) {
    final name = r['fullName'] as String? ?? '—';
    final handle = r['handle'] as String? ?? '';
    final joined = r['joinedAt'] as String?;
    String dateStr = '';
    if (joined != null) {
      try { dateStr = DateFormat('dd MMM yyyy').format(DateTime.parse(joined).toLocal()); }
      catch (_) {}
    }
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.mc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.mc.surfaceLine),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: MyrabaColors.green.withValues(alpha: 0.15),
          child: Text(initial,
              style: const TextStyle(fontWeight: FontWeight.w700, color: MyrabaColors.green)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(fontWeight: FontWeight.w600,
                color: context.mc.textPrimary, fontSize: 13)),
            if (handle.isNotEmpty)
              Text('m₦ $handle',
                  style: TextStyle(fontSize: 11, color: context.mc.textHint)),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: MyrabaColors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('+₦50 + 100pts',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: MyrabaColors.green)),
          ),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(dateStr, style: TextStyle(fontSize: 10, color: context.mc.textHint)),
          ],
        ]),
      ]),
    );
  }
}
