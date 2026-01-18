import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({Key? key}) : super(key: key);

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedAction = 'All';
  String _selectedStatus = 'All';
  
  final List<String> _actionFilters = ['All', 'assign_locker', 'force_release', 'mark_out_of_service', 'suspend_member'];
  final List<String> _statusFilters = ['All', 'completed', 'failed'];

  String _getActionLabel(String action) {
    switch (action) {
      case 'assign_locker':
        return 'Dodjela ormara';
      case 'force_release':
        return 'Oslobađanje ormara';
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
                  child: FilterChip(
                    label: Text(_selectedAction),
                    onSelected: (_) => _showActionFilterDialog(),
                    backgroundColor: Colors.grey[100],
                    selectedColor: Colors.blue[100],
                    selected: _selectedAction != 'All',
                  ),
                ),
                const SizedBox(width: 8),
                // Status filter
                SizedBox(
                  height: 40,
                  child: FilterChip(
                    label: Text(_selectedStatus),
                    onSelected: (_) => _showStatusFilterDialog(),
                    backgroundColor: Colors.grey[100],
                    selectedColor: Colors.green[100],
                    selected: _selectedStatus != 'All',
                  ),
                ),
                const SizedBox(width: 8),
                // Reset filters
                if (_selectedAction != 'All' || _selectedStatus != 'All')
                  SizedBox(
                    height: 40,
                    child: FilterChip(
                      label: const Text('Očisti'),
                      onSelected: (_) => setState(() {
                        _selectedAction = 'All';
                        _selectedStatus = 'All';
                      }),
                      backgroundColor: Colors.red[100],
                      deleteIcon: const Icon(Icons.close),
                      onDeleted: () => setState(() {
                        _selectedAction = 'All';
                        _selectedStatus = 'All';
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 0),
          // Activity logs
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Greška: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Nema aktivnosti'),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final log = docs[index].data() as Map<String, dynamic>;
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

  Stream<QuerySnapshot> _buildQuery() {
    var query = _firestore.collection('activityLogs').orderBy('timestamp', descending: true);

    if (_selectedAction != 'All') {
      query = query.where('action', isEqualTo: _selectedAction) as Query<Map<String, dynamic>>;
    }

    if (_selectedStatus != 'All') {
      query = query.where('status', isEqualTo: _selectedStatus) as Query<Map<String, dynamic>>;
    }

    return query.limit(100).snapshots();
  }

  void _showActionFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filtriraj po akciji'),
        children: _actionFilters.map((action) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() => _selectedAction = action);
              Navigator.pop(context);
            },
            child: Text(action == 'All' ? 'Sve akcije' : _getActionLabel(action)),
          );
        }).toList(),
      ),
    );
  }

  void _showStatusFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filtriraj po statusu'),
        children: _statusFilters.map((status) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() => _selectedStatus = status);
              Navigator.pop(context);
            },
            child: Text(status == 'All' ? 'Svi statusi' : status),
          );
        }).toList(),
      ),
    );
  }
}

class ActivityLogTile extends StatelessWidget {
  final Map<String, dynamic> log;
  final Color actionColor;
  final String actionLabel;

  const ActivityLogTile({
    Key? key,
    required this.log,
    required this.actionColor,
    required this.actionLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timestamp = (log['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final timeString = DateFormat('HH:mm:ss  dd.MM.yyyy').format(timestamp);
    final success = log['success'] as bool? ?? false;
    final description = log['description'] as String? ?? 'Nema opisa';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: success ? Colors.green[50] : Colors.red[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: success ? Colors.green[200]! : Colors.red[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    color: success ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    success ? '✓ Uspješna' : '✗ Greška',
                    style: TextStyle(
                      color: success ? Colors.green[700] : Colors.red[700],
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
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

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
