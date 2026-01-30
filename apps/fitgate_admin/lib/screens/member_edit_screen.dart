import 'package:fitgate_admin/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:fitgate_shared/fitgate_shared.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _notesController;
  late DateTime _membershipValidUntil;
  DateTime? _birthDate;
  bool _cardAssigned = false;
  String _status = 'active';
  String? _originalCityId;
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
    _phoneController = TextEditingController();
    _cityController = TextEditingController();
    _notesController = TextEditingController();
    _membershipValidUntil =
        widget.member?.membershipValidUntil ?? DateTime.now().add(const Duration(days: 365));
    _birthDate = null;
    _cardAssigned = false;
    _status = widget.member?.status ?? 'active';

    if (_isEditMode) {
      _firestoreService.getMemberData(widget.member!.id).then((data) {
        if (data != null && mounted) {
          setState(() {
            _emailController.text = data['email'] ?? '';
            _phoneController.text = data['phoneNumber'] ?? '';
            // If we have a cityId, fetch the city name for display
            _originalCityId = data['cityId'];
            if (_originalCityId != null) {
              _firestoreService.getCityById(_originalCityId!).then((cityDoc) {
                if (cityDoc != null && mounted) {
                  setState(() {
                    _cityController.text = cityDoc['cityName'] ?? _originalCityId!;
                  });
                }
              }).catchError((_) {
                _cityController.text = data['city'] ?? _originalCityId!;
              });
            } else {
              _cityController.text = data['city'] ?? '';
            }
            _notesController.text = data['notes'] ?? '';
            _cardAssigned = data['cardAssigned'] ?? false;
            _status = data['status'] ?? _status;
            if (data['birthDate'] is Timestamp) {
              _birthDate = (data['birthDate'] as Timestamp).toDate();
            } else if (data['birthDate'] is String) {
              try {
                _birthDate = DateTime.parse(data['birthDate']);
              } catch (_) {}
            }
            // membershipValidUntil may be present in the document
            if (data['membershipValidUntil'] is Timestamp) {
              _membershipValidUntil = (data['membershipValidUntil'] as Timestamp).toDate();
            } else if (data['membershipValidUntil'] is String) {
              try {
                _membershipValidUntil = DateTime.parse(data['membershipValidUntil']);
              } catch (_) {}
            }
          });
        }
      }).catchError((e) {
        // ignore errors for optional fields
      });
    }
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
        // persist additional fields like email, phone, notes, city, birthDate, cardAssigned, status
        final fields = <String, dynamic>{
          'email': _emailController.text,
          'phoneNumber': _phoneController.text,
          'notes': _notesController.text,
          'cityId': _cityController.text,
          'cardAssigned': _cardAssigned,
          'status': _status,
        };
        if (_birthDate != null) fields['birthDate'] = Timestamp.fromDate(_birthDate!);
        await _firestoreService.updateMemberFields(widget.member!.id, fields);
      } else {
        final newId = await _firestoreService.createMember(member);
        final fields = <String, dynamic>{
          'email': _emailController.text,
          'phoneNumber': _phoneController.text,
          'notes': _notesController.text,
          'cityId': _cityController.text,
          'cardAssigned': _cardAssigned,
          'status': _status,
        };
        if (_birthDate != null) fields['birthDate'] = Timestamp.fromDate(_birthDate!);
        await _firestoreService.updateMemberFields(newId, fields);
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
                    // Membership valid until picker
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
                    const SizedBox(height: 16),
                    // Additional editable fields
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Telefon',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    // Birth date picker
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _birthDate ?? DateTime(2000, 1, 1),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _birthDate = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Datum rođenja',
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
                          _birthDate != null
                              ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                              : 'Nije uneseno',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cityController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Grad',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Napomene',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _cardAssigned,
                          onChanged: (v) => setState(() => _cardAssigned = v ?? false),
                        ),
                        const SizedBox(width: 4),
                        const Text('Kartica dodijeljena'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Status radio buttons
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Status'),
                        Row(
                          children: [
                            Radio<String>(
                              value: 'active',
                              groupValue: _status,
                              onChanged: (v) => setState(() => _status = v ?? 'active'),
                            ),
                            const Text('Aktivno'),
                            const SizedBox(width: 12),
                            Radio<String>(
                              value: 'expired',
                              groupValue: _status,
                              onChanged: (v) => setState(() => _status = v ?? 'expired'),
                            ),
                            const Text('Isteklo'),
                            const SizedBox(width: 12),
                            Radio<String>(
                              value: 'suspended',
                              groupValue: _status,
                              onChanged: (v) => setState(() => _status = v ?? 'suspended'),
                            ),
                            const Text('Suspenzivirano'),
                          ],
                        ),
                      ],
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
