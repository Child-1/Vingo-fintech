import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => const _LegalScreen(
    title: 'Privacy Policy',
    sections: [
      _Section('Introduction', [
        'Myraba ("we", "us", "our") is committed to protecting your personal information. This Privacy Policy explains how we collect, use, and safeguard your data when you use the Myraba app.',
      ]),
      _Section('Information We Collect', [
        'Identity data: full name, date of birth, BVN/NIN for KYC verification.',
        'Contact data: phone number and/or email address.',
        'Financial data: transaction history, wallet balance, gift activity, bill payment records.',
        'Device data: device type, operating system, IP address, and app usage statistics.',
        'Communications: messages sent to our support team.',
      ]),
      _Section('How We Use Your Information', [
        'To provide and improve our financial services.',
        'To verify your identity and comply with Nigerian financial regulations (CBN, NFIU).',
        'To process transactions and prevent fraud.',
        'To send service-related notifications (OTPs, transaction alerts, broadcasts).',
        'To respond to your support requests.',
      ]),
      _Section('Data Sharing', [
        'We do not sell your personal data.',
        'We may share data with: KYC verification providers (Dojah), payment processors (Flutterwave), regulatory authorities when required by law.',
        'All third-party providers are contractually bound to protect your data.',
      ]),
      _Section('Data Retention', [
        'We retain your data for as long as your account is active or as required by Nigerian law (typically 5–7 years for financial records).',
        'You may request deletion of your account; however, transaction records required for regulatory compliance will be retained.',
      ]),
      _Section('Your Rights', [
        'Access: request a copy of the personal data we hold about you.',
        'Correction: ask us to correct inaccurate data.',
        'Deletion: request deletion of your account and non-regulatory data.',
        'Portability: request your transaction history in a standard format.',
        'Contact us at support@myraba.app to exercise any of these rights.',
      ]),
      _Section('Security', [
        'All data is encrypted in transit (TLS) and at rest (AES-256).',
        'Passwords are hashed using BCrypt; we never store plaintext passwords.',
        'We use industry-standard practices to protect against unauthorized access.',
      ]),
      _Section('Changes to This Policy', [
        'We may update this policy periodically. We will notify you of significant changes via in-app notification.',
        'Continued use of the app after changes constitutes acceptance.',
      ]),
      _Section('Contact Us', [
        'Email: support@myraba.app',
        'For data protection enquiries, contact our Data Protection Officer at dpo@myraba.app.',
      ]),
    ],
  );
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _LegalScreen(
    title: 'Terms & Conditions',
    sections: [
      _Section('Acceptance of Terms', [
        'By downloading, registering, or using Myraba, you agree to these Terms and Conditions. If you do not agree, do not use the app.',
      ]),
      _Section('Eligibility', [
        'You must be at least 18 years old and a resident of Nigeria.',
        'You must provide accurate information during registration.',
        'Corporate accounts are not currently supported.',
      ]),
      _Section('Account Responsibilities', [
        'You are responsible for all activity on your account.',
        'Keep your password and transaction PIN confidential.',
        'Notify us immediately at support@myraba.app if you suspect unauthorized access.',
        'Do not share your OTPs with anyone — Myraba staff will never ask for your OTP.',
      ]),
      _Section('Wallet & Transactions', [
        'Your Myraba wallet is not a bank account and does not earn interest unless you use our Fixed Deposit feature.',
        'Transfers are irreversible once completed. Verify recipient details before confirming.',
        'We reserve the right to freeze accounts suspected of fraudulent activity pending investigation.',
        'Daily transaction limits apply as per our current fee schedule.',
      ]),
      _Section('Prohibited Activities', [
        'Money laundering, fraud, or financing illegal activities.',
        'Using the app to deceive or harm other users.',
        'Attempting to reverse-engineer, hack, or exploit the platform.',
        'Creating multiple accounts to abuse referral or promotional schemes.',
      ]),
      _Section('Fees', [
        'We charge a small fee on certain transactions. Current fees are displayed at the point of transaction.',
        'Fees are subject to change with 7 days\' notice via in-app notification.',
      ]),
      _Section('Dispute Resolution', [
        'For transaction disputes, use the Dispute feature in the app within 30 days of the transaction.',
        'Disputes are reviewed within 2–3 business days.',
        'Our decision on disputes is final unless overturned by a Nigerian court of competent jurisdiction.',
      ]),
      _Section('Limitation of Liability', [
        'Myraba is not liable for losses arising from: unauthorized access due to user negligence, force majeure events, third-party service failures, or errors in user-provided information.',
        'Our total liability to you shall not exceed the amount of funds held in your wallet at the time of the claim.',
      ]),
      _Section('Governing Law', [
        'These Terms are governed by the laws of the Federal Republic of Nigeria.',
        'Any disputes shall be resolved in the courts of Lagos State, Nigeria.',
      ]),
      _Section('Contact', [
        'For any questions regarding these terms, contact us at legal@myraba.app.',
      ]),
    ],
  );
}

// ─── Shared layout ─────────────────────────────────────────────────────────────

class _Section {
  final String title;
  final List<String> items;
  const _Section(this.title, this.items);
}

class _LegalScreen extends StatelessWidget {
  final String title;
  final List<_Section> sections;
  const _LegalScreen({super.key, required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        itemCount: sections.length,
        itemBuilder: (context, i) {
          final s = sections[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.mc.textPrimary)),
                const SizedBox(height: 8),
                ...s.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                            color: MyrabaColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item,
                            style: TextStyle(
                                fontSize: 13,
                                color: context.mc.textSecond,
                                height: 1.5)),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          );
        },
      ),
    );
  }
}
