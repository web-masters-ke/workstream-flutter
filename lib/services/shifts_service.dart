import 'api_service.dart';

class Shift {
  final String id;
  final DateTime start;
  final DateTime end;
  final String label;
  final String status; // SCHEDULED, ACTIVE, MISSED, COMPLETED
  Shift({
    required this.id,
    required this.start,
    required this.end,
    required this.label,
    required this.status,
  });

  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
        id: j['id']?.toString() ?? '',
        start: DateTime.tryParse(j['start']?.toString() ?? '') ?? DateTime.now(),
        end: DateTime.tryParse(j['end']?.toString() ?? '') ??
            DateTime.now().add(const Duration(hours: 4)),
        label: j['label']?.toString() ?? 'Shift',
        status: j['status']?.toString() ?? 'SCHEDULED',
      );
}

class ShiftsService {
  final _api = ApiService.instance;

  Future<List<Shift>> mine() async {
    try {
      final r = await _api.get('/agents/me/shifts');
      final d = unwrap<dynamic>(r);
      final list = d is List ? d : const <dynamic>[];
      return list
          .whereType<Map>()
          .map((e) => Shift.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      final now = DateTime.now();
      return [
        Shift(
          id: 's1',
          start: DateTime(now.year, now.month, now.day, 9),
          end: DateTime(now.year, now.month, now.day, 13),
          label: 'Morning shift — Customer Support',
          status: 'ACTIVE',
        ),
        Shift(
          id: 's2',
          start: DateTime(now.year, now.month, now.day + 1, 14),
          end: DateTime(now.year, now.month, now.day + 1, 18),
          label: 'Afternoon shift — Sales',
          status: 'SCHEDULED',
        ),
        Shift(
          id: 's3',
          start: DateTime(now.year, now.month, now.day + 3, 9),
          end: DateTime(now.year, now.month, now.day + 3, 13),
          label: 'Morning shift — Order Processing',
          status: 'SCHEDULED',
        ),
      ];
    }
  }
}
