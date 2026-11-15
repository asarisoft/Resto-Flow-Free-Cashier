enum Role {
  owner,
  kasir;

  static Role fromDb(String value) {
    return Role.values.firstWhere(
      (r) => r.name == value,
      orElse: () => Role.kasir,
    );
  }

  String toDb() => name;
}

class AppUser {
  final String id;
  final String username;
  final String role;
  final bool active;

  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    required this.active,
  });

  Role get roleEnum => Role.fromDb(role);
}
