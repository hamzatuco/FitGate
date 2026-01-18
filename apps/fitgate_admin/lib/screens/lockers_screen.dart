import 'package:fitgate_admin/services/firestore_service.dart';
import 'package:flutter/material.dart';
import '../models/locker.dart';
import '../widgets/locker_tile.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/loading_view.dart';
import '../widgets/empty_view.dart';

/// Lockers management screen
class LockersScreen extends StatefulWidget {
  const LockersScreen({super.key});

  @override
  State<LockersScreen> createState() => _LockersScreenState();
}

class _LockersScreenState extends State<LockersScreen> {
  bool _isLoading = true;
  List<Locker> _lockers = [];
  String _selectedSector = 'All';
  String _selectedStatus = 'All';
  final List<String> _sectors = ['All', 'A', 'B', 'C', 'D'];
  final List<String> _statuses = ['All', 'free', 'occupied', 'out_of_service'];
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadLockers();
  }

  Future<void> _loadLockers() async {
    setState(() => _isLoading = true);
    try {
      final lockers = await _firestoreService.getLockers();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lockers = lockers;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri učitavanju ormara: $e')),
        );
      }
    }
  }

  List<Locker> get _filteredLockers {
    var filtered = _lockers;
    
    // Filter by sector
    if (_selectedSector != 'All') {
      filtered = filtered.where((l) => l.sector == _selectedSector).toList();
    }
    
    // Filter by status
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ormar je uspješno oslobođen')),
          );
          _loadLockers();
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
            const SnackBar(
                content: Text('Ormar je označen kao neispravno')),
          );
          _loadLockers();
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
        _loadLockers();
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
    return Scaffold(
      body: _isLoading
          ? LoadingView(message: 'Učitavanje ormara...')
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ormari',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Status ormara u realnom vremenu i upravljanje',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _assignLockerToMember,
                            icon: const Icon(Icons.nfc),
                            label: const Text('Pridruži Ormar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _loadLockers,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Osvježi'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Sector filter
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
                            onSelected: (selected) {
                              setState(() => _selectedSector = sector);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Status filter
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
                            onSelected: (selected) {
                              setState(() => _selectedStatus = status);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Locker grid
                  Expanded(
                    child: _filteredLockers.isEmpty
                        ? EmptyView(
                          title: 'Nema ormara',
                          subtitle:
                            'Nema ormara koji odgovaraju filtrima',
                            icon: Icons.storage,
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: _filteredLockers.length,
                            itemBuilder: (context, index) {
                              final locker = _filteredLockers[index];
                              return LockerTile(
                                lockerNumber: locker.number,
                                sector: locker.sector,
                                status: locker.status,
                                assignedMember: locker.currentMember,
                                onForceRelease: locker.status == 'occupied'
                                    ? () =>
                                        _forceReleaseLocker(locker)
                                    : null,
                                onMarkOutOfService: locker.status != 'out_of_service'
                                    ? () =>
                                        _markOutOfService(locker)
                                    : null,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
