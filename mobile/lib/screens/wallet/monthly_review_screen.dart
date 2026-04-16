import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class MonthlyReviewScreen extends StatefulWidget {
  const MonthlyReviewScreen({super.key});

  @override
  State<MonthlyReviewScreen> createState() => _MonthlyReviewScreenState();
}

class _MonthlyReviewScreenState extends State<MonthlyReviewScreen> {
  List<dynamic> _data = [];
  bool _loading = true;
  String? _error;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) return;
    try {
      final res = await ApiService(auth.token!).getMonthlyReview(months: 12);
      if (!mounted) return;
      setState(() {
        _data = (res['data'] as List?) ?? [];
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyrabaColors.bg,
      appBar: AppBar(
        backgroundColor: MyrabaColors.bg,
        title: const Text('Monthly Review', style: TextStyle(color: MyrabaColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: MyrabaColors.textPrimary),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: MyrabaColors.green))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: MyrabaColors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: MyrabaColors.green,
                  backgroundColor: MyrabaColors.surface,
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildContent() {
    if (_data.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Column(children: [
            Icon(Icons.bar_chart_rounded, color: MyrabaColors.textHint, size: 52),
            SizedBox(height: 12),
            Text('No transactions yet', style: TextStyle(color: MyrabaColors.textSecond, fontSize: 16, fontWeight: FontWeight.w500)),
            SizedBox(height: 6),
            Text('Your monthly review will appear here once you start transacting.',
              textAlign: TextAlign.center,
              style: TextStyle(color: MyrabaColors.textHint, fontSize: 13)),
          ])),
        ],
      );
    }

    // Last 6 months for bar chart, all 12 for summary
    final recent = _data.length > 6 ? _data.sublist(_data.length - 6) : _data;
    double totalIncome  = _data.fold(0, (s, d) => s + (double.tryParse(d['income']  ?? '0') ?? 0));
    double totalExpense = _data.fold(0, (s, d) => s + (double.tryParse(d['expense'] ?? '0') ?? 0));
    double maxVal = recent.fold(0.0, (m, d) {
      final inc = double.tryParse(d['income']  ?? '0') ?? 0;
      final exp = double.tryParse(d['expense'] ?? '0') ?? 0;
      return [m, inc, exp].reduce((a, b) => a > b ? a : b);
    });
    if (maxVal == 0) maxVal = 1000;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Summary cards
        Row(children: [
          Expanded(child: _summaryCard('Total Money In', totalIncome, MyrabaColors.green, Icons.arrow_downward_rounded)),
          const SizedBox(width: 12),
          Expanded(child: _summaryCard('Total Money Out', totalExpense, MyrabaColors.red, Icons.arrow_upward_rounded)),
        ]),
        const SizedBox(height: 24),

        // Bar chart title
        const Text('Last 6 Months', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: MyrabaColors.textSecond)),
        const SizedBox(height: 4),
        const Text('Income vs Expense', style: TextStyle(fontSize: 12, color: MyrabaColors.textHint)),
        const SizedBox(height: 16),

        // Bar chart
        Container(
          decoration: myrabaCard(),
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          height: 260,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.25,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final d = recent[group.x];
                    final label = rodIndex == 0 ? 'In' : 'Out';
                    final color = rodIndex == 0 ? MyrabaColors.green : MyrabaColors.red;
                    return BarTooltipItem(
                      '$label: ₦${_fmt(rod.toY)}',
                      TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
                    );
                  },
                ),
                touchCallback: (event, response) {
                  setState(() => _touchedIndex = response?.spot?.touchedBarGroupIndex ?? -1);
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (v, meta) => Text('₦${_shortFmt(v)}',
                    style: const TextStyle(fontSize: 10, color: MyrabaColors.textHint)),
                )),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= recent.length) return const SizedBox();
                    final label = (recent[i]['label'] as String?) ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(label, style: const TextStyle(fontSize: 9, color: MyrabaColors.textHint)),
                    );
                  },
                )),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFF3D3060), strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(recent.length, (i) {
                final inc = double.tryParse(recent[i]['income']  ?? '0') ?? 0;
                final exp = double.tryParse(recent[i]['expense'] ?? '0') ?? 0;
                final isTouched = i == _touchedIndex;
                return BarChartGroupData(
                  x: i,
                  groupVertically: false,
                  barRods: [
                    BarChartRodData(
                      toY: inc, width: 10,
                      color: isTouched ? MyrabaColors.green : MyrabaColors.green.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    BarChartRodData(
                      toY: exp, width: 10,
                      color: isTouched ? MyrabaColors.red : MyrabaColors.red.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),

        // Legend
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legend(MyrabaColors.green, 'Money In'),
          const SizedBox(width: 20),
          _legend(MyrabaColors.red, 'Money Out'),
        ]),

        const SizedBox(height: 28),

        // Monthly breakdown table
        const Text('Breakdown by Month', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: MyrabaColors.textSecond)),
        const SizedBox(height: 12),
        Container(
          decoration: myrabaCard(),
          child: Column(
            children: _data.reversed.take(12).toList().asMap().entries.map((e) {
              final isLast = e.key == (_data.length > 12 ? 11 : _data.length - 1);
              return _monthRow(e.value, !isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyrabaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: MyrabaColors.textHint)),
          ]),
          const SizedBox(height: 8),
          Text('₦${_fmt(value)}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _monthRow(Map<String, dynamic> d, bool divider) {
    final inc = double.tryParse(d['income']  ?? '0') ?? 0;
    final exp = double.tryParse(d['expense'] ?? '0') ?? 0;
    final net = inc - exp;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(child: Text(d['label'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: MyrabaColors.textPrimary))),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(children: [
                  const Icon(Icons.arrow_downward_rounded, size: 12, color: MyrabaColors.green),
                  const SizedBox(width: 3),
                  Text('₦${_fmt(inc)}', style: const TextStyle(fontSize: 12, color: MyrabaColors.green, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.arrow_upward_rounded, size: 12, color: MyrabaColors.red),
                  const SizedBox(width: 3),
                  Text('₦${_fmt(exp)}', style: const TextStyle(fontSize: 12, color: MyrabaColors.red, fontWeight: FontWeight.w600)),
                ]),
              ]),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (net >= 0 ? MyrabaColors.green : MyrabaColors.red).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${net >= 0 ? '+' : ''}₦${_fmt(net)}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: net >= 0 ? MyrabaColors.green : MyrabaColors.red)),
              ),
            ],
          ),
        ),
        if (divider) const Divider(height: 1, indent: 16, endIndent: 16, color: MyrabaColors.surfaceLine),
      ],
    );
  }

  Widget _legend(Color color, String label) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, color: MyrabaColors.textSecond)),
    ]);
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  String _shortFmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(0)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}
