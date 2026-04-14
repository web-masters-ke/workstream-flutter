class Business {
  final String id;
  final String name;
  final String? logoUrl;
  final String? industry;
  final double rating;

  Business({
    required this.id,
    required this.name,
    this.logoUrl,
    this.industry,
    required this.rating,
  });

  factory Business.fromJson(Map<String, dynamic> json) => Business(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    logoUrl: json['logoUrl']?.toString(),
    industry: json['industry']?.toString(),
    rating: _toDouble(json['rating']),
  );

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
