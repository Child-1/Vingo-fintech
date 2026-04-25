import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../thrift/thrift_tab.dart';
import 'fixed_deposit_screen.dart';
import '../goals/community_goals_screen.dart';
import 'financial_planner_screen.dart';

class FinancesTab extends StatelessWidget {
  const FinancesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(title: const Text('Finances')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What would you like to do?',
              style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
            const SizedBox(height: 16),
            _FeatureCard(
              icon: Icons.savings_rounded,
              iconColor: MyrabaColors.green,
              title: 'Thrift (Ajo)',
              subtitle: 'Join a rotating savings group and collect your payout.',
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const _ThriftScreen())),
            ),
            const SizedBox(height: 12),
            _FeatureCard(
              icon: Icons.lock_clock_rounded,
              iconColor: MyrabaColors.gold,
              title: 'Fixed Deposits',
              subtitle: 'Lock funds for 30–365 days and earn up to 15% interest p.a.',
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const FixedDepositScreen())),
            ),
            const SizedBox(height: 12),
            _FeatureCard(
              icon: Icons.bar_chart_rounded,
              iconColor: MyrabaColors.teal,
              title: 'Financial Planner',
              subtitle: 'Track spending by category and set monthly budget limits.',
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const FinancialPlannerScreen())),
            ),
            const SizedBox(height: 12),
            _FeatureCard(
              icon: Icons.flag_rounded,
              iconColor: MyrabaColors.purple,
              title: 'Community Goals',
              subtitle: 'Create a shared savings pot. Invite friends to contribute and track progress together.',
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CommunityGoalsScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.mc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.mc.surfaceLine),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w700, color: context.mc.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 12,
                    color: context.mc.textSecond, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: context.mc.textHint),
          ],
        ),
      ),
    );
  }
}

// Wrap ThriftTab content in a standalone Scaffold so it can be pushed
class _ThriftScreen extends StatelessWidget {
  const _ThriftScreen();

  @override
  Widget build(BuildContext context) => const ThriftTab();
}
