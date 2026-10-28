import 'package:chegher_1/coach_tools/models/coach_template.dart';
import 'package:chegher_1/coach_tools/models/manual_program_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ManualProgramDraft server payload', () {
    test('only sends fields supported by the current manual API', () {
      final draft = ManualProgramDraft.fresh()
        ..athleteName = 'رضا احمدی'
        ..validityDays = 60
        ..medicationsEnabled = true
        ..medicationsPrompt = 'پیش‌نویس دارو'
        ..nutritionEnabled = true
        ..supplementsEnabled = true;

      draft.sessions.first.exercises.add(
        ProgramExerciseDraft(name: 'اسکوات', sets: '4', reps: '10'),
      );
      draft.mealDays.first
        ..enabled = true
        ..calculateNutrition = true
        ..meals.first.title = 'صبحانه'
        ..meals.first.content = 'تخم‌مرغ و نان';
      draft.supplements.first
        ..title = 'کراتین'
        ..content = 'روزی ۵ گرم';
      draft.medications.first
        ..title = 'داروی آزمایشی'
        ..content = 'نباید ارسال شود';

      final payload = draft.toServerPayload();

      expect(payload['name'], 'رضا احمدی');
      expect(payload['days'], isA<List<dynamic>>());
      expect(payload['meal_sections'], [
        {'title': 'روز 1 — صبحانه', 'content': 'تخم‌مرغ و نان'},
      ]);
      expect(payload['supplements'], [
        {'title': 'کراتین', 'content': 'روزی ۵ گرم'},
      ]);
      expect(payload.containsKey('medications'), isFalse);
      expect(payload.containsKey('validity_days'), isFalse);
      expect(payload.containsKey('calculate_nutrition'), isFalse);
    });

    test('superset metadata is adapted into the supported note field', () {
      final draft = ManualProgramDraft.fresh()..athleteName = 'سارا';
      final first = ProgramExerciseDraft(name: 'پرس سینه', reps: '12');
      final second = ProgramExerciseDraft(name: 'شنا', reps: '10');
      final superset = SupersetDraft(
        rounds: '4',
        exerciseLocalIds: [first.localId, second.localId],
      );
      first.supersetId = superset.id;
      second.supersetId = superset.id;
      draft.sessions.first
        ..exercises.addAll([first, second])
        ..supersets.add(superset);

      final payload = draft.toServerPayload();
      final days = payload['days'] as List<dynamic>;
      final exercises =
          (days.first as Map<String, dynamic>)['exercises'] as List<dynamic>;

      expect(
        (exercises.first as Map<String, dynamic>)['note'],
        contains('سوپرست 1، 4 دور'),
      );
      expect(
        (exercises.first as Map<String, dynamic>).containsKey('superset_id'),
        isFalse,
      );
    });
  });

  group('CoachTemplate application', () {
    CoachTemplate buildTemplate(TemplateApplyMode mode) {
      final session = TrainingSessionDraft();
      session.exercises.add(ProgramExerciseDraft(name: 'گرم‌کردن'));
      return CoachTemplate(
        id: 'template-1',
        title: 'گرم‌کردن',
        applyMode: mode,
        sessions: [session],
      );
    }

    test('prepend keeps manual exercises and avoids duplicate injection', () {
      final draft = ManualProgramDraft.fresh()..athleteName = 'رضا';
      draft.sessions.first.exercises.add(
        ProgramExerciseDraft(name: 'حرکت دستی'),
      );
      final template = buildTemplate(TemplateApplyMode.prepend);

      template.applyTo(draft);
      template.applyTo(draft);

      expect(draft.sessions.first.exercises.map((item) => item.name).toList(), [
        'گرم‌کردن',
        'حرکت دستی',
      ]);
    });

    test('replace removes current workout only after caller chooses it', () {
      final draft = ManualProgramDraft.fresh()..athleteName = 'رضا';
      draft.sessions.first.exercises.add(
        ProgramExerciseDraft(name: 'حرکت دستی'),
      );
      final template = buildTemplate(TemplateApplyMode.replace);

      template.applyTo(draft);

      expect(draft.sessions, hasLength(1));
      expect(draft.sessions.first.exercises.single.name, 'گرم‌کردن');
      expect(
        draft.sessions.first.exercises.single.sourceTemplateId,
        'template-1',
      );
    });
  });
}
