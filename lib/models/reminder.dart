/// A dhikr reminder.
///
/// Either a fixed time (optionally on selected weekdays) or a prayer-based one
/// (e.g. "after Fajr"), in which case [prayer] holds the prayer key and the
/// concrete times are computed with the offline adhan package.
class Reminder {
  final String id;
  String time; // "HH:mm"
  List<int> days; // DateTime.weekday values 1..7; empty = every day
  String dhikrId;
  String message;
  String? prayer; // 'fajr' | 'dhuhr' | 'asr' | 'maghrib' | 'isha' | null
  bool enabled;

  Reminder({
    required this.id,
    required this.time,
    required this.days,
    required this.dhikrId,
    required this.message,
    this.prayer,
    this.enabled = true,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] as String,
        time: json['time'] as String? ?? '08:00',
        days: ((json['days'] as List?) ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
        dhikrId: json['dhikrId'] as String? ?? 'subhanallah',
        message: json['message'] as String? ?? '',
        prayer: json['prayer'] as String?,
        enabled: json['enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time,
        'days': days,
        'dhikrId': dhikrId,
        'message': message,
        'prayer': prayer,
        'enabled': enabled,
      };

  int get hour => int.parse(time.split(':')[0]);
  int get minute => int.parse(time.split(':')[1]);
}

/// Prayer keys supported for prayer-based reminders.
const List<String> prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

/// Quick reminder presets: (presetKey, prayerKey|null, defaultTime, defaultDays).
const List<(String, String?, String, List<int>)> reminderPresets = [
  ('afterFajr', 'fajr', '06:00', []),
  ('afterZuhr', 'dhuhr', '13:30', []),
  ('afterAsr', 'asr', '17:00', []),
  ('afterMaghrib', 'maghrib', '19:00', []),
  ('afterIsha', 'isha', '21:00', []),
  ('beforeSleep', null, '22:30', []),
  ('morningAdhkar', null, '07:00', []),
  ('eveningAdhkar', null, '18:00', []),
];
