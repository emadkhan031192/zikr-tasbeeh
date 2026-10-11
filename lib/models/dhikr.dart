/// Dhikr presets and per-dhikr state.
///
/// Each dhikr keeps its own saved count, target and completed rounds.
/// The JSON shape here is mirrored by the native overlay service, which reads
/// and writes the same SharedPreferences keys directly.
class DhikrPreset {
  final String id;
  final String arabic;
  final String transliteration;
  final String meaningEn;
  final int defaultTarget;
  final bool isCustom;

  const DhikrPreset({
    required this.id,
    required this.arabic,
    required this.transliteration,
    required this.meaningEn,
    required this.defaultTarget,
    this.isCustom = false,
  });
}

const List<DhikrPreset> dhikrPresets = [
  DhikrPreset(
    id: 'subhanallah',
    arabic: 'سُبْحَانَ الله',
    transliteration: 'SubhanAllah',
    meaningEn: 'Glory be to Allah',
    defaultTarget: 33,
  ),
  DhikrPreset(
    id: 'alhamdulillah',
    arabic: 'الْحَمْدُ لِلَّه',
    transliteration: 'Alhamdulillah',
    meaningEn: 'All praise is due to Allah',
    defaultTarget: 33,
  ),
  DhikrPreset(
    id: 'allahuakbar',
    arabic: 'اللهُ أَكْبَر',
    transliteration: 'Allahu Akbar',
    meaningEn: 'Allah is the Greatest',
    defaultTarget: 34,
  ),
  DhikrPreset(
    id: 'astaghfirullah',
    arabic: 'أَسْتَغْفِرُ الله',
    transliteration: 'Astaghfirullah',
    meaningEn: "I seek Allah's forgiveness",
    defaultTarget: 100,
  ),
  DhikrPreset(
    id: 'lailahaillallah',
    arabic: 'لَا إِلَهَ إِلَّا الله',
    transliteration: 'La ilaha illallah',
    meaningEn: 'There is no god but Allah',
    defaultTarget: 100,
  ),
  DhikrPreset(
    id: 'durood',
    arabic: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّد',
    transliteration: 'Durood Sharif',
    meaningEn: 'O Allah, send blessings upon Muhammad',
    defaultTarget: 100,
  ),
  DhikrPreset(
    id: 'custom',
    arabic: 'ذِكْر',
    transliteration: 'Custom',
    meaningEn: 'Your own dhikr',
    defaultTarget: 100,
    isCustom: true,
  ),
];

DhikrPreset dhikrById(String id) =>
    dhikrPresets.firstWhere((d) => d.id == id, orElse: () => dhikrPresets.first);

/// Saved per-dhikr state: count, target and completed rounds.
class DhikrState {
  int count;
  int target;
  int rounds;

  DhikrState({required this.count, required this.target, required this.rounds});

  factory DhikrState.initial(int defaultTarget) =>
      DhikrState(count: 0, target: defaultTarget, rounds: 0);

  factory DhikrState.fromJson(Map<String, dynamic> json) => DhikrState(
        count: (json['count'] as num?)?.toInt() ?? 0,
        target: (json['target'] as num?)?.toInt() ?? 33,
        rounds: (json['rounds'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'count': count, 'target': target, 'rounds': rounds};
}
