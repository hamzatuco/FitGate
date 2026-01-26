import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fitgate_shared/fitgate_shared.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';

/// Member details screen showing comprehensive member information
class MemberDetailsScreen extends StatefulWidget {
  final Member member;

  const MemberDetailsScreen({super.key, required this.member});

  @override
  State<MemberDetailsScreen> createState() => _MemberDetailsScreenState();
}

class _MemberDetailsScreenState extends State<MemberDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;
  late Member _member;
  Locker? _assignedLocker;
  Map<String, dynamic> _additionalData = {};

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _loadMemberDetails();
  }

  Future<void> _loadMemberDetails() async {
    try {
      // Load locker info if assigned
      if (_member.assignedLocker != null) {
        final locker = await _firestoreService.getLocker(_member.assignedLocker!);
        if (mounted) {
          setState(() => _assignedLocker = locker);
        }
      }

      // Load additional member data from Firestore
      final memberData = await _firestoreService.getMemberData(_member.id);
      if (memberData != null) {
        // Fetch city name if cityId exists
        if (memberData['cityId'] != null) {
          try {
            final cityDoc = await _firestoreService.getCityById(memberData['cityId']);
            if (cityDoc != null) {
              memberData['city'] = cityDoc['cityName'] ?? memberData['cityId'];
            } else {
              memberData['city'] = memberData['cityId'];
            }
          } catch (e) {
            memberData['city'] = memberData['cityId'];
          }
        }
        if (mounted) {
          setState(() => _additionalData = memberData);
        }
      }
    } catch (e) {
      debugPrint('Greška pri učitavanju podataka člana: $e');
    }
  }

  Future<void> _suspendMember() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspenziviranje člana'),
        content: Text(
          'Jeste li sigurni da želite suspenzivirati člana ${_member.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Suspenzivira'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final updatedMember = Member(
        id: _member.id,
        name: _member.name,
        cardId: _member.cardId,
        status: 'suspended',
        assignedLocker: _member.assignedLocker,
        membershipValidUntil: _member.membershipValidUntil,
        registeredAt: _member.registeredAt,
      );

      await _firestoreService.updateMember(_member.id, updatedMember);
      
      await _firestoreService.logActivity(
        action: 'suspend_member',
        memberId: _member.id,
        memberName: _member.name,
        staffId: 'admin-1',
        staffName: 'Admin',
        description: 'Član ${_member.name} je suspenziviran',
        success: true,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _member = updatedMember;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Član je uspješno suspenziviran')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  Future<void> _releaseLocked() async {
    if (_member.assignedLocker == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Otpuštanje ormara'),
        content: Text(
          'Jeste li sigurni da želite otpustiti ormar ${_member.assignedLocker} od člana ${_member.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
            ),
            child: const Text('Otpusti'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final lockerNumber = _member.assignedLocker;
      
      final updatedMember = Member(
        id: _member.id,
        name: _member.name,
        cardId: _member.cardId,
        status: _member.status,
        assignedLocker: null,
        membershipValidUntil: _member.membershipValidUntil,
        registeredAt: _member.registeredAt,
      );

      await _firestoreService.updateMember(_member.id, updatedMember);
      
      // Update locker status to free
      if (_assignedLocker != null) {
        final updatedLocker = Locker(
          id: _assignedLocker!.id,
          number: _assignedLocker!.number,
          sector: _assignedLocker!.sector,
          status: 'free',
          assignedTo: null,
          currentMember: null,
          lastAccessTime: _assignedLocker!.lastAccessTime,
        );
        await _firestoreService.updateLocker(_assignedLocker!.id, updatedLocker);
      }

      await _firestoreService.logActivity(
        action: 'force_release',
        memberId: _member.id,
        memberName: _member.name,
        staffId: 'admin-1',
        staffName: 'Admin',
        description: 'Ormar $lockerNumber je otpušten od člana ${_member.name}',
        success: true,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _member = updatedMember;
          _assignedLocker = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ormar je uspješno otpušten')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalji člana'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Member header card
                  _buildHeaderCard(),
                  const SizedBox(height: 32),

                  // Two column layout for desktop
                  if (!isMobile)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 1, child: _buildLeftColumn()),
                        const SizedBox(width: 32),
                        Expanded(flex: 1, child: _buildRightColumn()),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildLeftColumn(),
                        const SizedBox(height: 32),
                        _buildRightColumn(),
                      ],
                    ),
                  const SizedBox(height: 32),

                  // Action buttons
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Row(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
            ),
            child: Center(
              child: Text(
                _member.name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _member.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _member.cardId,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    fontFamily: 'Courier',
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getMemberStatusColor(_member.status)
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getMemberStatusLabel(_member.status),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kontakt informacije
        _buildSection(
          title: '📧 Kontakt informacije',
          children: [
            _buildInfoRow(
              'Email',
              _additionalData['email'] ?? 'Nije dostupno',
            ),
            _buildInfoRow(
              'Telefon',
              _additionalData['phoneNumber'] ?? 'Nije dostupno',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RFID Kartica',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _member.cardId,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Kopiraj RFID',
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: _member.cardId));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('RFID kopiran u clipboard')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Lični podaci
        _buildSection(
          title: '👤 Lični podaci',
          children: [
            _buildInfoRow(
              'Grad',
              _additionalData['city'] ?? 'Nije dostupno',
            ),
            _buildInfoRow(
              'Datum rođenja',
              _formatDate(_additionalData['birthDate']),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Članarina informacije
        _buildSection(
          title: '💳 Članarina',
          children: [
            _buildInfoRow(
              'Važeća do',
              _formatDate(_member.membershipValidUntil),
            ),
            _buildInfoRow(
              'Registrovan',
              _formatDate(_member.registeredAt),
            ),
            _buildDaysRemainingRow(),
          ],
        ),
        const SizedBox(height: 24),

        // Ormar informacije
        _buildSection(
          title: '🔐 Ormar',
          children: _assignedLocker != null
              ? [
                  _buildInfoRow('Broj', _assignedLocker!.number),
                  _buildInfoRow('Sektor', _assignedLocker!.sector),
                  _buildInfoRow('Status', _assignedLocker!.status),
                  if (_assignedLocker!.lastAccessTime != null)
                    _buildInfoRow(
                      'Zadnja pristupa',
                      _assignedLocker!.lastAccessTime!
                          .toString()
                          .split('.')[0],
                    ),
                ]
              : [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Nema dodijeljena ormara',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _suspendMember,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _member.status == 'suspended'
                      ? Colors.red.withOpacity(0.3)
                      : Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _member.status == 'suspended'
                      ? 'Član je suspenziviran'
                      : 'Suspenzivira člana',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (_member.assignedLocker != null)
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _releaseLocked,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Otpusti ormar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context)
                      .pushNamed('/member/edit', arguments: _member);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Uredi člana',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysRemainingRow() {
    final daysRemaining =
        _member.membershipValidUntil.difference(DateTime.now()).inDays;
    final color = daysRemaining > 30
        ? Colors.green
        : daysRemaining > 0
            ? Colors.orange
            : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Preostalo dana',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              daysRemaining > 0 ? '$daysRemaining dana' : 'Istekla',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getMemberStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getMemberStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Aktivno';
      case 'expired':
        return 'Isteklo';
      case 'suspended':
        return 'Suspenzivirano';
      default:
        return status;
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Nije dostupno';
    try {
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else {
        return 'Nije dostupno';
      }
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return 'Nije dostupno';
    }
  }
}
