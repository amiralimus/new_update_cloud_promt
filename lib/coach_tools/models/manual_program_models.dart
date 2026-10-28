import 'exercise_model.dart';

String _draftId(String prefix) {
  _draftSequence += 1;
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_draftSequence';
}

int _draftSequence = 0;

class ProgramExerciseDraft {
  ProgramExerciseDraft({
    String? localId,
    this.exerciseId,
    this.name = '',
    this.sets = '',
    this.reps = '',
    this.rest = '',
    this.duration = '',
    this.note = '',
    this.supersetId,
    this.sourceTemplateId,
    this.sourceTemplateSession,
  }) : localId = localId ?? _draftId('exercise');

  factory ProgramExerciseDraft.fromExercise(CoachExercise exercise) {
    return ProgramExerciseDraft(
      exerciseId: exercise.externalId,
      name: exercise.name,
    );
  }

  final String localId;
  String? exerciseId;
  String name;
  String sets;
  String reps;
  String rest;
  String duration;
  String note;
  String? supersetId;
  String? sourceTemplateId;
  int? sourceTemplateSession;

  bool get hasContent => name.trim().isNotEmpty;

  ProgramExerciseDraft copy({bool keepLocalId = false}) {
    return ProgramExerciseDraft(
      localId: keepLocalId ? localId : null,
      exerciseId: exerciseId,
      name: name,
      sets: sets,
      reps: reps,
      rest: rest,
      duration: duration,
      note: note,
      supersetId: supersetId,
      sourceTemplateId: sourceTemplateId,
      sourceTemplateSession: sourceTemplateSession,
    );
  }

  Map<String, dynamic> toServerJson({String? supersetLabel}) {
    return {
      if (exerciseId?.trim().isNotEmpty == true) 'exercise_id': exerciseId,
      'name': name.trim(),
      if (sets.trim().isNotEmpty) 'sets': sets.trim(),
      if (reps.trim().isNotEmpty) 'reps': reps.trim(),
      if (rest.trim().isNotEmpty) 'rest': rest.trim(),
      if (supersetLabel != null && supersetLabel.isNotEmpty)
        'note': supersetLabel,
    };
  }
}

class SupersetDraft {
  SupersetDraft({String? id, this.rounds = '', List<String>? exerciseLocalIds})
    : id = id ?? _draftId('superset'),
      exerciseLocalIds = exerciseLocalIds ?? <String>[];

  final String id;
  String rounds;
  final List<String> exerciseLocalIds;
}

class TrainingSessionDraft {
  TrainingSessionDraft({
    String? id,
    this.title = '',
    this.note = '',
    List<ProgramExerciseDraft>? exercises,
    List<SupersetDraft>? supersets,
  }) : id = id ?? _draftId('session'),
       exercises = exercises ?? <ProgramExerciseDraft>[],
       supersets = supersets ?? <SupersetDraft>[];

  final String id;
  String title;
  String note;
  final List<ProgramExerciseDraft> exercises;
  final List<SupersetDraft> supersets;

  bool get hasContent => exercises.any((exercise) => exercise.hasContent);

  TrainingSessionDraft copy() {
    final copiedExercises = exercises
        .map((exercise) => exercise.copy())
        .toList();
    final localIdMap = <String, String>{};
    for (var index = 0; index < exercises.length; index += 1) {
      localIdMap[exercises[index].localId] = copiedExercises[index].localId;
    }
    final copiedSupersets = supersets
        .map(
          (superset) => SupersetDraft(
            rounds: superset.rounds,
            exerciseLocalIds: superset.exerciseLocalIds
                .map((localId) => localIdMap[localId])
                .whereType<String>()
                .toList(),
          ),
        )
        .toList();
    for (final exercise in copiedExercises) {
      if (exercise.supersetId == null) continue;
      final originalIndex = exercises.indexWhere(
        (source) =>
            source.localId ==
            localIdMap.entries
                .firstWhere(
                  (entry) => entry.value == exercise.localId,
                  orElse: () => const MapEntry('', ''),
                )
                .key,
      );
      if (originalIndex < 0) continue;
      final originalSupersetId = exercises[originalIndex].supersetId;
      final supersetIndex = supersets.indexWhere(
        (superset) => superset.id == originalSupersetId,
      );
      exercise.supersetId = supersetIndex < 0
          ? null
          : copiedSupersets[supersetIndex].id;
    }
    return TrainingSessionDraft(
      title: title,
      note: note,
      exercises: copiedExercises,
      supersets: copiedSupersets,
    );
  }

