import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class MonthlyReviewScreen extends StatefulWidget {
  const MonthlyReviewScreen({super.key});

  @override
  State<MonthlyReviewScreen> createState() => _MonthlyReviewScreenState();
}

class _MonthlyReviewScreenState extends State<MonthlyReviewScreen> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;
  String? _error;
  int _months = 6;
  int? _touchedIndex;

  final _nfmt = NumberFormat('#,##0', 'en_NG');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _touchedIndex = null;
    });
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) return;
    try {
      final result =
          await ApiService(auth.token!).getMonthlyReview(months: _months);
      final raw = result['data'] as List<dynamic>? ?? [];
      setState(() {
        _data = raw.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  double _parse(dynamic v) =>
      v == null ? 0 : double.tryParse(v.toString()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(
        backgroundColor: context.mc.surface,
        title: Text('Monthly Review',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.mc.textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: context.mc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<int>(
            color: context.mc.surface,
            icon: Icon(Icons.date_range_rounded,
                color: context.mc.textSecond),
            onSelected: (v) {
              setState(() => _months = v);
              _load();
            },
            itemBuilder: (_) => [
              _periodItem(3, '3 months'),
              _periodItem(6, '6 months'),
              _periodItem(12, '12 months'),
            ],
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: MyrabaColors.green))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: MyrabaColors.green,
                  backgroundColor: context.mc.surface,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 28),
                      _buildBarChart(),
                      const SizedBox(height: 28),
                      _buildMonthList(),
                    ],
                  ),
                ),
    );
  }

  PopupMenuItem<int> _periodItem(int v, String label) => PopupMenuItem(
        value: v,
        child: Text(label,
            style: TextStyle(
                color: _months == v
                    ? MyrabaColors.green
                    : context.mc.textPrimary)),
      );

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 48, color: context.mc.textHint),
          SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(
                  color: context.mc.textHint, fontSize: 13)),
          SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    double totalIncome = 0;
    double totalExpense = 0;
    for (final d in _data) {
      totalIncome += _parse(d['income']);
      totalExpense += _parse(d['expense']);
    }
    final net = totalIncome - totalExpense;
    final netPositive = net >= 0;

    return Row(
      children: [
        Expanded(
            child: _summaryCard(
          'Total In',
          '₦${_nfmt.format(totalIncome)}',
          Icons.arrow_downward_rounded,
          MyrabaColors.teal,
          MyrabaColors.tealGlow,
        )),
        const SizedBox(width: 12),
        Expanded(
            child: _summaryCard(
          'Total Out',
          '₦${_nfmt.format(totalExpense)}',
          Icons.arrow_upward_rounded,
          MyrabaColors.red,
          MyrabaColors.red.withValues(alpha: 0.12),
        )),
        const SizedBox(width: 12),
        Expanded(
            child: _summaryCard(
          'Net',
          '${netPositive ? '+' : ''}₦${_nfmt.format(net.abs())}',
          netPositive
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          netPositive ? MyrabaColors.green : MyrabaColors.red,
          netPositive
              ? MyrabaColors.greenGlow
              : MyrabaColors.red.withValues(alpha: 0.12),
        )),
      ],
    );
  }

  Widget _summaryCard(
      String label, String value, IconData icon, Color color, Color glow) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: context.mc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: glow, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          SizedBox(height: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: context.mc.textHint)),
          SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    if (_data.isEmpty) {
      return _emptyState('No transactions yet in this period.');
    }

    final maxVal = _data.fold<double>(0, (m, d) {
      final inc = _parse(d['income']);
      final exp = _parse(d['expense']);
      return [m, inc, exp].reduce((a, b) => a > b ? a : b);
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: context.mc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.mc.surfaceLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Income vs Expenses',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.mc.textPrimary)),
          SizedBox(height: 6),
          Row(
            children: [
              _legend(MyrabaColors.teal, 'Income'),
              const SizedBox(width: 16),
              _legend(MyrabaColors.red, 'Expenses'),
            ],
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.25 == 0 ? 1000 : maxVal * 1.25,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => context.mc.surfaceHigh,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 6,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final d = _data[groupIndex];
                      final isIncome = rodIndex == 0;
                      final label = isIncome ? 'In' : 'Out';
                      final amount = isIncome ? d['income'] : d['expense'];
                      return BarTooltipItem(
                        '$label ₦${_nfmt.format(_parse(amount))}',
                        TextStyle(
                          color: isIncome ? MyrabaColors.teal : MyrabaColors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                  touchCallback: (event, response) {
                    setState(() {
                      _touchedIndex =
                          response?.spot?.touchedBarGroupIndex;
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= _data.length) {
                          return const SizedBox.shrink();
                        }
                        final label = _data[idx]['label'] as String? ?? '';
                        final parts = label.split(' ');
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(parts.isNotEmpty ? parts[0] : '',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: context.mc.textHint)),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, meta) {
                        if (v == 0) {
                          return Text('0',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: context.mc.textHint));
                        }
                        final formatted = v >= 1000000
                            ? '${(v / 1000000).toStringAsFixed(1)}M'
                            : v >= 1000
                                ? '${(v / 1000).toStringAsFixed(0)}K'
                                : v.toStringAsFixed(0);
                        return Text(formatted,
                            style: TextStyle(
                                fontSize: 9,
                                color: context.mc.textHint));
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: context.mc.surfaceLine,
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(_data.length, (i) {
                  final d = _data[i];
                  final inc = _parse(d['income']);
                  final exp = _parse(d['expense']);
                  final isTouched = _touchedIndex == i;
                  return BarChartGroupData(
                    x: i,
                    groupVertically: false,
                    barRods: [
                      BarChartRodData(
                        toY: inc,
                        width: isTouched ? 10 : 8,
                        color: MyrabaColors.teal.withValues(
                            alpha: isTouched ? 1.0 : 0.85),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: exp,
                        width: isTouched ? 10 : 8,
                        color: MyrabaColors.red.withValues(
                            alpha: isTouched ? 1.0 : 0.85),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: context.mc.textSecond)),
      ],
    );
  }

  Widget _buildMonthList() {
    if (_data.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Breakdown by Month',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.mc.textPrimary)),
        SizedBox(height: 12),
        ...List.generate(_data.length, (i) {
          // Show latest month first
          final d = _data[_data.length - 1 - i];
          final inc = _parse(d['income']);
          final exp = _parse(d['expense']);
          final net = inc - exp;
          final netPos = net >= 0;
          final label = d['label'] as String? ?? '—';

          // Calculate bar width proportions
          final total = inc + exp;
          final incPct = total == 0 ? 0.5 : inc / total;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.mc.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.mc.surfaceLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.mc.textPrimary)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: netPos
                              ? MyrabaColors.tealGlow
                              : MyrabaColors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${netPos ? '+' : '−'}₦${_nfmt.format(net.abs())}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: netPos ? MyrabaColors.teal : MyrabaColors.red),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Split bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: (incPct * 1000).round().clamp(1, 999),
                          child: Container(
                            height: 6,
                            color: MyrabaColors.teal,
                          ),
                        ),
                        Expanded(
                          flex: ((1 - incPct) * 1000).round().clamp(1, 999),
                          child: Container(
                            height: 6,
                            color: MyrabaColors.red.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _amountCell(Icons.arrow_downward_rounded,
                            'Income', inc, MyrabaColors.teal),
                      ),
                      Expanded(
                        child: _amountCell(Icons.arrow_upward_rounded,
                            'Expenses', exp, MyrabaColors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _amountCell(IconData icon, String label, double amount, Color color) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: context.mc.textHint)),
            Text('₦${_nfmt.format(amount)}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ],
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 48, color: context.mc.textHint),
            SizedBox(height: 12),
            Text(msg,
                style: TextStyle(
                    color: context.mc.textHint, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
