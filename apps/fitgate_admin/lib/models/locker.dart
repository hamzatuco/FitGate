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

/// Represents a locker in the gym
class Locker {
  final String id;
  final String number;
  final String sector;
  final String status; // 'free', 'occupied', 'out_of_service'
  final String? assignedTo; // Member ID
  final String? currentMember; // Member name for display
  final DateTime? lastAccessTime;

  Locker({
    required this.id,
    required this.number,
    required this.sector,
    required this.status,
    this.assignedTo,
    this.currentMember,
    this.lastAccessTime,
  });

  factory Locker.fromJson(Map<String, dynamic> json) {
    return Locker(
      id: json['id'] ?? '',
      number: json['number'] ?? '',
      sector: json['sector'] ?? '',
      status: json['status'] ?? 'free',
      assignedTo: json['assignedTo'],
      currentMember: json['currentMember'],
      lastAccessTime: json['lastAccessTime'] != null
          ? DateTime.parse(json['lastAccessTime'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'sector': sector,
      'status': status,
      'assignedTo': assignedTo,
      'currentMember': currentMember,
      'lastAccessTime': lastAccessTime?.toIso8601String(),
    };
  }
}
