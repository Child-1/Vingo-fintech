import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'wallet/send_money_screen.dart';
import 'wallet/fund_wallet_screen.dart';
import 'wallet/transaction_history_screen.dart';
import 'qr_screen.dart';
import 'stats/monthly_review_screen.dart';
import 'support/support_chat_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _wallet;
  List<dynamic> _transactions = [];
  bool _loading = true;
  bool _balanceHidden = false;
  bool _hasError = false;

  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _shimmerAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));
    _load();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) return;
    final api = ApiService(auth.token!);
    try {
      final results = await Future.wait([
        api.getMyProfile(),
        api.getHistory(),
      ]);
      final profile = results[0];
      final history = results[1];
      if (!mounted) return;
      // Propagate KYC status app-wide
      final kycStatus = profile['kycStatus'] as String? ?? 'NONE';
      Provider.of<AuthService>(context, listen: false).updateKycStatus(kycStatus);
      setState(() {
        _wallet = {'balance': profile['balance'], 'accountNumber': profile['accountNumber']};
        _transactions = (history['transactions'] as List?)?.take(5).toList() ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return Scaffold(
      backgroundColor: context.mc.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: MyrabaColors.green,
        backgroundColor: context.mc.surface,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(auth),
            SliverToBoxAdapter(
              child: _loading
                  ? _buildSkeleton()
                  : _hasError
                      ? _buildError()
                      : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBalanceCard(auth),
                          if (!auth.isKycApproved) ...[
                            const SizedBox(height: 16),
                            _buildKycBanner(auth),
                          ],
                          const SizedBox(height: 28),
                          _buildQuickActions(auth),
                          const SizedBox(height: 28),
                          _buildRecentTransactions(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKycBanner(AuthService auth) {
    final isPending = auth.kycStatus == 'PENDING';
    final isRejected = auth.kycStatus == 'REJECTED';
    final color = isPending ? MyrabaColors.gold : isRejected ? MyrabaColors.red : MyrabaColors.orange;
    final icon = isPending ? Icons.hourglass_top_rounded : isRejected ? Icons.cancel_outlined : Icons.shield_outlined;
    final title = isPending ? 'KYC Under Review' : isRejected ? 'KYC Rejected' : 'Verify Your Identity';
    final subtitle = isPending
        ? 'Your documents are being reviewed. Transactions are locked until approved.'
        : isRejected
            ? 'Your KYC was rejected. Please resubmit your details.'
            : 'Complete identity verification to unlock sending, payments & thrift.';

    return GestureDetector(
      onTap: isPending ? null : () => _showKycSheet(auth),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11, color: context.mc.textHint),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (!isPending) ...[
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }

  void _showKycSheet(AuthService auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.mc.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: context.mc.surfaceLine,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: MyrabaColors.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined,
                  color: MyrabaColors.orange, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Verify Your Identity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: context.mc.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'To protect our users, all financial transactions require identity verification (KYC). This takes less than 2 minutes.',
              style: TextStyle(fontSize: 13, color: context.mc.textHint, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _kycStep(Icons.badge_outlined, 'Prepare your BVN or NIN'),
            const SizedBox(height: 10),
            _kycStep(Icons.verified_user_outlined, 'Submit for verification'),
            const SizedBox(height: 10),
            _kycStep(Icons.lock_open_rounded, 'Unlock all Myraba features'),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to KYC screen via profile tab
                  // For now show a snackbar directing them
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Go to Profile → KYC Verification to get started'),
                      backgroundColor: MyrabaColors.orange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyrabaColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Verify Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kycStep(IconData icon, String label) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: MyrabaColors.orange.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: MyrabaColors.orange, size: 16),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
      ],
    );
  }

  /// Checks KYC before running any financial action.
  void _requireKyc(AuthService auth, VoidCallback action) {
    if (auth.isKycApproved) {
      action();
    } else {
      _showKycSheet(auth);
    }
  }

  Widget _buildSkeleton() {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (_, __) {
        final base = context.mc.surfaceHigh.withValues(alpha: _shimmerAnim.value);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance card skeleton
              Container(
                width: double.infinity, height: 140,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              const SizedBox(height: 28),
              // Quick actions skeleton
              Container(width: 120, height: 14, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (_) => Column(
                  children: [
                    Container(width: 60, height: 60, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(18))),
                    const SizedBox(height: 8),
                    Container(width: 40, height: 10, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
                  ],
                )),
              ),
              const SizedBox(height: 28),
              // Transactions skeleton
              Container(width: 160, height: 14, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(color: context.mc.surface, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: List.generate(4, (i) => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(width: 42, height: 42, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(12))),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(width: double.infinity, height: 12, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
                                const SizedBox(height: 6),
                                Container(width: 80, height: 10, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
                              ],
                            )),
                            const SizedBox(width: 12),
                            Container(width: 60, height: 14, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
                          ],
                        ),
                      ),
                      if (i < 3) Divider(height: 1, indent: 70, endIndent: 16, color: context.mc.surfaceLine),
                    ],
                  )),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: context.mc.textHint),
            const SizedBox(height: 14),
            Text('Could not load your wallet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.mc.textSecond)),
            const SizedBox(height: 6),
            Text('Check your connection and pull down to retry',
                style: TextStyle(fontSize: 13, color: context.mc.textHint)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() { _loading = true; _hasError = false; });
                _load();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MyrabaColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(AuthService auth) {
    return SliverAppBar(
      backgroundColor: context.mc.bg,
      floating: true,
      snap: true,
      titleSpacing: 20,
      title: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Good ${_greeting()},',
                style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
              Text(
                auth.myrabaTag ?? 'Welcome',
                style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: MyrabaColors.green,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.qr_code_scanner_rounded, color: context.mc.textPrimary),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QrScreen())),
        ),
        IconButton(
          icon: Icon(Icons.support_agent_rounded, color: context.mc.textPrimary),
          tooltip: 'Support',
          onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SupportChatScreen())),
        ),
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: context.mc.textPrimary),
          onPressed: () => _showNotifications(),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBalanceCard(AuthService auth) {
    final balance = _wallet?['balance'] ?? '0.00';
    final amt = double.tryParse(balance.toString()) ?? 0.0;

    // Color tier: red < ₦1 · yellow ₦1–₦500 · green > ₦500
    final List<Color> gradColors;
    final Color borderColor;
    final Color glowColor;
    final String tierLabel;
    if (amt < 1.0) {
      gradColors  = const [Color(0xFF4C0519), Color(0xFF7F1D1D)];
      borderColor = const Color(0xFFEF4444);
      glowColor   = const Color(0xFFEF4444);
      tierLabel   = 'Low balance';
    } else if (amt <= 500.0) {
      gradColors  = const [Color(0xFF451A03), Color(0xFF78350F)];
      borderColor = const Color(0xFFF59E0B);
      glowColor   = const Color(0xFFF59E0B);
      tierLabel   = 'Balance';
    } else {
      gradColors  = const [Color(0xFF064E3B), Color(0xFF065F46)];
      borderColor = MyrabaColors.green;
      glowColor   = MyrabaColors.green;
      tierLabel   = 'Balance';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.18),
            blurRadius: 30, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: borderColor,
                    boxShadow: [BoxShadow(color: borderColor, blurRadius: 4)],
                  ),
                ),
                const SizedBox(width: 6),
                Text(tierLabel,
                  style: const TextStyle(fontSize: 13, color: Colors.white60)),
              ]),
              GestureDetector(
                onTap: () => setState(() => _balanceHidden = !_balanceHidden),
                child: Icon(
                  _balanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white60, size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _balanceHidden ? '₦ ••••••' : '₦ $balance',
            style: const TextStyle(
              fontSize: 34, fontWeight: FontWeight.w800,
              color: Colors.white, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _cardChip(Icons.account_balance_outlined,
                _wallet?['accountNumber']?.toString().isNotEmpty == true
                    ? _wallet!['accountNumber'].toString()
                    : 'Loading...'),
              const Spacer(),
              _cardChip(Icons.person_outline_rounded, auth.myrabaHandle ?? ''),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.white54),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white60)),
      ],
    );
  }

  Widget _buildQuickActions(AuthService auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.mc.textSecond)),
        SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _action(Icons.send_rounded, 'Send', MyrabaColors.green,
                auth.isKycApproved, () {
              _requireKyc(auth, () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SendMoneyScreen())));
            }),
            _action(Icons.add_circle_outline_rounded, 'Fund', MyrabaColors.blue,
                auth.isKycApproved, () {
              _requireKyc(auth, () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => FundWalletScreen(myrabaHandle: auth.myrabaHandle ?? ''))));
            }),
            _action(Icons.qr_code_rounded, 'Receive', MyrabaColors.purple, true, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScreen()));
            }),
            _action(Icons.bar_chart_rounded, 'Stats', MyrabaColors.orange, true, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyReviewScreen()));
            }),
          ],
        ),
      ],
    );
  }

  Widget _action(IconData icon, String label, Color color, bool unlocked, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: unlocked ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: unlocked ? 0.25 : 0.15)),
                ),
                child: Icon(icon, color: color.withValues(alpha: unlocked ? 1.0 : 0.4), size: 26),
              ),
              if (!unlocked)
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: MyrabaColors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.mc.bg, width: 1.5),
                    ),
                    child: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                color: unlocked ? context.mc.textSecond : context.mc.textHint)),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Transactions',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                  color: context.mc.textSecond)),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TransactionHistoryScreen())),
              child: const Text('See all',
                style: TextStyle(fontSize: 13, color: MyrabaColors.green,
                    fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        SizedBox(height: 12),
        if (_transactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: context.mc.card(),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, color: context.mc.textHint, size: 40),
                SizedBox(height: 10),
                Text('No transactions yet',
                  style: TextStyle(color: context.mc.textHint, fontSize: 14)),
              ],
            ),
          )
        else
          Container(
            decoration: context.mc.card(),
            child: Column(
              children: _transactions.asMap().entries.map((e) {
                final tx = e.value as Map<String, dynamic>;
                final isLast = e.key == _transactions.length - 1;
                return _txTile(tx, isLast);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _txTile(Map<String, dynamic> tx, bool isLast) {
    final type = tx['type'] as String? ?? 'TRANSFER';
    final isSent = type == 'SENT' || type == 'WITHDRAWAL' || type == 'CONTRIBUTION';
    final color = isSent ? MyrabaColors.red : MyrabaColors.teal;
    final sign  = isSent ? '-' : '+';
    final icon  = _txIcon(type);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx['description'] ?? type,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                          color: context.mc.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    SizedBox(height: 3),
                    Text(_formatDate(tx['date'] as String?),
                      style: TextStyle(fontSize: 12, color: context.mc.textHint)),
                  ],
                ),
              ),
              Text('$sign₦${tx['amount']}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 70, endIndent: 16,
              color: context.mc.surfaceLine),
      ],
    );
  }

  IconData _txIcon(String type) {
    switch (type) {
      case 'SENT':       return Icons.arrow_upward_rounded;
      case 'RECEIVED':   return Icons.arrow_downward_rounded;
      case 'FUNDED':     return Icons.add_rounded;
      case 'CONTRIBUTION': return Icons.savings_rounded;
      case 'PAYOUT':     return Icons.celebration_rounded;
      case 'PENALTY':    return Icons.warning_amber_rounded;
      default:           return Icons.swap_horiz_rounded;
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]}, ${_pad(dt.hour)}:${_pad(dt.minute)}';
    } catch (_) { return iso; }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.mc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: context.mc.surfaceLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.notifications_outlined, color: MyrabaColors.green, size: 22),
                SizedBox(width: 10),
                Text('Notifications',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                      color: context.mc.textPrimary)),
              ],
            ),
            SizedBox(height: 32),
            Icon(Icons.notifications_off_outlined,
                color: context.mc.textHint, size: 48),
            SizedBox(height: 12),
            Text('No notifications yet',
              style: TextStyle(fontSize: 15, color: context.mc.textSecond,
                  fontWeight: FontWeight.w500)),
            SizedBox(height: 6),
            Text("You're all caught up!",
              style: TextStyle(fontSize: 13, color: context.mc.textHint)),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
