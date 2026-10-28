import 'manual_program_models.dart';

enum TemplateApplyMode { replace, prepend, append }

extension TemplateApplyModeLabel on TemplateApplyMode {
  String get apiValue {
    switch (this) {
      case TemplateApplyMode.prepend:
        return 'prepend';
      case TemplateApplyMode.append:
        return 'append';
      case TemplateApplyMode.replace:
        return 'replace';
    }
  }

  String get label {
    switch (this) {
      case TemplateApplyMode.prepend:
        return 'افزودن به ابتدای هر جلسه';
      case TemplateApplyMode.append:
        return 'افزودن به انتهای هر جلسه';
      case TemplateApplyMode.replace:
        return 'جایگزینی برنامه';
    }
  }

  static TemplateApplyMode parse(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'prepend':
        return TemplateApplyMode.prepend;
      case 'append':
        return TemplateApplyMode.append;
      default:
        return TemplateApplyMode.replace;
    }
  }
}

class CoachTemplate {
  CoachTemplate({
    required this.id,
    required this.title,
    this.categoryPath = const [],
    this.summary = '',
    this.applyMode = TemplateApplyMode.replace,
    this.serverOwned = false,
    List<TrainingSessionDraft>? sessions,
    List<MealDayDraft>? mealDays,
    List<OptionalPlanItemDraft>? supplements,
    List<OptionalPlanItemDraft>? medications,
  }) : sessions = sessions ?? <TrainingSessionDraft>[],
       mealDays = mealDays ?? <MealDayDraft>[],
       supplements = supplements ?? <OptionalPlanItemDraft>[],
       medications = medications ?? <OptionalPlanItemDraft>[];

  final String id;
  String title;
  List<String> categoryPath;
  String summary;
  TemplateApplyMode applyMode;
  bool serverOwned;
  final List<TrainingSessionDraft> sessions;
  final List<MealDayDraft> mealDays;
  final List<OptionalPlanItemDraft> supplements;
  final List<OptionalPlanItemDraft> medications;

  String get categoryLabel =>
      categoryPath.isEmpty ? 'بدون دسته‌بندی' : categoryPath.join(' / ');

  factory CoachTemplate.fromJson(Map<String, dynamic> json) {
    final rawSessions = json['sessions'] ?? json['days'];
    final sessions = <TrainingSessionDraft>[];
    if (rawSessions is List) {
      for (final rawSession in rawSessions.whereType<Map>()) {
        final sessionJson = Map<String, dynamic>.from(rawSession);
        final session = TrainingSessionDraft(
          title: sessionJson['title']?.toString() ?? '',
          note: sessionJson['note']?.toString() ?? '',
        );
        final rawExercises = sessionJson['exercises'];
        if (rawExercises is List) {
          for (final rawExercise in rawExercises.whereType<Map>()) {
            final exerciseJson = Map<String, dynamic>.from(rawExercise);
            session.exercises.add(
              ProgramExerciseDraft(
                exerciseId: exerciseJson['exercise_id']?.toString(),
                name: exerciseJson['name']?.toString() ?? '',
                sets: exerciseJson['sets']?.toString() ?? '',
                reps: exerciseJson['reps']?.toString() ?? '',
                rest: exerciseJson['rest']?.toString() ?? '',
                duration: exerciseJson['duration']?.toString() ?? '',
                note: exerciseJson['note']?.toString() ?? '',
              ),
            );
          }
        }
        sessions.add(session);
      }
    }

    final category = json['category'];
    final rawPath = json['category_path'];
    final categoryPath = rawPath is List
        ? rawPath
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : category == null || category.toString().trim().isEmpty
        ? <String>[]
        : <String>[category.toString().trim()];

    return CoachTemplate(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'تمپلیت بدون عنوان',
      categoryPath: categoryPath,
      summary: json['summary']?.toString() ?? '',
      applyMode: TemplateApplyModeLabel.parse(
        json['apply_mode'] ?? json['mode'],
      ),
      serverOwned:
          json['server_owned'] == true ||
          json['owner_type']?.toString() == 'server',
      sessions: sessions,
    );
  }

  Map<String, dynamic> toApiPayload() {
    final usableSessions = sessions.where((session) => session.hasContent);
    final usableMealDays = mealDays.where(
      (day) => day.meals.any(
        (meal) =>
            meal.title.trim().isNotEmpty || meal.content.trim().isNotEmpty,
      ),
    );
    return {
      'title': title.trim(),
      'category_path': categoryPath,
      'apply_mode': applyMode.apiValue,
      'sessions': usableSessions.indexed
          .map(
            (entry) => entry.$2.toServerJson(fallbackNumber: entry.$1 + 1),
          )
          .toList(),
      'meal_days': usableMealDays.map((day) {
        return {
          'day': day.dayNumber,
          'enabled': true,
          'meals': day.meals
              .where(
                (meal) =>
                    meal.title.trim().isNotEmpty ||
                    meal.content.trim().isNotEmpty,
              )
              .map(
                (meal) => {
                  'title': meal.title.trim(),
                  'content': meal.content.trim(),
                },
              )
              .toList(),
        };
      }).toList(),
      'supplements': supplements
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
          .toList(),
      'medications': medications
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
          .toList(),
    };
  }

  List<ProgramExerciseDraft> exercisesForSession(int sessionIndex) {
    if (sessionIndex < 0 || sessionIndex >= sessions.length) return const [];
    return sessions[sessionIndex].exercises.map((exercise) {
      final copy = exercise.copy();
      copy.sourceTemplateId = id;
      copy.sourceTemplateSession = sessionIndex;
      return copy;
    }).toList();
  }

  void applyTo(ManualProgramDraft draft) {
    if (applyMode == TemplateApplyMode.replace) {
      draft.sessions
        ..clear()
        ..addAll(
          sessions.map((session) {
            final copy = session.copy();
            for (final exercise in copy.exercises) {
              exercise.sourceTemplateId = id;
            }
            return copy;
          }),
        );
      if (draft.sessions.isEmpty) draft.sessions.add(TrainingSessionDraft());
      return;
    }

    for (
      var sessionIndex = 0;
      sessionIndex < draft.sessions.length && sessionIndex < sessions.length;
      sessionIndex += 1
    ) {
      final target = draft.sessions[sessionIndex];
      final alreadyApplied = target.exercises.any(
        (exercise) =>
            exercise.sourceTemplateId == id &&
            exercise.sourceTemplateSession == sessionIndex,
      );
      if (alreadyApplied) continue;
      final additions = exercisesForSession(sessionIndex);
      if (applyMode == TemplateApplyMode.prepend) {
        target.exercises.insertAll(0, additions);
      } else {
        target.exercises.addAll(additions);
      }
    }
  }
}

class TemplateCatalogResult {
  const TemplateCatalogResult({
    required this.available,
    this.templates = const [],
    this.message,
  });

  final bool available;
  final List<CoachTemplate> templates;
  final String? message;
}
