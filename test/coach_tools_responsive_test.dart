import 'package:chegher_1/coach_tools/models/exercise_model.dart';
import 'package:chegher_1/coach_tools/models/manual_program_models.dart';
import 'package:chegher_1/coach_tools/pages/exercise_library_page.dart';
import 'package:chegher_1/coach_tools/widgets/coach_tools_common.dart';
import 'package:chegher_1/coach_tools/widgets/nutrition_editor.dart';
import 'package:chegher_1/coach_tools/widgets/optional_plan_editor.dart';
import 'package:chegher_1/coach_tools/widgets/training_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAtSize(WidgetTester tester, Size size, Widget child) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );
    await tester.pump();
  }

  testWidgets('coach page frame fits compact mobile screens', (tester) async {
    await pumpAtSize(
      tester,
      const Size(320, 568),
      CoachPageFrame(
        title: 'ساخت برنامه جدید',
        subtitle: 'ورزشکار را انتخاب کنید و بخش‌های موردنیاز را تکمیل کنید.',
        onBack: () {},
        actions: [
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.dashboard_customize_outlined),
            label: const Text('تمپلیت‌ها'),
          ),
        ],
        body: ListView(
          children: const [
            CoachSurface(
              child: SizedBox(height: 500, child: Text('محتوای صفحه')),
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('ساخت برنامه جدید'), findsOneWidget);
  });

  testWidgets('exercise details adapt to mobile and desktop', (tester) async {
    const exercise = CoachExercise(
      externalId: 'demo',
      name: 'پرس سینه با دمبل',
      equipment: 'دمبل',
      target: 'سینه',
      instructions: 'حرکت را آرام و کنترل‌شده اجرا کنید.',
      steps: ['روی نیمکت قرار بگیرید.', 'وزنه‌ها را کنترل‌شده بالا ببرید.'],
    );

    for (final size in [const Size(375, 720), const Size(1280, 800)]) {
      await pumpAtSize(
        tester,
        size,
        ExerciseDetailView(
          exercise: exercise,
          onBack: () {},
          onAddToProgram: (_) {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('پرس سینه با دمبل'), findsOneWidget);
    }
  });

  testWidgets('program editors fit narrow mobile content', (tester) async {
    final draft = ManualProgramDraft.fresh();
    final sections = <Widget>[
      TrainingEditor(sessions: draft.sessions, onChanged: () {}),
      NutritionEditor(
        days: draft.mealDays,
        prompt: '',
        onPromptChanged: (_) {},
        onChanged: () {},
      ),
      OptionalPlanEditor(
        title: 'مکمل',
        prompt: '',
        items: draft.supplements,
        onPromptChanged: (_) {},
        onChanged: () {},
      ),
    ];

    for (final section in sections) {
      await pumpAtSize(
        tester,
        const Size(320, 700),
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: section,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
