import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class SavingsGoalsTab extends StatefulWidget {
  const SavingsGoalsTab({super.key});

  @override
  State<SavingsGoalsTab> createState() => _SavingsGoalsTabState();
}

class _SavingsGoalsTabState extends State<SavingsGoalsTab> {
  List<Map<String, dynamic>> _goals = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final api  = ApiService(auth.token!);
    try {
      final res = await api.getSavingsGoals();
      if (!mounted) return;
      setState(() {
        _goals = List<Map<String, dynamic>>.from(res['goals'] as List? ?? []);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _loading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
            ? _emptyState()
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _goals.length,
                  itemBuilder: (_, i) => _goalCard(_goals[i]),
                ),
              ),
        Positioned(
          bottom: 16, right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'goal_fab',
            onPressed: () => _showCreateSheet(),
            backgroundColor: MyrabaColors.green,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('New Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.flag_rounded, size: 52, color: context.mc.textHint),
        const SizedBox(height: 16),
        Text('No savings goals yet.',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.mc.textPrimary)),
        const SizedBox(height: 8),
        Text('Create a goal, set a target date, and let the system automatically save for you.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: context.mc.textSecond, height: 1.5)),
      ]),
    ),
  );

  Widget _goalCard(Map<String, dynamic> g) {
    final status   = g['status'] as String? ?? 'ACTIVE';
    final saved    = double.tryParse(g['savedAmount'].toString()) ?? 0;
    final target   = double.tryParse(g['targetAmount'].toString()) ?? 1;
    final progress = double.tryParse(g['progressPercent'].toString()) ?? 0;
    final days     = g['daysRemaining'] as int? ?? 0;
    final isActive = status == 'ACTIVE';
    final isDone   = status == 'COMPLETED';

    Color statusColor = isActive ? MyrabaColors.green : isDone ? MyrabaColors.teal : context.mc.textHint;

    return GestureDetector(
      onTap: () => _openDetail(g),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.mc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.mc.surfaceLine),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(g['name'] as String? ?? 'Goal',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.mc.textPrimary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ]),
          if ((g['description'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(g['description'] as String,
              style: TextStyle(fontSize: 12, color: context.mc.textHint), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (progress / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: context.mc.surfaceLine,
              valueColor: AlwaysStoppedAnimation(isDone ? MyrabaColors.teal : MyrabaColors.green),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Text('₦${_fmt(saved)} saved',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.mc.textPrimary)),
            const Spacer(),
            Text('₦${_fmt(target)} goal  •  ${progress.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, color: context.mc.textHint)),
          ]),
          if (isActive) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 13, color: context.mc.textHint),
              const SizedBox(width: 4),
              Text('$days day${days == 1 ? '' : 's'} remaining',
                style: TextStyle(fontSize: 12, color: context.mc.textHint)),
              if (g['autoDeductFrequency'] != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.repeat_rounded, size: 13, color: MyrabaColors.green),
                const SizedBox(width: 4),
                Text('₦${_fmt(double.tryParse(g['autoDeductAmount']?.toString() ?? '0') ?? 0)} ${(g['autoDeductFrequency'] as String).toLowerCase()}',
                  style: const TextStyle(fontSize: 12, color: MyrabaColors.green, fontWeight: FontWeight.w600)),
              ],
            ]),
          ],
        ]),
      ),
    );
  }

  Future<void> _openDetail(Map<String, dynamic> goal) async {
    await Navigator.push(context,
      MaterialPageRoute(builder: (_) => SavingsGoalDetailScreen(goal: goal, onRefresh: _load)));
  }

  Future<void> _showCreateSheet() async {
    final nameCtrl  = TextEditingController();
    final descCtrl  = TextEditingController();
    final amtCtrl   = TextEditingController();
    final initCtrl  = TextEditingController();
    final dedCtrl   = TextEditingController();
    DateTime? targetDate;
    String frequency = 'WEEKLY';
    bool autoDeduct = false;

    // Calculator state
    String calcResult = '';

    void recalc(StateSetter setSt) {
      final target = double.tryParse(amtCtrl.text.trim());
      if (target == null || target <= 0 || targetDate == null) { setSt(() => calcResult = ''); return; }
      final days = targetDate!.difference(DateTime.now()).inDays.clamp(1, 99999);
      final periods = frequency == 'DAILY' ? days : frequency == 'WEEKLY' ? (days / 7).ceil() : (days / 30).ceil();
      final per = target / periods;
      setSt(() => calcResult =
        'To save ₦${_fmt(target)} in ${_fmtPeriod(periods, frequency)}, you need ₦${_fmt(per)} / ${frequency.toLowerCase()}.');
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.mc.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => DraggableScrollableSheet(
          initialChildSize: 0.9, minChildSize: 0.6, maxChildSize: 0.95, expand: false,
          builder: (_, ctrl) => ListView(
            controller: ctrl,
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: ctx.mc.surfaceLine, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('New Savings Goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ctx.mc.textPrimary)),
              const SizedBox(height: 6),
              Text('Set a target, pick a date, and save automatically.', style: TextStyle(fontSize: 13, color: ctx.mc.textSecond)),
              const SizedBox(height: 24),

              _label('Goal Name', ctx),
              TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'e.g. New iPhone, Holiday 2025')),
              const SizedBox(height: 16),

              _label('Description (optional)', ctx),
              TextField(controller: descCtrl, decoration: const InputDecoration(hintText: 'What are you saving for?')),
              const SizedBox(height: 16),

              _label('Target Amount (₦)', ctx),
              TextField(
                controller: amtCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: '₦ ', hintText: '0.00'),
                onChanged: (_) => recalc(setSt),
              ),
              const SizedBox(height: 16),

              _label('Target Date', ctx),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (d != null) { setSt(() => targetDate = d); recalc(setSt); }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: ctx.mc.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ctx.mc.surfaceLine),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_rounded, size: 16, color: ctx.mc.textHint),
                    const SizedBox(width: 10),
                    Text(targetDate != null
                      ? DateFormat('dd MMM yyyy').format(targetDate!)
                      : 'Select a date',
                      style: TextStyle(color: targetDate != null ? ctx.mc.textPrimary : ctx.mc.textHint, fontSize: 14)),
                  ]),
                ),
              ),

              // Calculator hint
              if (calcResult.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MyrabaColors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: MyrabaColors.green.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calculate_rounded, size: 16, color: MyrabaColors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(calcResult,
                      style: const TextStyle(fontSize: 12, color: MyrabaColors.green, height: 1.4))),
                  ]),
                ),
              ],

              const SizedBox(height: 16),

              _label('Initial Deposit (optional)', ctx),
              TextField(
                controller: initCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: '₦ ', hintText: 'Amount to lock now'),
              ),
              const SizedBox(height: 20),

              // Auto-deduction toggle
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Auto-deduction', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ctx.mc.textPrimary)),
                  Text('Automatically save from your wallet on a schedule.',
                    style: TextStyle(fontSize: 11, color: ctx.mc.textHint)),
                ])),
                Switch(
                  value: autoDeduct,
                  onChanged: (v) => setSt(() => autoDeduct = v),
                  activeColor: MyrabaColors.green,
                ),
              ]),

              if (autoDeduct) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('Amount (₦)', ctx),
                      TextField(
                        controller: dedCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(prefixText: '₦ ', hintText: '1000'),
                        onChanged: (_) => recalc(setSt),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('Frequency', ctx),
                      DropdownButtonFormField<String>(
                        value: frequency,
                        dropdownColor: ctx.mc.surface,
                        decoration: InputDecoration(filled: true, fillColor: ctx.mc.bg),
                        items: ['DAILY','WEEKLY','MONTHLY'].map((f) => DropdownMenuItem(
                          value: f, child: Text(f.toLowerCase(), style: TextStyle(color: ctx.mc.textPrimary)))).toList(),
                        onChanged: (v) { if (v != null) { setSt(() => frequency = v); recalc(setSt); } },
                      ),
                    ]),
                  ),
                ]),
              ],

              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a goal name')));
                    return;
                  }
                  final target = double.tryParse(amtCtrl.text.trim());
                  if (target == null || target < 500) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Minimum goal amount is ₦500')));
                    return;
                  }
                  if (targetDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a target date')));
                    return;
                  }
                  final auth = Provider.of<AuthService>(context, listen: false);
                  final api  = ApiService(auth.token!);
                  try {
                    await api.createSavingsGoal(
                      name: nameCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                      targetAmount: target,
                      targetDate: targetDate!,
                      initialAmount: double.tryParse(initCtrl.text.trim()),
                      autoDeductAmount: autoDeduct ? double.tryParse(dedCtrl.text.trim()) : null,
                      autoDeductFrequency: autoDeduct ? frequency : null,
                    );
                    if (mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyrabaColors.green,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );

    nameCtrl.dispose(); descCtrl.dispose(); amtCtrl.dispose();
    initCtrl.dispose(); dedCtrl.dispose();
    if (result == true) _load();
  }

  static Widget _label(String t, BuildContext ctx) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: TextStyle(fontSize: 12, color: ctx.mc.textSecond, fontWeight: FontWeight.w500)),
  );

  static String _fmtPeriod(int n, String freq) {
    final unit = freq == 'DAILY' ? 'day' : freq == 'WEEKLY' ? 'week' : 'month';
    return '$n ${unit}${n == 1 ? '' : 's'}';
  }

  String _fmt(double v) => NumberFormat('#,##0.00', 'en_NG').format(v);
}

