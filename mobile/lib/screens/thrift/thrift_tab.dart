import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class ThriftTab extends StatefulWidget {
  const ThriftTab({super.key});

  @override
  State<ThriftTab> createState() => _ThriftTabState();
}

class _ThriftTabState extends State<ThriftTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _categories = [];
  List<dynamic> _myThrifts = [];
  List<dynamic> _myPrivate = [];
  bool _loading = true;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    setState(() { _loading = true; _loadError = false; });

    // Categories are public — load regardless of auth state
    final publicApi = ApiService(auth.token ?? '');
    List<dynamic> categories = [];
    bool catError = false;
    try {
      final res = await publicApi.getThriftCategories();
      categories = (res['categories'] as List?) ?? [];
    } catch (_) {
      catError = true;
    }

    // User-specific data only when authenticated
    List<dynamic> myThrifts = [];
    List<dynamic> myPrivate = [];
    if (auth.token != null) {
      final api = ApiService(auth.token!);
      try {
        final res = await api.getMyThrifts();
        myThrifts = (res['thrifts'] as List?) ?? [];
      } catch (_) {}
      try {
        final res = await api.getMyPrivateThrifts();
        myPrivate = (res['memberships'] as List?) ?? [];
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _categories = categories;
      _myThrifts = myThrifts;
      _myPrivate = myPrivate;
      _loading = false;
      _loadError = catError && categories.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyrabaColors.bg,
      appBar: AppBar(
        backgroundColor: MyrabaColors.bg,
        title: const Text('Thrift'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: MyrabaColors.green,
          labelColor: MyrabaColors.green,
          unselectedLabelColor: MyrabaColors.textHint,
          tabs: const [
            Tab(text: 'Savings Plans'),
            Tab(text: 'Private Groups'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: MyrabaColors.green))
          : _loadError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded,
                          color: MyrabaColors.textHint, size: 48),
                      const SizedBox(height: 16),
                      const Text('Could not load thrift data',
                          style: TextStyle(color: MyrabaColors.textSecond)),
                      const SizedBox(height: 8),
                      const Text(
                          'The server may be waking up — try again in a moment.',
                          style: TextStyle(
                              color: MyrabaColors.textHint, fontSize: 12),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _SavingsPlansTab(
                        categories: _categories,
                        myThrifts: _myThrifts,
                        onRefresh: _load),
                    _PrivateGroupsTab(myPrivate: _myPrivate, onRefresh: _load),
                  ],
                ),
    );
  }
}

// ─── Savings Plans Tab ────────────────────────────────────────────────────────

class _SavingsPlansTab extends StatefulWidget {
  final List<dynamic> categories;
  final List<dynamic> myThrifts;
  final VoidCallback onRefresh;
  const _SavingsPlansTab(
      {required this.categories,
      required this.myThrifts,
      required this.onRefresh});

  @override
  State<_SavingsPlansTab> createState() => _SavingsPlansTabState();
}

class _SavingsPlansTabState extends State<_SavingsPlansTab> {
  String _filter = 'ALL'; // ALL | DAILY | WEEKLY | MONTHLY

