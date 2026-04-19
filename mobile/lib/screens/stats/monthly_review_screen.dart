import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

// ── Neon palette per spending category ────────────────────────────────────
const _kCategoryColors = <String, Color>{
  'transfers':   Color(0xFFFF6B35),
  'thrift':      Color(0xFF00FF87),
  'gifts':       Color(0xFFFF3CAC),
  'airtime':     Color(0xFF00D4FF),
  'data':        Color(0xFF7B2FFF),
  'electricity': Color(0xFFFFD60A),
  'cable':       Color(0xFFFF9F1C),
  'betting':     Color(0xFFFF4444),
  'education':   Color(0xFF4FC3F7),
  'withdrawals': Color(0xFFAB47BC),
};

const _kCategoryIcons = <String, IconData>{
  'transfers':   Icons.swap_horiz_rounded,
  'thrift':      Icons.savings_rounded,
  'gifts':       Icons.card_giftcard_rounded,
  'airtime':     Icons.phone_android_rounded,
  'data':        Icons.wifi_rounded,
  'electricity': Icons.bolt_rounded,
  'cable':       Icons.tv_rounded,
  'betting':     Icons.sports_soccer_rounded,
  'education':   Icons.school_rounded,
  'withdrawals': Icons.account_balance_rounded,
};

class MonthlyReviewScreen extends StatefulWidget {
  const MonthlyReviewScreen({super.key});

  @override
  State<MonthlyReviewScreen> createState() => _MonthlyReviewScreenState();
}

