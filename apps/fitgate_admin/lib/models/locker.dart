// NOTE: Member class is now imported from fitgate_shared package
// See pubspec.yaml for fitgate_shared dependency

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
