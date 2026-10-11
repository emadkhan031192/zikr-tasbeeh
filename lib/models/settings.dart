/// All user settings, stored as one JSON object in SharedPreferences under
/// the key `zikr.settings`. The native overlay service reads the subset it
/// needs from the same store.
class AppSettings {
  // Counting
  bool vibration;
  int vibrationStrength; // 0 = light, 1 = medium, 2 = strong
  bool sound;
  bool volumeButtons;
  int stepSize; // 1, 5 or 10
  int defaultTarget; // used for the Custom dhikr
  String onTargetReached; // 'stop' | 'newRound' | 'nextDhikr'
  bool longVibrationAtTarget;
  int milestoneEvery; // 0 = off, otherwise 33 or 100
  bool lockReset;
  bool resetConfirmation;
  bool keepScreenAwake;

  // Display
  String theme; // 'cyan' | 'green' | 'orange' | 'purple'
  String digitSize; // 'small' | 'normal' | 'large'
  bool showArabic;
  bool showTransliteration;
  bool showMeaning;
  String language; // 'en' | 'ur' | 'ps'

  // Overlay
  String overlayDefaultMode; // 'bubble' | 'panel' | 'fullscreen'
  double bubbleSize; // scale factor
  double bubbleOpacity; // 0.3 - 1.0
  bool snapToEdge;
  bool hideOverlayInApp;
  bool autoStartOnBoot;
  bool tapThroughWhenDimmed;

  // Reminders
  bool reminderSound;
  bool reminderVibration;
  int snoozeMinutes; // 5, 10 or 15
  String reminderTapAction; // 'openDhikr' | 'startOverlay'
  String prayerCity;
  double prayerLat;
  double prayerLng;

  // Data
  int dailyGoal;

  AppSettings({
    this.vibration = true,
    this.vibrationStrength = 1,
    this.sound = false,
    this.volumeButtons = false,
    this.stepSize = 1,
    this.defaultTarget = 100,
    this.onTargetReached = 'newRound',
    this.longVibrationAtTarget = true,
    this.milestoneEvery = 0,
    this.lockReset = false,
    this.resetConfirmation = true,
    this.keepScreenAwake = false,
    this.theme = 'cyan',
    this.digitSize = 'normal',
    this.showArabic = true,
    this.showTransliteration = true,
    this.showMeaning = true,
    this.language = 'en',
    this.overlayDefaultMode = 'bubble',
    this.bubbleSize = 1.0,
    this.bubbleOpacity = 1.0,
    this.snapToEdge = true,
    this.hideOverlayInApp = true,
    this.autoStartOnBoot = false,
    this.tapThroughWhenDimmed = false,
    this.reminderSound = true,
    this.reminderVibration = true,
    this.snoozeMinutes = 10,
    this.reminderTapAction = 'openDhikr',
    this.prayerCity = 'Karachi',
    this.prayerLat = 24.8607,
    this.prayerLng = 67.0011,
    this.dailyGoal = 1000,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final s = AppSettings();
    s.vibration = json['vibration'] as bool? ?? true;
    s.vibrationStrength = (json['vibrationStrength'] as num?)?.toInt() ?? 1;
    s.sound = json['sound'] as bool? ?? false;
    s.volumeButtons = json['volumeButtons'] as bool? ?? false;
    s.stepSize = (json['stepSize'] as num?)?.toInt() ?? 1;
    s.defaultTarget = (json['defaultTarget'] as num?)?.toInt() ?? 100;
    s.onTargetReached = json['onTargetReached'] as String? ?? 'newRound';
    s.longVibrationAtTarget = json['longVibrationAtTarget'] as bool? ?? true;
    s.milestoneEvery = (json['milestoneEvery'] as num?)?.toInt() ?? 0;
    s.lockReset = json['lockReset'] as bool? ?? false;
    s.resetConfirmation = json['resetConfirmation'] as bool? ?? true;
    s.keepScreenAwake = json['keepScreenAwake'] as bool? ?? false;
    s.theme = json['theme'] as String? ?? 'cyan';
    s.digitSize = json['digitSize'] as String? ?? 'normal';
    s.showArabic = json['showArabic'] as bool? ?? true;
    s.showTransliteration = json['showTransliteration'] as bool? ?? true;
    s.showMeaning = json['showMeaning'] as bool? ?? true;
    s.language = json['language'] as String? ?? 'en';
    s.overlayDefaultMode = json['overlayDefaultMode'] as String? ?? 'bubble';
    s.bubbleSize = (json['bubbleSize'] as num?)?.toDouble() ?? 1.0;
    s.bubbleOpacity = (json['bubbleOpacity'] as num?)?.toDouble() ?? 1.0;
    s.snapToEdge = json['snapToEdge'] as bool? ?? true;
    s.hideOverlayInApp = json['hideOverlayInApp'] as bool? ?? true;
    s.autoStartOnBoot = json['autoStartOnBoot'] as bool? ?? false;
    s.tapThroughWhenDimmed = json['tapThroughWhenDimmed'] as bool? ?? false;
    s.reminderSound = json['reminderSound'] as bool? ?? true;
    s.reminderVibration = json['reminderVibration'] as bool? ?? true;
    s.snoozeMinutes = (json['snoozeMinutes'] as num?)?.toInt() ?? 10;
    s.reminderTapAction = json['reminderTapAction'] as String? ?? 'openDhikr';
    s.prayerCity = json['prayerCity'] as String? ?? 'Karachi';
    s.prayerLat = (json['prayerLat'] as num?)?.toDouble() ?? 24.8607;
    s.prayerLng = (json['prayerLng'] as num?)?.toDouble() ?? 67.0011;
    s.dailyGoal = (json['dailyGoal'] as num?)?.toInt() ?? 1000;
    return s;
  }

  Map<String, dynamic> toJson() => {
        'vibration': vibration,
        'vibrationStrength': vibrationStrength,
        'sound': sound,
        'volumeButtons': volumeButtons,
        'stepSize': stepSize,
        'defaultTarget': defaultTarget,
        'onTargetReached': onTargetReached,
        'longVibrationAtTarget': longVibrationAtTarget,
        'milestoneEvery': milestoneEvery,
        'lockReset': lockReset,
        'resetConfirmation': resetConfirmation,
        'keepScreenAwake': keepScreenAwake,
        'theme': theme,
        'digitSize': digitSize,
        'showArabic': showArabic,
        'showTransliteration': showTransliteration,
        'showMeaning': showMeaning,
        'language': language,
        'overlayDefaultMode': overlayDefaultMode,
        'bubbleSize': bubbleSize,
        'bubbleOpacity': bubbleOpacity,
        'snapToEdge': snapToEdge,
        'hideOverlayInApp': hideOverlayInApp,
        'autoStartOnBoot': autoStartOnBoot,
        'tapThroughWhenDimmed': tapThroughWhenDimmed,
        'reminderSound': reminderSound,
        'reminderVibration': reminderVibration,
        'snoozeMinutes': snoozeMinutes,
        'reminderTapAction': reminderTapAction,
        'prayerCity': prayerCity,
        'prayerLat': prayerLat,
        'prayerLng': prayerLng,
        'dailyGoal': dailyGoal,
      };
}
