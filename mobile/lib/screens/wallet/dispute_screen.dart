import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class DisputeScreen extends StatefulWidget {
  final Map<String, dynamic>? transaction;
  const DisputeScreen({super.key, this.transaction});

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _disputes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this,
        initialIndex: widget.transaction != null ? 1 : 0);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final api = ApiService(auth.token!);
    try {
      final res = await api.getDisputes();
      if (mounted) {
        setState(() {
          _disputes = List<dynamic>.from(res['disputes'] as List? ?? []);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(
        title: const Text('Disputes'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'My Disputes'), Tab(text: 'File a Dispute')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _myDisputesTab(),
          _fileDisputeTab(),
        ],
      ),
    );
  }

  Widget _myDisputesTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_disputes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.gavel_rounded, size: 48, color: context.mc.textHint),
            const SizedBox(height: 16),
            Text('No disputes filed yet.',
                style: TextStyle(color: context.mc.textSecond)),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _disputes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _disputeTile(_disputes[i]),
      ),
    );
  }

  Widget _disputeTile(dynamic d) {
    final status = d['status'] as String? ?? 'OPEN';
    final reason = d['reason'] as String? ?? '';
    final desc   = d['description'] as String? ?? '';
    final note   = d['adminNote'] as String?;
    final raw    = d['createdAt'] as String?;
    String dateStr = '';
    if (raw != null) {
      try { dateStr = DateFormat('dd MMM yyyy').format(DateTime.parse(raw.toString()).toLocal()); }
      catch (_) {}
    }

    final (color, icon) = switch (status) {
      'RESOLVED' => (MyrabaColors.green, Icons.check_circle_outline_rounded),
      'REJECTED' => (MyrabaColors.red,   Icons.cancel_outlined),
      'REVIEWING'=> (MyrabaColors.gold,  Icons.hourglass_top_rounded),
      _          => (context.mc.textHint, Icons.radio_button_unchecked_rounded),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.mc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.mc.surfaceLine),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(reason.replaceAll('_', ' '),
              style: TextStyle(fontWeight: FontWeight.w700, color: context.mc.textPrimary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(status,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(desc, style: TextStyle(fontSize: 12, color: context.mc.textSecond, height: 1.4)),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MyrabaColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.admin_panel_settings_rounded, size: 14, color: MyrabaColors.gold),
              const SizedBox(width: 6),
              Expanded(child: Text('Admin: $note',
                  style: const TextStyle(fontSize: 11, color: MyrabaColors.gold))),
            ]),
          ),
        ],
        const SizedBox(height: 6),
        Text(dateStr, style: TextStyle(fontSize: 11, color: context.mc.textHint)),
      ]),
    );
  }

  Widget _fileDisputeTab() => _FileDisputeForm(
    transaction: widget.transaction,
    onFiled: () { _load(); _tabs.animateTo(0); },
  );
}

class _FileDisputeForm extends StatefulWidget {
  final Map<String, dynamic>? transaction;
  final VoidCallback onFiled;
  const _FileDisputeForm({this.transaction, required this.onFiled});

  @override
  State<_FileDisputeForm> createState() => _FileDisputeFormState();
}

class _FileDisputeFormState extends State<_FileDisputeForm> {
  final _txCtrl   = TextEditingController();
  final _descCtrl = TextEditingController();
  String _reason  = 'WRONG_TRANSFER';
  bool _loading   = false;
  String? _error;

  static const _reasons = [
    ('WRONG_TRANSFER', 'Wrong Transfer'),
    ('DUPLICATE',      'Duplicate Charge'),
    ('FRAUD',          'Fraud / Unauthorized'),
    ('OTHER',          'Other'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _txCtrl.text = widget.transaction!['id']?.toString() ?? '';
    }
  }

  @override
  void dispose() { _txCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final txId = int.tryParse(_txCtrl.text.trim());
    if (txId == null) { setState(() => _error = 'Enter a valid transaction ID'); return; }
    if (_descCtrl.text.trim().isEmpty) { setState(() => _error = 'Describe the issue'); return; }

    setState(() { _loading = true; _error = null; });
    final auth = Provider.of<AuthService>(context, listen: false);
    final api  = ApiService(auth.token!);
    try {
      await api.fileDispute({
        'transactionId': txId,
        'reason':        _reason,
        'description':   _descCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispute filed successfully!')),
      );
      _txCtrl.clear();
      _descCtrl.clear();
      widget.onFiled();
    } catch (e) {
      setState(() { _error = 'Failed to file dispute. Try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.transaction != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.mc.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.mc.surfaceLine),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_rounded, size: 18, color: MyrabaColors.teal),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Transaction #${widget.transaction!['id']} · ₦${widget.transaction!['amount']}',
                style: TextStyle(fontWeight: FontWeight.w600,
                    color: context.mc.textPrimary, fontSize: 13),
              )),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        Text('Transaction ID',
            style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _txCtrl,
          keyboardType: TextInputType.number,
          enabled: widget.transaction == null,
          decoration: InputDecoration(
            hintText: 'Enter transaction ID',
            prefixIcon: Icon(Icons.tag_rounded, color: context.mc.textHint, size: 20),
          ),
        ),

        const SizedBox(height: 20),
        Text('Reason', style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: context.mc.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.mc.surfaceLine),
          ),
          child: DropdownButton<String>(
            value: _reason,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: context.mc.surface,
            items: _reasons.map((r) => DropdownMenuItem(
              value: r.$1,
              child: Text(r.$2, style: TextStyle(color: context.mc.textPrimary, fontSize: 13)),
            )).toList(),
            onChanged: (v) => setState(() => _reason = v!),
          ),
        ),

        const SizedBox(height: 20),
        Text('Describe the issue',
            style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(height: 8),
        TextField(
          controller: _descCtrl,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Please be as specific as possible…',
            alignLabelWithHint: true, // ignore: prefer_const_constructors
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: MyrabaColors.red, fontSize: 13)),
        ],

        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(_loading ? 'Submitting…' : 'Submit Dispute'),
        ),

        const SizedBox(height: 16),
        Text(
          'Disputes are reviewed within 2–3 business days. You\'ll see the outcome in "My Disputes".',
          style: TextStyle(fontSize: 11, color: context.mc.textHint, height: 1.5),
        ),
      ]),
    );
  }
}
