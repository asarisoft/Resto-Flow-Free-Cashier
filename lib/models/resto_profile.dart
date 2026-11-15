class RestoProfile {
  final String name;
  final String? address;
  final String? phone;
  final String? footerNote;
  final int paperWidth;
  final bool useLogo;
  final String? logoPath;
  final DateTime createdAt;

  const RestoProfile({
    required this.name,
    this.address,
    this.phone,
    this.footerNote,
    this.paperWidth = 58,
    this.useLogo = false,
    this.logoPath,
    required this.createdAt,
  });

  RestoProfile copyWith({
    String? name,
    String? address,
    String? phone,
    String? footerNote,
    int? paperWidth,
    bool? useLogo,
    String? logoPath,
  }) =>
      RestoProfile(
        name: name ?? this.name,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        footerNote: footerNote ?? this.footerNote,
        paperWidth: paperWidth ?? this.paperWidth,
        useLogo: useLogo ?? this.useLogo,
        logoPath: logoPath ?? this.logoPath,
        createdAt: createdAt,
      );
}
