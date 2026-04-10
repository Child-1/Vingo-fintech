import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/myraba_logo.dart';
import 'welcome_screen.dart';

// ═══════════════════════════════════════════════════════════════════
// ENTRY POINT
// ═══════════════════════════════════════════════════════════════════
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tab = 0;

  void _goToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isLoggedIn) {
      _goToLogin();
      return const Scaffold(
        backgroundColor: MyrabaColors.bg,
        body:
            Center(child: CircularProgressIndicator(color: MyrabaColors.orange)),
      );
    }
    if (!auth.isAdmin) {
      return Scaffold(
        backgroundColor: MyrabaColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, color: MyrabaColors.red, size: 48),
              const SizedBox(height: 12),
              const Text('Access Denied',
                  style: TextStyle(
                      color: MyrabaColors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  auth.logout();
                  _goToLogin();
                },
                child: const Text('Sign Out',
                    style: TextStyle(color: MyrabaColors.textHint)),
              ),
            ],
          ),
        ),
      );
    }

    final token = auth.token!;
    final tabs = [
      _OverviewTab(token: token, auth: auth),
      _UsersTab(token: token, role: auth.role ?? ''),
      _TransactionsTab(token: token, role: auth.role ?? ''),
      _KycTab(token: token),
      _ConsoleTab(auth: auth, onSignOut: _goToLogin),
    ];

    return Scaffold(
      backgroundColor: MyrabaColors.bg,
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: _AdminBottomNav(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BOTTOM NAV
// ═══════════════════════════════════════════════════════════════════
class _AdminBottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _AdminBottomNav({required this.current, required this.onTap});

  static const _items = [
    (Icons.dashboard_rounded, Icons.dashboard_outlined, 'Overview'),
    (Icons.people_rounded, Icons.people_outline_rounded, 'Users'),
    (Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Txns'),
    (Icons.verified_user_rounded, Icons.verified_user_outlined, 'KYC'),
    (Icons.terminal_rounded, Icons.terminal_rounded, 'Console'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MyrabaColors.surface,
        border: Border(top: BorderSide(color: MyrabaColors.surfaceLine)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(_items.length, (i) {
              final sel = i == current;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(sel ? _items[i].$1 : _items[i].$2,
                          color:
                              sel ? MyrabaColors.orange : MyrabaColors.textHint,
                          size: 22),
                      const SizedBox(height: 3),
                      Text(_items[i].$3,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color:
                                sel ? MyrabaColors.orange : MyrabaColors.textHint,
                          )),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 1 — OVERVIEW
// ═══════════════════════════════════════════════════════════════════
class _OverviewTab extends StatefulWidget {
  final String token;
  final AuthService auth;
  const _OverviewTab({required this.token, required this.auth});
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _liquidity;
  List<dynamic> _recentTx = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final h = {'Authorization': 'Bearer ${widget.token}'};
    try {
      final results = await Future.wait([
        http.get(Uri.parse('${AuthService.baseUrl}/api/admin/dashboard/stats'),
            headers: h),
        http.get(
            Uri.parse('${AuthService.baseUrl}/api/admin/transactions/summary'),
            headers: h),
        http.get(Uri.parse('${AuthService.baseUrl}/api/admin/system/liquidity'),
            headers: h),
        http.get(
            Uri.parse(
                '${AuthService.baseUrl}/api/admin/transactions?page=0&size=8'),
            headers: h),
      ]);
      if (!mounted) return;
      setState(() {
        if (results[0].statusCode == 200) _stats = jsonDecode(results[0].body);
        if (results[1].statusCode == 200) {
          _summary = jsonDecode(results[1].body);
        }
        if (results[2].statusCode == 200) {
          _liquidity = jsonDecode(results[2].body);
        }
        if (results[3].statusCode == 200) {
          final b = jsonDecode(results[3].body);
          _recentTx = b is List ? b : (b['transactions'] as List? ?? []);
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final summary = _summary;
    final liquidity = _liquidity;
    final role = widget.auth.role ?? '';
    final name = widget.auth.fullName ?? widget.auth.myrabaHandle ?? 'Admin';

    return RefreshIndicator(
      onRefresh: _load,
      color: MyrabaColors.orange,
      backgroundColor: MyrabaColors.surface,
      child: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: MyrabaColors.bg,
            expandedHeight: 110,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
                child: Row(
                  children: [
                    const MyrabaLogoMark(size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Admin Console',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: MyrabaColors.textHint,
                                  fontWeight: FontWeight.w500)),
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: MyrabaColors.textPrimary)),
                        ],
                      ),
                    ),
                    _rolePill(role),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: MyrabaColors.surfaceLine),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
                child: Center(
                    child:
                        CircularProgressIndicator(color: MyrabaColors.orange)))
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Alerts ──────────────────────────────────────
                    if (stats != null) ...[
                      if ((stats['failedTransactions24h'] ?? 0) > 0)
                        _AlertBanner(Icons.warning_rounded, MyrabaColors.red,
                            '${stats['failedTransactions24h']} failed transactions in last 24h'),
                      if ((stats['kycPending'] ?? 0) > 0)
                        _AlertBanner(
                            Icons.verified_user_rounded,
                            MyrabaColors.gold,
                            '${stats['kycPending']} users awaiting KYC approval'),
                      if ((stats['pendingPayouts'] ?? 0) > 0)
                        _AlertBanner(Icons.pending_rounded, MyrabaColors.blue,
                            '${stats['pendingPayouts']} payouts pending'),
                    ],

                    const SizedBox(height: 4),
                    const _SectionHeader('Platform Overview'),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── KPI grid ─────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _KpiCard(
                      'Total Users',
                      _fmt(stats?['totalUsers']),
                      Icons.people_rounded,
                      MyrabaColors.blue,
                      'New today: ${_fmt(stats?['newUsersToday'])}'),
                  _KpiCard(
                      'System Volume',
                      '₦${_fmtMoney(stats?['totalVolume'])}',
                      Icons.swap_horiz_rounded,
                      MyrabaColors.orange,
                      'Fees: ₦${_fmtMoney(stats?['totalServiceFees'])}'),
                  _KpiCard(
                      'System Balance',
                      '₦${_fmtMoney(stats?['systemLiquidity'])}',
                      Icons.account_balance_wallet_rounded,
                      MyrabaColors.teal,
                      'Locked: ₦${_fmtMoney(stats?['totalLockedInThrifts'])}'),
                  _KpiCard(
                      'Active Thrifts',
                      _fmt(stats?['activeThrifts']),
                      Icons.savings_rounded,
                      MyrabaColors.purple,
                      'Pending payouts: ${_fmt(stats?['pendingPayouts'])}'),
                ],
              ),
            ),

            // ── Liquidity panel ───────────────────────────────────
            if (liquidity != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _LiquidityPanel(liquidity),
                ),
              ),

            // ── Recent transactions ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _SectionHeader('Recent Transactions'),
                    if (summary != null)
                      Text(
                          'Vol: ₦${_fmtMoney(summary['totalVolume'])}  ·  Fees: ₦${_fmtMoney(summary['totalFees'])}',
                          style: const TextStyle(
                              fontSize: 11, color: MyrabaColors.textHint)),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  if (_recentTx.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                          child: Text('No transactions yet',
                              style: TextStyle(color: MyrabaColors.textHint))),
                    );
                  }
                  final tx = _recentTx[i] as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _TxListTile(tx: tx, onTap: null),
                  );
                },
                childCount: _recentTx.isEmpty ? 1 : _recentTx.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 2 — USERS
