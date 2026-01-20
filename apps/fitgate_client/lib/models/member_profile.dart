/// User authentication model
class AuthUser {
  final String uid;
  final String email;
  final String? displayName;

  AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
  });
}

/// Member profile model
class MemberProfile {
  final String id;
  final String fullName;
  final String email;
  final String status; // 'active', 'expired', 'suspended'
  final DateTime membershipValidUntil;
  final String? assignedLockerId;
  final String? assignedLockerSector;
  final String? assignedLockerNumber;
  final DateTime? lastCheckInTime;
  final bool cardAssigned;
  final int notificationCount;

  MemberProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.status = 'active',
    required this.membershipValidUntil,
    this.assignedLockerId,
    this.assignedLockerSector,
    this.assignedLockerNumber,
    this.lastCheckInTime,
    this.cardAssigned = false,
    this.notificationCount = 0,
  });

  /// Factory constructor for mock data
  factory MemberProfile.mock() {
    return MemberProfile(
      id: 'member-123',
      fullName: 'Marko Marić',
      email: 'marko@example.com',
      status: 'active',
      membershipValidUntil: DateTime.now().add(const Duration(days: 180)),
      assignedLockerSector: 'A',
      assignedLockerNumber: '045',
      lastCheckInTime: DateTime.now().subtract(const Duration(hours: 2)),
      cardAssigned: true,
      notificationCount: 2,
    );
  }
}
