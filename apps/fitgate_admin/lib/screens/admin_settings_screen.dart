import 'package:flutter/material.dart';
import '../services/firestore_initializer.dart';

/// Admin settings screen for database initialization
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _isInitializing = false;
  String _status = '';

  Future<void> _initializeDatabase() async {
    setState(() {
      _isInitializing = true;
      _status = '⏳ Inicijalizacija u toku...';
    });

    try {
      final initializer = FirestoreInitializer();
      await initializer.initializeCollections();

      setState(() {
        _status = '✅ Baza je uspešno inicijalizovana!';
        _isInitializing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Baza je uspešno inicijalizovana!')),
        );
      }
    } catch (e) {
      setState(() {
        _status = '❌ Greška: $e';
        _isInitializing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri inicijalizaciji: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Podešavanja'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inicijalizacija Baze Podataka',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚠️ Ova akcija će kreirati:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('• 40 novih ormara (sektori A-D, po 10 komada)'),
                    const Text('• ActivityLogs kolekcija'),
                    const SizedBox(height: 16),
                    if (_status.isNotEmpty)
                      Text(
                        _status,
                        style: TextStyle(
                          color: _status.startsWith('✅')
                              ? Colors.green
                              : _status.startsWith('❌')
                                  ? Colors.red
                                  : Colors.blue,
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isInitializing ? null : _initializeDatabase,
                      icon: _isInitializing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.build),
                      label: Text(
                        _isInitializing
                            ? 'Inicijalizacija u toku...'
                            : 'Inicijalizuj Bazu',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
