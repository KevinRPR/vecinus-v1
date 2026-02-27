class UserPreferences {
  final double textScale;
  final bool highContrast;
  final bool reduceMotion;
  final NotificationPreferences notifications;
  final QuietHours quietHours;
  final InmueblePreferences inmueble;
  final SecurityPreferences security;

  const UserPreferences({
    required this.textScale,
    required this.highContrast,
    required this.reduceMotion,
    required this.notifications,
    required this.quietHours,
    required this.inmueble,
    required this.security,
  });

  factory UserPreferences.defaults() {
    return UserPreferences(
      textScale: 1.0,
      highContrast: false,
      reduceMotion: false,
      notifications: NotificationPreferences.defaults(),
      quietHours: QuietHours.defaults(),
      inmueble: InmueblePreferences.defaults(),
      security: SecurityPreferences.defaults(),
    );
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      textScale: (json['textScale'] as num?)?.toDouble() ?? 1.0,
      highContrast: json['highContrast'] as bool? ?? false,
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      notifications: NotificationPreferences.fromJson(
        (json['notifications'] as Map<String, dynamic>?) ?? const {},
      ),
      quietHours: QuietHours.fromJson(
        (json['quietHours'] as Map<String, dynamic>?) ?? const {},
      ),
      inmueble: InmueblePreferences.fromJson(
        (json['inmueble'] as Map<String, dynamic>?) ?? const {},
      ),
      security: SecurityPreferences.fromJson(
        (json['security'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'textScale': textScale,
      'highContrast': highContrast,
      'reduceMotion': reduceMotion,
      'notifications': notifications.toJson(),
      'quietHours': quietHours.toJson(),
      'inmueble': inmueble.toJson(),
      'security': security.toJson(),
    };
  }

  UserPreferences copyWith({
    double? textScale,
    bool? highContrast,
    bool? reduceMotion,
    NotificationPreferences? notifications,
    QuietHours? quietHours,
    InmueblePreferences? inmueble,
    SecurityPreferences? security,
  }) {
    return UserPreferences(
      textScale: textScale ?? this.textScale,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      notifications: notifications ?? this.notifications,
      quietHours: quietHours ?? this.quietHours,
      inmueble: inmueble ?? this.inmueble,
      security: security ?? this.security,
    );
  }
}

class NotificationPreferences {
  final bool avisos;
  final bool alertas;
  final bool eventos;
  final bool pagos;
  final bool push;
  final bool email;
  final bool whatsapp;

  const NotificationPreferences({
    required this.avisos,
    required this.alertas,
    required this.eventos,
    required this.pagos,
    required this.push,
    required this.email,
    required this.whatsapp,
  });

  factory NotificationPreferences.defaults() {
    return const NotificationPreferences(
      avisos: true,
      alertas: true,
      eventos: true,
      pagos: true,
      push: true,
      email: false,
      whatsapp: false,
    );
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      avisos: json['avisos'] as bool? ?? true,
      alertas: json['alertas'] as bool? ?? true,
      eventos: json['eventos'] as bool? ?? true,
      pagos: json['pagos'] as bool? ?? true,
      push: json['push'] as bool? ?? true,
      email: json['email'] as bool? ?? false,
      whatsapp: json['whatsapp'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'avisos': avisos,
      'alertas': alertas,
      'eventos': eventos,
      'pagos': pagos,
      'push': push,
      'email': email,
      'whatsapp': whatsapp,
    };
  }

  NotificationPreferences copyWith({
    bool? avisos,
    bool? alertas,
    bool? eventos,
    bool? pagos,
    bool? push,
    bool? email,
    bool? whatsapp,
  }) {
    return NotificationPreferences(
      avisos: avisos ?? this.avisos,
      alertas: alertas ?? this.alertas,
      eventos: eventos ?? this.eventos,
      pagos: pagos ?? this.pagos,
      push: push ?? this.push,
      email: email ?? this.email,
      whatsapp: whatsapp ?? this.whatsapp,
    );
  }
}

class QuietHours {
  final bool enabled;
  final int startMinutes;
  final int endMinutes;
  final List<int> days;

  const QuietHours({
    required this.enabled,
    required this.startMinutes,
    required this.endMinutes,
    required this.days,
  });

  factory QuietHours.defaults() {
    return const QuietHours(
      enabled: false,
      startMinutes: 1320,
      endMinutes: 420,
      days: <int>[],
    );
  }

  factory QuietHours.fromJson(Map<String, dynamic> json) {
    return QuietHours(
      enabled: json['enabled'] as bool? ?? false,
      startMinutes: json['startMinutes'] as int? ?? 1320,
      endMinutes: json['endMinutes'] as int? ?? 420,
      days: (json['days'] as List?)
              ?.whereType<num>()
              .map((value) => value.toInt())
              .toList() ??
          <int>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'days': days,
    };
  }

  QuietHours copyWith({
    bool? enabled,
    int? startMinutes,
    int? endMinutes,
    List<int>? days,
  }) {
    return QuietHours(
      enabled: enabled ?? this.enabled,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      days: days ?? this.days,
    );
  }

  bool isActive(DateTime now) {
    if (!enabled || days.isEmpty) return false;
    if (!days.contains(now.weekday)) return false;
    final nowMinutes = now.hour * 60 + now.minute;
    if (startMinutes == endMinutes) return true;
    if (startMinutes < endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    }
    return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
  }
}

enum DashboardCardOrder { balanceFirst, announcementsFirst }

class InmueblePreferences {
  final String? favoriteInmuebleId;
  final DashboardCardOrder cardOrder;
  final bool compactSummary;

  const InmueblePreferences({
    required this.favoriteInmuebleId,
    required this.cardOrder,
    required this.compactSummary,
  });

  factory InmueblePreferences.defaults() {
    return const InmueblePreferences(
      favoriteInmuebleId: null,
      cardOrder: DashboardCardOrder.balanceFirst,
      compactSummary: false,
    );
  }

  factory InmueblePreferences.fromJson(Map<String, dynamic> json) {
    final order = json['cardOrder'] as String?;
    return InmueblePreferences(
      favoriteInmuebleId: json['favoriteInmuebleId'] as String?,
      cardOrder: order == 'announcementsFirst'
          ? DashboardCardOrder.announcementsFirst
          : DashboardCardOrder.balanceFirst,
      compactSummary: json['compactSummary'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'favoriteInmuebleId': favoriteInmuebleId,
      'cardOrder': cardOrder == DashboardCardOrder.announcementsFirst
          ? 'announcementsFirst'
          : 'balanceFirst',
      'compactSummary': compactSummary,
    };
  }

  InmueblePreferences copyWith({
    String? favoriteInmuebleId,
    bool clearFavorite = false,
    DashboardCardOrder? cardOrder,
    bool? compactSummary,
  }) {
    return InmueblePreferences(
      favoriteInmuebleId:
          clearFavorite ? null : favoriteInmuebleId ?? this.favoriteInmuebleId,
      cardOrder: cardOrder ?? this.cardOrder,
      compactSummary: compactSummary ?? this.compactSummary,
    );
  }
}

class SecurityPreferences {
  final bool biometricForLogin;
  final bool biometricForSensitive;
  final bool pinForLogin;
  final bool pinForSensitive;
  final bool twoFactorEnabled;

  const SecurityPreferences({
    required this.biometricForLogin,
    required this.biometricForSensitive,
    required this.pinForLogin,
    required this.pinForSensitive,
    required this.twoFactorEnabled,
  });

  factory SecurityPreferences.defaults() {
    return const SecurityPreferences(
      biometricForLogin: false,
      biometricForSensitive: false,
      pinForLogin: false,
      pinForSensitive: false,
      twoFactorEnabled: false,
    );
  }

  factory SecurityPreferences.fromJson(Map<String, dynamic> json) {
    return SecurityPreferences(
      biometricForLogin: json['biometricForLogin'] as bool? ?? false,
      biometricForSensitive: json['biometricForSensitive'] as bool? ?? false,
      pinForLogin: json['pinForLogin'] as bool? ?? false,
      pinForSensitive: json['pinForSensitive'] as bool? ?? false,
      twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'biometricForLogin': biometricForLogin,
      'biometricForSensitive': biometricForSensitive,
      'pinForLogin': pinForLogin,
      'pinForSensitive': pinForSensitive,
      'twoFactorEnabled': twoFactorEnabled,
    };
  }

  SecurityPreferences copyWith({
    bool? biometricForLogin,
    bool? biometricForSensitive,
    bool? pinForLogin,
    bool? pinForSensitive,
    bool? twoFactorEnabled,
  }) {
    return SecurityPreferences(
      biometricForLogin: biometricForLogin ?? this.biometricForLogin,
      biometricForSensitive:
          biometricForSensitive ?? this.biometricForSensitive,
      pinForLogin: pinForLogin ?? this.pinForLogin,
      pinForSensitive: pinForSensitive ?? this.pinForSensitive,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
    );
  }
}
