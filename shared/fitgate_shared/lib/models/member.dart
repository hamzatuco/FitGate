/// Represents a gym member in the system
class Member {
  final String id;
  final String name;
  final String cardId; // RFID card UID
  final String status; // 'active', 'expired', 'suspended'
  final String? assignedLocker; // Locker number if assigned
  final DateTime membershipValidUntil;
  final DateTime registeredAt;

  Member({
    required this.id,
    required this.name,
    required this.cardId,
    required this.status,
    this.assignedLocker,
    required this.membershipValidUntil,
    required this.registeredAt,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      cardId: json['cardId'] ?? '',
      status: json['status'] ?? 'active',
      assignedLocker: json['assignedLocker'],
      membershipValidUntil: json['membershipValidUntil'] != null
          ? DateTime.parse(json['membershipValidUntil'])
          : DateTime.now(),
      registeredAt: json['registeredAt'] != null
          ? DateTime.parse(json['registeredAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cardId': cardId,
      'status': status,
      'assignedLocker': assignedLocker,
      'membershipValidUntil': membershipValidUntil.toIso8601String(),
      'registeredAt': registeredAt.toIso8601String(),
    };
  }
}
