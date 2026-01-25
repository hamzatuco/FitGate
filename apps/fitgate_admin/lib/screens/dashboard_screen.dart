import 'package:fitgate_admin/services/firestore_service.dart';
import 'package:flutter/material.dart';
import '../widgets/stat_card.dart';
import '../widgets/loading_view.dart';
import '../widgets/empty_view.dart';

/// Dashboard screen with overview statistics
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _activityLogs = [];
  Map<String, dynamic> _stats = {
    'activeMembersCount': 0,
    'activeSessionsCount': 0,
    'freeLockers': 0,
    'occupiedLockers': 0,
  };
  final FirestoreService _firestoreService = FirestoreService();
  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  String _getActionLabel(String? action) {
    switch (action) {
      case 'assign_locker':
        return 'Ormaric dodijeljen';
      case 'force_release':
        return 'Ormaric skinut od strane admina';
      case 'problem_reported':
        return 'Prijavljen problem';
      case 'mark_out_of_service':
        return 'Ormaric izvan funkcije';
      case 'suspend_member':
        return 'Clanstvo suspendovano';
      default:
        return action ?? '';
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _firestoreService.getDashboardStats();
      final logs = await _firestoreService.getActivityLogs(limit: 10);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _stats = stats;
          _activityLogs = logs;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greska pri ucitavanju: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? LoadingView(message: 'Učitavanje kontrolne ploče...')
          : SingleChildScrollView(
              child: Padding(
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
                              'Kontrolna Ploča',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pregled rada teretane u realnom vremenu',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _loadDashboard,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Osvježi'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Stat cards
                    GridView.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        StatCard(
                          title: 'Aktivni Članovi',
                          value: '${_stats['activeMembersCount'] ?? 0}',
                          icon: Icons.people,
                          color: Colors.blue,
                        ),
                        StatCard(
                          title: 'Aktivne Sesije',
                          value: '${_stats['activeSessionsCount'] ?? 0}',
                          icon: Icons.access_time,
                          color: Colors.purple,
                        ),
                        StatCard(
                          title: 'Slobodni Ormarići',
                          value: '${_stats['freeLockers'] ?? 0}',
                          icon: Icons.lock_open,
                          color: Colors.green,
                        ),
                        StatCard(
                          title: 'Zauzeti Ormarići',
                          value: '${_stats['occupiedLockers'] ?? 0}',
                          icon: Icons.lock,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Activity logs section
                    Text(
                      'Nedavna Aktivnost',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[200]!, width: 1),
                      ),
                      child: _activityLogs.isEmpty
                          ? EmptyView(
                              title: 'Nema aktivnosti',
                              subtitle:
                                  'Aktivnost ce biti prikazana kada clanovi koriste ormare',
                              icon: Icons.history,
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Vrijeme')),
                                  DataColumn(label: Text('Akcija')),
                                  DataColumn(label: Text('Clan')),
                                  DataColumn(label: Text('Ormar')),
                                ],
                                rows: _activityLogs
                                    .map(
                                      (log) {
                                        final timestamp = log['timestamp'];
                                        final timeStr = timestamp is DateTime
                                            ? '${timestamp.day}.${timestamp.month}.${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}'
                                            : (timestamp?.toString() ?? '-');
                                        final isProblem = log['action'] == 'problem_reported';
                                        final lockerValue = (log['lockerSector'] != null && log['lockerNumber'] != null)
                                            ? '${log['lockerSector']}-${log['lockerNumber']}'
                                            : (log['lockerId'] ?? '');
                                        
                                        return DataRow(
                                          color: isProblem
                                              ? WidgetStateProperty.all(Colors.red[200])
                                              : null,
                                          cells: [
                                          DataCell(Text(timeStr)),
                                          DataCell(Text(_getActionLabel(log['action'] as String?))),
                                          DataCell(Text(log['memberName'] ?? '')),
                                          DataCell(Text(lockerValue)),
                                        ]);
                                      },
                                    )
                                    .toList(),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
