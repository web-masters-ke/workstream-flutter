// Models for the Free Agents Marketplace feature

class MarketplaceListing {
  final String id;
  final String title;
  final String description;
  final String? category;
  final List<String> requiredSkills;
  final int budgetCents;
  final String currency;
  final DateTime dueAt;
  final String? locationText;
  final String marketplaceStatus;
  final String businessName;
  final String? businessLogo;
  final String? businessCity;
  final int bidCount;
  final String createdAt;
  // Only present on detail view
  final MyBidOnListing? myBid;

  const MarketplaceListing({
    required this.id,
    required this.title,
    required this.description,
    this.category,
    required this.requiredSkills,
    required this.budgetCents,
    required this.currency,
    required this.dueAt,
    this.locationText,
    required this.marketplaceStatus,
    required this.businessName,
    this.businessLogo,
    this.businessCity,
    required this.bidCount,
    required this.createdAt,
    this.myBid,
  });

  factory MarketplaceListing.fromJson(Map<String, dynamic> json) {
    return MarketplaceListing(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString(),
      requiredSkills: _parseStringList(json['requiredSkills']),
      budgetCents: _parseInt(json['budgetCents']),
      currency: json['currency']?.toString() ?? 'KES',
      dueAt: _parseDate(json['dueAt']),
      locationText: json['locationText']?.toString(),
      marketplaceStatus: json['marketplaceStatus']?.toString() ?? 'APPROVED',
      businessName: json['businessName']?.toString() ?? '',
      businessLogo: json['businessLogo']?.toString(),
      businessCity: json['businessCity']?.toString(),
      bidCount: _parseInt(json['bidCount']),
      createdAt: json['createdAt']?.toString() ?? '',
      myBid: json['myBid'] != null
          ? MyBidOnListing.fromJson(json['myBid'] as Map<String, dynamic>)
          : null,
    );
  }

  double get budgetKes => budgetCents / 100.0;

  /// Days until deadline. Negative = overdue.
  int get daysUntilDue {
    return dueAt.difference(DateTime.now()).inDays;
  }

  String get deadlineLabel {
    final d = daysUntilDue;
    if (d < 0) return 'Overdue';
    if (d == 0) return 'Today';
    if (d == 1) return 'Tomorrow';
    if (d <= 7) return '${d}d left';
    return '${dueAt.day} ${_monthShort(dueAt.month)}';
  }

  bool get isDeadlineUrgent => daysUntilDue <= 3;
}

class MyBidOnListing {
  final String id;
  final int proposedCents;
  final String? coverNote;
  final int? estimatedDays;
  final String status;
  final String? rejectionNote;

  const MyBidOnListing({
    required this.id,
    required this.proposedCents,
    this.coverNote,
    this.estimatedDays,
    required this.status,
    this.rejectionNote,
  });

  factory MyBidOnListing.fromJson(Map<String, dynamic> json) {
    return MyBidOnListing(
      id: json['id']?.toString() ?? '',
      proposedCents: _parseInt(json['proposedCents']),
      coverNote: json['coverNote']?.toString(),
      estimatedDays: json['estimatedDays'] != null ? _parseInt(json['estimatedDays']) : null,
      status: json['status']?.toString() ?? 'PENDING',
      rejectionNote: json['rejectionNote']?.toString(),
    );
  }

  double get proposedKes => proposedCents / 100.0;
}

class BidItem {
  final String id;
  final String agentId;
  final String agentName;
  final String? agentEmail;
  final List<String> agentSkills;
  final int completedTaskCount;
  final int proposedCents;
  final String? coverNote;
  final int? estimatedDays;
  final String status;
  final String? rejectionNote;
  final String createdAt;

  const BidItem({
    required this.id,
    required this.agentId,
    required this.agentName,
    this.agentEmail,
    required this.agentSkills,
    required this.completedTaskCount,
    required this.proposedCents,
    this.coverNote,
    this.estimatedDays,
    required this.status,
    this.rejectionNote,
    required this.createdAt,
  });

