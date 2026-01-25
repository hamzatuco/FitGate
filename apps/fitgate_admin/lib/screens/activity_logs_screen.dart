import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedAction = 'All';
  String _selectedStatus = 'All';
  bool _isDescending = true;
  
  final List<String> _actionFilters = ['All', 'assign_locker', 'force_release', 'mark_out_of_service', 'suspend_member', 'problem_reported'];
  final List<String> _statusFilters = ['All', 'completed', 'failed'];

  String _getActionLabel(String action) {
    switch (action) {
      case 'assign_locker':
        return 'Dodjela ormara';
      case 'force_release':
        return 'Oslobađanje ormara';
      case 'problem_reported':
        return 'Prijavljen problem';
      case 'mark_out_of_service':
        return 'Ormar van usluge';
      case 'suspend_member':
        return 'Suspenzija člana';
      default:
        return action;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'assign_locker':
        return Colors.green;
      case 'force_release':
        return Colors.orange;
      case 'problem_reported':
        return Colors.red;
      case 'mark_out_of_service':
        return Colors.red;
      case 'suspend_member':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nedavna Aktivnost'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Action filter
                SizedBox(
                  height: 40,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButton<String>(
                        value: _selectedAction,
                        underline: const SizedBox.shrink(),
                        icon: const Icon(Icons.expand_more, size: 18),
                        items: _actionFilters.map((action) {
                          return DropdownMenuItem(
                            value: action,
                            child: Text(action == 'All' ? 'Sve akcije' : _getActionLabel(action)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedAction = val ?? 'All'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Status filter
                SizedBox(
                  height: 40,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        underline: const SizedBox.shrink(),
                        icon: const Icon(Icons.expand_more, size: 18),
                        items: _statusFilters.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status == 'All' ? 'Svi statusi' : status),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedStatus = val ?? 'All'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Sort order
                SizedBox(
                  height: 40,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: DropdownButton<bool>(
                        value: _isDescending,
                        underline: const SizedBox.shrink(),
                        icon: const Icon(Icons.expand_more, size: 18),
                        items: const [
                          DropdownMenuItem(
                            value: true,
                            child: Text('Najnovije'),
                          ),
                          DropdownMenuItem(
                            value: false,
                            child: Text('Najstarije'),
                          ),
                        ],
                        onChanged: (val) => setState(() => _isDescending = val ?? true),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Reset filters
                if (_selectedAction != 'All' || _selectedStatus != 'All')
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red[700]),
                    onPressed: () => setState(() {
                      _selectedAction = 'All';
                      _selectedStatus = 'All';
                    }),
                    tooltip: 'Očisti filtere',
                  ),
              ],
            ),
          ),
          const Divider(height: 0),
          // Activity logs
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildQuery(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Greška: ${snapshot.error}'));
                }

                var docs = snapshot.data?.docs ?? [];

                // Apply all filters client-side to avoid Firestore composite index requirements
                if (_selectedAction != 'All') {
                  docs = docs
                      .where((d) => (d.data()['action'] as String? ?? '') == _selectedAction)
                      .toList();
                }

                if (_selectedStatus != 'All') {
                  docs = docs
                      .where((d) => (d.data()['status'] as String? ?? '') == _selectedStatus)
                      .toList();
                }

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Nema aktivnosti'),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final log = docs[index].data();
                    return ActivityLogTile(
                      log: log,
                      actionColor: _getActionColor(log['action'] ?? ''),
                      actionLabel: _getActionLabel(log['action'] ?? ''),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildQuery() {
    // No where clauses - all filtering done client-side to avoid composite index
    return _firestore
        .collection('activityLogs')
        .orderBy('timestamp', descending: _isDescending)
        .limit(100)
        .snapshots();
  }
}

class ActivityLogTile extends StatelessWidget {
  final Map<String, dynamic> log;
  final Color actionColor;
  final String actionLabel;

  const ActivityLogTile({
    super.key,
    required this.log,
    required this.actionColor,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = (log['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final timeString = DateFormat('HH:mm:ss  dd.MM.yyyy').format(timestamp);
    final success = log['success'] as bool? ?? false;
    final isProblem = (log['action'] as String?) == 'problem_reported';
    final description = log['description'] as String? ?? 'Nema opisa';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: isProblem
          ? Colors.red[50]
          : success
              ? Colors.green[50]
              : Colors.red[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isProblem
              ? Colors.red[300]!
              : success
                  ? Colors.green[200]!
                  : Colors.red[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isProblem)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.report, color: Colors.red, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Prijavljen problem',
                          style: TextStyle(
                            color: Colors.red[800],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Hitno',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Header: Action + Status
            Row(
              children: [
                // Action badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: actionColor, width: 1),
                  ),
                  child: Text(
                    actionLabel,
                    style: TextStyle(
                      color: actionColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isProblem
                        ? Colors.red[100]
                        : success
                            ? Colors.green[100]
                            : Colors.red[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isProblem
                        ? 'Problem'
                        : success
                            ? '✓ Uspješna'
                            : '✗ Greška',
                    style: TextStyle(
                      color: isProblem
                          ? Colors.red[700]
                          : success
                              ? Colors.green[700]
                              : Colors.red[700],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                // Time
                Text(
                  timeString,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            // Details
            if (log['memberName'] != null || log['lockerNumber'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    if (log['memberName'] != null)
                      Expanded(
                        child: _DetailChip(
                          label: 'Član',
                          value: log['memberName'] ?? 'N/A',
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (log['lockerNumber'] != null)
                      Expanded(
                        child: _DetailChip(
                          label: 'Ormar',
                          value: '${log['lockerSector'] ?? 'N/A'}-${log['lockerNumber'] ?? 'N/A'}',
                        ),
                      ),
                  ],
                ),
              ),
            // Error message
            if (!success && log['errorMessage'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Greška: ${log['errorMessage']}',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;

  const _DetailChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
