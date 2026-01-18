import 'package:flutter/material.dart';
import '../models/member_profile.dart';
import '../widgets/info_card.dart';
import '../widgets/primary_button.dart';
import '../services/auth_service.dart';

/// Dashboard screen showing member profile
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();
  late Stream<MemberProfile?> _profileStream;

  @override
  void initState() {
    super.initState();
    _profileStream = _authService.getCurrentUserProfileStream();
    print('🚀 DashboardScreen initState - Stream kreiran');
  }

  Future<void> _handleLogout() async {
    try {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri odjavi: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.red;
      case 'suspended':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Aktivno';
      case 'expired':
        return 'Isteklo';
      case 'suspended':
        return 'Suspenzija';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MemberProfile?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        print('\n📊 StreamBuilder state:');
        print('   - connectionState: ${snapshot.connectionState}');
        print('   - hasData: ${snapshot.hasData}');
        print('   - hasError: ${snapshot.hasError}');
        if (snapshot.hasError) {
          print('   - ERROR: ${snapshot.error}');
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Moj Profil'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Moj Profil'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Greška pri učitavanju profila',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Pokušaj Again',
                    onPressed: () {
                      setState(() {
                        _profileStream = _authService.getCurrentUserProfileStream();
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }

        final profile = snapshot.data!;

        print('🎨 Dashboard building with profile:');
        print('   - fullName: ${profile.fullName}');
        print('   - email: ${profile.email}');
        print('   - status: ${profile.status}');
        print('   - assignedLockerSector: ${profile.assignedLockerSector}');
        print('   - assignedLockerNumber: ${profile.assignedLockerNumber}');
        print('   - lastCheckInTime: ${profile.lastCheckInTime}');
        print('   - cardAssigned: ${profile.cardAssigned}');

        return Scaffold(
          appBar: AppBar(
            title: const Text('Moj Profil'),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Member profile card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey[200]!, width: 1),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.blue[300]!,
                                  Colors.blue[700]!,
                                ],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                profile.fullName
                                    .split(' ')
                                    .take(2)
                                    .map((e) => e[0].toUpperCase())
                                    .join(),
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Member info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Member name
                                Text(
                                  profile.fullName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Member email
                                Text(
                                  profile.email,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(profile.status).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getStatusLabel(profile.status),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _getStatusColor(profile.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Membership section
                  Text(
                    'Članarina',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  // Membership grid
                  Row(
                    children: [
                      Expanded(
                        child: InfoCard(
                          title: 'Važeća Do',
                          value:
                              '${profile.membershipValidUntil.day}. ${profile.membershipValidUntil.month}. ${profile.membershipValidUntil.year}.',
                          icon: Icons.calendar_today,
                          iconColor: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Locker section
                  Text(
                    'Ormar',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  // Assigned locker
                  InfoCard(
                    title: 'Dodjeljeni Ormar',
                    value: profile.assignedLockerSector != null &&
                            profile.assignedLockerNumber != null
                        ? 'Sektor ${profile.assignedLockerSector} - ${profile.assignedLockerNumber}'
                        : 'Ormar nije dodijeljen',
                    icon: Icons.lock,
                    iconColor: profile.assignedLockerSector != null
                        ? Colors.green[700]
                        : Colors.grey[600],
                  ),
                  const SizedBox(height: 32),

                  // Other info section
                  Text(
                    'Dodatno',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  // Info grid - 2 columns
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      // Last check-in
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 64) / 2,
                        child: InfoCard(
                          title: 'Posljednja Prijava',
                          value: profile.lastCheckInTime != null
                              ? '${profile.lastCheckInTime!.hour}:${profile.lastCheckInTime!.minute.toString().padLeft(2, '0')}\n${profile.lastCheckInTime!.day}.${profile.lastCheckInTime!.month}.'
                              : 'Nema podataka',
                          icon: Icons.access_time,
                          iconColor: Colors.orange[700],
                        ),
                      ),
                      // Card status
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 64) / 2,
                        child: InfoCard(
                          title: 'Status Kartice',
                          value: profile.cardAssigned ? 'Dodijeljena' : 'Nije dodijeljena',
                          icon: Icons.nfc,
                          iconColor: profile.cardAssigned
                              ? Colors.green[700]
                              : Colors.grey[600],
                        ),
                      ),
                      // Notifications - full width
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 64) / 2,
                        child: InfoCard(
                          title: 'Obavijesti',
                          value: '${profile.notificationCount} nova',
                          icon: Icons.notifications,
                          iconColor: profile.notificationCount > 0
                              ? Colors.red[700]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Logout button
                  PrimaryButton(
                    label: 'Odjavi se',
                    onPressed: _handleLogout,
                    backgroundColor: Colors.red[600],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
