import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class FundWalletScreen extends StatefulWidget {
  final String myrabaHandle;
  const FundWalletScreen({super.key, required this.myrabaHandle});

  @override
  State<FundWalletScreen> createState() => _FundWalletScreenState();
}

class _FundWalletScreenState extends State<FundWalletScreen> {
  final _amountCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _success = false;

  final _quickAmounts = ['1000', '2000', '5000', '10000', '20000', '50000'];

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _fund() async {
    final amount = _amountCtrl.text.trim();
    if (amount.isEmpty) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    final auth = Provider.of<AuthService>(context, listen: false);
    final api = ApiService(auth.token!);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await api.fundWallet(widget.myrabaHandle, amount);
      if (!mounted) return;
      if (res.containsKey('balance') ||
          (res['message']?.toString().contains('success') ?? false)) {
        setState(() {
          _success = true;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Funding failed. Try again.';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Connection error';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(title: Text('Fund Wallet')),
      body: _success ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: context.mc.card(),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: MyrabaColors.blue, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Funds are added to your Myraba wallet. '
                    'For live funding via card/bank, Flutterwave integration applies.',
                    style:
                        TextStyle(fontSize: 12, color: context.mc.textSecond),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 28),
          Text('Quick amounts',
              style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
          SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _quickAmounts
                .map((a) => GestureDetector(
                      onTap: () => setState(() => _amountCtrl.text = a),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _amountCtrl.text == a
                              ? MyrabaColors.greenGlow
                              : context.mc.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _amountCtrl.text == a
                                  ? MyrabaColors.green
                                  : context.mc.surfaceLine),
                        ),
                        child: Text(
                          '₦${_fmt(a)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _amountCtrl.text == a
                                ? MyrabaColors.green
                                : context.mc.textPrimary,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          SizedBox(height: 24),
          Text('Or enter amount',
              style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
          SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '0.00',
              prefixText: '₦ ',
              prefixStyle: TextStyle(
                  color: MyrabaColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 18),
            ),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!,
                style: const TextStyle(color: MyrabaColors.red, fontSize: 13)),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loading ? null : _fund,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Fund Wallet'),
          ),
        ],
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: MyrabaColors.greenGlow,
                shape: BoxShape.circle,
                border: Border.all(color: MyrabaColors.green),
              ),
              child: const Icon(Icons.check_rounded,
                  color: MyrabaColors.green, size: 40),
            ),
            SizedBox(height: 24),
            Text('Wallet Funded!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            SizedBox(height: 10),
            Text('₦${_amountCtrl.text} added to your wallet',
                style: TextStyle(
                    color: context.mc.textSecond, fontSize: 15)),
            SizedBox(height: 40),
            ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done')),
          ],
        ),
      ),
    );
  }

  String _fmt(String amount) {
    final n = int.tryParse(amount);
    if (n == null) return amount;
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return amount;
  }
}
