import 'package:flutter/material.dart';

class LevelBadgeWidget extends StatelessWidget {
  final String levelKey; // 'bronze','silver','gold','platinum','legendary'
  final String nameAr;
  final double size;

  const LevelBadgeWidget({
    super.key,
    required this.levelKey,
    required this.nameAr,
    this.size = 24,
  });

  Color get _levelColor {
    switch (levelKey.toLowerCase()) {
      case 'bronze':
        return const Color(0xFFCD7F32);
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'gold':
        return const Color(0xFFFFD700);
      case 'platinum':
        return const Color(0xFFE5E4E2);
      case 'legendary':
        return const Color(0xFF9B59B6);
      default:
        return Colors.grey;
    }
  }

  IconData get _levelIcon {
    switch (levelKey.toLowerCase()) {
      case 'legendary':
        return Icons.auto_awesome_rounded;
      case 'platinum':
        return Icons.diamond_rounded;
      case 'gold':
        return Icons.workspace_premium_rounded;
      case 'silver':
        return Icons.shield_rounded;
      case 'bronze':
      default:
        return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: nameAr,
      child: Icon(
        _levelIcon,
        color: _levelColor,
        size: size,
        shadows: [
          Shadow(
            color: _levelColor.withOpacity(0.4),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
