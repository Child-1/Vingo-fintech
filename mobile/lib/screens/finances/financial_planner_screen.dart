import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class FinancialPlannerScreen extends StatefulWidget {
  const FinancialPlannerScreen({super.key});

  @override
  State<FinancialPlannerScreen> createState() => _FinancialPlannerScreenState();
}

class _FinancialPlannerScreenState extends State<FinancialPlannerScreen> {
  bool _loading = true;
  Map<String, double> _spending = {};
  Map<String, double> _budgets  = {};

  static const _categories = [
    ('airtime',     'Airtime',     Icons.phone_android_rounded,  MyrabaColors.green),
    ('data',        'Data',        Icons.wifi_rounded,           MyrabaColors.teal),
    ('electricity', 'Electricity', Icons.bolt_rounded,           MyrabaColors.gold),
    ('cable',       'Cable TV',    Icons.tv_rounded,             MyrabaColors.blue),
    ('betting',     'Betting',     Icons.sports_soccer_rounded,  MyrabaColors.red),
    ('transfer',    'Transfers',   Icons.send_rounded,           Color(0xFF9B59B6)),
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final auth  = Provider.of<AuthService>(context, listen: false);
    final api   = ApiService(auth.token!);
    final prefs = await SharedPreferences.getInstance();

    // Load budgets from prefs
    final budgets = <String, double>{};
    for (final cat in _categories) {
      final v = prefs.getDouble('budget_${cat.$1}');
      if (v != null) budgets[cat.$1] = v;
    }

    try {
      final billsData = await _fetchBills(api);
      final txData    = await api.getHistory();

      final spending = <String, double>{};
      for (final b in billsData) {
        final cat = (b['category'] as String? ?? 'other').toLowerCase();
        final amt = double.tryParse(b['amount']?.toString() ?? '0') ?? 0;
        spending[cat] = (spending[cat] ?? 0) + amt;
      }

      // Transfers from wallet history
      final txList = List<dynamic>.from(txData['transactions'] as List? ?? []);
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 90));
      for (final t in txList) {
        final raw = t['createdAt'] as String?;
        if (raw == null) continue;
        final dt = DateTime.tryParse(raw);
        if (dt == null || dt.isBefore(cutoff)) continue;
        if (t['type'] == 'TRANSFER' && t['receiverWallet'] == null) {
          spending['transfer'] = (spending['transfer'] ?? 0) +
              (double.tryParse(t['amount']?.toString() ?? '0') ?? 0);
        }
      }

      if (mounted) {
        setState(() {
          _spending = spending;
          _budgets  = budgets;
          _loading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<dynamic>> _fetchBills(ApiService api) async {
    try {
      final res = await api.getHistory();
      final all = List<dynamic>.from(res['transactions'] as List? ?? []);
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 90));
      return all.where((t) {
        final raw = t['createdAt'] as String?;
        if (raw == null) return false;
        final dt = DateTime.tryParse(raw);
        if (dt == null || dt.isBefore(cutoff)) return false;
        final type = (t['type'] as String? ?? '').toUpperCase();
        return type == 'BILL' || type == 'AIRTIME' || type == 'DATA';
      }).toList();
    } catch (_) { return []; }
  }

  Future<void> _setBudget(String cat, String label) async {
    final current = _budgets[cat];
    final ctrl = TextEditingController(
        text: current != null ? current.toStringAsFixed(0) : '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.mc.surface,
        title: Text('Set $label Budget',
            style: TextStyle(color: context.mc.textPrimary)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            prefixText: '₦ ',
            hintText: 'Monthly limit',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final v = double.tryParse(ctrl.text.trim());
              final prefs = await SharedPreferences.getInstance();
              if (v != null && v > 0) {
                await prefs.setDouble('budget_$cat', v);
                setState(() => _budgets[cat] = v);
              } else {
                await prefs.remove('budget_$cat');
                setState(() => _budgets.remove(cat));
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(
        title: const Text('Financial Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAll,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Header ────────────────────────────────────
                  Text('Last 90 Days Spending',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                          color: context.mc.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Tap any category to set a monthly budget.',
                      style: TextStyle(fontSize: 12, color: context.mc.textHint)),
                  const SizedBox(height: 16),

                  // ── Category cards ────────────────────────────
                  ..._categories.map((cat) => _categoryCard(cat)),

                  const SizedBox(height: 20),

                  // ── Total ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.mc.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.mc.surfaceLine),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Spending (90d)',
                              style: TextStyle(fontSize: 12, color: context.mc.textHint)),
                          const SizedBox(height: 4),
                          Text(
                            '₦${_fmtAmt(_spending.values.fold(0.0, (a, b) => a + b))}',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                                color: MyrabaColors.red),
                          ),
                        ],
                      )),
                      const Icon(Icons.account_balance_wallet_rounded,
                          color: MyrabaColors.red, size: 32),
                    ]),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _categoryCard((String, String, IconData, Color) cat) {
    final key   = cat.$1;
    final label = cat.$2;
    final icon  = cat.$3;
    final color = cat.$4;
    final spent  = _spending[key] ?? 0;
    final budget = _budgets[key];
    final ratio  = budget != null && budget > 0 ? (spent / budget).clamp(0.0, 1.0) : null;
    final over   = budget != null && spent > budget;

    return GestureDetector(
      onTap: () => _setBudget(key, label),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.mc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: over ? MyrabaColors.red.withValues(alpha: 0.4) : context.mc.surfaceLine,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w600,
                    color: context.mc.textPrimary, fontSize: 13)),
                if (budget != null)
                  Text('Budget: ₦${_fmtAmt(budget)}',
                      style: TextStyle(fontSize: 11, color: context.mc.textHint)),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₦${_fmtAmt(spent)}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: over ? MyrabaColors.red : context.mc.textPrimary)),
              if (over)
                Text('Over budget!',
                    style: const TextStyle(fontSize: 10, color: MyrabaColors.red,
                        fontWeight: FontWeight.w600)),
            ]),
          ]),
          if (ratio != null && budget != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                backgroundColor: context.mc.surfaceLine,
                valueColor: AlwaysStoppedAnimation(
                    over ? MyrabaColors.red : color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              over
                  ? '₦${_fmtAmt(spent - budget)} over limit'
                  : '₦${_fmtAmt(budget - spent)} remaining',
              style: TextStyle(
                  fontSize: 10,
                  color: over ? MyrabaColors.red : context.mc.textHint),
            ),
          ],
          if (budget == null) ...[
            const SizedBox(height: 6),
            Text('Tap to set a budget limit',
                style: TextStyle(fontSize: 10, color: context.mc.textHint)),
          ],
        ]),
      ),
    );
  }

  String _fmtAmt(double v) => NumberFormat('#,##0.00', 'en_NG').format(v);
}
