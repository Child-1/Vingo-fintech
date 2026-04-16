import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../stats/monthly_review_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<dynamic> _transactions = [];
  bool _loading = true;
  String? _error;

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
      final res = await api.getHistory();
      if (!mounted) return;
      setState(() {
        _transactions = (res['transactions'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load transactions';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(
            tooltip: 'Monthly Review',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MonthlyReviewScreen())),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: MyrabaColors.green))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: TextStyle(color: MyrabaColors.red)))
              : _transactions.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: MyrabaColors.green,
                      backgroundColor: context.mc.surface,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _txCard(_transactions[i] as Map<String, dynamic>),
                      ),
                    ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              color: context.mc.textHint, size: 64),
          SizedBox(height: 16),
          Text('No transactions yet',
              style: TextStyle(fontSize: 16, color: context.mc.textSecond)),
          SizedBox(height: 8),
          Text('Your transaction history will appear here',
              style: TextStyle(fontSize: 13, color: context.mc.textHint)),
        ],
      ),
    );
  }

  Widget _txCard(Map<String, dynamic> tx) {
    final type = tx['type'] as String? ?? 'TRANSFER';
    final isSent =
        type == 'SENT' || type == 'WITHDRAWAL' || type == 'CONTRIBUTION';
    final color = isSent ? MyrabaColors.red : MyrabaColors.teal;
    final sign = isSent ? '-' : '+';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.mc.card(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_txIcon(type), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx['description'] ?? type,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.mc.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: 4),
                Text(_formatDate(tx['date'] as String?),
                    style: TextStyle(
                        fontSize: 12, color: context.mc.textHint)),
                if (tx['reference'] != null) ...[
                  SizedBox(height: 2),
                  Text('Ref: ${tx['reference']}',
                      style: TextStyle(
                          fontSize: 11, color: context.mc.textHint)),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$sign₦${tx['amount']}',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(tx['status']).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  (tx['status'] as String? ?? 'SUCCESS').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(tx['status']),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _txIcon(String type) {
    switch (type) {
      case 'SENT':
        return Icons.arrow_upward_rounded;
      case 'RECEIVED':
        return Icons.arrow_downward_rounded;
      case 'FUNDED':
        return Icons.add_rounded;
      case 'CONTRIBUTION':
        return Icons.savings_rounded;
      case 'PAYOUT':
        return Icons.celebration_rounded;
      case 'PENALTY':
        return Icons.warning_amber_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  Color _statusColor(dynamic status) {
    switch ((status as String? ?? '').toUpperCase()) {
      case 'SUCCESS':
        return MyrabaColors.teal;
      case 'FAILED':
        return MyrabaColors.red;
      case 'PENDING':
        return MyrabaColors.gold;
      default:
        return context.mc.textSecond;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${_pad(dt.hour)}:${_pad(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
