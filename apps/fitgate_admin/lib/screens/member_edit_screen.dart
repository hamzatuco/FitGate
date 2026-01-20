import 'package:fitgate_admin/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:fitgate_shared/fitgate_shared.dart';
import '../widgets/loading_view.dart';

/// Member registration and edit screen
class MemberEditScreen extends StatefulWidget {
  final Member? member;

  const MemberEditScreen({super.key, this.member});

  @override
  State<MemberEditScreen> createState() => _MemberEditScreenState();
}

class _MemberEditScreenState extends State<MemberEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _cardIdController;
  late TextEditingController _emailController;
  late DateTime _membershipValidUntil;
  bool _isLoading = false;
  bool _isEditMode = false;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.member != null;
    _nameController = TextEditingController(text: widget.member?.name ?? '');
    _cardIdController =
        TextEditingController(text: widget.member?.cardId ?? '');
    _emailController = TextEditingController();
    _membershipValidUntil =
        widget.member?.membershipValidUntil ?? DateTime.now().add(const Duration(days: 365));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cardIdController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_nameController.text.isEmpty || _cardIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Molim popunite sva polja')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final member = Member(
        id: widget.member?.id ?? '',
        name: _nameController.text,
        cardId: _cardIdController.text,
        status: widget.member?.status ?? 'active',
        assignedLocker: widget.member?.assignedLocker,
        membershipValidUntil: _membershipValidUntil,
        registeredAt: widget.member?.registeredAt ?? DateTime.now(),
      );

      if (_isEditMode) {
        await _firestoreService.updateMember(widget.member!.id, member);
      } else {
        await _firestoreService.createMember(member);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Član uspješno ažuriran'
                : 'Član uspješno registrovan'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Uredi Člana' : 'Registruj Novog Člana'),
        elevation: 0,
      ),
      body: _isLoading
            ? LoadingView(
              message: _isEditMode
                ? 'Ažuriranje člana...'
                : 'Registrovanje člana...')
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personal Information Section
                    Text(
                      'Lični Podaci',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Puno Ime',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 32),

                    // RFID Card Section
                    Text(
                      'Dodjela RFID Kartice',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cardIdController,
                            decoration: InputDecoration(
                              labelText: 'UID Kartice',
                              hintText: 'RF123456789',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Scan RFID card
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('RFID sken uskoro dostupan')),
                            );
                          },
                          icon: const Icon(Icons.nfc),
                          label: const Text('Skeniraj Karticu'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Membership Section
                    Text(
                      'Detalji Članstva',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _membershipValidUntil,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setState(() => _membershipValidUntil = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Važeći Do',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          '${_membershipValidUntil.day}/${_membershipValidUntil.month}/${_membershipValidUntil.year}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Otkaži'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleSave,
                          child: Text(_isEditMode ? 'Ažuriraj Člana' : 'Registruj Člana'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
