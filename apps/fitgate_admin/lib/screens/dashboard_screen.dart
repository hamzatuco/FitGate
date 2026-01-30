import 'package:fitgate_admin/services/firestore_service.dart';
import 'package:flutter/material.dart';
import '../widgets/stat_card.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_view.dart';
import '../widgets/empty_view.dart';

/// Dashboard s real-time streamovima – bez potrebe za manualnim Osvježi
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  String _getActionLabel(String? action) {
    switch (action) {
      case 'assign_locker':
        return 'Ormarić dodijeljen';
      case 'force_release':
        return 'Ormarić skinut od strane admina';
      case 'problem_reported':
        return 'Prijavljen problem';
      case 'mark_out_of_service':
        return 'Ormarić izvan funkcije';
      case 'suspend_member':
        return 'Članstvo suspendovano';
      default:
        return action ?? '';
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
      child: SingleChildScrollView(
        child: Padding(
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
                        'Kontrolna ploča',
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
                              boxShadow: [
                                BoxShadow(color: Colors.green, blurRadius: 4),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Uživo',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              StreamBuilder<Map<String, dynamic>>(
                stream: _firestoreService.getDashboardStatsStream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                    return LoadingView(message: 'Učitavanje...');
                  }
                  final stats = snap.data ?? {
                    'activeMembersCount': 0,
                    'activeSessionsCount': 0,
                    'freeLockers': 0,
                    'occupiedLockers': 0,
                  };
                  return GridView.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      StatCard(
                        title: 'Aktivni članovi',
                        value: '${stats['activeMembersCount'] ?? 0}',
                        icon: Icons.people_rounded,
                        color: AppColors.primary,
                      ),
                      StatCard(
                        title: 'Aktivne sesije',
                        value: '${stats['activeSessionsCount'] ?? 0}',
                        icon: Icons.access_time_rounded,
                        color: Colors.purple,
                      ),
                      StatCard(
                        title: 'Slobodni ormarići',
                        value: '${stats['freeLockers'] ?? 0}',
                        icon: Icons.lock_open_rounded,
                        color: Colors.green,
                      ),
                      StatCard(
                        title: 'Zauzeti ormarići',
                        value: '${stats['occupiedLockers'] ?? 0}',
                        icon: Icons.lock_rounded,
                        color: Colors.orange,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              Text(
                'Nedavna aktivnost',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _firestoreService.getActivityLogsStream(limit: 10),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  final logs = snap.data ?? [];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: logs.isEmpty
                          ? EmptyView(
                              title: 'Nema aktivnosti',
                              subtitle: 'Aktivnost će se prikazati kada članovi koriste ormare',
                              icon: Icons.history_rounded,
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Vrijeme')),
                                  DataColumn(label: Text('Akcija')),
                                  DataColumn(label: Text('Član')),
                                  DataColumn(label: Text('Ormarić')),
                                ],
                                rows: logs.map((log) {
                                  final timestamp = log['timestamp'];
                                  final timeStr = timestamp is DateTime
                                      ? '${timestamp.day}.${timestamp.month}.${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}'
                                      : (timestamp?.toString() ?? '-');
                                  final isProblem = log['action'] == 'problem_reported';
                                  final lockerValue =
                                      (log['lockerSector'] != null && log['lockerNumber'] != null)
                                          ? '${log['lockerSector']}-${log['lockerNumber']}'
                                          : (log['lockerId']?.toString() ?? '');
                                  return DataRow(
                                    color: isProblem
                                        ? WidgetStateProperty.all(Colors.red.shade50)
                                        : null,
                                    cells: [
                                      DataCell(Text(timeStr)),
                                      DataCell(Text(_getActionLabel(log['action'] as String?))),
                                      DataCell(Text(log['memberName']?.toString() ?? '')),
                                      DataCell(Text(lockerValue)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
