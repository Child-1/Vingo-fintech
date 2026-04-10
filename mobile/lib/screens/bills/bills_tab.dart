import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class BillsTab extends StatelessWidget {
  const BillsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyrabaColors.bg,
      appBar: AppBar(
        backgroundColor: MyrabaColors.bg,
        title: const Text('Pay Bills'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('What would you like to pay?',
            style: TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: [
              _BillTile(
                icon: Icons.phone_android_rounded,
                label: 'Airtime',
                color: MyrabaColors.green,
                onTap: () => _push(context, const _AirtimeScreen()),
              ),
              _BillTile(
                icon: Icons.wifi_rounded,
                label: 'Data',
                color: MyrabaColors.blue,
                onTap: () => _push(context, const _DataScreen()),
              ),
              _BillTile(
                icon: Icons.electric_bolt_rounded,
                label: 'Electricity',
                color: MyrabaColors.gold,
                onTap: () => _push(context, const _ElectricityScreen()),
              ),
              _BillTile(
                icon: Icons.tv_rounded,
                label: 'Cable TV',
                color: MyrabaColors.purple,
                onTap: () => _push(context, const _CableScreen()),
              ),
              _BillTile(
                icon: Icons.sports_soccer_rounded,
                label: 'Betting',
                color: MyrabaColors.orange,
                onTap: () => _push(context, const _BettingScreen()),
              ),
              _BillTile(
                icon: Icons.receipt_long_rounded,
                label: 'History',
                color: MyrabaColors.textSecond,
                onTap: () => _push(context, const _BillHistoryScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _BillTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BillTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: myrabaCard(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                  color: MyrabaColors.textSecond)),
          ],
        ),
      ),
    );
  }
}

// ─── Airtime ──────────────────────────────────────────────────────────────────

class _AirtimeScreen extends StatefulWidget {
  const _AirtimeScreen();

  @override
  State<_AirtimeScreen> createState() => _AirtimeScreenState();
}

class _AirtimeScreenState extends State<_AirtimeScreen> {
  final _phoneCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _network   = 'MTN';
  bool _loading     = false;
  bool _success     = false;

  static const _networks = ['MTN', 'Airtel', 'Glo', '9mobile', 'Opay'];

  @override
  void dispose() { _phoneCtrl.dispose(); _amountCtrl.dispose(); super.dispose(); }

