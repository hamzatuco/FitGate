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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
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
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'L$lockerNumber',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sector,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            if (assignedMember != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  assignedMember!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
            if (status == 'occupied') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: onForceRelease,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'Release',
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
