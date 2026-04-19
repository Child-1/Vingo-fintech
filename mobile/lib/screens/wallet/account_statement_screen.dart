import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class AccountStatementScreen extends StatefulWidget {
  const AccountStatementScreen({super.key});

  @override
  State<AccountStatementScreen> createState() => _AccountStatementScreenState();
}

class _AccountStatementScreenState extends State<AccountStatementScreen> {
  List<dynamic> _transactions = [];
  bool _loading = true;

  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to   = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final api  = ApiService(auth.token!);
    try {
      final res = await api.getHistory();
      if (!mounted) return;
      final all = List<dynamic>.from(res['transactions'] as List? ?? []);
      setState(() {
        _transactions = all.where((t) {
          final raw = t['createdAt'] as String?;
          if (raw == null) return false;
          final dt = DateTime.tryParse(raw)?.toLocal();
          if (dt == null) return false;
          return !dt.isBefore(_from) && !dt.isAfter(_to.add(const Duration(days: 1)));
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2024),
      lastDate: _to,
    );
    if (picked != null) { setState(() => _from = picked); _load(); }
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime.now(),
    );
    if (picked != null) { setState(() => _to = picked); _load(); }
  }

  void _share(AuthService auth) {
    final handle = auth.myrabaTag ?? 'User';
    final buf = StringBuffer();
    buf.writeln('MYRABA ACCOUNT STATEMENT');
    buf.writeln('Account: m₦ $handle');
    buf.writeln('Period: ${_fmt(_from)} – ${_fmt(_to)}');
    buf.writeln('Generated: ${_fmt(DateTime.now())}');
    buf.writeln('─' * 40);
    for (final t in _transactions) {
      final type   = t['type'] as String? ?? '';
      final amt    = t['amount']?.toString() ?? '0.00';
      final status = t['status'] as String? ?? '';
      final desc   = t['description'] as String? ?? '';
      final date   = t['createdAt'] != null
          ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(t['createdAt']).toLocal())
          : '';
      final sign   = (type == 'TRANSFER' && (t['receiverWallet'] != null)) ? '+' : '-';
      buf.writeln('$date | $sign₦$amt | $type | $status');
      if (desc.isNotEmpty) buf.writeln('  $desc');
    }
    buf.writeln('─' * 40);
    buf.writeln('Total transactions: ${_transactions.length}');

    share_plus.Share.share(buf.toString(), subject: 'Myraba Account Statement');
  }

  String _fmt(DateTime dt) => DateFormat('dd MMM yyyy').format(dt);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);

    double credits = 0, debits = 0;
    for (final t in _transactions) {
      final amt = double.tryParse(t['amount']?.toString() ?? '0') ?? 0;
      final type = t['type'] as String? ?? '';
      final hasReceiver = t['receiverWallet'] != null;
      if (type == 'TRANSFER' && hasReceiver) {
        credits += amt;
      } else {
        debits += amt;
      }
    }

    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(
        title: const Text('Account Statement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share statement',
            onPressed: _transactions.isEmpty ? null : () => _share(auth),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Date range picker ────────────────────────────────────
          Container(
            color: context.mc.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(child: _dateBtn('From', _from, _pickFrom)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('→', style: TextStyle(fontWeight: FontWeight.w700))),
              Expanded(child: _dateBtn('To', _to, _pickTo)),
            ]),
          ),

          // ── Summary row ──────────────────────────────────────────
          if (!_loading && _transactions.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: context.mc.surface,
              child: Row(children: [
                _summaryChip('Credits', '+₦${_fmtAmt(credits)}', MyrabaColors.green),
                const SizedBox(width: 12),
                _summaryChip('Debits', '-₦${_fmtAmt(debits)}', MyrabaColors.red),
                const Spacer(),
                Text('${_transactions.length} txns',
                  style: TextStyle(fontSize: 12, color: context.mc.textHint)),
              ]),
            ),

          const Divider(height: 1),

          // ── Transactions ─────────────────────────────────────────
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _transactions.isEmpty
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.receipt_long_rounded, size: 48, color: context.mc.textHint),
                      const SizedBox(height: 16),
                      Text('No transactions in this period.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.mc.textSecond)),
                    ]),
                  ))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _transactions.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1, indent: 72,
                      color: context.mc.surfaceLine),
                    itemBuilder: (_, i) => _txRow(_transactions[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dateBtn(String label, DateTime dt, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.mc.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.mc.surfaceLine),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: context.mc.textHint)),
          const SizedBox(height: 2),
          Text(_fmt(dt), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: context.mc.textPrimary)),
        ]),
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: color)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _txRow(dynamic t) {
    final type     = t['type'] as String? ?? '';
    final status   = t['status'] as String? ?? '';
    final amt      = double.tryParse(t['amount']?.toString() ?? '0') ?? 0;
    final desc     = t['description'] as String? ?? type;
    final raw      = t['createdAt'] as String?;
    final hasRecv  = t['receiverWallet'] != null;
    final isCredit = type == 'TRANSFER' && hasRecv;
    final color    = isCredit ? MyrabaColors.green : MyrabaColors.red;
    final sign     = isCredit ? '+' : '-';

    String dateStr = '';
    if (raw != null) {
      try { dateStr = DateFormat('dd MMM · h:mm a').format(DateTime.parse(raw).toLocal()); }
      catch (_) {}
    }

    IconData icon;
    switch (type) {
      case 'TRANSFER':   icon = isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded; break;
      case 'WITHDRAWAL': icon = Icons.arrow_upward_rounded; break;
      case 'DEPOSIT':    icon = Icons.arrow_downward_rounded; break;
      default:           icon = Icons.swap_horiz_rounded;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(desc, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
        color: context.mc.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(children: [
        Text(dateStr, style: TextStyle(fontSize: 11, color: context.mc.textHint)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: (status == 'SUCCESS' ? MyrabaColors.green : MyrabaColors.red)
              .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4)),
          child: Text(status, style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w600,
            color: status == 'SUCCESS' ? MyrabaColors.green : MyrabaColors.red)),
        ),
      ]),
      trailing: Text('$sign₦${_fmtAmt(amt)}',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
    );
  }

  String _fmtAmt(double v) => NumberFormat('#,##0.00', 'en_NG').format(v);
}