  SupersetDraft? supersetFor(String? id) {
    if (id == null) return null;
    for (final superset in supersets) {
      if (superset.id == id) return superset;
    }
    return null;
  }

  void removeExerciseAt(int index) {
    final removed = exercises.removeAt(index);
    final superset = supersetFor(removed.supersetId);
    if (superset == null) return;
    superset.exerciseLocalIds.remove(removed.localId);
    if (superset.exerciseLocalIds.length < 2) {
      for (final exercise in exercises) {
        if (exercise.supersetId == superset.id) exercise.supersetId = null;
      }
      supersets.removeWhere((item) => item.id == superset.id);
    }
  }

  Map<String, dynamic> toServerJson({int fallbackNumber = 1}) {
    final supersetNumbers = <String, int>{};
    for (var index = 0; index < supersets.length; index += 1) {
      supersetNumbers[supersets[index].id] = index + 1;
    }
    final usableExercises = exercises.where((exercise) => exercise.hasContent);
    return {
      'title': title.trim().isEmpty ? 'جلسه $fallbackNumber' : title.trim(),
      'exercises': usableExercises.map((exercise) {
        final superset = supersetFor(exercise.supersetId);
        String? label;
        if (superset != null) {
          final number = supersetNumbers[superset.id] ?? 1;
          final rounds = superset.rounds.trim();
          label = rounds.isEmpty
              ? 'سوپرست $number'
              : 'سوپرست $number، $rounds دور';
        }
        return exercise.toServerJson(supersetLabel: label);
      }).toList(),
    };
  }
}

class MealDraft {
  MealDraft({String? id, this.title = '', this.content = ''})
    : id = id ?? _draftId('meal');

  final String id;
  String title;
  String content;
}

class MealDayDraft {
  MealDayDraft({
    required this.dayNumber,
    this.enabled = false,
    this.calculateNutrition = false,
    List<MealDraft>? meals,
  }) : meals = meals ?? <MealDraft>[MealDraft()];

  final int dayNumber;
  bool enabled;
  bool calculateNutrition;
  final List<MealDraft> meals;
}

class OptionalPlanItemDraft {
  OptionalPlanItemDraft({String? id, this.title = '', this.content = ''})
    : id = id ?? _draftId('optional-item');

  final String id;
  String title;
  String content;
}

class ManualProgramDraft {
  ManualProgramDraft.fresh()
    : workoutEnabled = true,
      nutritionEnabled = false,
      supplementsEnabled = false,
      medicationsEnabled = false,
      nutritionAiMode = false,
      validityDays = 30,
      sessions = <TrainingSessionDraft>[TrainingSessionDraft()],
      mealDays = List<MealDayDraft>.generate(
        7,
        (index) => MealDayDraft(dayNumber: index + 1),
      ),
      supplements = <OptionalPlanItemDraft>[OptionalPlanItemDraft()],
      medications = <OptionalPlanItemDraft>[OptionalPlanItemDraft()];

  int? athleteId;
  String athleteName = '';
  String notes = '';
  bool workoutEnabled;
  bool nutritionEnabled;
  bool supplementsEnabled;
  bool medicationsEnabled;
  bool nutritionAiMode;
  int validityDays;
  String nutritionPrompt = '';
  String supplementsPrompt = '';
  String medicationsPrompt = '';
  final List<TrainingSessionDraft> sessions;
  final List<MealDayDraft> mealDays;
  final List<OptionalPlanItemDraft> supplements;
  final List<OptionalPlanItemDraft> medications;

