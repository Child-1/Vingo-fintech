import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class FixedDepositScreen extends StatefulWidget {
  final bool embedded;
  const FixedDepositScreen({super.key, this.embedded = false});

  @override
  State<FixedDepositScreen> createState() => _FixedDepositScreenState();
}

class _FixedDepositScreenState extends State<FixedDepositScreen> {
  List<Map<String, dynamic>> _deposits = [];
  bool _loading = true;

  static const _terms = [
    {'days': 30,  'rate': '8%',  'label': '1 Month'},
    {'days': 90,  'rate': '10%', 'label': '3 Months'},
    {'days': 180, 'rate': '12%', 'label': '6 Months'},
    {'days': 365, 'rate': '15%', 'label': '1 Year'},
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final api  = ApiService(auth.token!);
    try {
      final res = await api.getFixedDeposits();
      if (!mounted) return;
      setState(() {
        _deposits = List<Map<String, dynamic>>.from(res['deposits'] as List? ?? []);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createDeposit() async {
    final amtCtrl = TextEditingController();
    int selectedDays = 90;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.mc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24,
            MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: ctx.mc.surfaceLine,
                    borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Lock Funds', style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w700, color: ctx.mc.textPrimary)),
                const SizedBox(height: 6),
                Text('Earn interest by locking funds for a fixed period.',
                  style: TextStyle(fontSize: 13, color: ctx.mc.textSecond)),
                const SizedBox(height: 20),
                Text('Select Term', style: TextStyle(fontSize: 13, color: ctx.mc.textSecond)),
                const SizedBox(height: 10),
                ...(_terms.map((t) {
                  final active = selectedDays == t['days'];
                  return GestureDetector(
                    onTap: () => setSt(() => selectedDays = t['days'] as int),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: active ? MyrabaColors.greenGlow : ctx.mc.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: active
                          ? MyrabaColors.green : ctx.mc.surfaceLine,
                          width: active ? 1.5 : 1),
                      ),
                      child: Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['label'] as String,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                color: active ? MyrabaColors.green : ctx.mc.textPrimary)),
                            Text('${t['days']} days', style: TextStyle(
                              fontSize: 12, color: ctx.mc.textHint)),
                          ],
                        )),
                        Text('${t['rate']} p.a.',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                            color: active ? MyrabaColors.green : MyrabaColors.gold)),
                      ]),
                    ),
                  );
                })),
                const SizedBox(height: 16),
                Text('Amount (₦)', style: TextStyle(fontSize: 13, color: ctx.mc.textSecond)),
                const SizedBox(height: 8),
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '0.00', prefixText: '₦ ',
                    prefixStyle: TextStyle(color: MyrabaColors.gold,
                      fontWeight: FontWeight.w700, fontSize: 16)),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text('Minimum: ₦1,000',
                  style: TextStyle(fontSize: 11, color: ctx.mc.textHint)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final amt = double.tryParse(amtCtrl.text.trim());
                    if (amt == null || amt < 1000) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Minimum deposit is ₦1,000')));
                      return;
                    }
                    final auth = Provider.of<AuthService>(context, listen: false);
                    final api  = ApiService(auth.token!);
                    try {
                      await api.createFixedDeposit(amt, selectedDays);
                      if (mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
                      }
                    }
                  },
                  child: const Text('Lock Funds'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    amtCtrl.dispose();
    if (result == true) _load();
  }

  Future<void> _withdraw(Map<String, dynamic> deposit) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final api  = ApiService(auth.token!);
    try {
      final res = await api.withdrawDeposit(deposit['id'] as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] as String? ?? 'Withdrawn!'),
          backgroundColor: MyrabaColors.green));
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    }
  }

  Future<void> _breakEarly(Map<String, dynamic> deposit) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final api  = ApiService(auth.token!);
    final id   = deposit['id'] as int;

    // Fetch preview
    Map<String, dynamic> preview;
    try {
      preview = await api.getDepositBreakPreview(id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      return;
    }
    if (!mounted) return;

    final locked        = _fmt(double.tryParse(preview['lockedAmount'].toString()) ?? 0);
    final warnPenalty   = _fmt(double.tryParse(preview['warningPenalty'].toString()) ?? 0);
    final warnReturn    = _fmt(double.tryParse(preview['warningReturn'].toString()) ?? 0);

    // Show scary warning
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.mc.surface,
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: MyrabaColors.red, size: 22),
          const SizedBox(width: 8),
          Text('Break Deposit?', style: TextStyle(color: context.mc.textPrimary, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to break your fixed deposit early.',
              style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
            const SizedBox(height: 16),
            _penaltyRow('Locked amount', '₦$locked', context.mc.textPrimary),
            const SizedBox(height: 8),
            _penaltyRow('Penalty (25%)', '- ₦$warnPenalty', MyrabaColors.red),
            const Divider(height: 20),
            _penaltyRow('You receive', '₦$warnReturn', MyrabaColors.red, bold: true),
            const SizedBox(height: 12),
            Text('No interest will be paid. This cannot be undone.',
              style: TextStyle(fontSize: 11, color: context.mc.textHint)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep it locked', style: TextStyle(color: context.mc.textSecond))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MyrabaColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Break Deposit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final res = await api.breakDeposit(id);
      if (!mounted) return;
      _load();
      // Show mercy message
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.mc.surface,
          title: Row(children: [
            const Text('🙏', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text('We showed mercy', style: TextStyle(color: MyrabaColors.green, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          content: Text(res['message'] as String? ?? 'Funds returned to your wallet.',
            style: TextStyle(fontSize: 13, color: context.mc.textSecond, height: 1.5)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
      ? const Center(child: CircularProgressIndicator())
      : _deposits.isEmpty
        ? Center(child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_clock_rounded, size: 48, color: context.mc.textHint),
              const SizedBox(height: 16),
              Text('No deposits yet.\nTap "Lock Funds" to earn interest on your savings.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.mc.textSecond, height: 1.5)),
            ]),
          ))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _deposits.length,
              itemBuilder: (_, i) => _depositCard(_deposits[i]),
            ),
          );

    if (widget.embedded) {
      return Stack(
        children: [
          body,
          Positioned(
            bottom: 16, right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'fd_fab',
              onPressed: _createDeposit,
              backgroundColor: MyrabaColors.gold,
              icon: const Icon(Icons.lock_rounded, color: Colors.white),
              label: const Text('Lock Funds', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(title: const Text('Fixed Deposits')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDeposit,
        backgroundColor: MyrabaColors.gold,
        icon: const Icon(Icons.lock_rounded, color: Colors.white),
        label: const Text('Lock Funds', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: body,
    );
  }

  Widget _depositCard(Map<String, dynamic> d) {
    final status  = d['status'] as String? ?? 'ACTIVE';
    final amount  = double.tryParse(d['amount'].toString()) ?? 0;
    final returns = double.tryParse(d['expectedReturn'].toString()) ?? 0;
    final interest = double.tryParse(d['interest'].toString()) ?? 0;
    final days    = d['daysRemaining'] as int? ?? 0;

    Color statusColor;
    switch (status) {
      case 'ACTIVE':  statusColor = MyrabaColors.gold; break;
      case 'MATURED': statusColor = MyrabaColors.green; break;
      default:        statusColor = context.mc.textHint;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.mc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.mc.surfaceLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('${d['termDays']}-Day Deposit',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: context.mc.textPrimary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(status, style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _infoCol('Locked', '₦${_fmt(amount)}'),
            const SizedBox(width: 24),
            _infoCol('At Maturity', '₦${_fmt(returns)}', valueColor: MyrabaColors.green),
            const SizedBox(width: 24),
            _infoCol('Interest', '+₦${_fmt(interest)}', valueColor: MyrabaColors.green),
          ]),
          if (status == 'ACTIVE') ...[
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 13, color: context.mc.textHint),
              const SizedBox(width: 4),
              Text('$days day${days == 1 ? '' : 's'} remaining',
                style: TextStyle(fontSize: 12, color: context.mc.textHint)),
              const Spacer(),
              Text('${d['interestRate']}% p.a.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MyrabaColors.gold)),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _breakEarly(d),
                icon: const Icon(Icons.lock_open_rounded, size: 15, color: MyrabaColors.red),
                label: const Text('Break Early', style: TextStyle(color: MyrabaColors.red, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: MyrabaColors.red, width: 0.8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
          if (status == 'MATURED') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _withdraw(d),
                icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                label: const Text('Withdraw to Wallet'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoCol(String label, String value, {Color? valueColor}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: context.mc.textHint)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
        color: valueColor ?? context.mc.textPrimary)),
    ]);
  }

  static Widget _penaltyRow(String label, String value, Color valueColor, {bool bold = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13)),
      Text(value, style: TextStyle(fontSize: 13, color: valueColor,
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
    ]);
  }

  String _fmt(double v) => NumberFormat('#,##0.00', 'en_NG').format(v);
}
