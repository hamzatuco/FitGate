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

String _monthShortName(int month) {
  const months = [
    'jan', 'feb', 'mar', 'apr', 'maj', 'jun',
    'jul', 'avg', 'sep', 'okt', 'nov', 'dec'
  ];
  return months[(month - 1).clamp(0, 11)];
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
            title: Text('FitGate'),
            elevation: 0,
            automaticallyImplyLeading: false,
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade50.withOpacity(0.6),
                  Colors.purple.shade50.withOpacity(0.3),
                  const Color(0xFFf8fafc),
                  Colors.white,
                ],
                stops: const [0.0, 0.25, 0.5, 1.0],
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modern, tight profile card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE0F7FF),
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
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B5ED7),
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      profile.fullName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF2F80ED)),
                                    tooltip: 'Uredi profil',
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/edit-profile',
                                        arguments: profile,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile.email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.1,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Tooltip(
                                message: profile.status == 'active' ? 'Članarina aktivna' : '',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: profile.status == 'active'
                                        ? const Color(0xFFDEF9EC)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: profile.status == 'active'
                                              ? const Color(0xFF047857)
                                              : Colors.grey[400],
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _getStatusLabel(profile.status),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: profile.status == 'active'
                                              ? const Color(0xFF047857)
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // No large CTA for edit profile (handled by icon in card)

                  const SizedBox(height: 24),

                  // Split View: Članarina i Ormarić - pola pola
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      // Left side: Članarina
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final now = DateTime.now();
                            final validUntil = profile.membershipValidUntil;
                            final totalDuration = validUntil.difference(now);
                            final daysRemaining = totalDuration.inDays;
                            final isExpired = daysRemaining < 0;
                            final estimatedPeriod = daysRemaining > 180
                                ? 365
                                : daysRemaining > 60
                                    ? 90
                                    : 30;
                            final progress = isExpired
                                ? 1.0
                                : (1.0 - (daysRemaining / estimatedPeriod)).clamp(0.0, 1.0);
                            String formattedDate = '${validUntil.day.toString().padLeft(2, '0')}. '
                                '${_monthShortName(validUntil.month)} ${validUntil.year}';
                            String expiresText = isExpired
                                ? 'Istekla'
                                : daysRemaining == 0
                                    ? 'Ističe danas'
                                    : 'Ističe za $daysRemaining ${daysRemaining == 1 ? 'dan' : 'dana'}';
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: isExpired ? Colors.red[600] : const Color(0xFF0B5ED7),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isExpired ? Colors.red : const Color(0xFF0B5ED7)).withOpacity(0.13),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          isExpired ? Icons.warning_amber_rounded : Icons.card_membership_outlined,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Članarina',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.95),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      expiresText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      const Text(
                                        'Preostalo',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: isExpired ? 1.0 : progress,
                                            backgroundColor: Colors.white.withOpacity(0.22),
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              isExpired ? Colors.red[900]! : Colors.white,
                                            ),
                                            minHeight: 6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // Right side: Ormarić
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: profile.assignedLockerId != null
                                ? const Color(0xFF4CC9F0)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: (profile.assignedLockerId != null ? const Color(0xFF4CC9F0) : Colors.grey)
                                    .withOpacity(0.13),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: profile.assignedLockerId != null
                                          ? Colors.white.withOpacity(0.18)
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      profile.assignedLockerId != null
                                          ? Icons.lock_open_outlined
                                          : Icons.lock_outline,
                                      color: profile.assignedLockerId != null
                                          ? Colors.white
                                          : Colors.grey[500],
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Moj Ormar',
                                      style: TextStyle(
                                        color: profile.assignedLockerId != null
                                            ? Colors.white.withOpacity(0.95)
                                            : const Color(0xFF64748B),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Dodjeljeni Ormar',
                                style: TextStyle(
                                  color: profile.assignedLockerId != null
                                      ? Colors.white.withOpacity(0.8)
                                      : const Color(0xFF64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                profile.assignedLockerId != null &&
                                        profile.assignedLockerSector != null &&
                                        profile.assignedLockerNumber != null
                                    ? 'Sektor ${profile.assignedLockerSector} - ${profile.assignedLockerNumber}'
                                    : 'Nije dodijeljen',
                                style: TextStyle(
                                  color: profile.assignedLockerId != null
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: _isOpeningLocker
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          Icons.lock_open_outlined,
                                          size: 22,
                                          color: profile.assignedLockerId != null
                                              ? Colors.white
                                              : Colors.grey[500],
                                        ),
                                  label: Text(
                                    _isOpeningLocker ? 'Otvaranje...' : 'Otvori',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: profile.assignedLockerId != null
                                          ? Colors.white
                                          : Colors.grey[500],
                                    ),
                                  ),
                                  onPressed: profile.assignedLockerId == null || _isOpeningLocker
                                      ? null
                                      : () => _handleOpenLocker(profile),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: profile.assignedLockerId != null
                                        ? Colors.orange[600]
                                        : Colors.grey[300],
                                    foregroundColor: profile.assignedLockerId != null
                                        ? Colors.white
                                        : Colors.grey[500],
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    ),
                  ),

                  // Removed info box for 'Zahtjev za otvaranje ormarica je poslan.' (toast is enough)

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

                  // Notifications list - Enhanced
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
                      final visibleNotifs = _showAllNotifications ? notifs : notifs.take(3).toList();

                      return Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.07),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.grey.shade200.withOpacity(0.7),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: visibleNotifs.isNotEmpty
                            ? Column(
                                children: [
                                  for (final notif in visibleNotifs)
                                    Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                                      decoration: BoxDecoration(
                                        color: notif.type == 'fail'
                                            ? Colors.red[50]
                                            : Colors.green[50],
                                        border: Border.all(
                                          color: notif.type == 'fail'
                                              ? Colors.red[200]!
                                              : Colors.green[200]!,
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (notif.type == 'fail' ? Colors.red : Colors.green)
                                                .withOpacity(0.08),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
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
                    label: 'Prijavi grešku',
                    onPressed: () async {
                      final profile = snapshot.data!;
                      await _showReportProblemDialog(profile);
                    },
                    backgroundColor: Colors.orange[600],
                  ),
                  const SizedBox(height: 16),
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

