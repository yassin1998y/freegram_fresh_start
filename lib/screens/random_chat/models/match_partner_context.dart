class MatchPartnerContext {
  final String id;
  final String name;
  final String avatarUrl;
  final int age;
  final List<String> mutualInterests;

  MatchPartnerContext({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.age,
    this.mutualInterests = const [],
  });

  MatchPartnerContext copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    int? age,
    List<String>? mutualInterests,
  }) {
    return MatchPartnerContext(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      age: age ?? this.age,
      mutualInterests: mutualInterests ?? this.mutualInterests,
    );
  }
}