  factory BidItem.fromJson(Map<String, dynamic> json) {
    final agent = json['agent'] as Map<String, dynamic>? ?? {};
    final user = agent['user'] as Map<String, dynamic>? ?? {};
    return BidItem(
      id: json['id']?.toString() ?? '',
      agentId: json['agentId']?.toString() ?? '',
      agentName: user['name']?.toString() ?? agent['name']?.toString() ?? 'Unknown agent',
      agentEmail: user['email']?.toString(),
      agentSkills: _parseStringList(agent['skills']),
      completedTaskCount: _parseInt(json['_completedTasks'] ?? agent['completedTaskCount'] ?? 0),
      proposedCents: _parseInt(json['proposedCents']),
      coverNote: json['coverNote']?.toString(),
      estimatedDays: json['estimatedDays'] != null ? _parseInt(json['estimatedDays']) : null,
      status: json['status']?.toString() ?? 'PENDING',
      rejectionNote: json['rejectionNote']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  double get proposedKes => proposedCents / 100.0;
}

class MyBid {
  final String id;
  final String taskId;
  final int proposedCents;
  final String? coverNote;
  final int? estimatedDays;
  final String status;
  final String? rejectionNote;
  final String? acceptedAt;
  final String? rejectedAt;
  final String createdAt;
  final BidListingInfo listing;

  const MyBid({
    required this.id,
    required this.taskId,
    required this.proposedCents,
    this.coverNote,
    this.estimatedDays,
    required this.status,
    this.rejectionNote,
    this.acceptedAt,
    this.rejectedAt,
    required this.createdAt,
    required this.listing,
  });

  factory MyBid.fromJson(Map<String, dynamic> json) {
    return MyBid(
      id: json['id']?.toString() ?? '',
      taskId: json['taskId']?.toString() ?? '',
      proposedCents: _parseInt(json['proposedCents']),
      coverNote: json['coverNote']?.toString(),
      estimatedDays: json['estimatedDays'] != null ? _parseInt(json['estimatedDays']) : null,
      status: json['status']?.toString() ?? 'PENDING',
      rejectionNote: json['rejectionNote']?.toString(),
      acceptedAt: json['acceptedAt']?.toString(),
      rejectedAt: json['rejectedAt']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      listing: BidListingInfo.fromJson(
        json['listing'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  double get proposedKes => proposedCents / 100.0;
}

class BidListingInfo {
  final String id;
  final String title;
  final String? category;
  final int budgetCents;
  final String currency;
  final String dueAt;
  final String? locationText;
  final String marketplaceStatus;
  final String businessName;

  const BidListingInfo({
    required this.id,
    required this.title,
    this.category,
    required this.budgetCents,
    required this.currency,
    required this.dueAt,
    this.locationText,
    required this.marketplaceStatus,
    required this.businessName,
  });

  factory BidListingInfo.fromJson(Map<String, dynamic> json) {
    return BidListingInfo(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString(),
      budgetCents: _parseInt(json['budgetCents']),
      currency: json['currency']?.toString() ?? 'KES',
      dueAt: json['dueAt']?.toString() ?? '',
      locationText: json['locationText']?.toString(),
      marketplaceStatus: json['marketplaceStatus']?.toString() ?? '',
      businessName: json['businessName']?.toString() ?? '',
    );
  }
}

class MyListing {
  final String id;
  final String title;
  final String description;
  final String? category;
  final List<String> requiredSkills;
  final int budgetCents;
  final String currency;
  final String dueAt;
  final String? locationText;
  final String marketplaceStatus;
  final String? adminRejectNote;
  final int totalBids;
  final int pendingBids;
  final int acceptedBids;
  final String createdAt;

  const MyListing({
    required this.id,
    required this.title,
    required this.description,
    this.category,
    required this.requiredSkills,
    required this.budgetCents,
    required this.currency,
    required this.dueAt,
    this.locationText,
    required this.marketplaceStatus,
    this.adminRejectNote,
    required this.totalBids,
    required this.pendingBids,
    required this.acceptedBids,
    required this.createdAt,
  });

  factory MyListing.fromJson(Map<String, dynamic> json) {
    final bids = json['bids'] as Map<String, dynamic>? ?? {};
    return MyListing(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString(),
      requiredSkills: _parseStringList(json['requiredSkills']),
      budgetCents: _parseInt(json['budgetCents']),
      currency: json['currency']?.toString() ?? 'KES',
      dueAt: json['dueAt']?.toString() ?? '',
      locationText: json['locationText']?.toString(),
      marketplaceStatus: json['marketplaceStatus']?.toString() ?? 'DRAFT',
      adminRejectNote: json['adminRejectNote']?.toString(),
      totalBids: _parseInt(bids['total'] ?? json['bidCount'] ?? 0),
      pendingBids: _parseInt(bids['pending'] ?? 0),
      acceptedBids: _parseInt(bids['accepted'] ?? 0),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  double get budgetKes => budgetCents / 100.0;
}

// ── Private helpers ──────────────────────────────────────────────────────────

List<String> _parseStringList(dynamic raw) {
  if (raw is List) return raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  return [];
}

int _parseInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now().add(const Duration(days: 7));
  try { return DateTime.parse(v.toString()); } catch (_) { return DateTime.now().add(const Duration(days: 7)); }
}

String _monthShort(int m) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return months[(m - 1).clamp(0, 11)];
}
