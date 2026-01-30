import 'package:fitgate_admin/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:fitgate_shared/fitgate_shared.dart';
import '../widgets/locker_tile.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/loading_view.dart';
import '../widgets/empty_view.dart';
import '../theme/app_colors.dart';
/// Lockers management screen
class LockersScreen extends StatefulWidget {
  const LockersScreen({super.key});

  @override
  State<LockersScreen> createState() => _LockersScreenState();
}

class _LockersScreenState extends State<LockersScreen> {
  String _selectedSector = 'All';
  String _selectedStatus = 'All';
  final List<String> _sectors = ['All', 'A', 'B', 'C', 'D'];
  final List<String> _statuses = ['All', 'free', 'occupied', 'out_of_service'];
  final FirestoreService _firestoreService = FirestoreService();

  List<Locker> _filterLockers(List<Locker> lockers) {
    var filtered = lockers;
    if (_selectedSector != 'All') {
      filtered = filtered.where((l) => l.sector == _selectedSector).toList();
    }
    if (_selectedStatus != 'All') {
      filtered = filtered.where((l) => l.status == _selectedStatus).toList();
    }
    return filtered;
  }
  
  String _getStatusLabel(String status) {
    switch (status) {
      case 'free':
        return 'Dostupno';
      case 'occupied':
        return 'Zauzeto';
      case 'out_of_service':
        return 'Neispravno';
      default:
        return 'Sve';
    }
  }

  Future<void> _forceReleaseLocker(Locker locker) async {
    final confirmed = await ConfirmDialog.show(
      context,
        title: 'Oslobodi Ormar Prinudno?',
        message:
          'Ovo će osloboditi ormar L${locker.number} i može prekinuti člana. Jeste li sigurni?',
        confirmButtonText: 'Oslobodi',
      confirmColor: Colors.red,
    );

    if (confirmed == true) {
      try {
        await _firestoreService.forceReleaseLocker(locker.id, 'staff-1', 'Admin action');
        
        // Log activity
        await _firestoreService.logActivity(
          action: 'force_release',
          lockerId: locker.id,
          lockerSector: locker.sector,
          lockerNumber: locker.number,
          staffId: 'staff-1',
          staffName: 'Admin',
          description: 'Ormar ${locker.sector}-${locker.number} oslobođen prinudno',
          success: true,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ormar je uspješno oslobođen')),
          );
        }
      } catch (e) {
        // Log failed activity
        await _firestoreService.logActivity(
          action: 'force_release',
          lockerId: locker.id,
          lockerSector: locker.sector,
          lockerNumber: locker.number,
          staffId: 'staff-1',
          staffName: 'Admin',
          description: 'Pokušaj oslobađanja ormara ${locker.sector}-${locker.number}',
          success: false,
          errorMessage: e.toString(),
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Greška: $e')),
          );
        }
      }
    }
  }

  Future<void> _markOutOfService(Locker locker) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Označi Ormar Kao Neispravno?',
      message: 'Ovo će označiti ormar L${locker.number} kao neispravno.',
      confirmButtonText: 'Potvrdi',
      confirmColor: Colors.orange,
    );

    if (confirmed == true) {
      try {
        await _firestoreService.markLockerOutOfService(locker.id, 'staff-1', 'Maintenance needed', null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ormar je označen kao neispravno')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Greška: $e')),
          );
        }
      }
    }
  }

  Future<void> _assignLockerToMember() async {
    final cardIdController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pridruži Ormar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Skeniraj ili unesi RFID karticu člana:'),
            const SizedBox(height: 16),
            TextField(
              controller: cardIdController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'ID Kartice',
                hintText: 'RF123456',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performAssignment(cardIdController.text);
            },
            child: const Text('Pridruži'),
          ),
        ],
      ),
    );
  }

  Future<void> _performAssignment(String cardId) async {
    if (cardId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Molim unesi ID kartice')),
      );
      return;
    }

    try {
      final result = await _firestoreService.assignLockerToMember(cardId, 'staff-1');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ormar ${result['lockerSector']}-${result['lockerNumber']} asigniran članu ${result['memberName']}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri dodjeli: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _assignSpecificLockerToMember(Locker locker) async {
    // Show dialog to enter RFID card
    String cardId = '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Asigniraj Ormar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ormar: ${locker.sector}-${locker.number}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Unesi RFID karticu člana:'),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'RFID kartice',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => cardId = value,
              onSubmitted: (value) {
                cardId = value;
                Navigator.pop(context);
                _assignLockerByRFID(locker.id, cardId);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (cardId.isNotEmpty) {
                _assignLockerByRFID(locker.id, cardId);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Molim unesi RFID karticu'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Asigniraj'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignLockerByRFID(String lockerId, String cardId) async {
    try {
      final result = await _firestoreService.assignSpecificLockerByRFID(
        cardId: cardId,
        lockerId: lockerId,
        staffId: 'staff-1',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ormar ${result['lockerSector']}-${result['lockerNumber']} asigniran članu ${result['memberName']}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri dodjeli: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFf8fafc),
            const Color(0xFFf1f5f9),
            Colors.white.withOpacity(0.95),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: StreamBuilder<List<Locker>>(
        stream: _firestoreService.getLockersStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return LoadingView(message: 'Učitavanje ormara...');
          }
          final lockers = snap.data ?? [];
          final filtered = _filterLockers(lockers);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ormari',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.green, blurRadius: 4)],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Status u realnom vremenu',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _assignLockerToMember,
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text('Pridruži ormar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text('Sektor:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    ..._sectors.map(
                      (sector) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(sector),
                          selected: _selectedSector == sector,
                          onSelected: (_) => setState(() => _selectedSector = sector),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Status:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    ..._statuses.map(
                      (status) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_getStatusLabel(status)),
                          selected: _selectedStatus == status,
                          onSelected: (_) => setState(() => _selectedStatus = status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyView(
                          title: 'Nema ormara',
                          subtitle: 'Nema ormara koji odgovaraju filtrima',
                          icon: Icons.lock_rounded,
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final locker = filtered[index];
                            return LockerTile(
                              lockerNumber: locker.number,
                              sector: locker.sector,
                              status: locker.status,
                              assignedMember: locker.assignedTo,
                              onForceRelease: locker.status == 'occupied'
                                  ? () => _forceReleaseLocker(locker)
                                  : null,
                              onMarkOutOfService: locker.status != 'out_of_service'
                                  ? () => _markOutOfService(locker)
                                  : null,
                              onAssignMember: locker.status == 'free'
                                  ? () => _assignSpecificLockerToMember(locker)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
