import 'package:flutter/material.dart';
import 'package:fitgate_shared/fitgate_shared.dart';
import '../models/member_profile.dart';
import '../models/notification_item.dart';
import '../services/auth_service.dart';

/// Dashboard screen showing member profile
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
    bool _showAllNotifications = false;
  final _authService = AuthService();
  late Stream<MemberProfile?> _profileStream;
  final List<String> _problemPresets = const [
    'Ormaric nije u funkciji',
    'RFID kartica ne otvara ormaric',
    'Vrata se ne zatvaraju dobro',
    'Sumnjam na ostecenje ormara',
  ];
  bool _isSendingProblem = false;

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

  Future<void> _showReportProblemDialog(MemberProfile profile) async {
    final controller = TextEditingController(text: _problemPresets.first);
    String selected = _problemPresets.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Prijavi problem',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Brzi odabir',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _problemPresets.map((preset) {
                      final isSelected = preset == selected;
                      return ChoiceChip(
                        label: Text(preset),
                        selected: isSelected,
                        onSelected: (_) {
                          setModalState(() {
                            selected = preset;
                            controller.text = preset;
                          });
                        },
                        selectedColor: Colors.red[100],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Opis problema',
                      hintText: 'Opisite u cemu je problem... ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isSendingProblem
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_isSendingProblem ? 'Slanje...' : 'Poalji prijavu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isSendingProblem
                          ? null
                          : () async {
                              final text = controller.text.trim();
                              if (text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Unesite opis problema')),
                                );
                                return;
                              }

                              setState(() => _isSendingProblem = true);
                              try {
                                await _authService.reportProblem(
                                  profile: profile,
                                  description: text,
                                );
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Problem prijavljen. Hvala!')),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Greska: $e')),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _isSendingProblem = false);
                                }
                              }
                            },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String time,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: Text(
        time,
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 11,
        ),
      ),
    );
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
                  const SizedBox(height: 16),
                  
                  // Edit Profile Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[800]!],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      label: const Text(
                        'Uredi Profil',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/edit-profile',
                          arguments: profile,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Membership section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Članarina',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified, size: 16, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              'Aktivna',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Membership card with gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[800]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Važeća do',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${profile.membershipValidUntil.difference(DateTime.now()).inDays} dana',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${profile.membershipValidUntil.day}. ${profile.membershipValidUntil.month}. ${profile.membershipValidUntil.year}.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: 0.75,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Notifications section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Obavještenja',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (profile.notificationCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${profile.notificationCount} nova',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (!_showAllNotifications)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showAllNotifications = true;
                            });
                          },
                          child: const Text('View more'),
                        ),
                      if (_showAllNotifications)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showAllNotifications = false;
                            });
                          },
                          child: const Text('Show less'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Notifications list
                  StreamBuilder<List<NotificationItem>>(
                    stream: _authService.notificationsStream(profile.id),
                    builder: (context, notifSnapshot) {
                      if (notifSnapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final notifs = notifSnapshot.data ?? [];
                      final visibleNotifs = _showAllNotifications ? notifs : notifs.take(3).toList();
                      return Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: visibleNotifs.isNotEmpty
                            ? Column(
                                children: [
                                  for (final notif in visibleNotifs)
                                    Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: notif.type == 'fail' ? Colors.red : Colors.green,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        color: notif.type == 'fail' ? Colors.red[50] : Colors.green[50],
                                      ),
                                      child: ListTile(
                                        leading: Icon(
                                          notif.type == 'success' ? Icons.check_circle : Icons.error,
                                          color: notif.type == 'success' ? Colors.green : Colors.red,
                                        ),
                                        title: Text(
                                          notif.type == 'success' ? 'Uspješan pristup' : 'Neuspješan pokušaj',
                                          style: TextStyle(
                                            color: notif.type == 'success' ? Colors.green[800] : Colors.red[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(notif.message),
                                        trailing: notif.timestamp != null
                                            ? Text(
                                                '${notif.timestamp!.day}.${notif.timestamp!.month}.${notif.timestamp!.year}',
                                                style: const TextStyle(fontSize: 12),
                                              )
                                            : null,
                                      ),
                                    ),
                                ],
                              )
                            : Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.notifications_none,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Nema novih obavještenja',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Locker section
                  Text(
                    'Moj Ormar',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  // Assigned locker card
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: profile.assignedLockerId != null
                            ? [Colors.green[400]!, Colors.green[600]!]
                            : [Colors.grey[300]!, Colors.grey[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (profile.assignedLockerId != null
                                  ? Colors.green
                                  : Colors.grey)
                              .withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            profile.assignedLockerId != null
                                ? Icons.lock_open
                                : Icons.lock_outline,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dodjeljeni Ormar',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile.assignedLockerId != null &&
                                        profile.assignedLockerSector != null &&
                                        profile.assignedLockerNumber != null
                                    ? 'Sektor ${profile.assignedLockerSector} - ${profile.assignedLockerNumber}'
                                    : 'Nije dodijeljen',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.report_problem),
                    label: const Text('Prijavi problem sa ormarom'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _showReportProblemDialog(profile),
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
