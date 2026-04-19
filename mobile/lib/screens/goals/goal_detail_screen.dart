import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class GoalDetailScreen extends StatefulWidget {
  final String inviteCode;
  final bool isCreator;
  const GoalDetailScreen({super.key, required this.inviteCode, this.isCreator = false});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  Map<String, dynamic>? _goal;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final api  = ApiService(auth.token!);
    try {
      final res = await api.getGoalByCode(widget.inviteCode);
      if (!mounted) return;
      setState(() { _goal = res; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load goal'; _loading = false; });
    }
  }

  void _share() {
    final code = _goal?['inviteCode'] as String? ?? widget.inviteCode;
    final title = _goal?['title'] as String? ?? 'Community Goal';
    share_plus.Share.share(
      'Join my Community Goal on Myraba!\n\n'
      '"$title"\n\n'
      'Open Myraba → Finances → Community Goals → Enter Code: $code\n\n'
      'Or tap: https://myraba.app/goal/$code',
    );
  }

  Future<void> _contribute() async {
    final amountCtrl = TextEditingController();
    final noteCtrl   = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.mc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24,
          MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: ctx.mc.surfaceLine,
                borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Contribute to Goal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: ctx.mc.textPrimary)),
            const SizedBox(height: 20),
            Text('Amount (₦)', style: TextStyle(fontSize: 13, color: ctx.mc.textSecond)),
            const SizedBox(height: 8),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '0.00', prefixText: '₦ ',
                prefixStyle: TextStyle(color: MyrabaColors.gold, fontWeight: FontWeight.w700, fontSize: 16)),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text('Note (optional)', style: TextStyle(fontSize: 13, color: ctx.mc.textSecond)),
            const SizedBox(height: 8),
            TextField(controller: noteCtrl,
              decoration: const InputDecoration(hintText: 'e.g. For the generator fund')),
            const SizedBox(height: 24),
            StatefulBuilder(builder: (_, setSt) {
              return ElevatedButton(
                onPressed: () async {
                  final amt = double.tryParse(amountCtrl.text.trim());
                  if (amt == null || amt < 50) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Minimum contribution is ₦50')));
                    return;
                  }
                  final auth = Provider.of<AuthService>(context, listen: false);
                  final api  = ApiService(auth.token!);
                  try {
                    await api.contributeToGoal(widget.inviteCode, amt,
                      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
                    if (context.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
                  }
                },
                child: const Text('Confirm Contribution'),
              );
            }),
          ],
        ),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _withdraw() async {
    final goalId = _goal?['id'] as int?;
    if (goalId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Withdraw Funds'),
        content: Text('Move ₦${_goal!['balance']} to your wallet?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (confirmed != true) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final api  = ApiService(auth.token!);
    try {
      final res = await api.withdrawGoal(goalId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] as String? ?? 'Withdrawn!'),
          backgroundColor: MyrabaColors.green));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(
        title: Text(_goal?['title'] as String? ?? 'Goal'),
        actions: [
          if (_goal != null)
            IconButton(icon: const Icon(Icons.share_rounded), onPressed: _share),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: context.mc.textSecond)))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final g = _goal!;
    final target  = double.tryParse(g['targetAmount'].toString()) ?? 0;
    final balance = double.tryParse(g['balance'].toString()) ?? 0;
    final percent = target > 0 ? (balance / target).clamp(0.0, 1.0) : 0.0;
    final pctLabel = g['percentFunded']?.toString() ?? '0';
    final status   = g['status'] as String? ?? 'ACTIVE';
    final contributions = List<Map<String, dynamic>>.from(g['contributions'] as List? ?? []);
    final deadline = g['deadline'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Goal card ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.mc.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.mc.surfaceLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(g['title'] as String? ?? '',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                      color: context.mc.textPrimary))),
                  _statusChip(status),
                ]),
                const SizedBox(height: 6),
                Text(g['description'] as String? ?? '',
                  style: TextStyle(fontSize: 13, color: context.mc.textSecond, height: 1.5)),
                const SizedBox(height: 20),
                // Progress bar
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('₦${_fmt(balance)} raised',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: MyrabaColors.green)),
                  Text('of ₦${_fmt(target)}',
                    style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 10,
                    backgroundColor: MyrabaColors.green.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(MyrabaColors.green),
                  ),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('$pctLabel% funded',
                    style: TextStyle(fontSize: 12, color: context.mc.textHint)),
                  Text('${g['contributorCount']} contributor${(g['contributorCount'] as int? ?? 0) == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 12, color: context.mc.textHint)),
                ]),
                if (deadline != null) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Icon(Icons.schedule_rounded, size: 14, color: context.mc.textHint),
                    const SizedBox(width: 6),
                    Text('Deadline: ${DateFormat('d MMM y').format(DateTime.parse(deadline))}',
                      style: TextStyle(fontSize: 12, color: context.mc.textHint)),
                  ]),
                ],
                const SizedBox(height: 16),
                // Invite code chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: MyrabaColors.greenGlow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: MyrabaColors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.tag_rounded, color: MyrabaColors.green, size: 16),
                    const SizedBox(width: 8),
                    Text('Code: ${g['inviteCode']}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: MyrabaColors.green, letterSpacing: 1.5)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _share,
                      child: const Icon(Icons.share_rounded, color: MyrabaColors.green, size: 18)),
                  ]),
                ),
              ],
            ),
          ),

          // ── Actions ──────────────────────────────────────────────
          const SizedBox(height: 20),
          if (status == 'ACTIVE' && !widget.isCreator)
            ElevatedButton.icon(
              onPressed: _contribute,
              icon: const Icon(Icons.volunteer_activism_rounded),
              label: const Text('Contribute'),
            ),
          if (widget.isCreator && balance > 0 && status != 'WITHDRAWN') ...[
            ElevatedButton.icon(
              onPressed: _withdraw,
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: const Text('Withdraw to Wallet'),
            ),
          ],

          // ── Contribution history ──────────────────────────────────
          const SizedBox(height: 28),
          Text('Contributions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
              color: context.mc.textPrimary)),
          const SizedBox(height: 12),
          if (contributions.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No contributions yet. Share the code to get started!',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.mc.textSecond, fontSize: 13)),
            ))
          else
            ...contributions.map((c) => _contributionTile(c)),
        ],
      ),
    );
  }

  Widget _contributionTile(Map<String, dynamic> c) {
    final contributor = c['contributor'] as Map<String, dynamic>? ?? {};
    final amt = double.tryParse(c['amount'].toString()) ?? 0;
    final createdAt = c['createdAt'] as String?;
    String timeStr = '';
    if (createdAt != null) {
      try { timeStr = DateFormat('d MMM y · h:mm a').format(DateTime.parse(createdAt).toLocal()); } catch (_) {}
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.mc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.mc.surfaceLine),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: MyrabaColors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(
            (contributor['fullName'] as String? ?? '?')[0].toUpperCase(),
            style: const TextStyle(color: MyrabaColors.green, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contributor['fullName'] as String? ?? 'Anonymous',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: context.mc.textPrimary)),
            Text('m₦ ${contributor['handle']}',
              style: TextStyle(fontSize: 11, color: context.mc.textHint)),
            if ((c['note'] as String?) != null && (c['note'] as String).isNotEmpty)
              Text(c['note'] as String,
                style: TextStyle(fontSize: 12, color: context.mc.textSecond, height: 1.4)),
            Text(timeStr, style: TextStyle(fontSize: 11, color: context.mc.textHint)),
          ],
        )),
        Text('₦${_fmt(amt)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: MyrabaColors.green)),
      ]),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'ACTIVE':    color = MyrabaColors.green; break;
      case 'COMPLETED': color = MyrabaColors.gold; break;
      case 'WITHDRAWN': color = MyrabaColors.purple; break;
      default:          color = MyrabaColors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  String _fmt(double v) => NumberFormat('#,##0.00', 'en_NG').format(v);
}
