import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitgate_shared/fitgate_shared.dart';
import '../models/member_profile.dart';

class EditProfileScreen extends StatefulWidget {
  final MemberProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLoading = false;
  DateTime? _selectedBirthDate;
  String? _selectedCityId;
  List<Map<String, dynamic>> _cities = [];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.profile.fullName;
    _phoneController.text = ''; // Dodati phoneNumber u model
    _loadCities();
    _loadMemberData();
  }

  Future<void> _loadCities() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('cities')
          .orderBy('cityName')
          .get();
      
      setState(() {
        _cities = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': data['cityId'] as String,
            'name': data['cityName'] as String,
          };
        }).toList();
      });
    } catch (e) {
      print('Greška pri učitavanju gradova: $e');
    }
  }

  Future<void> _loadMemberData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.profile.id)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _phoneController.text = data['phoneNumber'] ?? '';
          _selectedCityId = data['cityId']?.toString();
          if (data['birthDate'] != null) {
            _selectedBirthDate = (data['birthDate'] as Timestamp).toDate();
          }
        });
      }
    } catch (e) {
      print('Greška pri učitavanju podataka: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.profile.id)
          .update({
        'name': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'cityId': _selectedCityId,
        'birthDate': _selectedBirthDate != null
            ? Timestamp.fromDate(_selectedBirthDate!)
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil uspješno ažuriran')),
        );
        Navigator.pop(context);
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
        title: const Text('Uredi Profil'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.blue[300]!,
                                  Colors.blue[700]!,
                                ],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                widget.profile.fullName
                                    .split(' ')
                                    .take(2)
                                    .map((e) => e[0].toUpperCase())
                                    .join(),
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[600],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Ime i prezime
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Ime i prezime',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Unesite ime i prezime';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email (readonly)
                    TextFormField(
                      initialValue: widget.profile.email,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabled: false,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Broj telefona
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Broj telefona',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: '+387 XX XXX XXX',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Grad
                    DropdownButtonFormField<String>(
                      value: _selectedCityId,
                      decoration: InputDecoration(
                        labelText: 'Grad',
                        prefixIcon: const Icon(Icons.location_city),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      hint: const Text('Odaberite grad'),
                      items: _cities.map((city) {
                        return DropdownMenuItem<String>(
                          value: city['id'],
                          child: Text(city['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCityId = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Datum rođenja
                    InkWell(
                      onTap: _selectBirthDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Datum rođenja',
                          prefixIcon: const Icon(Icons.cake),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _selectedBirthDate != null
                              ? '${_selectedBirthDate!.day}.${_selectedBirthDate!.month}.${_selectedBirthDate!.year}.'
                              : 'Odaberite datum',
                          style: TextStyle(
                            color: _selectedBirthDate != null
                                ? Colors.black
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save button
                    PrimaryButton(
                      label: 'Spremi promjene',
                      onPressed: _saveProfile,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
