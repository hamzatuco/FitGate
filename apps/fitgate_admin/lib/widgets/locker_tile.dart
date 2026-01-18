import 'package:flutter/material.dart';

/// Locker tile for grid display
/// Shows locker number, status, and assigned member
class LockerTile extends StatelessWidget {
  final String lockerNumber;
  final String sector;
  final String status; // 'free', 'occupied', 'out_of_service'
  final String? assignedMember;
  final VoidCallback? onTap;
  final VoidCallback? onForceRelease;
  final VoidCallback? onMarkOutOfService;

  const LockerTile({
    Key? key,
    required this.lockerNumber,
    required this.sector,
    required this.status,
    this.assignedMember,
    this.onTap,
    this.onForceRelease,
    this.onMarkOutOfService,
  }) : super(key: key);

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'free':
        return Colors.green;
      case 'occupied':
        return Colors.orange;
      case 'out_of_service':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: _getStatusColor().withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    status == 'free'
                        ? Icons.lock_open
                        : status == 'occupied'
                            ? Icons.lock
                            : Icons.error_outline,
                    color: _getStatusColor(),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lockerNumber,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sector,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
              if (status == 'occupied') ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 24,
                  child: ElevatedButton(
                    onPressed: onForceRelease,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: const Text(
                      'Release',
                      style: TextStyle(fontSize: 9, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
