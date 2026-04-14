import 'package:flutter/foundation.dart';

import '../models/wallet.dart';
import '../services/wallet_service.dart';

class WalletController extends ChangeNotifier {
  final _svc = WalletService();

  Wallet? _wallet;
  List<WalletTransaction> _transactions = [];
  bool _loading = false;
  String? _error;

  Wallet? get wallet => _wallet;
  List<WalletTransaction> get transactions => _transactions;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _wallet = await _svc.get();
      _transactions = await _svc.transactions();
    } catch (e) {
      _error = e.toString();
      _wallet = null;
      _transactions = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String? _lastPayoutRef;
  String? get lastPayoutRef => _lastPayoutRef;

  Future<bool> requestPayout({
    required double amount,
    required String method,
    required String destination,
  }) async {
    try {
      final result = await _svc.requestPayout(
        amount: amount,
        method: method,
        destination: destination,
      );
      _lastPayoutRef = result.reference;
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> reload() => load();
}
