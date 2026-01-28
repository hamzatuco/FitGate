import 'package:flutter/material.dart';

/// Status badge widget
/// Shows member or locker status with appropriate colors
class StatusBadge extends StatelessWidget {
  final String status; // 'active', 'occupied', 'free', 'expired', 'suspended', 'out_of_service'
  final bool compact; // If true, shows smaller badge

  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  Color _getBackgroundColor() {
    switch (status.toLowerCase()) {
      case 'active':
      case 'free':
        return const Color(0xFFDEF9EC); // Light green
      case 'occupied':
        return const Color(0xFFFEF3C7); // Light orange
      case 'expired':
      case 'out_of_service':
        return const Color(0xFFEF4444); // Red
      case 'suspended':
        return const Color(0xFFF3F4F6); // Gray
      default:
        return Colors.grey[100]!;
    }
  }

  Color _getTextColor() {
    switch (status.toLowerCase()) {
      case 'active':
      case 'free':
        return const Color(0xFF047857); // Dark green
      case 'occupied':
        return const Color(0xFFB45309); // Dark orange
      case 'expired':
      case 'out_of_service':
        return const Color(0xFFDC2626); // Dark red
      case 'suspended':
        return const Color(0xFF6B7280); // Dark gray
      default:
        return Colors.black54;
    }
  }

  String _getDisplayText() {
    return status[0].toUpperCase() + status.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _getDisplayText(),
        style: TextStyle(
          fontSize: compact ? 11 : 13,
          fontWeight: FontWeight.w600,
          color: _getTextColor(),
        ),
      ),
    );
  }
}