class _MonthlyReviewScreenState extends State<MonthlyReviewScreen>
    with TickerProviderStateMixin {
  // ── Data ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _monthlyData = [];
  double _total = 0;
  bool _loading = true;
  String? _error;
  int _months = 3;
  int _touchedIndex = -1;

  // ── Animation ────────────────────────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _entranceAnim;
  late final Animation<double> _pulseAnim;

  final _nfmt = NumberFormat('#,##0', 'en_NG');

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    _entranceAnim =
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic);
    _pulseAnim =
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOutSine);
    _load();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _touchedIndex = -1;
    });
    _entranceCtrl.reset();

    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) return;
    final api = ApiService(auth.token!);

    try {
      final results = await Future.wait([
        api.getSpendingBreakdown(months: _months),
        api.getMonthlyReview(months: _months),
      ]);

      final breakdown = results[0];
      final review    = results[1];

      final rawCats = breakdown['categories'] as List<dynamic>? ?? [];
      final rawData = review['data'] as List<dynamic>? ?? [];

      setState(() {
        _categories  = rawCats.cast<Map<String, dynamic>>();
        _monthlyData = rawData.cast<Map<String, dynamic>>();
        _total       = double.tryParse(breakdown['total']?.toString() ?? '0') ?? 0;
        _loading     = false;
      });
      _entranceCtrl.forward();
    } catch (e) {
      setState(() {
        _error   = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  double _parse(dynamic v) =>
      v == null ? 0 : double.tryParse(v.toString()) ?? 0;

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(
        backgroundColor: context.mc.surface,
        title: Text('Financial Pulse',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.mc.textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.mc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<int>(
            color: context.mc.surface,
            icon: Icon(Icons.date_range_rounded, color: context.mc.textSecond),
            onSelected: (v) {
              setState(() => _months = v);
              _load();
            },
            itemBuilder: (_) => [
              _periodItem(1, '1 month'),
              _periodItem(3, '3 months'),
              _periodItem(6, '6 months'),
              _periodItem(12, '12 months'),
            ],
          ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: MyrabaColors.green,
                  backgroundColor: context.mc.surface,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 60),
                    children: [
                      _buildPeriodChips(),
                      const SizedBox(height: 28),
                      _buildHologramDonut(),
                      const SizedBox(height: 28),
                      _buildCategoryGrid(),
                      const SizedBox(height: 32),
                      _buildMonthlySection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: MyrabaColors.purple,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text('Loading pulse…',
              style: TextStyle(color: context.mc.textHint, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: context.mc.textHint),
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(color: context.mc.textHint, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  PopupMenuItem<int> _periodItem(int v, String label) => PopupMenuItem(
        value: v,
        child: Text(label,
            style: TextStyle(
                color: _months == v
                    ? MyrabaColors.purple
                    : context.mc.textPrimary)),
      );

  // ── Period chips ──────────────────────────────────────────────────────────
  Widget _buildPeriodChips() {
    final options = [1, 3, 6, 12];
    final labels  = ['1M', '3M', '6M', '12M'];
    return Row(
      children: List.generate(options.length, (i) {
        final active = _months == options[i];
        return Padding(
          padding: EdgeInsets.only(right: i < options.length - 1 ? 10 : 0),
          child: GestureDetector(
            onTap: () {
              if (_months != options[i]) {
                setState(() => _months = options[i]);
                _load();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? MyrabaColors.purple.withValues(alpha: 0.18)
                    : context.mc.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active
                        ? MyrabaColors.purple
                        : context.mc.surfaceLine),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? MyrabaColors.purple
                      : context.mc.textSecond,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Holographic donut ─────────────────────────────────────────────────────
  Widget _buildHologramDonut() {
    if (_categories.isEmpty) return _buildEmptyDonut();

    final selected = _touchedIndex >= 0 && _touchedIndex < _categories.length
        ? _categories[_touchedIndex] : null;
    final selectedLabel  = selected?['label']  as String? ?? 'Total Spent';
    final selectedAmount = selected != null ? _parse(selected['amount']) : _total;
    final selectedKey    = selected?['key'] as String? ?? '';
    final selectedColor  = _kCategoryColors[selectedKey] ?? const Color(0xFF7B2FFF);

    return AnimatedBuilder(
      animation: Listenable.merge([_entranceAnim, _pulseAnim]),
      builder: (_, __) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0A0118),
                  const Color(0xFF0D0320),
                  const Color(0xFF080014),
                ],
              ),
              border: Border.all(
                color: selectedColor.withValues(alpha: 0.35 + 0.15 * _pulseAnim.value),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: selectedColor.withValues(alpha: 0.25 + 0.1 * _pulseAnim.value),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                // ── Space grid background ───────────────────────────
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridPainter(
                      opacity: 0.06 * _entranceAnim.value,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 280,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // ── Outer glow rings ─────────────────────
                            CustomPaint(
                              size: const Size(280, 280),
                              painter: _GlowRingPainter(
                                color: selectedColor,
                                pulse: _pulseAnim.value,
                                entrance: _entranceAnim.value,
                              ),
                            ),

                            // ── Pie chart ────────────────────────────
                            PieChart(
                              PieChartData(
                                startDegreeOffset: -90,
                                centerSpaceRadius: 76,
                                sectionsSpace: 3,
                                pieTouchData: PieTouchData(
                                  touchCallback: (event, response) {
                                    if (!event.isInterestedForInteractions) return;
                                    setState(() {
                                      _touchedIndex = response
                                          ?.touchedSection
                                          ?.touchedSectionIndex ?? -1;
                                    });
                                  },
                                ),
                                sections: List.generate(_categories.length, (i) {
                                  final cat    = _categories[i];
                                  final key    = cat['key'] as String? ?? '';
                                  final amount = _parse(cat['amount']);
                                  final pct    = _total > 0 ? amount / _total : 0.0;
                                  final color  = _kCategoryColors[key] ?? const Color(0xFF7B2FFF);
                                  final isTouched = _touchedIndex == i;

                                  return PieChartSectionData(
                                    value: amount,
                                    color: color.withValues(alpha: isTouched ? 1.0 : 0.88),
                                    radius: isTouched
                                        ? 66 * _entranceAnim.value
                                        : 52 * _entranceAnim.value,
                                    title: pct > 0.07
                                        ? '${(pct * 100).toStringAsFixed(0)}%'
                                        : '',
                                    titleStyle: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      shadows: [Shadow(color: color, blurRadius: 8)],
                                    ),
                                    badgeWidget: isTouched
                                        ? Container(
                                            width: 10, height: 10,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                              boxShadow: [BoxShadow(
                                                color: color,
                                                blurRadius: 14,
                                                spreadRadius: 3,
                                              )],
                                            ),
                                          )
                                        : null,
                                    badgePositionPercentageOffset: 1.15,
                                  );
                                }),
                              ),
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                            ),

                            // ── Center hologram label ─────────────────
                            Opacity(
                              opacity: _entranceAnim.value,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (selectedKey.isNotEmpty) ...[
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: selectedColor.withValues(alpha: 0.15),
                                        border: Border.all(
                                          color: selectedColor.withValues(alpha: 0.4),
                                          width: 1,
                                        ),
                                        boxShadow: [BoxShadow(
                                          color: selectedColor.withValues(alpha: 0.4),
                                          blurRadius: 12,
                                        )],
                                      ),
                                      child: Icon(
                                        _kCategoryIcons[selectedKey] ?? Icons.category_rounded,
                                        color: selectedColor,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Text(
                                    selectedLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white.withValues(alpha: 0.5),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₦${_nfmt.format(selectedAmount)}',
                                    style: TextStyle(
                                      fontSize: selectedKey.isEmpty ? 18 : 15,
                                      fontWeight: FontWeight.w800,
                                      color: selectedKey.isEmpty
                                          ? Colors.white
                                          : selectedColor,
                                      shadows: [
                                        Shadow(
                                          color: selectedKey.isEmpty
                                              ? Colors.white.withValues(alpha: 0.3)
                                              : selectedColor.withValues(alpha: 0.6),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selectedKey.isEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'TOTAL SPENT',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white.withValues(alpha: 0.35),
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Scan line at bottom ─────────────────────────
                      Opacity(
                        opacity: _entranceAnim.value * 0.6,
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                selectedColor.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyDonut() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: context.mc.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.mc.surfaceLine),
      ),
      child: Column(
        children: [
          Icon(Icons.donut_large_rounded,
              size: 64, color: context.mc.textHint),
          const SizedBox(height: 16),
          Text('No spending data yet',
              style: TextStyle(
                  fontSize: 15, color: context.mc.textSecond)),
          const SizedBox(height: 6),
          Text('Make some transactions to see your pulse',
              style:
                  TextStyle(fontSize: 12, color: context.mc.textHint)),
        ],
      ),
    );
  }

  // ── Category grid ─────────────────────────────────────────────────────────
  Widget _buildCategoryGrid() {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Breakdown',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.mc.textPrimary)),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.5,
          ),
          itemCount: _categories.length,
          itemBuilder: (_, i) => _categoryTile(_categories[i], i),
        ),
      ],
    );
  }

  Widget _categoryTile(Map<String, dynamic> cat, int i) {
    final key    = cat['key'] as String? ?? '';
    final label  = cat['label'] as String? ?? key;
    final amount = _parse(cat['amount']);
    final color  = _kCategoryColors[key] ?? MyrabaColors.purple;
    final icon   = _kCategoryIcons[key] ?? Icons.category_rounded;
    final pct    = _total > 0 ? amount / _total : 0.0;
    final isTouched = _touchedIndex == i;

    return GestureDetector(
      onTap: () => setState(
          () => _touchedIndex = isTouched ? -1 : i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isTouched
              ? color.withValues(alpha: 0.12)
              : context.mc.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isTouched
                  ? color.withValues(alpha: 0.5)
                  : context.mc.surfaceLine),
          boxShadow: isTouched
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12)]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.mc.textSecond),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    '₦${_nfmt.format(amount)}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                ],
              ),
            ),
            Text(
              '${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Monthly breakdown ─────────────────────────────────────────────────────
  Widget _buildMonthlySection() {
    if (_monthlyData.isEmpty) return const SizedBox.shrink();

    // Calculate totals for summary
    double totalIncome  = 0;
    double totalExpense = 0;
    for (final d in _monthlyData) {
      totalIncome  += _parse(d['income']);
      totalExpense += _parse(d['expense']);
    }
    final net = totalIncome - totalExpense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Month by Month',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.mc.textPrimary)),
        const SizedBox(height: 14),
        // Summary row
        Row(
          children: [
            Expanded(
                child: _miniStat(
                    'In', totalIncome, MyrabaColors.teal,
                    MyrabaColors.tealGlow)),
            const SizedBox(width: 10),
            Expanded(
                child: _miniStat(
                    'Out', totalExpense, MyrabaColors.red,
                    MyrabaColors.red.withValues(alpha: 0.12))),
            const SizedBox(width: 10),
            Expanded(
                child: _miniStat(
                    'Net', net,
                    net >= 0 ? MyrabaColors.green : MyrabaColors.red,
                    net >= 0
                        ? MyrabaColors.greenGlow
                        : MyrabaColors.red.withValues(alpha: 0.12))),
          ],
        ),
        const SizedBox(height: 14),
        ...List.generate(_monthlyData.length, (i) {
          final d   = _monthlyData[_monthlyData.length - 1 - i];
          final inc = _parse(d['income']);
          final exp = _parse(d['expense']);
          final net = inc - exp;
          final netPos  = net >= 0;
          final label   = d['label'] as String? ?? '—';
          final total   = inc + exp;
          final incPct  = total == 0 ? 0.5 : inc / total;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
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
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: netPos
                              ? MyrabaColors.tealGlow
                              : MyrabaColors.red
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${netPos ? '+' : '−'}₦${_nfmt.format(net.abs())}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: netPos
                                  ? MyrabaColors.teal
                                  : MyrabaColors.red),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: (incPct * 1000).round().clamp(1, 999),
                          child: Container(
                              height: 5, color: MyrabaColors.teal),
                        ),
                        Expanded(
                          flex:
                              ((1 - incPct) * 1000).round().clamp(1, 999),
                          child: Container(
                              height: 5,
                              color: MyrabaColors.red
                                  .withValues(alpha: 0.75)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: _amountCell(
                              Icons.arrow_downward_rounded,
                              'Income',
                              inc,
                              MyrabaColors.teal)),
                      Expanded(
                          child: _amountCell(
                              Icons.arrow_upward_rounded,
                              'Expenses',
                              exp,
                              MyrabaColors.red)),
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

  Widget _miniStat(String label, double amount, Color color, Color glow) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: context.mc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: context.mc.textHint)),
          const SizedBox(height: 4),
          Text(
            '${label == 'Net' && amount < 0 ? '−' : ''}₦${_nfmt.format(amount.abs())}',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _amountCell(
      IconData icon, String label, double amount, Color color) {
    return Row(
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: context.mc.textHint)),
            Text('₦${_nfmt.format(amount)}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ],
    );
  }
}

// ── Space grid background painter ─────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final double opacity;
  _GridPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7B2FFF).withValues(alpha: opacity)
      ..strokeWidth = 0.5;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.opacity != opacity;
}

// ── Glow ring painter (hologram effect) ───────────────────────────────────────
class _GlowRingPainter extends CustomPainter {
  final Color color;
  final double pulse;
  final double entrance;

  _GlowRingPainter({
    required this.color,
    required this.pulse,
    required this.entrance,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseRadius = math.min(cx, cy) * 0.68;

    // Outer ambient glow — large diffuse halo
    canvas.drawCircle(
      Offset(cx, cy),
      baseRadius * 1.15,
      Paint()
        ..color = color.withValues(alpha: (0.18 + 0.08 * pulse) * entrance)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48),
    );

    // Three concentric rings with strong glow
    final ringData = [
      (baseRadius,        0.45 + 0.12 * pulse, 22.0),  // inner — brightest, pulses
      (baseRadius + 18,   0.22,                 14.0),  // mid
      (baseRadius + 34,   0.12,                 10.0),  // outer — subtle
    ];

    for (final (radius, alpha, blur) in ringData) {
      final a = (alpha * entrance).clamp(0.0, 1.0);
      if (a <= 0) continue;
      // Glow halo
      canvas.drawCircle(
        Offset(cx, cy), radius,
        Paint()
          ..color = color.withValues(alpha: a * 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 2),
      );
      // Crisp ring line on top
      canvas.drawCircle(
        Offset(cx, cy), radius,
        Paint()
          ..color = color.withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 0.4),
      );
    }

    // Center radial glow
    canvas.drawCircle(
      Offset(cx, cy),
      baseRadius * 0.58,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: (0.10 + 0.06 * pulse) * entrance),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
            center: Offset(cx, cy), radius: baseRadius * 0.58)),
    );
  }

  @override
  bool shouldRepaint(_GlowRingPainter old) =>
      old.pulse != pulse || old.entrance != entrance || old.color != color;
}
