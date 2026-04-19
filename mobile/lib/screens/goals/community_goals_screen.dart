import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'goal_detail_screen.dart';

class CommunityGoalsScreen extends StatefulWidget {
  const CommunityGoalsScreen({super.key});

  @override
  State<CommunityGoalsScreen> createState() => _CommunityGoalsScreenState();
}

class _CommunityGoalsScreenState extends State<CommunityGoalsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _myGoals      = [];
  List<Map<String, dynamic>> _backingGoals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final api  = ApiService(auth.token!);
    try {
      final results = await Future.wait([api.getMyGoals(), api.getGoalsIBack()]);
      if (!mounted) return;
      setState(() {
        _myGoals      = List<Map<String, dynamic>>.from(results[0]['goals'] as List? ?? []);
        _backingGoals = List<Map<String, dynamic>>.from(results[1]['goals'] as List? ?? []);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createGoal() async {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    final amtCtrl   = TextEditingController();
    final codeCtrl  = TextEditingController();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.mc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
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
              Text('Create Community Goal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                  color: ctx.mc.textPrimary)),
              const SizedBox(height: 20),
              Text('Title', style: TextStyle(fontSize: 13, color: ctx.mc.textSecond)),
              const SizedBox(height: 8),
              TextField(controller: titleCtrl,
                decoration: const InputDecoration(hintText: 'e.g. Church Generator Fund')),
              const SizedBox(height: 16),
              Text('Description', style: TextStyle(fontSize: 13, color: ctx.mc.textSecond)),
              const SizedBox(height: 8),
              TextField(controller: descCtrl, maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Tell contributors what this is for…')),
              const SizedBox(height: 16),
              Text('Target Amount (₦)', style: TextStyle(fontSize: 13, color: ctx.mc.textSecond)),
              const SizedBox(height: 8),
              TextField(
                controller: amtCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: '0.00', prefixText: '₦ ',
                  prefixStyle: TextStyle(color: MyrabaColors.gold, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  final desc  = descCtrl.text.trim();
                  final amt   = double.tryParse(amtCtrl.text.trim());
                  if (title.isEmpty || desc.isEmpty || amt == null || amt < 500) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fill in all fields. Minimum goal: ₦500')));
                    return;
                  }
                  final auth = Provider.of<AuthService>(context, listen: false);
                  final api  = ApiService(auth.token!);
                  try {
                    await api.createGoal({'title': title, 'description': desc, 'targetAmount': amt});
                    if (context.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
                  }
                },
                child: const Text('Create Goal'),
              ),
            ],
          ),
        ),
      ),
    );
    titleCtrl.dispose(); descCtrl.dispose(); amtCtrl.dispose(); codeCtrl.dispose();
    if (result == true) _load();
  }

  Future<void> _enterCode() async {
    final codeCtrl = TextEditingController();
    await showModalBottomSheet(
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
            Text('Enter Goal Code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: ctx.mc.textPrimary)),
            const SizedBox(height: 8),
            Text('Enter the 8-character code shared by the goal creator.',
              style: TextStyle(fontSize: 13, color: ctx.mc.textSecond)),
            const SizedBox(height: 20),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'e.g. AB3K7XPQ',
                prefixIcon: Icon(Icons.tag_rounded, color: ctx.mc.textHint)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final code = codeCtrl.text.trim().toUpperCase();
                if (code.length != 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid 8-character code')));
                  return;
                }
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => GoalDetailScreen(inviteCode: code)));
              },
              child: const Text('Find Goal'),
            ),
          ],
        ),
      ),
    );
    codeCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(
        title: const Text('Community Goals'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'My Goals'), Tab(text: 'Backing')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Enter code',
            onPressed: _enterCode,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGoal,
        backgroundColor: MyrabaColors.green,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabs,
            children: [
              _buildGoalList(_myGoals, isCreator: true),
              _buildGoalList(_backingGoals, isCreator: false),
            ],
          ),
    );
  }

  Widget _buildGoalList(List<Map<String, dynamic>> goals, {required bool isCreator}) {
    if (goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag_rounded, size: 48, color: context.mc.textHint),
              const SizedBox(height: 16),
              Text(
                isCreator
                  ? 'No goals yet.\nTap + to create your first community goal.'
                  : 'You haven\'t backed any goals yet.\nTap the code icon to find a goal.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.mc.textSecond, height: 1.5)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: goals.length,
        itemBuilder: (_, i) => _goalCard(goals[i], isCreator: isCreator),
      ),
    );
  }

  Widget _goalCard(Map<String, dynamic> g, {required bool isCreator}) {
    final target  = double.tryParse(g['targetAmount'].toString()) ?? 0;
    final balance = double.tryParse(g['balance'].toString()) ?? 0;
    final percent = target > 0 ? (balance / target).clamp(0.0, 1.0) : 0.0;
    final status  = g['status'] as String? ?? 'ACTIVE';
    final code    = g['inviteCode'] as String? ?? '';

    Color statusColor;
    switch (status) {
      case 'ACTIVE':    statusColor = MyrabaColors.green; break;
      case 'COMPLETED': statusColor = MyrabaColors.gold; break;
      case 'WITHDRAWN': statusColor = MyrabaColors.purple; break;
      default:          statusColor = MyrabaColors.red;
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => GoalDetailScreen(inviteCode: code, isCreator: isCreator)
      )).then((_) => _load()),
      child: Container(
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
              Expanded(child: Text(g['title'] as String? ?? '',
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
            const SizedBox(height: 4),
            Text(g['description'] as String? ?? '',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.mc.textSecond, height: 1.4)),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('₦${_fmt(balance)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: MyrabaColors.green)),
              Text('of ₦${_fmt(target)}',
                style: TextStyle(fontSize: 12, color: context.mc.textSecond)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 7,
                backgroundColor: MyrabaColors.green.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(statusColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.people_outline_rounded, size: 13, color: context.mc.textHint),
              const SizedBox(width: 4),
              Text('${g['contributorCount']} contributor${(g['contributorCount'] as int? ?? 0) == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 11, color: context.mc.textHint)),
              const Spacer(),
              Text('Code: $code',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: MyrabaColors.green, letterSpacing: 1)),
            ]),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => NumberFormat('#,##0.00', 'en_NG').format(v);
}