// ═══════════════════════════════════════════════════════════════════
class _UsersTab extends StatefulWidget {
  final String token;
  final String role;
  const _UsersTab({required this.token, required this.role});
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<dynamic> _users = [];
  bool _loading = true;
  String _filter = 'All';
  Timer? _debounce;
  final _ctrl = TextEditingController();

  static const _filters = ['All', 'KYC Pending', 'Admins'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load([String? search]) async {
    setState(() => _loading = true);
    final h = {'Authorization': 'Bearer ${widget.token}'};
    try {
      final q = search != null && search.isNotEmpty ? '&search=$search' : '';
      final res = await http.get(
        Uri.parse('${AuthService.baseUrl}/api/admin/users?page=0&size=50$q'),
        headers: h,
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _users = body is List ? body : (body['users'] as List? ?? []);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    var list = _users;
    if (_filter == 'KYC Pending') {
      list = list.where((u) => (u['kycStatus'] ?? '') == 'PENDING').toList();
    } else if (_filter == 'Admins') {
      list = list.where((u) {
        final r = (u['role'] ?? '').toString();
        return r == 'ADMIN' || r == 'SUPER_ADMIN' || r == 'STAFF';
      }).toList();
    }
    return list;
  }

  void _onSearch(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _load(val));
  }

  void _showUserSheet(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MyrabaColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _UserDetailSheet(
        user: user,
        token: widget.token,
        callerRole: widget.role,
        onUpdated: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyrabaColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Text('Users',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: MyrabaColors.textPrimary)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: MyrabaColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_filtered.length}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: MyrabaColors.orange,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _ctrl,
                onChanged: _onSearch,
                style: const TextStyle(
                    color: MyrabaColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by MyrabaHandle or account…',
                  hintStyle: const TextStyle(
                      color: MyrabaColors.textHint, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: MyrabaColors.textHint, size: 20),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: MyrabaColors.textHint, size: 18),
                          onPressed: () {
                            _ctrl.clear();
                            _load();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: MyrabaColors.surfaceHigh,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // Filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: _filters
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _filter = f),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: _filter == f
                                    ? MyrabaColors.orange
                                    : MyrabaColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(f,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _filter == f
                                        ? Colors.white
                                        : MyrabaColors.textSecond,
                                  )),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: MyrabaColors.orange))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: MyrabaColors.orange,
                      backgroundColor: MyrabaColors.surface,
                      child: _filtered.isEmpty
                          ? const Center(
                              child: Text('No users found',
                                  style:
                                      TextStyle(color: MyrabaColors.textHint)))
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final u = _filtered[i] as Map<String, dynamic>;
                                return _UserListTile(
                                    user: u, onTap: () => _showUserSheet(u));
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── User Detail Bottom Sheet ─────────────────────────────────────
class _UserDetailSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final String token;
  final String callerRole;
  final VoidCallback onUpdated;
  const _UserDetailSheet(
      {required this.user,
      required this.token,
      required this.callerRole,
      required this.onUpdated});
  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  bool _saving = false;
  String? _msg;

