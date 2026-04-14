import '../models/wallet.dart';
import 'api_service.dart';

class PayoutResult {
  final String reference;
  final String status;
  PayoutResult(this.reference, this.status);
}

class WalletService {
  final _api = ApiService.instance;

  Future<Wallet> get() async {
    final r = await _api.get('/wallet');
    final data = unwrap<Map<String, dynamic>>(r);
    return Wallet.fromJson(data);
  }

  Future<List<WalletTransaction>> transactions({int page = 1}) async {
    final r = await _api.get(
      '/wallet/transactions',
      query: {'page': page, 'size': 30},
    );
    final data = unwrap<dynamic>(r);
    final list = data is List
        ? data
        : (data is Map<String, dynamic> && data['items'] is List
              ? data['items'] as List
              : const []);
    return list
        .whereType<Map>()
        .map((e) => WalletTransaction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<PayoutResult> requestPayout({
    required double amount,
    required String method,
    required String destination,
  }) async {
    final r = await _api.post(
      '/wallet/payout',
      body: {'amount': amount, 'method': method, 'destination': destination},
    );
    final d = unwrap<Map<String, dynamic>>(r);
    return PayoutResult(
      d['reference']?.toString() ??
          'WS${DateTime.now().millisecondsSinceEpoch}',
      d['status']?.toString() ?? 'PROCESSING',
    );
  }
}