  Future<void> _pay() async {
    if (_phoneCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) return;
    final api = ApiService(auth.token!);
    setState(() => _loading = true);
    try {
      final res = await api.buyAirtime(_phoneCtrl.text.trim(), _amountCtrl.text.trim(), _network);
      if (!mounted) return;
      if (res['status'] == 'SUCCESS' || res['code'] == '000') {
        setState(() { _success = true; _loading = false; });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Payment failed'),
              backgroundColor: MyrabaColors.red),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BillScaffold(
      title: 'Buy Airtime',
      icon: Icons.phone_android_rounded,
      color: MyrabaColors.green,
      success: _success,
      successMessage: '₦${_amountCtrl.text} airtime sent to ${_phoneCtrl.text}',
      onDone: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _networkRow(_networks, _network, (v) => setState(() => _network = v)),
          const SizedBox(height: 20),
          _field('Phone Number', _phoneCtrl, TextInputType.phone, 'e.g. 08012345678'),
          const SizedBox(height: 16),
          _field('Amount (₦)', _amountCtrl, TextInputType.number, '0.00'),
          const SizedBox(height: 32),
          _payButton(_loading, _pay, 'Buy Airtime'),
        ],
      ),
    );
  }
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _DataScreen extends StatefulWidget {
  const _DataScreen();

  @override
  State<_DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<_DataScreen> {
  final _phoneCtrl = TextEditingController();
  String _network  = 'MTN';
  String _plan     = '';
  bool _loading    = false;
  bool _success    = false;

  static const _networks = ['MTN', 'Airtel', 'Glo', '9mobile', 'Opay'];
  static const _plans = {
    'MTN':     ['mtn-10mb-100', 'mtn-1gb-300', 'mtn-2gb-500', 'mtn-5gb-1500'],
    'Airtel':  ['airtel-500mb-200', 'airtel-1gb-350', 'airtel-5gb-1500'],
    'Glo':     ['glo-1gb-300', 'glo-2gb-500', 'glo-10gb-2500'],
    '9mobile': ['9mobile-1gb-200', '9mobile-2gb-500'],
    'Opay':    ['opay-1gb-250', 'opay-2gb-450'],
  };

  @override
  void dispose() { _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _pay() async {
    if (_phoneCtrl.text.trim().isEmpty || _plan.isEmpty) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) return;
    final api = ApiService(auth.token!);
    setState(() => _loading = true);
    try {
      final res = await api.buyData(_phoneCtrl.text.trim(), _network, _plan);
      if (!mounted) return;
      if (res['status'] == 'SUCCESS' || res['code'] == '000') {
        setState(() { _success = true; _loading = false; });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed'), backgroundColor: MyrabaColors.red),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans[_network] ?? [];
    return _BillScaffold(
      title: 'Buy Data',
      icon: Icons.wifi_rounded,
      color: MyrabaColors.blue,
      success: _success,
      successMessage: 'Data plan purchased for ${_phoneCtrl.text}',
      onDone: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _networkRow(_networks, _network, (v) => setState(() { _network = v; _plan = ''; })),
          const SizedBox(height: 20),
          _field('Phone Number', _phoneCtrl, TextInputType.phone, 'e.g. 08012345678'),
          const SizedBox(height: 20),
          const Text('Select Plan',
            style: TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: plans.map((p) {
              final active = _plan == p;
              return GestureDetector(
                onTap: () => setState(() => _plan = p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? MyrabaColors.blue.withValues(alpha: 0.15) : MyrabaColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? MyrabaColors.blue : MyrabaColors.surfaceLine),
                  ),
                  child: Text(p,
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: active ? MyrabaColors.blue : MyrabaColors.textSecond,
                    )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          _payButton(_loading, _pay, 'Buy Data'),
        ],
      ),
    );
  }
}

// ─── Electricity ──────────────────────────────────────────────────────────────

class _ElectricityScreen extends StatefulWidget {
  const _ElectricityScreen();

  @override
  State<_ElectricityScreen> createState() => _ElectricityScreenState();
}

class _ElectricityScreenState extends State<_ElectricityScreen> {
  final _meterCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  String _disco     = 'IKEDC';
  String _meterType = 'PREPAID';
  bool _loading     = false;
  bool _success     = false;

  static const _discos = ['IKEDC','EKEDC','AEDC','IBEDC','PHEDC','KEDCO','EEDC'];

  @override
  void dispose() {
    _meterCtrl.dispose(); _amountCtrl.dispose(); _phoneCtrl.dispose(); super.dispose();
  }

  Future<void> _pay() async {
    if (_meterCtrl.text.isEmpty || _amountCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) return;
    final api = ApiService(auth.token!);
    setState(() => _loading = true);
    try {
      final res = await api.payElectricity(
        meterNumber: _meterCtrl.text.trim(),
        disco: _disco, meterType: _meterType,
        amount: _amountCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res['status'] == 'SUCCESS' || res['code'] == '000') {
        setState(() { _success = true; _loading = false; });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed'), backgroundColor: MyrabaColors.red),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BillScaffold(
      title: 'Pay Electricity',
      icon: Icons.electric_bolt_rounded,
      color: MyrabaColors.gold,
      success: _success,
      successMessage: 'Electricity payment successful!',
      onDone: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Distribution Company',
            style: TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _discos.map((d) {
              final active = _disco == d;
              return GestureDetector(
                onTap: () => setState(() => _disco = d),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? MyrabaColors.gold.withValues(alpha: 0.15) : MyrabaColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? MyrabaColors.gold : MyrabaColors.surfaceLine),
                  ),
                  child: Text(d,
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: active ? MyrabaColors.gold : MyrabaColors.textSecond,
                    )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _meterTypeChip('PREPAID', _meterType, (v) => setState(() => _meterType = v))),
              const SizedBox(width: 10),
              Expanded(child: _meterTypeChip('POSTPAID', _meterType, (v) => setState(() => _meterType = v))),
            ],
          ),
          const SizedBox(height: 16),
          _field('Meter Number', _meterCtrl, TextInputType.number, 'e.g. 12345678901'),
          const SizedBox(height: 16),
          _field('Amount (₦)', _amountCtrl, TextInputType.number, '0.00'),
          const SizedBox(height: 16),
          _field('Phone Number', _phoneCtrl, TextInputType.phone, 'e.g. 08012345678'),
          const SizedBox(height: 32),
          _payButton(_loading, _pay, 'Pay Electricity'),
        ],
      ),
    );
  }

  Widget _meterTypeChip(String value, String current, ValueChanged<String> onChanged) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? MyrabaColors.gold.withValues(alpha: 0.15) : MyrabaColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? MyrabaColors.gold : MyrabaColors.surfaceLine),
        ),
        child: Center(
          child: Text(value,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: active ? MyrabaColors.gold : MyrabaColors.textSecond,
            )),
        ),
      ),
    );
  }
}

