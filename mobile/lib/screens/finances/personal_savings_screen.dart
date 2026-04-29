import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'savings_goals_tab.dart';
import 'fixed_deposit_screen.dart';

class PersonalSavingsScreen extends StatefulWidget {
  const PersonalSavingsScreen({super.key});

  @override
  State<PersonalSavingsScreen> createState() => _PersonalSavingsScreenState();
}

class _PersonalSavingsScreenState extends State<PersonalSavingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
      appBar: AppBar(
        title: const Text('Personal Savings'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: MyrabaColors.green,
          labelColor: MyrabaColors.green,
          unselectedLabelColor: context.mc.textHint,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'My Goals'),
            Tab(text: 'Lock Funds'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          SavingsGoalsTab(),
          _FixedDepositTab(),
        ],
      ),
    );
  }
}

// Wrap FixedDepositScreen body content without its own Scaffold/AppBar
class _FixedDepositTab extends StatelessWidget {
  const _FixedDepositTab();
  @override
  Widget build(BuildContext context) => const FixedDepositScreen(embedded: true);
}