  void addExerciseToFirstSession(CoachExercise exercise) {
    if (sessions.isEmpty) sessions.add(TrainingSessionDraft());
    final duplicate = sessions.first.exercises.any(
      (item) => item.exerciseId == exercise.externalId,
    );
    if (!duplicate) {
      sessions.first.exercises.add(ProgramExerciseDraft.fromExercise(exercise));
    }
  }

  Map<String, dynamic> toServerPayload() {
    final mealSections = <Map<String, dynamic>>[];
    if (nutritionEnabled) {
      for (final day in mealDays) {
        for (final meal in day.meals) {
          if (meal.title.trim().isEmpty && meal.content.trim().isEmpty) {
            continue;
          }
          final title = meal.title.trim().isEmpty ? 'وعده' : meal.title.trim();
          mealSections.add({
            'title': 'روز ${day.dayNumber} — $title',
            'content': meal.content.trim(),
          });
        }
      }
    }

    final supplementPayload = supplements
        .where(
          (item) =>
              item.title.trim().isNotEmpty || item.content.trim().isNotEmpty,
        )
        .map(
          (item) => {
            'title': item.title.trim(),
            'content': item.content.trim(),
          },
        )
        .toList();

    final usableSessions = workoutEnabled
        ? sessions.where((session) => session.hasContent)
        : const Iterable<TrainingSessionDraft>.empty();

    return {
      'name': athleteName.trim(),
      if (athleteId != null) 'gym_client': athleteId,
      'days': usableSessions.indexed
          .map(
            (entry) => entry.$2.toServerJson(fallbackNumber: entry.$1 + 1),
          )
          .toList(),
      if (mealSections.isNotEmpty) 'meal_sections': mealSections,
      if (supplementPayload.isNotEmpty) 'supplements': supplementPayload,
    };
  }
}

class ManualProgramQuota {
  const ManualProgramQuota({
    required this.nextIsFree,
    required this.nextCost,
    required this.freeRemaining,
    required this.balance,
    this.blocked = false,
    this.blockedMessage = '',
    this.access = '',
  });

  final bool nextIsFree;
  final int nextCost;
  final int freeRemaining;
  final int balance;
  final bool blocked;
  final String blockedMessage;
  final String access;

  factory ManualProgramQuota.fromJson(Map<String, dynamic> json) {
    int number(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
    return ManualProgramQuota(
      nextIsFree: json['next_is_free'] == true,
      nextCost: number(json['next_cost']),
      freeRemaining: number(json['free_remaining']),
      balance: number(json['balance']),
      blocked: json['blocked'] == true,
      blockedMessage: json['blocked_message']?.toString() ?? '',
      access: json['access']?.toString() ?? '',
    );
  }
}

class ManualProgramResult {
  const ManualProgramResult({
    required this.programId,
    required this.programType,
    required this.athleteName,
    required this.wasFree,
    required this.chargedTokens,
    this.message = '',
  });

  final int programId;
  final String programType;
  final String athleteName;
  final bool wasFree;
  final int chargedTokens;
  final String message;

  factory ManualProgramResult.fromJson(Map<String, dynamic> json) {
    final rawProgram = json['program'];
    final program = rawProgram is Map
        ? Map<String, dynamic>.from(rawProgram)
        : <String, dynamic>{};
    return ManualProgramResult(
      programId: int.tryParse(program['id']?.toString() ?? '') ?? 0,
      programType: program['program_type']?.toString() ?? 'workout',
      athleteName: program['name']?.toString() ?? '',
      wasFree: json['was_free'] == true,
      chargedTokens:
          int.tryParse(json['charged_tokens']?.toString() ?? '') ?? 0,
      message: json['message']?.toString() ?? '',
    );
  }
}
