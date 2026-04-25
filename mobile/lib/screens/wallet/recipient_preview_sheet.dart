import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';

/// Bottom sheet shown after a recipient is looked up — lets the user confirm
/// they're sending to the right person before the amount confirmation screen.
class RecipientPreviewSheet extends StatelessWidget {
  final Map<String, dynamic> recipient;
  final VoidCallback onConfirm;

  const RecipientPreviewSheet({
    super.key,
    required this.recipient,
    required this.onConfirm,
  });

  static Future<bool> show(
    BuildContext context,
    Map<String, dynamic> recipient,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecipientPreviewSheet(
        recipient: recipient,
        onConfirm: () => Navigator.pop(context, true),
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final handle    = recipient['myrabaHandle'] as String? ?? '';
    final tag       = recipient['myrabaTag'] as String? ?? 'm₦$handle';
    final fullName  = recipient['fullName'] as String? ?? handle;
    final picture   = recipient['profilePicture'] as String?;
    final gender    = recipient['gender'] as String?;
    final badge     = recipient['badgeTier'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: context.mc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: context.mc.surfaceLine,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text('Sending to', style: TextStyle(fontSize: 13, color: context.mc.textSecond)),
          const SizedBox(height: 20),

          UserAvatar(
            myrabaHandle: handle,
            profilePicture: picture,
            gender: gender,
            size: 88,
          ),
          const SizedBox(height: 14),

          Text(fullName,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                color: context.mc.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(tag,
            style: TextStyle(fontSize: 14, color: context.mc.textSecond),
          ),
          const SizedBox(height: 10),
          BadgeTierChip(tier: badge),
          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: context.mc.surfaceLine),
                  ),
                  child: Text('Cancel',
                    style: TextStyle(color: context.mc.textSecond)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: context.mc.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Confirm',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
