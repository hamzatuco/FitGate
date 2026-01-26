import 'package:flutter/material.dart';
import 'package:fitgate_shared/fitgate_shared.dart';

import '../models/member_profile.dart';
import '../models/notification_item.dart';
import '../services/auth_service.dart';
import '../services/locker_service.dart';

/// Dashboard screen showing member profile
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
    bool _isClearingNotifications = false;

    Future<void> _clearNotifications(String memberId) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Potvrda brisanja'),
          content: const Text('Da li ste sigurni da želite obrisati sve notifikacije? Ova radnja je nepovratna.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Otkaži'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Obriši', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      setState(() => _isClearingNotifications = true);
      try {
        await _authService.clearAllNotifications(memberId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sve notifikacije su obrisane.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Greška pri brisanju notifikacija: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isClearingNotifications = false);
      }
    }
  bool _showAllNotifications = false;

  final _authService = AuthService();
  final _lockerService = LockerService();

  late Stream<MemberProfile?> _profileStream;

  final List<String> _problemPresets = const [
    'Ormaric nije u funkciji',
    'RFID kartica ne otvara ormaric',
    'Vrata se ne zatvaraju dobro',
    'Sumnjam na ostecenje ormara',
  ];

  bool _isSendingProblem = false;
  bool _isOpeningLocker = false;
  String? _lockerOpenMessage;

  // Da ne spamamo SnackBar na svaku rebuild notifikacija
  String? _lastSuccessNotifId;

  @override
  void initState() {
    super.initState();
    _profileStream = _authService.getCurrentUserProfileStream();
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

  Future<void> _handleOpenLocker(MemberProfile profile) async {
    if (profile.assignedLockerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nemate dodijeljen ormaric.')),
        );
      }
      return;
    }

    setState(() {
      _isOpeningLocker = true;
      _lockerOpenMessage = null;
    });

    try {
      await _lockerService.openLocker(
        lockerId: profile.assignedLockerId!,
        memberId: profile.id,
      );

      if (!mounted) return;

      setState(() {
        _lockerOpenMessage = 'Zahtjev za otvaranje ormarica je poslan.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zahtjev za otvaranje ormarica je poslan.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lockerOpenMessage = 'Greška: ${e.toString()}';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isOpeningLocker = false;
      });
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
                      hintText: 'Opišite u čemu je problem...',
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
                      label: Text(_isSendingProblem ? 'Slanje...' : 'Pošalji prijavu'),
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
                                    SnackBar(content: Text('Greška: $e')),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MemberProfile?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Moj Profil')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Moj Profil')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[600]),
                  const SizedBox(height: 16),
                  Text(
                    'Greška pri učitavanju profila',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Pokušaj ponovo',
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

        return Scaffold(
          appBar: AppBar(
            title: const Text('Moj Profil'),
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade700, Colors.blue.shade900],
                ),
              ),
            ),
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade50.withOpacity(0.4),
                  const Color(0xFFf8fafc),
                  Colors.white,
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
            child: SingleChildScrollView(
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
                                    .where((e) => e.trim().isNotEmpty)
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
                                Text(
                                  profile.fullName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile.email,
                                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(profile.status).withOpacity(0.2),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      Text('Članarina', style: Theme.of(context).textTheme.titleLarge),
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

                  // Membership card
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
                              style: TextStyle(color: Colors.white70, fontSize: 14),
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
                  // Responsive notifications row
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 420;
                      return Flex(
                        direction: isNarrow ? Axis.vertical : Axis.horizontal,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Obavještenja', style: Theme.of(context).textTheme.titleLarge),
                              if (profile.notificationCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
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
                            ],
                          ),
                          const SizedBox(height: 4, width: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => setState(() => _showAllNotifications = !_showAllNotifications),
                                child: Text(_showAllNotifications ? 'Prikaži manje' : 'Prikaži više'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _isClearingNotifications ? null : () => _clearNotifications(profile.id),
                                child: _isClearingNotifications
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Očisti notifikacije'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
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

                      final notifs = (notifSnapshot.data ?? []).toList();

                      // (Opcionalno) sort po timestamp ako stream ne garantuje redoslijed
                      notifs.sort((a, b) {
                        final at = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
                        final bt = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
                        return bt.compareTo(at);
                      });

                      // SnackBar samo jednom za najnoviji success
                      NotificationItem? latestSuccess;
                      try {
                        latestSuccess = notifs.firstWhere(
                          (n) => n.type == 'success',
                        );
                      } catch (e) {
                        latestSuccess = null;
                      }
                      if (latestSuccess != null) {
                        final id = (latestSuccess.id ?? '${latestSuccess.timestamp}');
                        if (_lastSuccessNotifId != id) {
                          _lastSuccessNotifId = id;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(latestSuccess!.message)),
                              );
                            }
                          });
                        }
                      }

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
                                          notif.type == 'success'
                                              ? 'Uspješan pristup'
                                              : 'Neuspješan pokušaj',
                                          style: TextStyle(
                                            color: notif.type == 'success'
                                                ? Colors.green[800]
                                                : Colors.red[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(notif.message),
                                        trailing: notif.timestamp != null
                                            ? Text(
                                                '${notif.timestamp!.day.toString().padLeft(2, '0')}.${notif.timestamp!.month.toString().padLeft(2, '0')}.${notif.timestamp!.year} '
                                                '${notif.timestamp!.hour.toString().padLeft(2, '0')}:${notif.timestamp!.minute.toString().padLeft(2, '0')}',
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
                                    Icon(Icons.notifications_none, size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Nema novih obavještenja',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Locker section
                  Text('Moj Ormar', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),

                  // Assigned locker card (FIXED)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: profile.assignedLockerId != null
                            ? [Colors.green[600]!, Colors.green[800]!]
                            : [Colors.grey[500]!, Colors.grey[700]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          profile.assignedLockerId != null ? Icons.lock_open : Icons.lock_outline,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dodjeljeni Ormar',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
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

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.lock_open),
                          label: _isOpeningLocker
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Otvori ormarić'),
                          onPressed: _isOpeningLocker ? null : () => _handleOpenLocker(profile),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.report_problem),
                          label: const Text('Prijavi problem'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[700],
                            side: BorderSide(color: Colors.red[300]!),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _showReportProblemDialog(profile),
                        ),
                      ),
                    ],
                  ),

                  if (_lockerOpenMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _lockerOpenMessage!,
                      style: TextStyle(
                        color: _lockerOpenMessage!.startsWith('Greška')
                            ? Colors.red[700]
                            : Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Other info section
                  Text('Dodatno', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
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
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 64) / 2,
                        child: InfoCard(
                          title: 'Status Kartice',
                          value: profile.cardAssigned ? 'Dodijeljena' : 'Nije dodijeljena',
                          icon: Icons.nfc,
                          iconColor: profile.cardAssigned ? Colors.green[700] : Colors.grey[600],
                        ),
                      ),
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 64) / 2,
                        child: InfoCard(
                          title: 'Obavijesti',
                          value: '${profile.notificationCount} nova',
                          icon: Icons.notifications,
                          iconColor:
                              profile.notificationCount > 0 ? Colors.red[700] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  PrimaryButton(
                    label: 'Odjavi se',
                    onPressed: _handleLogout,
                    backgroundColor: Colors.red[600],
                  ),
                ],
              ),
            ),
          ),
        ));
      },
    );
  }
}