// ─── Goal Detail Screen ───────────────────────────────────────────────────────

class SavingsGoalDetailScreen extends StatefulWidget {
  final Map<String, dynamic> goal;
  final VoidCallback onRefresh;
  const SavingsGoalDetailScreen({super.key, required this.goal, required this.onRefresh});

  @override
  State<SavingsGoalDetailScreen> createState() => _SavingsGoalDetailScreenState();
}

class _SavingsGoalDetailScreenState extends State<SavingsGoalDetailScreen> {
  late Map<String, dynamic> _goal;

  @override
  void initState() { super.initState(); _goal = widget.goal; }

  Future<void> _topup() async {
    final ctrl = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.mc.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: ctx.mc.surfaceLine, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Add to Goal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ctx.mc.textPrimary)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(prefixText: '₦ ', hintText: '0.00'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(ctrl.text.trim());
              if (amt == null || amt <= 0) return;
              final auth = Provider.of<AuthService>(context, listen: false);
              final api  = ApiService(auth.token!);
              try {
                final res = await api.topupSavingsGoal(_goal['id'] as int, amt);
                if (mounted) { setState(() => _goal = Map<String, dynamic>.from(res)); Navigator.pop(ctx, true); }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: MyrabaColors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Add to Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
    ctrl.dispose();
    if (result == true) widget.onRefresh();
  }

  Future<void> _breakGoal() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final api  = ApiService(auth.token!);
    final id   = _goal['id'] as int;

    Map<String, dynamic> preview;
    try {
      preview = await api.getSavingsGoalBreakPreview(id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      return;
    }
    if (!mounted) return;

    final saved       = _fmtN(preview['savedAmount']);
    final warnPenalty = _fmtN(preview['warningPenalty']);
    final warnReturn  = _fmtN(preview['warningReturn']);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.mc.surface,
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: MyrabaColors.red, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text('Break "${_goal['name']}"?',
            style: TextStyle(color: context.mc.textPrimary, fontSize: 15), maxLines: 2)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Breaking your goal early will cost you a penalty.',
            style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
          const SizedBox(height: 16),
          _row('Total saved', '₦$saved', context.mc.textPrimary),
          const SizedBox(height: 6),
          _row('Penalty (25%)', '- ₦$warnPenalty', MyrabaColors.red),
          Divider(height: 20, color: context.mc.surfaceLine),
          _row('You receive', '₦$warnReturn', MyrabaColors.red, bold: true),
          const SizedBox(height: 12),
          Text('Think carefully. This money was set aside for: ${_goal['name']}',
            style: TextStyle(fontSize: 11, color: context.mc.textHint, fontStyle: FontStyle.italic)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep saving', style: TextStyle(color: MyrabaColors.green, fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Break it', style: TextStyle(color: MyrabaColors.red))),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final res = await api.breakSavingsGoal(id);
      if (!mounted) return;
      widget.onRefresh();
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.mc.surface,
          title: const Row(children: [
            Text('🙏', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Mercy Applied', style: TextStyle(color: MyrabaColors.green, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          content: Text(res['message'] as String? ?? 'Funds returned.',
            style: TextStyle(fontSize: 13, color: context.mc.textSecond, height: 1.5)),
          actions: [ElevatedButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text('Understood'))],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    }
  }