  bool get _canEdit =>
      widget.callerRole == 'ADMIN' || widget.callerRole == 'SUPER_ADMIN';

  Future<void> _updateRole(String newRole) async {
    setState(() {
      _saving = true;
      _msg = null;
    });
    try {
      final res = await http.put(
        Uri.parse(
            '${AuthService.baseUrl}/api/admin/users/${widget.user['id']}/role'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}'
        },
        body: jsonEncode({'role': newRole}),
      );
      setState(() {
        _saving = false;
        _msg = res.statusCode == 200
            ? 'Role updated to $newRole'
            : 'Failed: ${jsonDecode(res.body)['message'] ?? ''}';
      });
      if (res.statusCode == 200) widget.onUpdated();
    } catch (_) {
      setState(() {
        _saving = false;
        _msg = 'Network error';
      });
    }
  }

  Future<void> _updateKyc(String status) async {
    setState(() {
      _saving = true;
      _msg = null;
    });
    try {
      final res = await http.put(
        Uri.parse(
            '${AuthService.baseUrl}/api/admin/users/${widget.user['id']}/kyc'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}'
        },
        body: jsonEncode({'status': status}),
      );
      setState(() {
        _saving = false;
        _msg = res.statusCode == 200 ? 'KYC set to $status' : 'Failed';
      });
      if (res.statusCode == 200) widget.onUpdated();
    } catch (_) {
      setState(() {
        _saving = false;
        _msg = 'Network error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final role = (u['role'] ?? 'USER') as String;
    final kyc = (u['kycStatus'] ?? 'NONE') as String;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: MyrabaColors.surfaceLine,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          // Avatar + name
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: MyrabaColors.orange.withValues(alpha: 0.15),
                child: Text((u['fullName'] as String? ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: MyrabaColors.orange)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u['fullName'] ?? '—',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: MyrabaColors.textPrimary)),
                    Text('v₦${u['myrabaHandle']}',
                        style: const TextStyle(
                            fontSize: 13, color: MyrabaColors.textHint)),
                  ],
                ),
              ),
              _rolePill(role),
            ],
          ),
          const SizedBox(height: 20),

          // Details grid
          _detailRow('Account', u['accountNumber'] ?? '—', copyable: true),
          _detailRow('Phone', u['phone'] ?? '—'),
          _detailRow('Email', u['email'] ?? '—'),
          _detailRow('Balance', '₦${u['balance'] ?? '0.00'}'),
          _detailRow('KYC', kyc, badge: _kycColor(kyc)),
          _detailRow('Joined', _shortDate(u['createdAt']?.toString() ?? '')),

          if (_msg != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _msg!.startsWith('Role') || _msg!.startsWith('KYC')
                    ? MyrabaColors.teal.withValues(alpha: 0.12)
                    : MyrabaColors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_msg!,
                  style: TextStyle(
                    fontSize: 13,
                    color: _msg!.startsWith('Role') || _msg!.startsWith('KYC')
                        ? MyrabaColors.teal
                        : MyrabaColors.red,
                  )),
            ),
          ],

          if (_canEdit) ...[
            const SizedBox(height: 20),
            const Text('Change Role',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MyrabaColors.textSecond)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['USER', 'STAFF', 'ADMIN', 'SUPER_ADMIN']
                  .map((r) => GestureDetector(
                        onTap: _saving ? null : () => _updateRole(r),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: role == r
                                ? MyrabaColors.orange.withValues(alpha: 0.15)
                                : MyrabaColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: role == r
                                    ? MyrabaColors.orange
                                    : Colors.transparent),
                          ),
                          child: Text(r,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: role == r
                                      ? MyrabaColors.orange
                                      : MyrabaColors.textSecond)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text('Update KYC Status',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MyrabaColors.textSecond)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['NONE', 'PENDING', 'APPROVED', 'REJECTED']
                  .map((s) => GestureDetector(
                        onTap: _saving ? null : () => _updateKyc(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: kyc == s
                                ? _kycColor(s).withValues(alpha: 0.15)
                                : MyrabaColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: kyc == s
                                    ? _kycColor(s)
                                    : Colors.transparent),
                          ),
                          child: Text(s,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kyc == s
                                      ? _kycColor(s)
                                      : MyrabaColors.textSecond)),
                        ),
                      ))
                  .toList(),
            ),
          ],

          if (_saving) ...[
            const SizedBox(height: 16),
            const Center(
                child: CircularProgressIndicator(color: MyrabaColors.orange)),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value,
      {bool copyable = false, Color? badge}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: MyrabaColors.textHint))),
          Expanded(
            child: badge != null
                ? Row(children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: badge, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(value,
                        style: TextStyle(
                            fontSize: 13,
                            color: badge,
                            fontWeight: FontWeight.w600)),
                  ])
                : Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        color: MyrabaColors.textPrimary,
                        fontWeight: FontWeight.w500)),
          ),
          if (copyable)
            GestureDetector(
              onTap: () => Clipboard.setData(ClipboardData(text: value)),
              child: const Icon(Icons.copy_rounded,
                  size: 14, color: MyrabaColors.textHint),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 3 — TRANSACTIONS
// ═══════════════════════════════════════════════════════════════════
class _TransactionsTab extends StatefulWidget {
  final String token;
  final String role;
  const _TransactionsTab({required this.token, required this.role});
  @override
  State<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<_TransactionsTab> {
  List<dynamic> _txs = [];
  bool _loading = true;
  String _filter = 'All';

  static const _filters = ['All', 'TRANSFER', 'FUNDED', 'REVERSAL', 'Failed'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final h = {'Authorization': 'Bearer ${widget.token}'};
    try {
      String url =
          '${AuthService.baseUrl}/api/admin/transactions?page=0&size=80';
      if (_filter == 'Failed') {
        url += '&status=FAILED';
      } else if (_filter != 'All') url += '&type=$_filter';
      final res = await http.get(Uri.parse(url), headers: h);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final b = jsonDecode(res.body);
        setState(() {
          _txs = b is List ? b : (b['transactions'] as List? ?? []);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showTxSheet(Map<String, dynamic> tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MyrabaColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) =>
          _TxDetailSheet(tx: tx, token: widget.token, role: widget.role),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyrabaColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const Text('Transactions',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: MyrabaColors.textPrimary)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: MyrabaColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${_txs.length}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: MyrabaColors.orange,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            // Filter chips
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _filters
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _filter = f);
                              _load();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: _filter == f
                                    ? MyrabaColors.orange
                                    : MyrabaColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(f,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _filter == f
                                          ? Colors.white
                                          : MyrabaColors.textSecond)),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: MyrabaColors.orange))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: MyrabaColors.orange,
                      backgroundColor: MyrabaColors.surface,
                      child: _txs.isEmpty
                          ? const Center(
                              child: Text('No transactions',
                                  style:
                                      TextStyle(color: MyrabaColors.textHint)))
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _txs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final tx = _txs[i] as Map<String, dynamic>;
                                return _TxListTile(
                                    tx: tx, onTap: () => _showTxSheet(tx));
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Transaction Detail Sheet ─────────────────────────────────────
class _TxDetailSheet extends StatefulWidget {
  final Map<String, dynamic> tx;
  final String token;
  final String role;
  const _TxDetailSheet(
      {required this.tx, required this.token, required this.role});
  @override
  State<_TxDetailSheet> createState() => _TxDetailSheetState();
}

class _TxDetailSheetState extends State<_TxDetailSheet> {
  bool _reversing = false;
  String? _msg;

  bool get _canReverse =>
      (widget.role == 'ADMIN' || widget.role == 'SUPER_ADMIN') &&
      widget.tx['status'] == 'SUCCESS' &&
      (widget.tx['type'] == 'TRANSFER' || widget.tx['type'] == 'FUNDED');

  Future<void> _reverse() async {
    final reason = await _promptReason();
    if (reason == null || reason.isEmpty) return;
    setState(() {
      _reversing = true;
      _msg = null;
    });
    try {
      final res = await http.post(
        Uri.parse(
            '${AuthService.baseUrl}/api/admin/transactions/${widget.tx['id']}/reverse'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}'
        },
        body: jsonEncode({'reason': reason}),
      );
      setState(() {
        _reversing = false;
        _msg = res.statusCode == 200
            ? 'Transaction reversed successfully'
            : jsonDecode(res.body)['message'] ?? 'Reversal failed';
      });
    } catch (_) {
      setState(() {
        _reversing = false;
        _msg = 'Network error';
      });
    }
  }

  Future<String?> _promptReason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MyrabaColors.surface,
        title: const Text('Reversal Reason',
            style: TextStyle(color: MyrabaColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: MyrabaColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter reason…',
            hintStyle: TextStyle(color: MyrabaColors.textHint),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: MyrabaColors.surfaceLine)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: MyrabaColors.orange)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child:
                const Text('Reverse', style: TextStyle(color: MyrabaColors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    final status = tx['status'] as String? ?? '';
    final type = tx['type'] as String? ?? '';
    final isSent =
        type == 'TRANSFER' || type == 'WITHDRAWAL' || type == 'DEBIT';
    final color = _statusColor(status);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: MyrabaColors.surfaceLine,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (isSent ? MyrabaColors.orange : MyrabaColors.teal)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_txIcon(type),
                      color: isSent ? MyrabaColors.orange : MyrabaColors.teal,
                      size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: MyrabaColors.textPrimary)),
                      Text('ID: #${tx['id']}',
                          style: const TextStyle(
                              fontSize: 12, color: MyrabaColors.textHint)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _txDetail('Amount', '₦${tx['amount'] ?? '0'}'),
            if ((tx['fee'] ?? '') != '' &&
                tx['fee'] != null &&
                tx['fee'] != '0.00')
              _txDetail('Fee', '₦${tx['fee']}'),
            _txDetail('From', tx['senderHandle'] ?? '—'),
            _txDetail('To', tx['receiverHandle'] ?? '—'),
            _txDetail('Description', tx['description'] ?? '—'),
            _txDetail('Date', _shortDate(tx['createdAt']?.toString() ?? '')),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _msg!.contains('success')
                      ? MyrabaColors.teal.withValues(alpha: 0.12)
                      : MyrabaColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_msg!,
                    style: TextStyle(
                        fontSize: 13,
                        color: _msg!.contains('success')
                            ? MyrabaColors.teal
                            : MyrabaColors.red)),
              ),
            ],
            if (_canReverse) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _reversing ? null : _reverse,
                  icon: _reversing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: MyrabaColors.red))
                      : const Icon(Icons.undo_rounded, color: MyrabaColors.red),
                  label: Text(_reversing ? 'Reversing…' : 'Reverse Transaction',
                      style: const TextStyle(color: MyrabaColors.red)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: MyrabaColors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _txDetail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
                width: 90,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: MyrabaColors.textHint))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        color: MyrabaColors.textPrimary,
                        fontWeight: FontWeight.w500))),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════
