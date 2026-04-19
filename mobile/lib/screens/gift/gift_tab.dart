import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

// ─── Category colour palette ────────────────────────────────────
const _catColors = [
  Color(0xFF9333EA),
  Color(0xFFF26522),
  Color(0xFF10B981),
  Color(0xFF3B82F6),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF06B6D4),
  Color(0xFFEC4899),
];
const _catEmojis = [
  '🎁',
  '🌹',
  '🎂',
  '💎',
  '☕',
  '🎮',
  '✈️',
  '💝',
  '🥂',
  '🎨',
  '🎵',
  '🍫'
];

class GiftTab extends StatefulWidget {
  const GiftTab({super.key});
  @override
  State<GiftTab> createState() => _GiftTabState();
}

class _GiftTabState extends State<GiftTab> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      body: Column(
        children: [
          _GiftHeader(tabController: _tabs),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _SendGiftTab(),
                _ReceivedGiftsTab(),
                _GiftBalanceTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HEADER WITH GRADIENT
// ═══════════════════════════════════════════════════════════════════
class _GiftHeader extends StatelessWidget {
  final TabController tabController;
  const _GiftHeader({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0A2E), Color(0xFF200A18), Color(0xFF0C0A18)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [Color(0xFF9333EA), Color(0xFFF26522)],
                    ).createShader(b),
                    child: const Text('Gifts',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        )),
                  ),
                  const SizedBox(width: 8),
                  const Text('✨', style: TextStyle(fontSize: 20)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF9333EA), Color(0xFFF26522)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Send',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              height: 44,
              decoration: BoxDecoration(
                color: context.mc.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.mc.surfaceLine),
              ),
              child: TabBar(
                controller: tabController,
                indicator: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF9333EA), Color(0xFFF26522)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: context.mc.textHint,
                labelStyle:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: '🎁 Send'),
                  Tab(text: '💌 Received'),
                  Tab(text: '💰 Balance'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 1 — SEND GIFT
// ═══════════════════════════════════════════════════════════════════
class _SendGiftTab extends StatefulWidget {
  const _SendGiftTab();
  @override
  State<_SendGiftTab> createState() => _SendGiftTabState();
}

class _SendGiftTabState extends State<_SendGiftTab> {
  int _step = 0;
  final _recipCtrl = TextEditingController();
  String? _recipient;

  List<dynamic> _categories = [];
  Map<String, dynamic>? _selCategory;

  List<dynamic> _items = [];
  Map<String, dynamic>? _selItem;

  final _noteCtrl = TextEditingController();
  bool _anonymous = false;
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  @override
  void dispose() {
    _recipCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final api = ApiService(auth.token ?? '');
      final res = await api.getGiftCategories();
      if (!mounted) return;
      final list = res['categories'] as List? ?? res['data'] as List? ?? [];
      setState(() {
        _categories = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadItems(int categoryId) async {
    setState(() {
      _loading = true;
      _items = [];
    });
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final api = ApiService(auth.token ?? '');
      final res = await api.getGiftItems(categoryId);
      if (!mounted) return;
      final list = res['items'] as List? ?? res['data'] as List? ?? [];
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendGift() async {
    if (_recipient == null || _selItem == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final api = ApiService(auth.token ?? '');
      await api.sendGift(
        recipientMyrabaHandle: _recipient!,
        giftItemId: (_selItem!['id'] as num).toInt(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        anonymous: _anonymous,
      );
      if (!mounted) return;
      setState(() {
        _sent = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      String msg = 'Could not send gift. Please try again.';
      final raw = e.toString();
      if (raw.contains('Exception: ')) {
        msg = raw.replaceFirst('Exception: ', '');
      }
      setState(() {
        _error = msg;
        _loading = false;
      });
    }
  }

  void _reset() => setState(() {
        _step = 0;
        _recipient = null;
        _selCategory = null;
        _selItem = null;
        _sent = false;
        _error = null;
        _anonymous = false;
        _recipCtrl.clear();
        _noteCtrl.clear();
      });

  @override
  Widget build(BuildContext context) {
    if (_sent) return _SentSuccess(onSendAnother: _reset);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        _StepIndicator(step: _step),
        const SizedBox(height: 20),

        // ── Step 0: Recipient ────────────────────────────────────
        _StepCard(
          step: 0,
          currentStep: _step,
          title: 'Who are you gifting?',
          emoji: '🎯',
          doneLabel: _recipient != null ? 'v₦$_recipient' : null,
          onEdit: _recipient != null
              ? () => setState(() {
                    _step = 0;
                    _recipient = null;
                  })
              : null,
          child: Column(
            children: [
              TextField(
                controller: _recipCtrl,
                style: TextStyle(color: context.mc.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter VingTag (e.g. Davinci96)',
                  hintStyle: TextStyle(color: context.mc.textHint),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: context.mc.textHint),
                  prefixText: 'v₦ ',
                  prefixStyle: TextStyle(
                      color: MyrabaColors.purple, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              _GradientButton(
                label: 'Continue',
                onTap: () {
                  final v = _recipCtrl.text.trim();
                  if (v.isEmpty) return;
                  setState(() {
                    _recipient = v;
                    _step = 1;
                  });
                },
              ),
            ],
          ),
        ),

        if (_step >= 1) ...[
          const SizedBox(height: 12),
          _StepCard(
            step: 1,
            currentStep: _step,
            title: 'Choose a category',
            emoji: '🏷️',
            doneLabel: _selCategory?['name']?.toString(),
            onEdit: _selCategory != null
                ? () => setState(() {
                      _step = 1;
                      _selCategory = null;
                      _selItem = null;
                    })
                : null,
            child: _loading && _categories.isEmpty
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                            color: MyrabaColors.purple)))
                : _categories.isEmpty
                    ? const _EmptyPlaceholder(
                        'No gift categories available yet 😢')
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _categories.length,
                        itemBuilder: (ctx, i) {
                          final cat = _categories[i] as Map<String, dynamic>;
                          final color = _catColors[i % _catColors.length];
                          final emoji = _catEmojis[i % _catEmojis.length];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selCategory = cat;
                                _step = 2;
                              });
                              _loadItems((cat['id'] as num).toInt());
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.35)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(emoji,
                                      style: const TextStyle(fontSize: 28)),
                                  const SizedBox(height: 6),
                                  Text(cat['name']?.toString() ?? '',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: color),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],

        if (_step >= 2) ...[
          const SizedBox(height: 12),
          _StepCard(
            step: 2,
            currentStep: _step,
            title: 'Pick a gift',
            emoji: '✨',
            doneLabel: _selItem?['name']?.toString(),
            onEdit: _selItem != null
                ? () => setState(() {
                      _step = 2;
                      _selItem = null;
                    })
                : null,
            child: _loading
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                            color: MyrabaColors.orange)))
                : _items.isEmpty
                    ? const _EmptyPlaceholder(
                        'No items in this category yet 😢')
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final item = _items[i] as Map<String, dynamic>;
                          final price = (item['nairaValue'] ?? item['price'])?.toString() ?? '0';
                          final catIdx = _categories.indexWhere(
                              (c) => c['id'] == _selCategory?['id']);
                          final color = catIdx >= 0
                              ? _catColors[catIdx % _catColors.length]
                              : MyrabaColors.orange;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selItem = item;
                              _step = 3;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                        child: Text(
                                      _catEmojis[i % _catEmojis.length],
                                      style: TextStyle(fontSize: 24),
                                    )),
                                  ),
                                  SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item['name']?.toString() ?? '—',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    context.mc.textPrimary)),
                                        if ((item['description'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          Text(item['description'].toString(),
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: context.mc.textHint),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('₦$price',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: color)),
                                      Icon(Icons.chevron_right_rounded,
                                          color: context.mc.textHint,
                                          size: 18),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],

        if (_step >= 3 && _selItem != null) ...[
          const SizedBox(height: 12),
          _StepCard(
            step: 3,
            currentStep: _step,
            title: 'Almost done!',
            emoji: '🚀',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gift summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      MyrabaColors.purple.withValues(alpha: 0.2),
                      MyrabaColors.orange.withValues(alpha: 0.15),
                    ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: MyrabaColors.purple.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Text('🎁', style: TextStyle(fontSize: 36)),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selItem!['name']?.toString() ?? '—',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: context.mc.textPrimary)),
                            SizedBox(height: 4),
                            Row(children: [
                              Text('To: ',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: context.mc.textHint)),
                              Text('v₦$_recipient',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: MyrabaColors.purple)),
                            ]),
                          ],
                        ),
                      ),
                      Text('₦${_selItem!['nairaValue'] ?? _selItem!['price'] ?? '0'}',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: MyrabaColors.orange)),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text('Add a message (optional)',
                    style: TextStyle(
                        fontSize: 13,
                        color: context.mc.textSecond,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  maxLength: 140,
                  style: TextStyle(
                      color: context.mc.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Write something heartfelt… 💬',
                    hintStyle: TextStyle(color: context.mc.textHint),
                    counterStyle: TextStyle(color: context.mc.textHint),
                  ),
                ),
                SizedBox(height: 12),
                // Anonymous toggle
                GestureDetector(
                  onTap: () => setState(() => _anonymous = !_anonymous),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _anonymous
                          ? MyrabaColors.purple.withValues(alpha: 0.12)
                          : context.mc.surfaceHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _anonymous
                            ? MyrabaColors.purple.withValues(alpha: 0.5)
                            : context.mc.surfaceLine,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(_anonymous ? '🕵️' : '😊',
                            style: TextStyle(fontSize: 20)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Send anonymously',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _anonymous
                                          ? MyrabaColors.purple
                                          : context.mc.textPrimary)),
                              Text("They won't see your name",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: context.mc.textHint)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _anonymous,
                          onChanged: (v) => setState(() => _anonymous = v),
                          activeThumbColor: MyrabaColors.purple,
                          trackColor: WidgetStateProperty.resolveWith((s) =>
                              s.contains(WidgetState.selected)
                                  ? MyrabaColors.purple.withValues(alpha: 0.3)
                                  : context.mc.surfaceLine),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MyrabaColors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: MyrabaColors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: MyrabaColors.red, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 20),
                _GradientButton(
                  label: _loading ? 'Sending…' : 'Send Gift 🎁',
                  onTap: _loading ? null : _sendGift,
                  loading: _loading,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SENT SUCCESS
// ═══════════════════════════════════════════════════════════════════
class _SentSuccess extends StatefulWidget {
  final VoidCallback onSendAnother;
  const _SentSuccess({required this.onSendAnother});
  @override
  State<_SentSuccess> createState() => _SentSuccessState();
}

class _SentSuccessState extends State<_SentSuccess>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale, _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9333EA), Color(0xFFF26522)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: MyrabaColors.purple.withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 10)
                    ],
                  ),
                  child: const Center(
                      child: Text('🎁', style: TextStyle(fontSize: 52))),
                ),
                const SizedBox(height: 28),
                ShaderMask(
                  shaderCallback: (b) => LinearGradient(
                    colors: [Color(0xFF9333EA), Color(0xFFF26522)],
                  ).createShader(b),
                  child: Text('Gift Sent! 🎉',
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
                SizedBox(height: 12),
                Text(
                    "Your gift is on its way.\nThey're going to love it! ✨",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        color: context.mc.textSecond,
                        height: 1.5)),
                SizedBox(height: 36),
                _GradientButton(
                    label: 'Send Another Gift', onTap: widget.onSendAnother),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 2 — RECEIVED GIFTS
// ═══════════════════════════════════════════════════════════════════
class _ReceivedGiftsTab extends StatefulWidget {
  const _ReceivedGiftsTab();
  @override
  State<_ReceivedGiftsTab> createState() => _ReceivedGiftsTabState();
}

class _ReceivedGiftsTabState extends State<_ReceivedGiftsTab> {
  List<dynamic> _gifts = [];
  bool _loading = true;
  int _newCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final api  = ApiService(auth.token ?? '');
      final res  = await api.getReceivedGifts();
      if (!mounted) return;
      final list = res['gifts'] as List? ?? res['data'] as List? ?? [];

      final prefs   = await SharedPreferences.getInstance();
      final lastSeen = prefs.getInt('lastSeenGiftCount') ?? 0;
      final newCount = (list.length - lastSeen).clamp(0, list.length);

      setState(() {
        _gifts    = list;
        _newCount = newCount;
        _loading  = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSeenGiftCount', _gifts.length);
    if (mounted) setState(() => _newCount = 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: MyrabaColors.purple));
    }
    if (_gifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎁', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text('No gifts yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: context.mc.textPrimary)),
            SizedBox(height: 8),
            Text('When someone sends you a gift,\nit will appear here ✨',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.mc.textHint, height: 1.5)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: MyrabaColors.purple,
      backgroundColor: context.mc.surface,
      child: Column(
        children: [
          // ── New gift notification banner ──────────────────────────
          if (_newCount > 0)
            GestureDetector(
              onTap: _markAllSeen,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: MyrabaColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MyrabaColors.purple.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$_newCount new gift${_newCount > 1 ? 's' : ''} received!',
                        style: const TextStyle(
                            color: MyrabaColors.purple,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ),
                    const Icon(Icons.close_rounded, color: MyrabaColors.purple, size: 18),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _gifts.length,
        separatorBuilder: (_, __) => SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final g = _gifts[i] as Map<String, dynamic>;
          final color = _catColors[i % _catColors.length];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.mc.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16)),
                  child: Center(
                      child: Text(_catEmojis[i % _catEmojis.length],
                          style: TextStyle(fontSize: 28))),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g['giftItemName']?.toString() ?? 'Gift',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.mc.textPrimary)),
                      SizedBox(height: 4),
                      Text(
                        g['anonymous'] == true
                            ? 'From: 🕵️ Anonymous'
                            : 'From: v₦${g['senderMyrabaHandle'] ?? '—'}',
                        style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600),
                      ),
                      if ((g['note'] ?? '').toString().isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text('"${g['note']}"',
                            style: TextStyle(
                                fontSize: 12,
                                color: context.mc.textHint,
                                fontStyle: FontStyle.italic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                Text('₦${g['value'] ?? g['price'] ?? '0'}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ],
            ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 3 — GIFT BALANCE
// ═══════════════════════════════════════════════════════════════════
class _GiftBalanceTab extends StatefulWidget {
  const _GiftBalanceTab();
  @override
  State<_GiftBalanceTab> createState() => _GiftBalanceTabState();
}

class _GiftBalanceTabState extends State<_GiftBalanceTab> {
  Map<String, dynamic>? _balance;
  bool _loading = true, _converting = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final api = ApiService(auth.token ?? '');
      final res = await api.getGiftBalance();
      if (!mounted) return;
      setState(() {
        _balance = res;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _convert() async {
    final amount = _balance?['balance']?.toString() ?? '0';
    if (amount == '0' || amount == '0.0' || amount == '0.00') return;
    setState(() {
      _converting = true;
      _msg = null;
    });
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final api = ApiService(auth.token ?? '');
      await api.convertGiftBalance(amount);
      if (!mounted) return;
      setState(() {
        _msg = 'Converted ₦$amount to your wallet!';
        _converting = false;
      });
      _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _msg = 'Conversion failed. Try again.';
          _converting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: MyrabaColors.purple));
    }

    final balance = _balance?['balance']?.toString() ?? '0.00';
    final totalReceived = _balance?['totalReceived']?.toString() ?? '0.00';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A0840), Color(0xFF2D1420)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: MyrabaColors.purple.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: MyrabaColors.purple.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: Offset(0, 8))
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🎀 Gift Balance',
                          style: TextStyle(
                              fontSize: 14,
                              color: context.mc.textHint,
                              fontWeight: FontWeight.w500)),
                      SizedBox(height: 4),
                      Text('Available to convert',
                          style: TextStyle(
                              fontSize: 12, color: context.mc.textHint)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20),
              ShaderMask(
                shaderCallback: (b) => LinearGradient(
                  colors: [Color(0xFF9333EA), Color(0xFFF26522)],
                ).createShader(b),
                child: Text('₦$balance',
                    style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ),
              SizedBox(height: 8),
              Text('Total received: ₦$totalReceived',
                  style: TextStyle(
                      fontSize: 13, color: context.mc.textHint)),
              SizedBox(height: 24),
              if (_msg != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _msg!.contains('wallet')
                        ? MyrabaColors.teal.withValues(alpha: 0.15)
                        : MyrabaColors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_msg!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: _msg!.contains('wallet')
                              ? MyrabaColors.teal
                              : MyrabaColors.red)),
                ),
              ],
              _GradientButton(
                label: _converting ? 'Converting…' : 'Convert to Wallet 💸',
                onTap: _converting ? null : _convert,
                loading: _converting,
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
        Text('What is Gift Balance?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.mc.textPrimary)),
        SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: context.mc.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.mc.surfaceLine)),
          child: Column(
            children: [
              _InfoPoint('🎁',
                  'When someone sends you a gift, its value is added to your Gift Balance.'),
              SizedBox(height: 10),
              _InfoPoint('💸',
                  'Convert your Gift Balance to real money in your Myraba Wallet anytime.'),
              SizedBox(height: 10),
              _InfoPoint(
                  '✨', 'Gift Balance is separate from your wallet balance.'),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════

class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});
  @override
  Widget build(BuildContext context) {
    const labels = ['Recipient', 'Category', 'Item', 'Confirm'];
    return Row(
      children: List.generate(labels.length, (i) {
        final done = i < step;
        final active = i == step;
        final color = active
            ? MyrabaColors.orange
            : done
                ? MyrabaColors.teal
                : context.mc.surfaceLine;
        return Expanded(
          child: Row(children: [
            if (i > 0)
              Expanded(
                  child: Container(
                      height: 2,
                      color:
                          done ? MyrabaColors.teal : context.mc.surfaceLine)),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Center(
                  child: done
                      ? Icon(Icons.check_rounded,
                          size: 14, color: MyrabaColors.teal)
                      : Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color))),
            ),
            if (i < labels.length - 1)
              Expanded(
                  child: Container(
                      height: 2,
                      color:
                          done ? MyrabaColors.teal : context.mc.surfaceLine)),
          ]),
        );
      }),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int step, currentStep;
  final String title, emoji;
  final String? doneLabel;
  final VoidCallback? onEdit;
  final Widget? child;
  const _StepCard(
      {required this.step,
      required this.currentStep,
      required this.title,
      required this.emoji,
      this.doneLabel,
      this.onEdit,
      this.child});

  @override
  Widget build(BuildContext context) {
    final isActive = step == currentStep;
    final isDone = doneLabel != null && step < currentStep;
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: context.mc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? MyrabaColors.orange.withValues(alpha: 0.5)
              : isDone
                  ? MyrabaColors.teal.withValues(alpha: 0.3)
                  : context.mc.surfaceLine,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: MyrabaColors.orange.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4))
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(emoji, style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.mc.textPrimary)),
              Spacer(),
              if (isDone && onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: MyrabaColors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_rounded,
                          color: MyrabaColors.teal, size: 12),
                      const SizedBox(width: 4),
                      Text(doneLabel!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: MyrabaColors.teal,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ),
            ]),
            if (isActive && child != null) ...[
              const SizedBox(height: 16),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  const _GradientButton(
      {required this.label, required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.6 : 1.0,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: onTap == null
                ? const LinearGradient(
                    colors: [Color(0xFF555555), Color(0xFF444444)])
                : const LinearGradient(
                    colors: [Color(0xFF9333EA), Color(0xFFF26522)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: onTap != null
                ? [
                    BoxShadow(
                        color: MyrabaColors.purple.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6))
                  ]
                : null,
          ),
          child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800))),
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final String message;
  const _EmptyPlaceholder(this.message);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
            child: Text(message,
                style:
                    TextStyle(color: context.mc.textHint, fontSize: 14),
                textAlign: TextAlign.center)),
      );
}

class _InfoPoint extends StatelessWidget {
  final String emoji, text;
  const _InfoPoint(this.emoji, this.text);
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: TextStyle(fontSize: 16)),
          SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13,
                      color: context.mc.textSecond,
                      height: 1.4))),
        ],
      );
}
