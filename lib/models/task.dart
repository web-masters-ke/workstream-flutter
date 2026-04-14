import 'business.dart';

enum TaskStatus {
  available,
  assigned,
  inProgress,
  submitted,
  completed,
  rejected,
  cancelled;

  String get label => switch (this) {
    TaskStatus.available => 'Available',
    TaskStatus.assigned => 'Assigned',
    TaskStatus.inProgress => 'In Progress',
    TaskStatus.submitted => 'Submitted',
    TaskStatus.completed => 'Completed',
    TaskStatus.rejected => 'Rejected',
    TaskStatus.cancelled => 'Cancelled',
  };

  static TaskStatus fromString(String? v) {
    switch ((v ?? '').toUpperCase()) {
      case 'ASSIGNED':
        return TaskStatus.assigned;
      case 'IN_PROGRESS':
      case 'INPROGRESS':
        return TaskStatus.inProgress;
      case 'SUBMITTED':
        return TaskStatus.submitted;
      case 'COMPLETED':
        return TaskStatus.completed;
      case 'REJECTED':
        return TaskStatus.rejected;
      case 'CANCELLED':
      case 'CANCELED':
        return TaskStatus.cancelled;
      default:
        return TaskStatus.available;
    }
  }

  String get apiValue => switch (this) {
    TaskStatus.inProgress => 'IN_PROGRESS',
    _ => name.toUpperCase(),
  };
}

enum TaskCategory {
  customerSupport,
  sales,
  orderProcessing,
  dataEntry,
  callCenter,
  other;

  String get label => switch (this) {
    TaskCategory.customerSupport => 'Customer Support',
    TaskCategory.sales => 'Sales',
    TaskCategory.orderProcessing => 'Order Processing',
    TaskCategory.dataEntry => 'Data Entry',
    TaskCategory.callCenter => 'Call Center',
    TaskCategory.other => 'General',
  };

  static TaskCategory fromString(String? v) {
    switch ((v ?? '').toUpperCase()) {
      case 'CUSTOMER_SUPPORT':
        return TaskCategory.customerSupport;
      case 'SALES':
        return TaskCategory.sales;
      case 'ORDER_PROCESSING':
        return TaskCategory.orderProcessing;
      case 'DATA_ENTRY':
        return TaskCategory.dataEntry;
      case 'CALL_CENTER':
        return TaskCategory.callCenter;
      default:
        return TaskCategory.other;
    }
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final String? instructions;
  final TaskCategory category;
  final TaskStatus status;
  final double reward;
  final String currency;
  final DateTime? deadline;
  final int? slaMinutes;
  final Business? business;
  final String? assignedAgentId;
  final DateTime createdAt;
  final List<String> tags;

  Task({
    required this.id,
    required this.title,
    required this.description,
    this.instructions,
    required this.category,
    required this.status,
    required this.reward,
    required this.currency,
    this.deadline,
    this.slaMinutes,
    this.business,
    this.assignedAgentId,
    required this.createdAt,
    required this.tags,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      instructions: json['instructions']?.toString(),
      category: TaskCategory.fromString(json['category']?.toString()),
      status: TaskStatus.fromString(json['status']?.toString()),
      reward: _toDouble(json['reward']),
      currency: json['currency']?.toString() ?? 'KES',
      deadline: _toDate(json['deadline']),
      slaMinutes: json['slaMinutes'] == null ? null : _toInt(json['slaMinutes']),
      business: json['business'] is Map<String, dynamic>
          ? Business.fromJson(json['business'] as Map<String, dynamic>)
          : null,
      assignedAgentId: json['assignedAgentId']?.toString(),
      createdAt: _toDate(json['createdAt']) ?? DateTime.now(),
      tags: json['tags'] is List
          ? (json['tags'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return DateTime.tryParse(s);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'instructions': instructions,
    'category': category.name,
    'status': status.apiValue,
    'reward': reward,
    'currency': currency,
    'deadline': deadline?.toIso8601String(),
    'slaMinutes': slaMinutes,
    'business': business == null
        ? null
        : {
            'id': business!.id,
            'name': business!.name,
            'industry': business!.industry,
            'rating': business!.rating,
          },
    'assignedAgentId': assignedAgentId,
    'createdAt': createdAt.toIso8601String(),
    'tags': tags,
  };

  Duration? timeLeft() {
    if (deadline == null) return null;
    return deadline!.difference(DateTime.now());
  }
}
