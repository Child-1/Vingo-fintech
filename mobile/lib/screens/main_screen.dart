import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_tab.dart';
import 'thrift/thrift_tab.dart';
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
    ThriftTab(),
    GiftTab(),
    BillsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyrabaColors.bg,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: _BottomNav(
        current: _index,
        onTap: (i) => setState(() => _index = i),
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
        color: MyrabaColors.surface,
        border: Border(top: BorderSide(color: MyrabaColors.surfaceLine.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _item(0, Icons.home_rounded,        Icons.home_outlined,        'Home'),
              _item(1, Icons.savings_rounded,     Icons.savings_outlined,     'Thrift'),
              _item(2, Icons.card_giftcard_rounded,Icons.card_giftcard_outlined,'Gift'),
              _item(3, Icons.receipt_long_rounded, Icons.receipt_long_outlined,'Bills'),
              _item(4, Icons.person_rounded,      Icons.person_outline_rounded,'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int index, IconData activeIcon, IconData inactiveIcon, String label) {
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
              color: active ? MyrabaColors.green : MyrabaColors.textHint,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? MyrabaColors.green : MyrabaColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
