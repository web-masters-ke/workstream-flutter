/// Availability states for an agent.
enum AgentAvailability {
  online,
  offline,
  busy;

  String get label => switch (this) {
    AgentAvailability.online => 'Online',
    AgentAvailability.offline => 'Offline',
    AgentAvailability.busy => 'Busy',
  };

  static AgentAvailability fromString(String? v) {
    switch ((v ?? '').toUpperCase()) {
      case 'ONLINE':
        return AgentAvailability.online;
      case 'BUSY':
        return AgentAvailability.busy;
      default:
        return AgentAvailability.offline;
    }
  }

  String get apiValue => name.toUpperCase();
}

class Agent {
  final String id;
  final String userId;
  final List<String> skills;
  final double rating;
  final int tasksCompleted;
  final double todaysEarnings;
  final AgentAvailability availability;
  final String? bio;
  final List<String> languages;

  Agent({
    required this.id,
    required this.userId,
    required this.skills,
    required this.rating,
    required this.tasksCompleted,
    required this.todaysEarnings,
    required this.availability,
    this.bio,
    required this.languages,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      skills: _stringList(json['skills']),
      rating: _toDouble(json['rating']),
      tasksCompleted: _toInt(json['tasksCompleted']),
      todaysEarnings: _toDouble(json['todaysEarnings']),
      availability: AgentAvailability.fromString(
        json['availability']?.toString(),
      ),
      bio: json['bio']?.toString(),
      languages: _stringList(json['languages']),
    );
  }

  Agent copyWith({
    AgentAvailability? availability,
    double? todaysEarnings,
    int? tasksCompleted,
    double? rating,
  }) => Agent(
    id: id,
    userId: userId,
    skills: skills,
    rating: rating ?? this.rating,
    tasksCompleted: tasksCompleted ?? this.tasksCompleted,
    todaysEarnings: todaysEarnings ?? this.todaysEarnings,
    availability: availability ?? this.availability,
    bio: bio,
    languages: languages,
  );

  static List<String> _stringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
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
}
