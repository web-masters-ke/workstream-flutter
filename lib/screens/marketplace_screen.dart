import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../models/marketplace.dart';
import '../services/marketplace_service.dart';
import '../theme/app_theme.dart';
import 'listing_detail_screen.dart';
import 'my_bids_screen.dart';
import 'my_listings_screen.dart';
import 'post_task_screen.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _fmtMoney(int cents, [String currency = 'KES']) {
  final amount = cents / 100.0;
  if (amount >= 1000000) return '${currency} ${(amount / 1000000).toStringAsFixed(1)}M';
  if (amount >= 1000) return '${currency} ${(amount / 1000).toStringAsFixed(0)}K';
  return '${currency} ${amount.toStringAsFixed(0)}';
}

// ─── Listing card ─────────────────────────────────────────────────────────────

class _ListingCard extends StatelessWidget {
  final MarketplaceListing listing;
  final VoidCallback onTap;

  const _ListingCard({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category strip + budget
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  if (listing.category != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        listing.category!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  Text(
                    _fmtMoney(listing.budgetCents, listing.currency),
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    listing.title,
                    style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Org name
                  Row(
                    children: [
                      Icon(Icons.business_rounded, size: 13, color: subtext),
                      const SizedBox(width: 4),
                      Text(
                        listing.businessName,
                        style: TextStyle(fontSize: 12, color: subtext),
                      ),
                      if (listing.businessCity != null) ...[
                        Text(' · ', style: TextStyle(color: subtext)),
                        Text(
                          listing.businessCity!,
                          style: TextStyle(fontSize: 12, color: subtext),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Description
                  Text(
                    listing.description,
                    style: TextStyle(fontSize: 13, color: subtext, height: 1.45),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Skills
                  if (listing.requiredSkills.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: listing.requiredSkills.take(4).map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(s, style: TextStyle(fontSize: 11, color: subtext)),
                      )).toList(),
                    ),

                  const SizedBox(height: 12),

                  // Footer: bids + deadline + location
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.gavel_rounded,
                        label: '${listing.bidCount} bids',
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        icon: Icons.schedule_rounded,
                        label: listing.deadlineLabel,
                        color: listing.isDeadlineUrgent ? AppColors.danger : subtext,
                      ),
                      if (listing.locationText != null) ...[
                        const SizedBox(width: 8),
                        _StatChip(
                          icon: Icons.location_on_rounded,
                          label: listing.locationText!,
                          color: subtext,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── Sort / filter bottom sheet ───────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final String currentSort;
  final String? currentCategory;
  final List<String> categories;
  final ValueChanged<({String sort, String? category})> onApply;

  const _FilterSheet({
    required this.currentSort,
    required this.currentCategory,
    required this.categories,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _sort;
  String? _category;

  static const _sortOptions = [
    ('NEWEST', 'Newest first'),
    ('BUDGET_HIGH', 'Highest budget'),
    ('BUDGET_LOW', 'Lowest budget'),
    ('DEADLINE_SOON', 'Deadline soon'),
    ('MOST_BIDS', 'Most bids'),
  ];

  @override
  void initState() {
    super.initState();
    _sort = widget.currentSort;
    _category = widget.currentCategory;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 36, height: 4, decoration: BoxDecoration(
              color: t.dividerColor, borderRadius: BorderRadius.circular(2),
            )),
          ),
          const SizedBox(height: 16),
          Text('Sort & Filter', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          Text('Sort by', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: subtext)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _sortOptions.map((opt) {
              final active = _sort == opt.$1;
              return GestureDetector(
                onTap: () => setState(() => _sort = opt.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: active ? AppColors.primary : borderColor),
                  ),
                  child: Text(
                    opt.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (widget.categories.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: subtext)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _category = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _category == null ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _category == null ? AppColors.primary : borderColor),
                    ),
                    child: Text('All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _category == null ? Colors.white : null)),
                  ),
                ),
                ...widget.categories.map((c) {
                  final active = _category == c;
                  return GestureDetector(
                    onTap: () => setState(() => _category = active ? null : c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: active ? AppColors.primary : borderColor),
                      ),
                      child: Text(c, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : null)),
                    ),
                  );
                }),
              ],
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onApply((sort: _sort, category: _category));
              },
              child: const Text('Apply filters'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Main screen ──────────────────────────────────────────────────────────────

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _service = MarketplaceService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<MarketplaceListing> _listings = [];
  int _total = 0;
  int _page = 1;
  List<String> _categories = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String _sort = 'NEWEST';
  String? _category;

  bool get _isAgent {
    final role = context.read<AuthController>().user?.role ?? '';
    return role == 'AGENT';
  }

  bool get _isBusiness {
    final role = context.read<AuthController>().user?.role ?? '';
    return ['OWNER', 'ADMIN', 'SUPERVISOR', 'BUSINESS'].contains(role);
  }

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(reset: true));
  }

  Future<void> _load({bool reset = false, bool more = false}) async {
    if (_loading || _loadingMore) return;
    final page = reset ? 1 : (more ? _page + 1 : _page);

    setState(() {
      if (reset) { _loading = true; _error = null; }
      if (more) _loadingMore = true;
    });

    try {
      final res = await _service.browse(
        page: page,
        search: _searchCtrl.text.trim(),
        category: _category,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _listings = res.items;
        } else {
          _listings = [..._listings, ...res.items];
        }
        _total = res.total;
        _page = page;
        if (res.categories.isNotEmpty) _categories = res.categories;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FilterSheet(
        currentSort: _sort,
        currentCategory: _category,
        categories: _categories,
        onApply: (val) {
          setState(() { _sort = val.sort; _category = val.category; });
          _load(reset: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _load(reset: true),
        child: CustomScrollView(
          slivers: [
            // ── App bar ──────────────────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: t.scaffoldBackgroundColor,
              elevation: 0,
              title: Text(
                'Free Agents',
                style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              actions: [
                // My bids (agent) / My listings (business)
                if (_isAgent)
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyBidsScreen()),
                    ),
                    icon: const Icon(Icons.gavel_rounded, size: 16),
                    label: const Text('My Bids'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                if (_isBusiness)
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyListingsScreen()),
                    ),
                    icon: const Icon(Icons.list_alt_rounded, size: 16),
                    label: const Text('My Listings'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                const SizedBox(width: 4),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      // Search
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search tasks, skills, orgs…',
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Filter button
                      Container(
                        decoration: BoxDecoration(
                          color: (_sort != 'NEWEST' || _category != null)
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_sort != 'NEWEST' || _category != null)
                                ? AppColors.primary
                                : t.dividerColor,
                          ),
                        ),
                        child: IconButton(
                          onPressed: _openFilters,
                          icon: Icon(
                            Icons.tune_rounded,
                            color: (_sort != 'NEWEST' || _category != null)
                                ? Colors.white
                                : subtext,
                          ),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Content ──────────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: subtext)),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => _load(reset: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_listings.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined, size: 56, color: subtext.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        _searchCtrl.text.isNotEmpty || _category != null
                            ? 'No listings match your search'
                            : 'No listings yet',
                        style: t.textTheme.titleSmall?.copyWith(color: subtext),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Be the first to post a task!',
                        style: TextStyle(fontSize: 13, color: subtext),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    if (i == _listings.length) {
                      // Load more / end
                      final hasMore = _listings.length < _total;
                      if (!hasMore) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              '${_total} listing${_total != 1 ? 's' : ''} total',
                              style: TextStyle(fontSize: 12, color: subtext),
                            ),
                          ),
                        );
                      }
                      if (_loadingMore) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: OutlinedButton(
                          onPressed: () => _load(more: true),
                          child: const Text('Load more'),
                        ),
                      );
                    }
                    final listing = _listings[i];
                    return _ListingCard(
                      listing: listing,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ListingDetailScreen(listingId: listing.id),
                        ),
                      ).then((_) => _load(reset: true)),
                    );
                  },
                  childCount: _listings.length + 1,
                ),
              ),
          ],
        ),
      ),

      // ── FAB: post task (business only) ───────────────────────
      floatingActionButton: _isBusiness
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PostTaskScreen()),
              ).then((_) => _load(reset: true)),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Post task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }
}