// ─── Cable TV ─────────────────────────────────────────────────────────────────

class _CableScreen extends StatefulWidget {
  const _CableScreen();

  @override
  State<_CableScreen> createState() => _CableScreenState();
}

class _CableScreenState extends State<_CableScreen> {
  final _cardCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _provider = 'DSTV';
  String _plan     = '';
  bool _loading    = false;
  bool _success    = false;

  static const _providers = ['DSTV', 'GOTV', 'Startimes'];
  static const _plans = {
    'DSTV':      ['dstv-padi', 'dstv-yanga', 'dstv-confam', 'dstv-compact', 'dstv-premium'],
    'GOTV':      ['gotv-lite', 'gotv-value', 'gotv-plus', 'gotv-max'],
    'Startimes': ['st-nova', 'st-basic', 'st-smart', 'st-classic'],
  };

  @override
  void dispose() { _cardCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _pay() async {
    if (_cardCtrl.text.isEmpty || _plan.isEmpty || _phoneCtrl.text.isEmpty) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) return;
    final api = ApiService(auth.token!);
    setState(() => _loading = true);
    try {
      final res = await api.payCable(
        smartCardNumber: _cardCtrl.text.trim(), provider: _provider,
        planCode: _plan, phone: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res['status'] == 'SUCCESS' || res['code'] == '000') {
        setState(() { _success = true; _loading = false; });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed'), backgroundColor: MyrabaColors.red),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans[_provider] ?? [];
    return _BillScaffold(
      title: 'Cable TV',
      icon: Icons.tv_rounded,
      color: MyrabaColors.purple,
      success: _success,
      successMessage: 'Cable subscription successful!',
      onDone: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _networkRow(_providers, _provider, (v) => setState(() { _provider = v; _plan = ''; })),
          const SizedBox(height: 20),
          _field('Smart Card / IUC Number', _cardCtrl, TextInputType.number, 'e.g. 1234567890'),
          const SizedBox(height: 20),
          const Text('Select Plan',
            style: TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: plans.map((p) {
              final active = _plan == p;
              return GestureDetector(
                onTap: () => setState(() => _plan = p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? MyrabaColors.purple.withValues(alpha: 0.15) : MyrabaColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? MyrabaColors.purple : MyrabaColors.surfaceLine),
                  ),
                  child: Text(p,
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: active ? MyrabaColors.purple : MyrabaColors.textSecond,
                    )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _field('Phone Number', _phoneCtrl, TextInputType.phone, 'e.g. 08012345678'),
          const SizedBox(height: 32),
          _payButton(_loading, _pay, 'Pay Cable'),
        ],
      ),
    );
  }
}

// ─── Betting ──────────────────────────────────────────────────────────────────

class _BettingScreen extends StatefulWidget {
  const _BettingScreen();

  @override
  State<_BettingScreen> createState() => _BettingScreenState();
}

class _BettingScreenState extends State<_BettingScreen> {
  final _userIdCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  String _provider  = 'Sportybet';
  bool _loading     = false;
  bool _success     = false;

  static const _providers = ['Sportybet', 'Bet9ja', 'BetKing', '1xBet', 'Betway', 'NairaBet'];

  @override
  void dispose() {
    _userIdCtrl.dispose(); _amountCtrl.dispose(); _phoneCtrl.dispose(); super.dispose();
  }

  Future<void> _pay() async {
    if (_userIdCtrl.text.isEmpty || _amountCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) return;
    final api = ApiService(auth.token!);
    setState(() => _loading = true);
    try {
      final res = await api.fundBetting(
        bettingUserId: _userIdCtrl.text.trim(), provider: _provider,
        amount: _amountCtrl.text.trim(), phone: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res['status'] == 'SUCCESS' || res['code'] == '000') {
        setState(() { _success = true; _loading = false; });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed'), backgroundColor: MyrabaColors.red),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BillScaffold(
      title: 'Fund Betting',
      icon: Icons.sports_soccer_rounded,
      color: MyrabaColors.orange,
      success: _success,
      successMessage: 'Betting account funded successfully!',
      onDone: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _networkRow(_providers, _provider, (v) => setState(() => _provider = v)),
          const SizedBox(height: 20),
          _field('Betting User ID', _userIdCtrl, TextInputType.text, 'Your account ID'),
          const SizedBox(height: 16),
          _field('Amount (₦)', _amountCtrl, TextInputType.number, '0.00'),
          const SizedBox(height: 16),
          _field('Phone Number', _phoneCtrl, TextInputType.phone, 'e.g. 08012345678'),
          const SizedBox(height: 32),
          _payButton(_loading, _pay, 'Fund Account'),
        ],
      ),
    );
  }
}

// ─── Bill History ─────────────────────────────────────────────────────────────

class _BillHistoryScreen extends StatefulWidget {
  const _BillHistoryScreen();

  @override
  State<_BillHistoryScreen> createState() => _BillHistoryScreenState();
}

class _BillHistoryScreenState extends State<_BillHistoryScreen> {
  List<dynamic> _history = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token == null) return;
    final api = ApiService(auth.token!);
    try {
      final res = await api.getBillHistory();
      if (!mounted) return;
      setState(() { _history = (res['payments'] as List?) ?? []; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyrabaColors.bg,
      appBar: AppBar(title: const Text('Bill History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: MyrabaColors.green))
          : _history.isEmpty
              ? const Center(
                  child: Text('No bill payments yet',
                    style: TextStyle(color: MyrabaColors.textHint)))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final b = _history[i] as Map<String, dynamic>;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: myrabaCard(),
                      child: Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: MyrabaColors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.receipt_rounded,
                                color: MyrabaColors.orange, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b['description'] ?? (b['category'] ?? 'Bill'),
                                  style: const TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: MyrabaColors.textPrimary)),
                                Text(b['recipient'] ?? '',
                                  style: const TextStyle(fontSize: 11,
                                      color: MyrabaColors.textHint)),
                              ],
                            ),
                          ),
                          Text('-₦${b['amount']}',
                            style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w700, color: MyrabaColors.red)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _BillScaffold extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool success;
  final String successMessage;
  final VoidCallback onDone;
  final Widget child;
  const _BillScaffold({
    required this.title, required this.icon, required this.color,
    required this.success, required this.successMessage,
    required this.onDone, required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyrabaColors.bg,
      appBar: AppBar(title: Text(title)),
      body: success
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: color),
                      ),
                      child: Icon(icon, color: color, size: 38),
                    ),
                    const SizedBox(height: 24),
                    const Text('Payment Successful!',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text(successMessage,
                      style: const TextStyle(fontSize: 14, color: MyrabaColors.textSecond),
                      textAlign: TextAlign.center),
                    const SizedBox(height: 40),
                    ElevatedButton(onPressed: onDone, child: const Text('Done')),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
    );
  }
}

Widget _networkRow(List<String> options, String current, ValueChanged<String> onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Network / Provider',
        style: TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: options.map((o) {
          final active = current == o;
          return GestureDetector(
            onTap: () => onChanged(o),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? MyrabaColors.greenGlow : MyrabaColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? MyrabaColors.green : MyrabaColors.surfaceLine),
              ),
              child: Text(o,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: active ? MyrabaColors.green : MyrabaColors.textSecond,
                )),
            ),
          );
        }).toList(),
      ),
    ],
  );
}

Widget _field(String label, TextEditingController ctrl, TextInputType type, String hint) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, color: MyrabaColors.textSecond)),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(hintText: hint),
      ),
    ],
  );
}

Widget _payButton(bool loading, VoidCallback onTap, String label) {
  return ElevatedButton(
    onPressed: loading ? null : onTap,
    child: loading
        ? const SizedBox(height: 22, width: 22,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Text(label),
  );
}
