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

  String _method = 'myrabatag'; // vingtag | account | custom
  bool _loading  = false;
  String? _error;
  bool _success  = false;

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
      if (_method == 'myrabatag') {
        res = await api.transfer(recipient, amount);
      } else if (_method == 'account') {
        res = await api.transferByAccount(recipient, amount);
      } else {
        res = await api.transferByCustomId(recipient, amount);
      }

      if (!mounted) return;
      if (res['status'] == 'SUCCESS') {
        setState(() { _success = true; _loading = false; });
      } else {
        setState(() { _error = res['status'] ?? 'Transfer failed'; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Connection error'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyrabaColors.bg,
      appBar: AppBar(title: const Text('Send Money')),
      body: _success ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Method selector
          const Text('Send via', style: TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
          const SizedBox(height: 10),
          Row(
            children: [
              _methodChip('myrabatag', 'MyrabaTag'),
              const SizedBox(width: 8),
              _methodChip('account', 'Account No.'),
              const SizedBox(width: 8),
              _methodChip('custom', 'Custom ID'),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _method == 'myrabatag' ? 'Recipient MyrabaTag'
              : _method == 'account' ? '10-digit Account Number'
              : 'Custom Account ID (e.g. 5678-smith)',
            style: const TextStyle(fontSize: 13, color: MyrabaColors.textSecond),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _recipientCtrl,
            decoration: InputDecoration(
              hintText: _method == 'myrabatag' ? 'e.g. Davinci96'
                : _method == 'account' ? 'e.g. 8012345678'
                : 'e.g. 5678-smith',
              prefixText: _method == 'myrabatag' ? 'v\u20a6 ' : null,
              prefixStyle: const TextStyle(color: MyrabaColors.green, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Amount (₦)', style: TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '0.00',
              prefixText: '₦ ',
              prefixStyle: TextStyle(color: MyrabaColors.gold, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          const Text('Note (optional)', style: TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
          const SizedBox(height: 8),
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
              child: Text(_error!, style: const TextStyle(color: MyrabaColors.red, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loading ? null : _send,
            child: _loading
                ? const SizedBox(height: 22, width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Send Money'),
          ),
        ],
      ),
    );
  }

  Widget _methodChip(String value, String label) {
    final active = _method == value;
    return GestureDetector(
      onTap: () => setState(() { _method = value; _recipientCtrl.clear(); }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? MyrabaColors.greenGlow : MyrabaColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? MyrabaColors.green : MyrabaColors.surfaceLine),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? MyrabaColors.green : MyrabaColors.textSecond,
          ),
        ),
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
              child: const Icon(Icons.check_rounded, color: MyrabaColors.green, size: 40),
            ),
            const SizedBox(height: 24),
            const Text('Money Sent!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: MyrabaColors.textPrimary)),
            const SizedBox(height: 10),
            Text('₦${_amountCtrl.text} sent to ${_recipientCtrl.text}',
              style: const TextStyle(color: MyrabaColors.textSecond, fontSize: 15),
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
