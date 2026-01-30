import 'package:fitgate_admin/services/firestore_service.dart';
import 'package:fitgate_admin/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:fitgate_shared/fitgate_shared.dart';
import '../widgets/loading_view.dart';
import '../widgets/empty_view.dart';
import '../widgets/status_badge.dart';

/// Members management screen
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  List<Member> _members = [];
  String _searchQuery = '';
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMembers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Osvježi članove kada se vrati u foreground
    if (state == AppLifecycleState.resumed) {
      _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await _firestoreService.getMembers();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _members = members;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri učitavanju članova: $e')),
        );
      }
    }
  }

  Future<void> _suspendMember(Member member) async {
    try {
      final updatedMember = Member(
        id: member.id,
        name: member.name,
        cardId: member.cardId,
        status: 'suspended',
        assignedLocker: member.assignedLocker,
        membershipValidUntil: member.membershipValidUntil,
        registeredAt: member.registeredAt,
      );
      
      await _firestoreService.updateMember(member.id, updatedMember);
      
      // Log activity
      await _firestoreService.logActivity(
        action: 'suspend_member',
        memberId: member.id,
        memberName: member.name,
        staffId: 'admin-1', // TODO: Get from actual admin user
        staffName: 'Admin',
        description: 'Član ${member.name} je suspenziviran',
        success: true,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Član je suspenziviran')),
        );
        _loadMembers();
      }
    } catch (e) {
      // Log failed activity
      await _firestoreService.logActivity(
        action: 'suspend_member',
        memberId: member.id,
        memberName: member.name,
        staffId: 'admin-1',
        staffName: 'Admin',
        description: 'Pokušaj suspenzije člana ${member.name}',
        success: false,
        errorMessage: e.toString(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri suspenziji člana: $e')),
        );
      }
    }
  }

  List<Member> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    return _members
        .where((m) =>
            m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            m.cardId.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? LoadingView(message: 'Učitavanje članova...')
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
                            'Članovi',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Upravljanje članovima i dodjelama RFID kartica',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).pushNamed('/member/edit');
                          // Osvježi liste nakon povratka
                          _loadMembers();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Registruj Člana'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _loadMembers,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Osvježi'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Search bar
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Pretražite po imenu ili ID karici...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Members table
                  Expanded(
                    child: _filteredMembers.isEmpty
                        ? EmptyView(
                            title: 'Nema pronađenih članova',
                            subtitle: _searchQuery.isEmpty
                              ? 'Registruj novog člana da počneš'
                              : 'Nema članova koji odgovaraju pretražavanju',
                            icon: Icons.people_outline,
                            actionText: 'Registruj Člana',
                            onAction: () {
                              Navigator.of(context).pushNamed('/member/edit');
                            },
                          )
                        : Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side:
                                  BorderSide(color: Colors.grey[200]!, width: 1),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                showCheckboxColumn: false,
                                columns: const [
                                  DataColumn(label: Text('Ime')),
                                  DataColumn(label: Text('RFID Kartica')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Ormar')),
                                  DataColumn(label: Text('Važeći Do')),
                                  DataColumn(label: Text('Akcije')),
                                ],
                                rows: _filteredMembers
                                    .map(
                                      (member) => DataRow(
                                        onSelectChanged: (_) {
                                          Navigator.of(context).pushNamed(
                                            '/member/details',
                                            arguments: member,
                                          );
                                        },
                                        cells: [
                                          DataCell(Text(member.name)),
                                          DataCell(Text(member.cardId)),
                                          DataCell(
                                            StatusBadge(status: member.status),
                                          ),
                                          DataCell(
                                            Text(member.assignedLocker ?? 'N/A'),
                                          ),
                                          DataCell(
                                            Text(member.membershipValidUntil
                                                .toString()
                                                .split(' ')[0]),
                                          ),
                                          DataCell(
                                          Row(
                                            children: [
                                              TextButton(
                                                onPressed: () async {
                                                  await Navigator.of(context)
                                                      .pushNamed('/member/edit',
                                                          arguments: member);
                                                  // Osvježi liste nakon povratka
                                                  _loadMembers();
                                                },
                                                child: const Text('Uredi'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  _suspendMember(member);
                                                },
                                                child: const Text(
                                                  'Suspenzija',
                                                  style: TextStyle(
                                                      color: Colors.orange),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      ),
                                    )
                                    .toList(),
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
