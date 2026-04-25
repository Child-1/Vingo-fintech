import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Displays a user's profile picture, falling back to a DiceBear auto-avatar
/// based on handle (and optionally gender for avatar style).
class UserAvatar extends StatelessWidget {
  final String myrabaHandle;
  final String? profilePicture;
  final String? gender;
  final double size;
  final BoxShape shape;

  const UserAvatar({
    super.key,
    required this.myrabaHandle,
    this.profilePicture,
    this.gender,
    this.size = 48,
    this.shape = BoxShape.circle,
  });

  String get _fallbackUrl {
    // Use avataaars-neutral for male/unset, lorelei for female
    final style = (gender?.toUpperCase() == 'FEMALE') ? 'lorelei' : 'avataaars-neutral';
    final seed = Uri.encodeComponent(myrabaHandle);
    return 'https://api.dicebear.com/9.x/$style/png?seed=$seed&size=200';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = (profilePicture?.isNotEmpty == true) ? profilePicture! : _fallbackUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(size * 0.22) : null,
        color: Colors.grey.shade200,
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => const _AvatarShimmer(),
        errorWidget: (_, __, ___) => Icon(Icons.person, size: size * 0.6, color: Colors.grey),
      ),
    );
  }
}

class _AvatarShimmer extends StatelessWidget {
  const _AvatarShimmer();
  @override
  Widget build(BuildContext context) =>
      Container(color: Colors.grey.shade300);
}

/// Badge chip showing the user's tier label.
class BadgeTierChip extends StatelessWidget {
  final String? tier;
  const BadgeTierChip({super.key, this.tier});

  static const _colors = {
    'Newcomer': Color(0xFF9E9E9E),
    'Bronze':   Color(0xFFCD7F32),
    'Silver':   Color(0xFFA8A9AD),
    'Gold':     Color(0xFFFFD700),
    'Platinum': Color(0xFF00BCD4),
    'Diamond':  Color(0xFF7C4DFF),
    'Elite':    Color(0xFFE91E63),
    'Master':   Color(0xFFFF5722),
    'Legend':   Color(0xFFFF9800),
    'Titan':    Color(0xFF1565C0),
  };

  @override
  Widget build(BuildContext context) {
    final label = tier ?? 'Newcomer';
    final color = _colors[label] ?? const Color(0xFF9E9E9E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.military_tech_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