  List<dynamic> get _filtered => _filter == 'ALL'
      ? widget.categories
      : widget.categories
          .where(
              (c) => (c['frequency'] as String? ?? '').toUpperCase() == _filter)
          .toList();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: MyrabaColors.green,
      backgroundColor: MyrabaColors.surface,
      child: ListView(
        padding: const EdgeInsets.all(0),
        children: [
          // ── How thrift works banner ──────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MyrabaColors.green.withValues(alpha: 0.15),
                  MyrabaColors.green.withValues(alpha: 0.05)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: MyrabaColors.green.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Text('🏦', style: TextStyle(fontSize: 28)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How Myraba Thrift Works',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: MyrabaColors.textPrimary)),
                      SizedBox(height: 4),
                      Text(
                          'Join a group · Contribute each cycle · Collect your full payout when it\'s your turn. Everyone wins.',
                          style: TextStyle(
                              fontSize: 11,
                              color: MyrabaColors.textSecond,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── My active plans ──────────────────────────────────────
          if (widget.myThrifts.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Text('My Active Plans',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MyrabaColors.textSecond)),
            ),
            ...widget.myThrifts
                .map((t) => _myThriftCard(t as Map<String, dynamic>)),
          ],

          // ── Frequency filter chips ───────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text('Available Plans',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MyrabaColors.textSecond)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['ALL', 'DAILY', 'WEEKLY', 'MONTHLY'].map((f) {
                  final active = _filter == f;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            active ? MyrabaColors.green : MyrabaColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? MyrabaColors.green
                              : MyrabaColors.surfaceLine,
                        ),
                      ),
                      child: Text(
                        f == 'ALL'
                            ? 'All Plans'
                            : '${f[0]}${f.substring(1).toLowerCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              active ? Colors.white : MyrabaColors.textSecond,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Plan cards ───────────────────────────────────────────
          if (_filtered.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: myrabaCard(),
              child: const Center(
                child: Text('No plans available',
                    style: TextStyle(color: MyrabaColors.textHint)),
              ),
            )
          else
            ..._filtered
                .map((c) => _categoryCard(context, c as Map<String, dynamic>)),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _myThriftCard(Map<String, dynamic> t) {
    final progressPercent = (t['progressPercent'] as num?)?.toDouble() ?? 0.0;
    final progress = (progressPercent / 100.0).clamp(0.0, 1.0);
    final cyclesDone = t['cyclesCompleted'] ?? 0;
    final cyclesReq = t['cyclesRequired'] ?? 1;
    final freq = (t['frequency'] as String? ?? '').toLowerCase();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: myrabaCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(t['categoryName'] ?? 'Savings Plan',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MyrabaColors.textPrimary)),
              ),
              _statusBadge(t['status'] as String? ?? 'ACTIVE'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _infoPill(
                  '₦${t['contributionAmount']} / $freq', MyrabaColors.green),
              const SizedBox(width: 8),
              _infoPill('Payout ₦${t['estimatedPayout']}', MyrabaColors.gold),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cycles: $cyclesDone / $cyclesReq',
                  style: const TextStyle(
                      fontSize: 11, color: MyrabaColors.textHint)),
              Text('Contributed: ₦${t['totalContributed'] ?? '0'}',
                  style: const TextStyle(
                      fontSize: 11, color: MyrabaColors.textSecond)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: MyrabaColors.surfaceLine,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(MyrabaColors.green),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Text('${progressPercent.toStringAsFixed(0)}% complete',
              style:
                  const TextStyle(fontSize: 10, color: MyrabaColors.textHint)),
        ],
      ),
    );
  }

  Widget _categoryCard(BuildContext context, Map<String, dynamic> c) {
    final freq = (c['frequency'] as String? ?? '').toLowerCase();
    final freqColor = freq == 'daily'
        ? MyrabaColors.green
        : freq == 'weekly'
            ? MyrabaColors.blue
            : MyrabaColors.purple;
    final freqIcon = freq == 'daily'
        ? '☀️'
        : freq == 'weekly'
            ? '📅'
            : '🗓️';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: myrabaCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: freqColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(freqIcon, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(freq[0].toUpperCase() + freq.substring(1),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: freqColor)),
                  ],
                ),
              ),
              const Spacer(),
              Text('${c['currentMemberCount'] ?? 0} members',
                  style: const TextStyle(
                      fontSize: 11, color: MyrabaColors.textHint)),
            ],
          ),
          const SizedBox(height: 12),
          Text(c['name'] ?? '',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MyrabaColors.textPrimary)),
          const SizedBox(height: 4),
          Text(c['description'] ?? '',
              style: const TextStyle(
                  fontSize: 12, color: MyrabaColors.textHint, height: 1.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statBox(
                    'Contribute', '₦${c['contributionAmount']}', 'per $freq'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _statBox('Cycles', '${c['cyclesRequired']}', 'to collect'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox(
                    'Collect', '₦${c['estimatedPayout']}', 'at payout'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _joinCategory(context, c),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Join ${c['name']}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MyrabaColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: MyrabaColors.textHint)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MyrabaColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
          Text(sub,
              style:
                  const TextStyle(fontSize: 10, color: MyrabaColors.textHint)),
        ],
      ),
    );
  }

  Widget _infoPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _statusBadge(String status) {
    final color = status == 'ACTIVE'
        ? MyrabaColors.green
        : status == 'COMPLETED'
            ? MyrabaColors.blue
            : MyrabaColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Future<void> _joinCategory(
      BuildContext context, Map<String, dynamic> c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MyrabaColors.surface,
        title: Text('Join ${c['name']}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'You will contribute ₦${c['contributionAmount']} every '
                '${(c['frequency'] as String).toLowerCase()} for '
                '${c['cyclesRequired']} cycles.',
                style: const TextStyle(
                    color: MyrabaColors.textSecond, fontSize: 13, height: 1.5)),
            const SizedBox(height: 8),
            Text('When it\'s your turn, you collect ₦${c['estimatedPayout']}.',
                style: const TextStyle(
                    color: MyrabaColors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: MyrabaColors.textSecond)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Join Plan'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) return;
    final api = ApiService(auth.token!);
    try {
      await api.joinThrift(c['id'] as int);
      widget.onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined ${c['name']}! 🎉'),
            backgroundColor: MyrabaColors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: MyrabaColors.red,
          ),
        );
      }
    }
  }
}

