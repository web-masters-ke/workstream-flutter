import '../models/marketplace.dart';
import 'api_service.dart';

class MarketplaceService {
  final _api = ApiService.instance;

  // ── Browse public listings ───────────────────────────────────────────────

  Future<BrowseResult> browse({
    int page = 1,
    String? search,
    String? category,
    int? budgetMin,
    int? budgetMax,
    String sort = 'NEWEST',
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': 20,
      'sort': sort,
    };
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (category != null && category.isNotEmpty) query['category'] = category;
    if (budgetMin != null) query['budgetMin'] = budgetMin;
    if (budgetMax != null) query['budgetMax'] = budgetMax;

    final r = await _api.get('/marketplace', query: query);
    final data = unwrap<dynamic>(r);
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final items = (map['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => MarketplaceListing.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return BrowseResult(
      items: items,
      total: _parseInt(map['total']),
      page: _parseInt(map['page']),
      categories: _parseStringList(map['categories']),
    );
  }

  // ── Get single listing (with myBid for agent) ────────────────────────────

  Future<MarketplaceListing> getListing(String id) async {
    final r = await _api.get('/marketplace/$id');
    final data = unwrap<Map<String, dynamic>>(r);
    return MarketplaceListing.fromJson(data);
  }

  // ── Get bids on a listing (org owner) ───────────────────────────────────

  Future<List<BidItem>> getListingBids(String listingId) async {
    final r = await _api.get('/marketplace/$listingId/bids');
    final data = unwrap<dynamic>(r);
    final list = data is List
        ? data
        : (data is Map<String, dynamic> ? data['items'] as List? ?? [] : []);
    return list
        .whereType<Map>()
        .map((e) => BidItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ── Place a bid (agent) ──────────────────────────────────────────────────

  Future<void> placeBid({
    required String listingId,
    required int proposedCents,
    required String coverNote,
    int? estimatedDays,
  }) async {
    await _api.post(
      '/marketplace/$listingId/bids',
      body: {
        'proposedCents': proposedCents,
        'coverNote': coverNote,
        if (estimatedDays != null) 'estimatedDays': estimatedDays,
      },
    );
  }

  // ── Withdraw a bid (agent) ───────────────────────────────────────────────

  Future<void> withdrawBid(String bidId) async {
    await _api.patch('/marketplace/bids/$bidId/withdraw', body: {});
  }

  // ── Accept / reject a bid (org owner) ───────────────────────────────────

  Future<void> acceptBid(String listingId, String bidId) async {
    await _api.patch('/marketplace/$listingId/bids/$bidId/accept', body: {});
  }

  Future<void> rejectBid(String listingId, String bidId, {String? note}) async {
    await _api.patch(
      '/marketplace/$listingId/bids/$bidId/reject',
      body: {if (note != null) 'note': note},
    );
  }

  // ── My bids (agent) ──────────────────────────────────────────────────────

  Future<List<MyBid>> myBids() async {
    final r = await _api.get('/marketplace/my-bids');
    return _parseMyBids(r);
  }

  List<MyBid> _parseMyBids(Map<String, dynamic> r) {
    final data = unwrap<dynamic>(r);
    final list = data is List
        ? data
        : (data is Map<String, dynamic> ? data['items'] as List? ?? [] : []);
    return list
        .whereType<Map>()
        .map((e) => MyBid.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ── My listings (org owner) ──────────────────────────────────────────────

  Future<List<MyListing>> myListings() async {
    final r = await _api.get('/marketplace/my-listings');
    final data = unwrap<dynamic>(r);
    final list = data is List
        ? data
        : (data is Map<String, dynamic> ? data['items'] as List? ?? [] : []);
    return list
        .whereType<Map>()
        .map((e) => MyListing.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ── Create a listing (org owner) ─────────────────────────────────────────

  Future<MarketplaceListing> createListing({
    required String title,
    required String description,
    required String? category,
    required List<String> skills,
    required int budgetCents,
    required DateTime dueAt,
    String? locationText,
    int? maxBids,
    DateTime? expiresAt,
  }) async {
    final r = await _api.post(
      '/marketplace',
      body: {
        'title': title,
        'description': description,
        if (category != null) 'category': category,
        'requiredSkills': skills,
        'budgetCents': budgetCents,
        'dueAt': dueAt.toIso8601String(),
        if (locationText != null) 'locationText': locationText,
        if (maxBids != null) 'maxBids': maxBids,
        if (expiresAt != null) 'marketplaceExpiresAt': expiresAt.toIso8601String(),
      },
    );
    final data = unwrap<Map<String, dynamic>>(r);
    return MarketplaceListing.fromJson(data);
  }

  // ── Close a listing (org owner) ──────────────────────────────────────────

  Future<void> closeListing(String id) async {
    await _api.patch('/marketplace/$id/close', body: {});
  }
}

class BrowseResult {
  final List<MarketplaceListing> items;
  final int total;
  final int page;
  final List<String> categories;
  BrowseResult({ required this.items, required this.total, required this.page, required this.categories });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

int _parseInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

List<String> _parseStringList(dynamic raw) {
  if (raw is List) return raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  return [];
}
