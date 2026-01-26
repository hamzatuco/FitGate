import 'dart:convert';
import 'package:http/http.dart' as http;

class LockerService {
final String apiUrl = 'https://europe-west1-fitgate-iot.cloudfunctions.net';

  Future<void> openLocker({required String lockerId, required String memberId}) async {
    final response = await http.post(
      Uri.parse('$apiUrl/openLocker'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'lockerId': lockerId,
        'memberId': memberId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Neuspješno otvaranje ormarica: ${response.body}');
    }
  }
}
