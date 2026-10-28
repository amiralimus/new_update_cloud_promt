class CoachAthlete {
  const CoachAthlete({
    required this.id,
    required this.name,
    this.age,
    this.gender,
    this.height,
    this.weight,
    this.goal = '',
    this.injuries = '',
    this.foodAllergies = '',
    this.clientUserId,
    this.isActivated = false,
    this.createdAt,
  });

  final int id;
  final String name;
  final int? age;
  final String? gender;
  final double? height;
  final double? weight;
  final String goal;
  final String injuries;
  final String foodAllergies;
  final int? clientUserId;
  final bool isActivated;
  final DateTime? createdAt;

  String get displayName => name.trim().isEmpty ? 'ورزشکار بدون نام' : name;

  factory CoachAthlete.fromJson(Map<String, dynamic> json) {
    return CoachAthlete(
      id: _asInt(json['id']) ?? 0,
      name: _asText(json['name']),
      age: _asInt(json['age']),
      gender: _nullableText(json['gender']),
      height: _asDouble(json['height']),
      weight: _asDouble(json['weight']),
      goal: _asText(json['goal']),
      injuries: _asText(json['injuries']),
      foodAllergies: _asText(json['food_allergies']),
      clientUserId: _asInt(json['client_user']),
      isActivated: json['is_used'] == true,
      createdAt: _asDate(json['created_at']),
    );
  }
}

class AthleteProgramSummary {
  const AthleteProgramSummary({
    required this.id,
    required this.name,
    required this.programType,
    required this.programDays,
    this.createdAt,
    this.exerciseHistory = '',
  });

  final int id;
  final String name;
  final String programType;
  final int programDays;
  final DateTime? createdAt;
  final String exerciseHistory;

  String get typeLabel {
    switch (programType) {
      case 'meal':
        return 'غذایی';
      case 'both':
        return 'ورزشی و غذایی';
      default:
        return 'ورزشی';
    }
  }

  String get dateLabel => formatCoachDate(createdAt);

  bool get hasWorkout => programType == 'workout' || programType == 'both';
  bool get hasMeal => programType == 'meal' || programType == 'both';

  DateTime? get expiresAt {
    final created = createdAt;
    if (created == null || programDays <= 0) return null;
    return created.add(Duration(days: programDays));
  }

  factory AthleteProgramSummary.fromJson(Map<String, dynamic> json) {
    return AthleteProgramSummary(
      id: _asInt(json['id']) ?? 0,
      name: _asText(json['name'], fallback: 'برنامه بدون نام'),
      programType: _asText(json['program_type'], fallback: 'workout'),
      programDays: _asInt(json['program_days']) ?? 0,
      createdAt: _asDate(json['created_at']),
      exerciseHistory: _asText(json['exercise_history']),
    );
  }
}

class AthleteProgramDetail {
  const AthleteProgramDetail({
    required this.summary,
    this.generatedWorkout = '',
    this.generatedMealPlan = '',
    this.source = '',
  });

  final AthleteProgramSummary summary;
  final String generatedWorkout;
  final String generatedMealPlan;
  final String source;

  factory AthleteProgramDetail.fromJson(Map<String, dynamic> json) {
    return AthleteProgramDetail(
      summary: AthleteProgramSummary.fromJson(json),
      generatedWorkout: _asText(json['generated_workout']),
      generatedMealPlan: _asText(json['generated_meal_plan']),
      source: _asText(json['source']),
    );
  }
}

class AthleteWithPrograms {
  const AthleteWithPrograms({
    required this.athlete,
    this.programs = const [],
    this.programsLoading = false,
    this.programsError,
  });

  final CoachAthlete athlete;
  final List<AthleteProgramSummary> programs;
  final bool programsLoading;
  final String? programsError;

  int get programCount => programs.length;
  DateTime? get lastProgramDate =>
      programs.isEmpty ? null : programs.first.createdAt;

  AthleteWithPrograms copyWith({
    CoachAthlete? athlete,
    List<AthleteProgramSummary>? programs,
    bool? programsLoading,
    String? programsError,
    bool clearError = false,
  }) {
    return AthleteWithPrograms(
      athlete: athlete ?? this.athlete,
      programs: programs ?? this.programs,
      programsLoading: programsLoading ?? this.programsLoading,
      programsError: clearError ? null : programsError ?? this.programsError,
    );
  }
}

String formatCoachDate(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
}

String _asText(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableText(dynamic value) {
  final text = _asText(value);
  return text.isEmpty ? null : text;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

DateTime? _asDate(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}
