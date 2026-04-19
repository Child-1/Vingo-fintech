import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class SendMoneyScreen extends StatefulWidget {
  final String? prefilledHandle;
  const SendMoneyScreen({super.key, this.prefilledHandle});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _recipientCtrl = TextEditingController();
  final _amountCtrl    = TextEditingController();
  final _noteCtrl      = TextEditingController();

  // Top-level: 'app_user' or 'bank'
  String _sendMode  = 'app_user';
  // Within app_user: 'myrabatag' or 'custom'
  String _appMethod = 'myrabatag';

  // Bank transfer verification
  bool _verifying = false;
  Map<String, dynamic>? _verifiedAccount; // {fullName, myrabaHandle, accountNumber}

  bool _loading = false;
  String? _error;
  bool _success = false;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledHandle != null) {
      _recipientCtrl.text = widget.prefilledHandle!;
    }
  }

  @override
  void dispose() {
    _recipientCtrl.dispose(); _amountCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyAccount() async {
    final accountNumber = _recipientCtrl.text.trim();
    if (accountNumber.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit account number');
      return;
    }
    final auth = Provider.of<AuthService>(context, listen: false);
    final api  = ApiService(auth.token!);
    setState(() { _verifying = true; _error = null; _verifiedAccount = null; });
    try {
      final res = await api.lookupAccountByNumber(accountNumber);
      if (!mounted) return;
      if (res.containsKey('fullName')) {
        setState(() { _verifiedAccount = res; _verifying = false; });
      } else {
        setState(() { _error = res['message'] as String? ?? 'Account not found'; _verifying = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Account not found'; _verifying = false; });
    }
  }

  String _friendlyError(String? status) {
    switch (status) {
      case 'INSUFFICIENT_FUNDS':      return 'Insufficient balance. Please fund your wallet first.';
      case 'RECEIVER_NOT_FOUND':      return 'Recipient not found. Check the details and try again.';
      case 'CANNOT_SEND_TO_SELF':     return 'You cannot send money to yourself.';
      case 'RECEIVER_ACCOUNT_FROZEN': return 'This recipient\'s account is currently unavailable.';
      default:                        return 'Transfer failed. Please try again.';
    }
  }

  void _goToConfirm() {
    final recipient = _recipientCtrl.text.trim();
    final amount    = _amountCtrl.text.trim();
    if (recipient.isEmpty) {
      setState(() => _error = 'Please enter a recipient');
      return;
    }
    if (_sendMode == 'bank' && _verifiedAccount == null) {
      setState(() => _error = 'Please verify the account number first');
      return;
    }
    if (amount.isEmpty) {
      setState(() => _error = 'Please enter an amount');
      return;
    }
    final parsed = double.tryParse(amount);
    if (parsed == null || parsed <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() { _confirming = true; _error = null; });
  }

  Future<void> _send() async {
    final recipient = _recipientCtrl.text.trim();
    final amount    = _amountCtrl.text.trim();
    if (recipient.isEmpty || amount.isEmpty) {
      setState(() => _error = 'Please fill in all required fields');
      return;
    }
    final auth = Provider.of<AuthService>(context, listen: false);
    final api  = ApiService(auth.token!);
    setState(() { _loading = true; _error = null; });

    try {
      Map<String, dynamic> res;
      if (_sendMode == 'bank') {
        res = await api.transferByAccount(recipient, amount);
      } else if (_appMethod == 'custom') {
        res = await api.transferByCustomId(recipient, amount);
      } else {
        res = await api.transfer(recipient, amount);
      }

      if (!mounted) return;
      if (res['status'] == 'SUCCESS') {
        setState(() { _success = true; _loading = false; });
      } else {
        setState(() { _error = _friendlyError(res['status']); _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Connection error. Check your internet.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(
        title: Text(_confirming ? 'Confirm Transfer' : 'Send Money'),
        leading: _confirming
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() { _confirming = false; _error = null; }),
              )
            : null,
      ),
      body: _success ? _buildSuccess() : _confirming ? _buildConfirmation() : _buildForm(),
    );
  }

  Widget _buildConfirmation() {
    final recipient = _recipientCtrl.text.trim();
    final amount    = _amountCtrl.text.trim();
    final note      = _noteCtrl.text.trim();

    String recipientLabel;
    if (_sendMode == 'bank' && _verifiedAccount != null) {
      recipientLabel = '${_verifiedAccount!['fullName']} · ${_verifiedAccount!['accountNumber']}';
    } else if (_appMethod == 'myrabatag') {
      recipientLabel = 'm₦ $recipient';
    } else {
      recipientLabel = recipient;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.mc.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.mc.surfaceLine),
            ),
            child: Column(
              children: [
                _confirmRow('Sending to', recipientLabel),
                const Divider(height: 28),
                _confirmRow('Amount', '₦$amount', valueStyle: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: MyrabaColors.gold)),
                if (note.isNotEmpty) ...[
                  const Divider(height: 28),
                  _confirmRow('Note', note),
                ],
                const Divider(height: 28),
                _confirmRow('Transfer type',
                  _sendMode == 'bank' ? 'Bank Transfer' :
                  _appMethod == 'custom' ? 'Custom ID' : 'MyrabaTag'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: MyrabaColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MyrabaColors.gold.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: MyrabaColors.gold, size: 15),
              const SizedBox(width: 8),
              Expanded(child: Text('Please review carefully. Transfers cannot be reversed.',
                style: TextStyle(fontSize: 12, color: MyrabaColors.gold))),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MyrabaColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MyrabaColors.red.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: MyrabaColors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                  style: const TextStyle(color: MyrabaColors.red, fontSize: 13))),
              ]),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loading ? null : _send,
            child: _loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirm & Send'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _loading ? null : () => setState(() { _confirming = false; _error = null; }),
              child: const Text('Edit'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(value,
            textAlign: TextAlign.right,
            style: valueStyle ?? TextStyle(fontSize: 14,
              fontWeight: FontWeight.w600, color: context.mc.textPrimary)),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Who are you sending to? ──────────────────────────────
          Text('Sending to',
            style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _modeCard(
                mode: 'app_user',
                icon: Icons.person_rounded,
                label: 'Myraba User',
                subtitle: 'Send via MyrabaTag or Custom ID',
              )),
              const SizedBox(width: 10),
              Expanded(child: _modeCard(
                mode: 'bank',
                icon: Icons.account_balance_outlined,
                label: 'Bank Transfer',
                subtitle: 'Send via 10-digit account number',
                onTap: () => setState(() {
                  _sendMode = 'bank';
                  _recipientCtrl.clear();
                  _verifiedAccount = null;
                  _error = null;
                }),
              )),
            ],
          ),

          // ── If App User: sub-method selector ─────────────────────
          if (_sendMode == 'app_user') ...[
            SizedBox(height: 20),
            Text('Find recipient by',
              style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
            SizedBox(height: 10),
            Row(
              children: [
                _subChip('myrabatag', 'MyrabaTag'),
                const SizedBox(width: 8),
                _subChip('custom', 'Custom ID'),
              ],
            ),
          ],

          SizedBox(height: 20),
          Text(
            _sendMode == 'bank'
              ? '10-digit Account Number'
              : _appMethod == 'custom'
                ? 'Custom Account ID'
                : 'MyrabaTag',
            style: TextStyle(fontSize: 13, color: context.mc.textSecond),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _recipientCtrl,
            keyboardType: _sendMode == 'bank'
              ? TextInputType.number
              : TextInputType.text,
            onChanged: _sendMode == 'bank'
              ? (_) => setState(() { _verifiedAccount = null; _error = null; })
              : null,
            decoration: InputDecoration(
              hintText: _sendMode == 'bank'
                ? 'e.g. 8012345678'
                : _appMethod == 'custom'
                  ? 'e.g. 5678-smith'
                  : 'e.g. Davinci96',
              prefixText: (_sendMode == 'app_user' && _appMethod == 'myrabatag') ? 'm₦ ' : null,
              prefixStyle: const TextStyle(color: MyrabaColors.green, fontWeight: FontWeight.w700),
              suffixIcon: _sendMode == 'bank'
                ? TextButton(
                    onPressed: _verifying ? null : _verifyAccount,
                    child: _verifying
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: MyrabaColors.green))
                      : const Text('Verify', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MyrabaColors.green)),
                  )
                : null,
            ),
          ),
          if (_sendMode == 'bank' && _verifiedAccount != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MyrabaColors.greenGlow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MyrabaColors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: MyrabaColors.green, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_verifiedAccount!['fullName'] as String? ?? '',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.mc.textPrimary)),
                        Text('m₦${_verifiedAccount!['myrabaHandle']}',
                          style: const TextStyle(fontSize: 11, color: MyrabaColors.green)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 20),
          Text('Amount (₦)',
            style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
          SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '0.00',
              prefixText: '₦ ',
              prefixStyle: TextStyle(color: MyrabaColors.gold, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 20),
          Text('Note (optional)',
            style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
          SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(hintText: 'What is this for?'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MyrabaColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MyrabaColors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: MyrabaColors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                      style: const TextStyle(color: MyrabaColors.red, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: (_loading || (_sendMode == 'bank' && _verifiedAccount == null)) ? null : _goToConfirm,
            child: const Text('Review Transfer'),
          ),
        ],
      ),
    );
  }

  Widget _modeCard({
    required String mode,
    required IconData icon,
    required String label,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final active = _sendMode == mode;
    return GestureDetector(
      onTap: onTap ?? () => setState(() {
        _sendMode = mode;
        _recipientCtrl.clear();
      }),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? MyrabaColors.greenGlow : context.mc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? MyrabaColors.green : context.mc.surfaceLine,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: active ? MyrabaColors.green : context.mc.textHint, size: 20),
            SizedBox(height: 8),
            Text(label,
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: active ? MyrabaColors.green : context.mc.textPrimary,
              )),
            SizedBox(height: 2),
            Text(subtitle,
              style: TextStyle(fontSize: 10, color: context.mc.textHint, height: 1.3)),
          ],
        ),
      ),
    );
  }

  Widget _subChip(String value, String label) {
    final active = _appMethod == value;
    return GestureDetector(
      onTap: () => setState(() { _appMethod = value; _recipientCtrl.clear(); }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? MyrabaColors.greenGlow : context.mc.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? MyrabaColors.green : context.mc.surfaceLine),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? MyrabaColors.green : context.mc.textSecond,
          )),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: MyrabaColors.greenGlow,
                shape: BoxShape.circle,
                border: Border.all(color: MyrabaColors.green),
              ),
              child: Icon(Icons.check_rounded, color: MyrabaColors.green, size: 40),
            ),
            SizedBox(height: 24),
            Text('Money Sent!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                  color: context.mc.textPrimary)),
            SizedBox(height: 10),
            Text('₦${_amountCtrl.text} sent to ${_recipientCtrl.text}',
              style: TextStyle(color: context.mc.textSecond, fontSize: 15),
              textAlign: TextAlign.center),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
