import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'home_tab.dart';
import 'finances/finances_tab.dart';
import 'gift/gift_tab.dart';
import 'bills/bills_tab.dart';
import 'profile/profile_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  final _tabs = const [
    HomeTab(),
    FinancesTab(),
    GiftTab(),
    BillsTab(),
    ProfileTab(),
  ];

  void _showKycRequired(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).extension<MyrabaColorScheme>()?.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        final mc = Theme.of(context).extension<MyrabaColorScheme>() ?? MyrabaColorScheme.dark;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: mc.surfaceLine,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: MyrabaColors.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, color: MyrabaColors.orange, size: 30),
              ),
              const SizedBox(height: 16),
              Text('Identity Verification Required',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: mc.textPrimary)),
              const SizedBox(height: 10),
              Text(
                'This feature is locked until you complete KYC verification.\n\nGo to Profile → KYC Verification to unlock all of Myraba.',
                style: TextStyle(fontSize: 13, color: mc.textHint, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _index = 4); // jump to Profile tab
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyrabaColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Go to Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: _BottomNav(
        current: _index,
        onTap: (i) {
          // Tabs 1 (Thrift), 2 (Gift), 3 (Bills) require KYC
          const kycGated = {1, 2, 3};
          if (kycGated.contains(i)) {
            final auth = Provider.of<AuthService>(context, listen: false);
            if (!auth.isKycApproved) {
              _showKycRequired(context);
              return;
            }
          }
          setState(() => _index = i);
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.mc.surface,
        border: Border(top: BorderSide(color: context.mc.surfaceLine.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _item(context, 0, Icons.home_rounded,        Icons.home_outlined,        'Home'),
              _item(context, 1, Icons.savings_rounded,     Icons.savings_outlined,     'Finances'),
              _item(context, 2, Icons.card_giftcard_rounded,Icons.card_giftcard_outlined,'Gift'),
              _item(context, 3, Icons.receipt_long_rounded, Icons.receipt_long_outlined,'Bills'),
              _item(context, 4, Icons.person_rounded,      Icons.person_outline_rounded,'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final active = current == index;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : inactiveIcon,
              color: active ? MyrabaColors.green : context.mc.textHint,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? MyrabaColors.green : context.mc.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