// ─── Private Groups Tab ───────────────────────────────────────────────────────

class _PrivateGroupsTab extends StatelessWidget {
  final List<dynamic> myPrivate;
  final VoidCallback onRefresh;
  const _PrivateGroupsTab({required this.myPrivate, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Explainer ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                MyrabaColors.purple.withValues(alpha: 0.15),
                MyrabaColors.purple.withValues(alpha: 0.05)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: MyrabaColors.purple.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Text('🤝', style: TextStyle(fontSize: 28)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Private Thrift Groups',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: MyrabaColors.textPrimary)),
                    SizedBox(height: 4),
                    Text(
                        'Save with friends, family or colleagues. You set the rules — amount, frequency, and payout order.',
                        style: TextStyle(
                            fontSize: 11,
                            color: MyrabaColors.textSecond,
                            height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Action buttons ─────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _actionButton(
                context,
                icon: Icons.add_circle_outline,
                label: 'Create Group',
                subtitle: 'Set your own rules',
                color: MyrabaColors.green,
                onTap: () => _showCreateDialog(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionButton(
                context,
                icon: Icons.vpn_key_outlined,
                label: 'Join with Code',
                subtitle: 'Have an invite code?',
                color: MyrabaColors.purple,
                onTap: () => _showJoinDialog(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── My groups ──────────────────────────────────────────────
        if (myPrivate.isNotEmpty) ...[
          const Text('My Groups',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MyrabaColors.textSecond)),
          const SizedBox(height: 12),
          ...myPrivate.map((g) => _groupCard(g as Map<String, dynamic>)),
        ] else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: myrabaCard(),
            child: const Column(
              children: [
                Icon(Icons.group_outlined,
                    color: MyrabaColors.textHint, size: 48),
                SizedBox(height: 12),
                Text('No private groups yet',
                    style:
                        TextStyle(color: MyrabaColors.textHint, fontSize: 14)),
                SizedBox(height: 4),
                Text('Create a group or join one with an invite code',
                    style:
                        TextStyle(color: MyrabaColors.textHint, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: MyrabaColors.textHint)),
          ],
        ),
      ),
    );
  }

  Widget _groupCard(Map<String, dynamic> g) {
    final status = g['status'] as String? ?? '';
    final statusColor = status == 'ACTIVE'
        ? MyrabaColors.green
        : status == 'PENDING'
            ? MyrabaColors.gold
            : MyrabaColors.textHint;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: myrabaCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(g['thriftName'] ?? 'Private Group',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MyrabaColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 13, color: MyrabaColors.textHint),
              const SizedBox(width: 4),
              Text('by ${g['creator'] ?? '—'}',
                  style: const TextStyle(
                      fontSize: 11, color: MyrabaColors.textHint)),
              const SizedBox(width: 14),
              const Icon(Icons.payments_outlined,
                  size: 13, color: MyrabaColors.textHint),
              const SizedBox(width: 4),
              Text('₦${g['contributionAmount'] ?? '—'} / cycle',
                  style: const TextStyle(
                      fontSize: 11, color: MyrabaColors.textHint)),
            ],
          ),
          if (g['position'] != null) ...[
            const SizedBox(height: 4),
            Text(
                'Position #${g['position']}  ·  Cycle ${g['currentCycle'] ?? '—'} of ${g['totalCycles'] ?? '—'}',
                style: const TextStyle(
                    fontSize: 11, color: MyrabaColors.textHint)),
          ],
        ],
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MyrabaColors.surface,
        title: const Text('Join Private Group'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Enter invite code',
            prefixIcon: Icon(Icons.vpn_key_outlined),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: MyrabaColors.textSecond)),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = ctrl.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(context);
              final auth = Provider.of<AuthService>(context, listen: false);
              if (auth.token == null) return;
              final api = ApiService(auth.token!);
              try {
                await api.joinPrivateThrift(code);
                onRefresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Join request sent! Accept the rules to confirm.'),
                      backgroundColor: MyrabaColors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: MyrabaColors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CreateThriftDialog(
        onCreated: (inviteCode, collateral) {
          onRefresh();
          _showInviteCodeDialog(context, inviteCode, collateral);
        },
      ),
    );
  }

  void _showInviteCodeDialog(
      BuildContext context, String code, String collateral) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MyrabaColors.surface,
        title: const Text('Group Created! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this invite code with your members:',
                style: TextStyle(color: MyrabaColors.textSecond, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MyrabaColors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: MyrabaColors.green.withValues(alpha: 0.3)),
              ),
              child: Text(code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: MyrabaColors.green,
                      letterSpacing: 4)),
            ),
            if (collateral.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(collateral,
                  style: const TextStyle(
                      fontSize: 11, color: MyrabaColors.textHint, height: 1.4)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invite code copied!'),
                  backgroundColor: MyrabaColors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Copy Code'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

// ─── Create Private Thrift Dialog ─────────────────────────────────────────────

class _CreateThriftDialog extends StatefulWidget {
  final void Function(String inviteCode, String collateral) onCreated;
  const _CreateThriftDialog({required this.onCreated});

  @override
  State<_CreateThriftDialog> createState() => _CreateThriftDialogState();
}

class _CreateThriftDialogState extends State<_CreateThriftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _cycCtrl = TextEditingController();
  final _rulesCtrl = TextEditingController();

  String _frequency = 'MONTHLY';
  String _assignment = 'RAFFLE';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _amtCtrl.dispose();
    _cycCtrl.dispose();
    _rulesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) {
      setState(() => _submitting = false);
      return;
    }
    final api = ApiService(auth.token!);
    try {
      final result = await api.createPrivateThrift(
        name: _nameCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        contributionAmount: _amtCtrl.text.trim(),
        frequency: _frequency,
        totalCycles: int.parse(_cycCtrl.text.trim()),
        positionAssignment: _assignment,
        creatorRules:
            _rulesCtrl.text.trim().isEmpty ? null : _rulesCtrl.text.trim(),
      );
      if (!mounted) return;
      final code = result['inviteCode'] as String? ?? '—';
      final collateral = result['collateral'] as String? ?? '';
      Navigator.pop(context);
      widget.onCreated(code, collateral);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: MyrabaColors.surface,
      title: const Text('Create Private Group'),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_nameCtrl, 'Group Name', required: true),
            const SizedBox(height: 12),
            _field(_descCtrl, 'Description (optional)'),
            const SizedBox(height: 12),
            _field(
              _amtCtrl,
              'Contribution Amount (₦)',
              required: true,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null || double.parse(v) <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              dropdownColor: MyrabaColors.surface,
              decoration: _inputDec('Frequency'),
              items: const [
                DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
              ],
              onChanged: (v) => setState(() => _frequency = v!),
            ),
            const SizedBox(height: 12),
            _field(
              _cycCtrl,
              'Number of Members / Cycles',
              required: true,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = int.tryParse(v);
                if (n == null || n < 2) return 'Minimum 2 members';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _assignment,
              dropdownColor: MyrabaColors.surface,
              decoration: _inputDec('Payout Order'),
              items: const [
                DropdownMenuItem(
                    value: 'RAFFLE', child: Text('Random (Fair Draw)')),
                DropdownMenuItem(
                    value: 'MANUAL', child: Text('I assign positions')),
              ],
              onChanged: (v) => setState(() => _assignment = v!),
            ),
            const SizedBox(height: 12),
            _field(_rulesCtrl, 'Group Rules (optional)', maxLines: 3),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MyrabaColors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MyrabaColors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: MyrabaColors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 13, color: MyrabaColors.red)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: MyrabaColors.textSecond)),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Create Group'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _inputDec(label),
      validator: validator ??
          (required
              ? (v) => (v == null || v.isEmpty) ? 'Required' : null
              : null),
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: MyrabaColors.textHint, fontSize: 13),
        isDense: true,
      );
}
