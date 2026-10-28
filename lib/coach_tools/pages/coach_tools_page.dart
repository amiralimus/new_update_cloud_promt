import 'package:flutter/material.dart';

import '../models/athlete_model.dart';
import '../models/exercise_model.dart';
import 'athletes_page.dart';
import 'coach_tools_dashboard_page.dart';
import 'exercise_library_page.dart';
import 'manual_program_editor_page.dart';
import 'templates_page.dart';

enum _CoachToolsSection { dashboard, library, editor, templates, athletes }

class CoachToolsPage extends StatefulWidget {
  const CoachToolsPage({super.key});

  @override
  State<CoachToolsPage> createState() => _CoachToolsPageState();
}

class _CoachToolsPageState extends State<CoachToolsPage> {
  final GlobalKey<ManualProgramEditorPageState> _editorKey =
      GlobalKey<ManualProgramEditorPageState>();
  final Map<_CoachToolsSection, Widget> _pageCache = {};
  final Set<_CoachToolsSection> _visited = {_CoachToolsSection.dashboard};
  _CoachToolsSection _section = _CoachToolsSection.dashboard;

  void _navigate(_CoachToolsSection section) {
    if (_section == section) return;
    setState(() {
      _visited.add(section);
      _section = section;
    });
  }

  void _openExerciseInNewProgram(CoachExercise exercise) {
    _navigate(_CoachToolsSection.editor);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editorKey.currentState?.startNewWithExercise(exercise);
    });
  }

  Widget _pageFor(_CoachToolsSection section) {
    return _pageCache.putIfAbsent(section, () {
      switch (section) {
        case _CoachToolsSection.dashboard:
          return CoachToolsDashboardPage(
            onOpenAthletes: () => _navigate(_CoachToolsSection.athletes),
            onOpenTemplates: () => _navigate(_CoachToolsSection.templates),
            onCreateProgram: () => _navigate(_CoachToolsSection.editor),
            onCreateProgramForAthlete: _createProgramForAthlete,
            onOpenLibrary: () => _navigate(_CoachToolsSection.library),
          );
        case _CoachToolsSection.library:
          return ExerciseLibraryPage(
            onBack: () => _navigate(_CoachToolsSection.dashboard),
            onAddToProgram: _openExerciseInNewProgram,
          );
        case _CoachToolsSection.editor:
          return ManualProgramEditorPage(
            key: _editorKey,
            onBack: () => _navigate(_CoachToolsSection.dashboard),
            onOpenTemplates: () => _navigate(_CoachToolsSection.templates),
          );
        case _CoachToolsSection.templates:
          return TemplatesPage(
            onBack: () => _navigate(_CoachToolsSection.dashboard),
          );
        case _CoachToolsSection.athletes:
          return AthletesPage(
            onBack: () => _navigate(_CoachToolsSection.dashboard),
          );
      }
    });
  }

  void _createProgramForAthlete(CoachAthlete athlete) {
    _navigate(_CoachToolsSection.editor);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editorKey.currentState?.startNewForAthlete(athlete);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final section in _visited)
          Positioned.fill(
            child: Offstage(
              offstage: section != _section,
              child: TickerMode(
                enabled: section == _section,
                child: _pageFor(section),
              ),
            ),
          ),
      ],
    );
  }
}