// TAB 4 — KYC REVIEW
// ═══════════════════════════════════════════════════════════════════
class _KycTab extends StatefulWidget {
  final String token;
  const _KycTab({required this.token});
  @override
  State<_KycTab> createState() => _KycTabState();
}

class _KycTabState extends State<_KycTab> {
  List<dynamic> _pending = [];
  bool _loading = true;
  final Map<int, bool> _processing = {};
  final Map<int, String?> _results = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final h = {'Authorization': 'Bearer ${widget.token}'};
    try {
      final res = await http.get(
          Uri.parse('${AuthService.baseUrl}/api/admin/users/kyc/pending'),
          headers: h);
      if (!mounted) return;
      setState(() {
        if (res.statusCode == 200) {
          final b = jsonDecode(res.body);
          _pending = b is List ? b : [];
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(int userId, String status) async {
    setState(() => _processing[userId] = true);
    final h = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}'
    };
    try {
      final res = await http.put(
        Uri.parse('${AuthService.baseUrl}/api/admin/users/$userId/kyc'),
        headers: h,
        body: jsonEncode({'status': status}),
      );
      if (!mounted) return;
      setState(() {
        _processing.remove(userId);
        _results[userId] = res.statusCode == 200 ? status : 'ERROR';
      });
      if (res.statusCode == 200) {
        await Future.delayed(const Duration(seconds: 1));
        _load();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _processing.remove(userId);
          _results[userId] = 'ERROR';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyrabaColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Text('KYC Review',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: MyrabaColors.textPrimary)),
                  const Spacer(),
                  if (!_loading)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _pending.isNotEmpty
                            ? MyrabaColors.gold.withValues(alpha: 0.15)
                            : MyrabaColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${_pending.length} pending',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _pending.isNotEmpty
                                  ? MyrabaColors.gold
                                  : MyrabaColors.textHint)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: MyrabaColors.orange))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: MyrabaColors.orange,
                      backgroundColor: MyrabaColors.surface,
                      child: _pending.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_rounded,
                                      color: MyrabaColors.teal, size: 48),
                                  SizedBox(height: 12),
                                  Text('All KYC reviews complete',
                                      style: TextStyle(
                                          color: MyrabaColors.teal,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  SizedBox(height: 6),
                                  Text('No pending submissions',
                                      style: TextStyle(
                                          color: MyrabaColors.textHint,
                                          fontSize: 13)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _pending.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final u = _pending[i] as Map<String, dynamic>;
                                final uid = (u['id'] as num).toInt();
                                final result = _results[uid];
                                final busy = _processing[uid] == true;
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: _myrabaCard(),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: MyrabaColors.gold
                                                .withValues(alpha: 0.15),
                                            child: Text(
                                              (u['fullName'] as String? ??
                                                      'U')[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: MyrabaColors.gold),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(u['fullName'] ?? '—',
                                                    style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: MyrabaColors
                                                            .textPrimary)),
                                                Text(
                                                    'v₦${u['myrabaHandle']}  ·  ${u['phone'] ?? u['email'] ?? ''}',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: MyrabaColors
                                                            .textHint)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (result != null) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: result == 'APPROVED'
                                                ? MyrabaColors.teal
                                                    .withValues(alpha: 0.12)
                                                : result == 'REJECTED'
                                                    ? MyrabaColors.red
                                                        .withValues(alpha: 0.12)
                                                    : MyrabaColors.surfaceHigh,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            result == 'ERROR'
                                                ? 'Action failed'
                                                : 'KYC $result',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: result == 'APPROVED'
                                                  ? MyrabaColors.teal
                                                  : result == 'REJECTED'
                                                      ? MyrabaColors.red
                                                      : MyrabaColors.textHint,
                                            ),
                                          ),
                                        ),
                                      ] else if (busy) ...[
                                        const Center(
                                            child: Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 8),
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: MyrabaColors.orange),
                                        )),
                                      ] else ...[
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () =>
                                                    _decide(uid, 'REJECTED'),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(
                                                      color: MyrabaColors.red),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 10),
                                                ),
                                                child: const Text('Reject',
                                                    style: TextStyle(
                                                        color: MyrabaColors.red,
                                                        fontWeight:
                                                            FontWeight.w700)),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () =>
                                                    _decide(uid, 'APPROVED'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      MyrabaColors.teal,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 10),
                                                ),
                                                child: const Text('Approve',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 5 — CONSOLE
// ═══════════════════════════════════════════════════════════════════
class _ConsoleTab extends StatefulWidget {
  final AuthService auth;
  final VoidCallback onSignOut;
  const _ConsoleTab({required this.auth, required this.onSignOut});
  @override
  State<_ConsoleTab> createState() => _ConsoleTabState();
}

class _ConsoleTabState extends State<_ConsoleTab> {
  Map<String, dynamic>? _health;
  Map<String, dynamic>? _liquidity;
  List<dynamic> _tagRequests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final h = {'Authorization': 'Bearer ${widget.auth.token}'};
    try {
      final results = await Future.wait([
        http.get(Uri.parse('${AuthService.baseUrl}/api/admin/system/health'),
            headers: h),
        http.get(Uri.parse('${AuthService.baseUrl}/api/admin/system/liquidity'),
            headers: h),
        http.get(
            Uri.parse(
                '${AuthService.baseUrl}/api/admin/tag-requests/pending?page=0&size=10'),
            headers: h),
      ]);
      if (!mounted) return;
      setState(() {
        if (results[0].statusCode == 200) _health = jsonDecode(results[0].body);
        if (results[1].statusCode == 200) {
          _liquidity = jsonDecode(results[1].body);
        }
        if (results[2].statusCode == 200) {
          final b = jsonDecode(results[2].body);
          _tagRequests = b is Map ? (b['content'] as List? ?? []) : [];
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _tagDecide(int id, bool approved) async {
    final h = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.auth.token}'
    };
    try {
      await http.put(
        Uri.parse('${AuthService.baseUrl}/api/admin/tag-requests/$id/decision'),
        headers: h,
        body: jsonEncode({'approved': approved}),
      );
      _load();
    } catch (_) {}
  }

  void _signOut() {
    widget.auth.logout();
    widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyrabaColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: MyrabaColors.orange,
        backgroundColor: MyrabaColors.surface,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 52, 16, 8),
                child: Text('Console',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: MyrabaColors.textPrimary)),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                  child: Center(
                      child:
                          CircularProgressIndicator(color: MyrabaColors.orange)))
            else ...[
              // ── System health ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader('System Health'),
                      const SizedBox(height: 10),
                      if (_health != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: _myrabaCard(
                              borderColor: _health!['status'] == 'UP'
                                  ? MyrabaColors.teal
                                  : MyrabaColors.red),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _health!['status'] == 'UP'
                                            ? MyrabaColors.teal
                                            : MyrabaColors.red,
                                      )),
                                  const SizedBox(width: 8),
                                  Text(
                                      _health!['status'] == 'UP'
                                          ? 'All Systems Operational'
                                          : 'System Issue Detected',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _health!['status'] == 'UP'
                                              ? MyrabaColors.teal
                                              : MyrabaColors.red)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_health!['metrics'] is Map)
                                ...(_health!['metrics'] as Map)
                                    .entries
                                    .map((e) => _consoleStat(
                                          e.key
                                              .toString()
                                              .replaceAllMapped(
                                                  RegExp(r'([A-Z])'),
                                                  (m) => ' ${m[0]}')
                                              .trim()
                                              .toLowerCase(),
                                          '${e.value}',
                                        )),
                              _consoleStat(
                                  'last checked',
                                  _shortDate(
                                      _health!['timestamp']?.toString() ?? '')),
                            ],
                          ),
                        ),
                      ] else
                        _consoleStat('Status', 'Unable to fetch health'),
                    ],
                  ),
                ),
              ),

              // ── Liquidity ──────────────────────────────────────
              if (_liquidity != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader('Liquidity Report'),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: _myrabaCard(),
                          child: Column(
                            children: [
                              _consoleStat('Total System Balance',
                                  '₦${_fmtMoney(_liquidity!['totalSystemBalance'])}'),
                              _consoleStat('Locked in Thrifts',
                                  '₦${_fmtMoney(_liquidity!['lockedInThrifts'])}'),
                              _consoleStat('Available Liquidity',
                                  '₦${_fmtMoney(_liquidity!['availableLiquidity'])}'),
                              _consoleStat('Total Transaction Volume',
                                  '₦${_fmtMoney(_liquidity!['totalTransactionVolume'])}'),
                              _consoleStat('Total Fees Collected',
                                  '₦${_fmtMoney(_liquidity!['totalFeesCollected'])}'),
                              _consoleStat(
                                  'Generated',
                                  _shortDate(
                                      _liquidity!['generatedAt']?.toString() ??
                                          '')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── VingTag requests ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _SectionHeader('VingTag Change Requests'),
                          const SizedBox(width: 8),
                          if (_tagRequests.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: MyrabaColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('${_tagRequests.length}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: MyrabaColors.gold,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_tagRequests.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: _myrabaCard(),
                          child: const Center(
                            child: Text('No pending tag requests',
                                style: TextStyle(
                                    color: MyrabaColors.textHint, fontSize: 13)),
                          ),
                        )
                      else
                        ..._tagRequests.map((r) {
                          final req = r as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: _myrabaCard(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text('v₦${req['currentTag']}',
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      color: MyrabaColors
                                                          .textSecond)),
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8),
                                                child: Icon(
                                                    Icons.arrow_forward_rounded,
                                                    size: 14,
                                                    color:
                                                        MyrabaColors.textHint),
                                              ),
                                              Text('v₦${req['requestedTag']}',
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          MyrabaColors.orange)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(req['reason'] ?? '—',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: MyrabaColors.textHint)),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _tagDecide(
                                              (req['id'] as num).toInt(),
                                              false),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: MyrabaColors.red),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text('Deny',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: MyrabaColors.red,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _tagDecide(
                                              (req['id'] as num).toInt(), true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: MyrabaColors.teal
                                                  .withValues(alpha: 0.15),
                                              border: Border.all(
                                                  color: MyrabaColors.teal),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text('Approve',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: MyrabaColors.teal,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),

              // ── Sign out ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 40),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _myrabaCard(),
                        child: Column(
                          children: [
                            _consoleStat(
                                'Signed in as',
                                widget.auth.fullName ??
                                    widget.auth.myrabaHandle ??
                                    '—'),
                            _consoleStat('Role', widget.auth.role ?? '—'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout_rounded,
                              color: MyrabaColors.red),
                          label: const Text('Sign Out',
                              style: TextStyle(
                                  color: MyrabaColors.red,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: MyrabaColors.red),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _consoleStat(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: MyrabaColors.textSecond)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    color: MyrabaColors.textPrimary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: MyrabaColors.textSecond,
          letterSpacing: 0.3));
}

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  const _AlertBanner(this.icon, this.color, this.message);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _LiquidityPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LiquidityPanel(this.data);
  @override
  Widget build(BuildContext context) {
    final total =
        double.tryParse(data['totalSystemBalance']?.toString() ?? '0') ?? 0;
    final locked =
        double.tryParse(data['lockedInThrifts']?.toString() ?? '0') ?? 0;
    final avail = total > 0 ? (total - locked) / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
          _myrabaCard(borderColor: MyrabaColors.teal.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Liquidity',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MyrabaColors.textSecond)),
              Text('${(avail * 100).toStringAsFixed(1)}% available',
                  style: const TextStyle(
                      fontSize: 12,
                      color: MyrabaColors.teal,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: avail.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: MyrabaColors.surfaceLine,
              valueColor: const AlwaysStoppedAnimation(MyrabaColors.teal),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _miniLiqStat(
                      'Total',
                      '₦${_fmtMoney(data['totalSystemBalance'])}',
                      MyrabaColors.blue)),
              Expanded(
                  child: _miniLiqStat(
                      'Locked',
                      '₦${_fmtMoney(data['lockedInThrifts'])}',
                      MyrabaColors.gold)),
              Expanded(
                  child: _miniLiqStat(
                      'Free',
                      '₦${_fmtMoney(data['availableLiquidity'])}',
                      MyrabaColors.teal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniLiqStat(String label, String val, Color c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: MyrabaColors.textHint)),
          const SizedBox(height: 2),
          Text(val,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: c)),
        ],
      );
}

class _KpiCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _KpiCard(this.label, this.value, this.icon, this.color, this.sub);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MyrabaColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                Container(
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: MyrabaColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: MyrabaColors.textHint,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(sub,
                    style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      );
}

class _UserListTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  const _UserListTile({required this.user, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final role = user['role'] as String? ?? 'USER';
    final kyc = user['kycStatus'] as String? ?? 'NONE';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _myrabaCard(),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: MyrabaColors.orange.withValues(alpha: 0.12),
              child: Text((user['fullName'] as String? ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MyrabaColors.orange)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['fullName'] ?? '—',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: MyrabaColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                      'v₦${user['myrabaHandle']}  ·  ${user['phone'] ?? user['email'] ?? '—'}',
                      style: const TextStyle(
                          fontSize: 12, color: MyrabaColors.textHint)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _rolePill(role),
                const SizedBox(height: 4),
                _kycPill(kyc),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TxListTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  final VoidCallback? onTap;
  const _TxListTile({required this.tx, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final type = tx['type'] as String? ?? 'TRANSFER';
    final status = tx['status'] as String? ?? '';
    final isSent =
        type == 'TRANSFER' || type == 'WITHDRAWAL' || type == 'DEBIT';
    final color = isSent ? MyrabaColors.orange : MyrabaColors.teal;
    final statColor = _statusColor(status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _myrabaCard(),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_txIcon(type), color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: MyrabaColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    '${tx['senderHandle'] ?? '—'} → ${tx['receiverHandle'] ?? '—'}',
                    style: const TextStyle(
                        fontSize: 11, color: MyrabaColors.textHint),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₦${tx['amount'] ?? '0'}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color)),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: statColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: statColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════

BoxDecoration _myrabaCard({Color? borderColor}) => BoxDecoration(
      color: MyrabaColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? MyrabaColors.surfaceLine),
    );

Widget _rolePill(String role) {
  final colors = {
    'SUPER_ADMIN': MyrabaColors.orange,
    'ADMIN': MyrabaColors.purple,
    'STAFF': MyrabaColors.blue,
    'USER': MyrabaColors.textHint,
  };
  final c = colors[role] ?? MyrabaColors.textHint;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: c.withValues(alpha: 0.35)),
    ),
    child: Text(role.replaceAll('_', ' '),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
  );
}

Widget _kycPill(String kyc) {
  final c = _kycColor(kyc);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(kyc,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
  );
}

Color _kycColor(String status) {
  switch (status) {
    case 'APPROVED':
      return MyrabaColors.teal;
    case 'PENDING':
      return MyrabaColors.gold;
    case 'REJECTED':
      return MyrabaColors.red;
    default:
      return MyrabaColors.textHint;
  }
}

Color _statusColor(String status) {
  switch (status.toUpperCase()) {
    case 'SUCCESS':
      return MyrabaColors.teal;
    case 'PENDING':
      return MyrabaColors.gold;
    case 'FAILED':
      return MyrabaColors.red;
    case 'REVERSED':
      return MyrabaColors.purple;
    default:
      return MyrabaColors.textHint;
  }
}

IconData _txIcon(String type) {
  switch (type) {
    case 'TRANSFER':
      return Icons.swap_horiz_rounded;
    case 'FUNDED':
      return Icons.add_circle_rounded;
    case 'REVERSAL':
      return Icons.undo_rounded;
    case 'WITHDRAWAL':
      return Icons.remove_circle_rounded;
    case 'PAYOUT':
      return Icons.savings_rounded;
    default:
      return Icons.receipt_long_rounded;
  }
}

String _fmt(dynamic v) => v?.toString() ?? '—';

String _fmtMoney(dynamic v) {
  if (v == null) return '0.00';
  final d = double.tryParse(v.toString()) ?? 0;
  if (d >= 1000000000) return '${(d / 1000000000).toStringAsFixed(2)}B';
  if (d >= 1000000) return '${(d / 1000000).toStringAsFixed(2)}M';
  if (d >= 1000) return '${(d / 1000).toStringAsFixed(2)}K';
  return d.toStringAsFixed(2);
}

String _shortDate(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso);
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso.substring(0, iso.length.clamp(0, 16));
  }
}