  Future<void> _completeGoal() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final api  = ApiService(auth.token!);
    try {
      final res = await api.completeSavingsGoal(_goal['id'] as int);
      if (!mounted) return;
      widget.onRefresh();
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.mc.surface,
          title: const Row(children: [Text('🎉', style: TextStyle(fontSize: 22)), SizedBox(width: 8),
            Text('Goal Completed!', style: TextStyle(color: MyrabaColors.green, fontSize: 15, fontWeight: FontWeight.w700))]),
          content: Text(res['message'] as String? ?? 'Funds released!',
            style: TextStyle(fontSize: 13, color: context.mc.textSecond, height: 1.5)),
          actions: [ElevatedButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text('Great!'))],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final g       = _goal;
    final saved   = double.tryParse(g['savedAmount'].toString()) ?? 0;
    final target  = double.tryParse(g['targetAmount'].toString()) ?? 1;
    final pct     = double.tryParse(g['progressPercent'].toString()) ?? 0;
    final days    = g['daysRemaining'] as int? ?? 0;
    final status  = g['status'] as String? ?? 'ACTIVE';
    final isActive = status == 'ACTIVE';
    final isComplete = status == 'COMPLETED';
    final targetDateStr = g['targetDate'] as String? ?? '';
    DateTime? targetDate;
    try { targetDate = DateTime.parse(targetDateStr); } catch (_) {}

    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(title: Text(g['name'] as String? ?? 'Goal')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Progress hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [MyrabaColors.green.withValues(alpha: 0.15), MyrabaColors.green.withValues(alpha: 0.03)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MyrabaColors.green.withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('₦${_fmtD(saved)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: context.mc.textPrimary)),
                Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: MyrabaColors.green)),
              ]),
              const SizedBox(height: 4),
              Text('of ₦${_fmtD(target)} goal', style: TextStyle(fontSize: 13, color: context.mc.textHint)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: context.mc.surfaceLine,
                  valueColor: const AlwaysStoppedAnimation(MyrabaColors.green),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: context.mc.textHint),
                const SizedBox(width: 6),
                Text(targetDate != null ? 'Target: ${DateFormat('dd MMM yyyy').format(targetDate)}' : '',
                  style: TextStyle(fontSize: 12, color: context.mc.textHint)),
                if (isActive) ...[
                  const Spacer(),
                  Text('$days day${days == 1 ? '' : 's'} left',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MyrabaColors.green)),
                ],
              ]),
            ]),
          ),

          const SizedBox(height: 16),

          // Auto-deduction info
          if (g['autoDeductFrequency'] != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.mc.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.mc.surfaceLine),
              ),
              child: Row(children: [
                const Icon(Icons.repeat_rounded, color: MyrabaColors.green, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Auto-deduction active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.mc.textPrimary)),
                  Text('₦${_fmtD(double.tryParse(g['autoDeductAmount']?.toString() ?? '0') ?? 0)} every ${(g['autoDeductFrequency'] as String).toLowerCase()}',
                    style: TextStyle(fontSize: 12, color: context.mc.textHint)),
                  if (g['nextDeductDate'] != null)
                    Text('Next: ${g['nextDeductDate']}', style: TextStyle(fontSize: 11, color: context.mc.textHint)),
                ])),
              ]),
            ),

          const SizedBox(height: 20),

          // Actions
          if (isActive) ...[
            ElevatedButton.icon(
              onPressed: _topup,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Money'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MyrabaColors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            if (targetDate != null && !DateTime.now().isBefore(targetDate))
              ElevatedButton.icon(
                onPressed: _completeGoal,
                icon: const Icon(Icons.celebration_rounded, size: 18),
                label: const Text('Release Funds 🎉'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyrabaColors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            if (targetDate == null || DateTime.now().isBefore(targetDate)) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: saved > 0 ? _breakGoal : null,
                icon: const Icon(Icons.lock_open_rounded, size: 16, color: MyrabaColors.red),
                label: const Text('Break Goal Early', style: TextStyle(color: MyrabaColors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: MyrabaColors.red, width: 0.8),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],

          if (isComplete)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MyrabaColors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MyrabaColors.green.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Text('🎉', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Goal Completed!', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MyrabaColors.green)),
                  Text('This goal has been completed and funds released to your wallet.',
                    style: TextStyle(fontSize: 12, color: context.mc.textHint)),
                ])),
              ]),
            ),
        ],
      ),
    );
  }

  static Widget _row(String label, String value, Color valueColor, {bool bold = false}) =>
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13)),
      Text(value, style: TextStyle(fontSize: 13, color: valueColor, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
    ]);

  String _fmtN(dynamic v) => NumberFormat('#,##0.00', 'en_NG').format(double.tryParse(v.toString()) ?? 0);
  String _fmtD(double v)   => NumberFormat('#,##0.00', 'en_NG').format(v);
}
