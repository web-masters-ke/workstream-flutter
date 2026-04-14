class Wallet {
  final String id;
  final String currency;
  final double balance;
  final double pending;
  final double lifetimeEarnings;

  Wallet({
    required this.id,
    required this.currency,
    required this.balance,
    required this.pending,
    required this.lifetimeEarnings,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
    id: json['id']?.toString() ?? '',
    currency: json['currency']?.toString() ?? 'KES',
    balance: _d(json['balance']),
    pending: _d(json['pending']),
    lifetimeEarnings: _d(json['lifetimeEarnings']),
  );

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

enum TxnType {
  earning,
  payout,
  bonus,
  adjustment,
  refund;

  String get label => switch (this) {
    TxnType.earning => 'Task earning',
    TxnType.payout => 'Payout',
    TxnType.bonus => 'Bonus',
    TxnType.adjustment => 'Adjustment',
    TxnType.refund => 'Refund',
  };

  static TxnType fromString(String? v) {
    switch ((v ?? '').toUpperCase()) {
      case 'PAYOUT':
      case 'WITHDRAWAL':
        return TxnType.payout;
      case 'BONUS':
        return TxnType.bonus;
      case 'ADJUSTMENT':
        return TxnType.adjustment;
      case 'REFUND':
        return TxnType.refund;
      default:
        return TxnType.earning;
    }
  }
}

enum TxnStatus {
  pending,
  completed,
  failed;

  static TxnStatus fromString(String? v) {
    switch ((v ?? '').toUpperCase()) {
      case 'COMPLETED':
      case 'SUCCESS':
        return TxnStatus.completed;
      case 'FAILED':
        return TxnStatus.failed;
      default:
        return TxnStatus.pending;
    }
  }

  String get label => switch (this) {
    TxnStatus.pending => 'Pending',
    TxnStatus.completed => 'Completed',
    TxnStatus.failed => 'Failed',
  };
}

class WalletTransaction {
  final String id;
  final TxnType type;
  final TxnStatus status;
  final double amount;
  final String currency;
  final String? reference;
  final String? note;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.currency,
    this.reference,
    this.note,
    required this.createdAt,
  });

  bool get isDebit => type == TxnType.payout;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id']?.toString() ?? '',
        type: TxnType.fromString(json['type']?.toString()),
        status: TxnStatus.fromString(json['status']?.toString()),
        amount: _d(json['amount']),
        currency: json['currency']?.toString() ?? 'KES',
        reference: json['reference']?.toString(),
        note: json['note']?.toString(),
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
