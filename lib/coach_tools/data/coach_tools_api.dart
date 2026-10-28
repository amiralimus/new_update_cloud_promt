import 'dart:typed_data';

import '../../core/network/api_config.dart';
import '../../core/network/server_endpoints.dart';
import '../../rigester-login/token_manegment.dart';
import '../models/athlete_model.dart';
import '../models/coach_template.dart';
import '../models/exercise_model.dart';
import '../models/manual_program_models.dart';

class CoachToolsException implements Exception {
  const CoachToolsException(this.message, {this.statusCode = 0, this.data});

  final String message;
  final int statusCode;
  final Map<String, dynamic>? data;

  @override
  String toString() => message;
}

class FeatureActionResult {
  const FeatureActionResult({
    required this.available,
    required this.success,
    required this.message,
  });

  final bool available;
  final bool success;
  final String message;
}

class CoachToolsApi {
  CoachToolsApi({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<ExercisePageResult> fetchExercises({
    String query = '',
    String equipment = '',
    String bodyPart = '',
    String category = '',
    int page = 1,
    int pageSize = 50,
  }) async {
    final parameters = <String, String>{
      if (query.trim().isNotEmpty) 'search': query.trim(),
      if (equipment.trim().isNotEmpty) 'equipment': equipment.trim(),
      if (bodyPart.trim().isNotEmpty) 'body_part': bodyPart.trim(),
      if (category.trim().isNotEmpty) 'category': category.trim(),
      'page': '$page',
      'page_size': '$pageSize',
    };
    final endpoint = _withQuery(ServerEndpoints.exerciseLibrary, parameters);
    final response = await _apiService.get(endpoint: endpoint);
    return ExercisePageResult.fromJson(_requireMap(response));
  }

  Future<List<CoachExercise>> fetchMyExercises() async {
    final response = await _apiService.get(
      endpoint: ServerEndpoints.myExercises,
    );
    final data = _requireMap(response);
    final rawResults = data['results'];
    if (rawResults is! List) return const [];
    return rawResults
        .whereType<Map>()
        .map((item) => CoachExercise.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ManualProgramQuota> fetchManualQuota({
    required String athleteName,
    int? athleteId,
  }) async {
    final endpoint = _withQuery(ServerEndpoints.manualProgramQuota, {
      if (athleteName.trim().isNotEmpty) 'name': athleteName.trim(),
      if (athleteId != null) 'gym_client': '$athleteId',
    });
    final response = await _apiService.get(endpoint: endpoint);
    return ManualProgramQuota.fromJson(_requireMap(response));
  }

  Future<ManualProgramResult> createManualProgram(
    ManualProgramDraft draft,
  ) async {
    final response = await _apiService.post(
      endpoint: ServerEndpoints.manualPrograms,
      body: draft.toServerPayload(),
    );
    return ManualProgramResult.fromJson(_requireMap(response));
  }

  Future<ManualProgramResult> createAiNutritionProgram(
    ManualProgramDraft draft, {
    CoachAthlete? athlete,
  }) async {
    final response = await _apiService.post(
      endpoint: ServerEndpoints.programsGenerate,
      timeout: ApiConfig.programGenerationTimeout,
      body: {
        'name': draft.athleteName.trim(),
        if (draft.athleteId != null) 'gym_client': draft.athleteId,
        'age': athlete?.age,
        'gender': athlete?.gender,
        'height': athlete?.height,
        'weight': athlete?.weight,
        'injuries': athlete?.injuries ?? '',
        'food_allergies': athlete?.foodAllergies ?? '',
        'exercise_history': '',
        'extra_notes': draft.nutritionPrompt.trim(),
        'program_days': draft.validityDays,
        'program_type': 'meal',
        'training_place': 'gym_equipment',
        'generate_pdf': true,
        'pdf_type': 'meal',
      },
    );
    return ManualProgramResult.fromJson(_requireMap(response));
  }

  Future<List<CoachAthlete>> fetchAthletes() async {
    final response = await _apiService.get(
      endpoint: ServerEndpoints.gymClients,
    );
    if (!response.success) throw _exception(response);
    final rawData = response.data;
    final rawItems = rawData is List
        ? rawData
        : rawData is Map
        ? rawData['results']
        : null;
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map>()
        .map((item) => CoachAthlete.fromJson(Map<String, dynamic>.from(item)))
        .where((athlete) => athlete.id > 0)
        .toList();
  }

  Future<List<AthleteProgramSummary>> fetchAthletePrograms(
    int athleteId,
  ) async {
    final response = await _apiService.get(
      endpoint: ServerEndpoints.programsHistoryForClient(athleteId),
    );
    if (!response.success) throw _exception(response);
    final rawItems = response.data;
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map>()
        .map(
          (item) =>
              AthleteProgramSummary.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<AthleteWithPrograms>> fetchAthletesWithPrograms({
    int? limit,
  }) async {
    final athletes = await fetchAthletes();
    final selected = limit == null || athletes.length <= limit
        ? athletes
        : athletes.take(limit).toList();
    return Future.wait(
      selected.map((athlete) async {
        try {
          final programs = await fetchAthletePrograms(athlete.id);
          return AthleteWithPrograms(athlete: athlete, programs: programs);
        } catch (error) {
          return AthleteWithPrograms(
            athlete: athlete,
            programsError: error.toString(),
          );
        }
      }),
    );
  }

  Future<CoachAthlete> updateAthlete(
    int athleteId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiService.patch(
      endpoint: ServerEndpoints.gymClient(athleteId),
      body: payload,
    );
    return CoachAthlete.fromJson(_requireMap(response));
  }

  Future<AthleteProgramDetail> fetchProgramDetail(int programId) async {
    final response = await _apiService.get(
      endpoint: ServerEndpoints.program(programId),
    );
    return AthleteProgramDetail.fromJson(_requireMap(response));
  }

  Future<Uint8List> downloadProgramPdf({
    required int programId,
    required String programType,
  }) async {
    final endpoint = switch (programType) {
      'workout' => ServerEndpoints.programPdfWorkout(programId),
      'meal' => ServerEndpoints.programPdfMeal(programId),
      _ => ServerEndpoints.programPdf(programId),
    };
    final bytes = await _apiService.getBytes(endpoint: endpoint);
    if (bytes == null || bytes.isEmpty) {
      throw const CoachToolsException('دریافت فایل PDF ناموفق بود.');
    }
    return bytes;
  }

  Future<TemplateCatalogResult> fetchTemplates() async {
    if (ServerEndpoints.coachTemplates.trim().isEmpty) {
      return const TemplateCatalogResult(
        available: false,
        message: 'سرویس تمپلیت هنوز به سرور متصل نشده است.',
      );
    }
    final response = await _apiService.get(
      endpoint: ServerEndpoints.coachTemplates,
    );
    final data = _requireMap(response);
    final rawTemplates = data['results'] ?? data['templates'];
    final templates = rawTemplates is List
        ? rawTemplates
              .whereType<Map>()
              .map(
                (item) =>
                    CoachTemplate.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <CoachTemplate>[];
    return TemplateCatalogResult(available: true, templates: templates);
  }

  Future<FeatureActionResult> saveTemplate(CoachTemplate template) async {
    if (ServerEndpoints.coachTemplates.trim().isEmpty) {
      return const FeatureActionResult(
        available: false,
        success: false,
        message: 'فرم آماده است؛ ذخیره پس از اتصال سرویس تمپلیت فعال می‌شود.',
      );
    }
    final response = await _apiService.post(
      endpoint: ServerEndpoints.coachTemplates,
      body: template.toApiPayload(),
    );
    return FeatureActionResult(
      available: true,
      success: response.success,
      message: response.success
          ? 'تمپلیت ذخیره شد.'
          : response.error ?? 'ذخیره تمپلیت ناموفق بود.',
    );
  }

  Future<FeatureActionResult> requestNutritionAnalysis(
    Map<String, dynamic> payload,
  ) async {
    if (ServerEndpoints.nutritionAnalysis.trim().isEmpty) {
      return const FeatureActionResult(
        available: false,
        success: false,
        message: 'محاسبه محتویات پس از اتصال سرویس فعال می‌شود.',
      );
    }
    final response = await _apiService.post(
      endpoint: ServerEndpoints.nutritionAnalysis,
      body: payload,
    );
    return FeatureActionResult(
      available: true,
      success: response.success,
      message: response.success
          ? 'محاسبه انجام شد.'
          : response.error ?? 'محاسبه ناموفق بود.',
    );
  }

  Future<FeatureActionResult> requestSectionDraft({
    required String sectionType,
    required String prompt,
  }) async {
    if (ServerEndpoints.sectionDraftGeneration.trim().isEmpty) {
      return const FeatureActionResult(
        available: false,
        success: false,
        message: 'تهیه پیش‌نویس پس از اتصال سرویس فعال می‌شود.',
      );
    }
    final response = await _apiService.post(
      endpoint: ServerEndpoints.sectionDraftGeneration,
      body: {'type': sectionType, 'prompt': prompt},
    );
    return FeatureActionResult(
      available: true,
      success: response.success,
      message: response.success
          ? 'پیش‌نویس آماده شد.'
          : response.error ?? 'تهیه پیش‌نویس ناموفق بود.',
    );
  }

  Map<String, dynamic> _requireMap(ApiResponse response) {
    if (!response.success) throw _exception(response);
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw const CoachToolsException('ساختار پاسخ سرور قابل خواندن نیست.');
  }

  CoachToolsException _exception(ApiResponse response) {
    return CoachToolsException(
      response.error ?? 'ارتباط با سرور ناموفق بود.',
      statusCode: response.statusCode,
      data: response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : null,
    );
  }

  String _withQuery(String endpoint, Map<String, String> parameters) {
    if (parameters.isEmpty) return endpoint;
    return '$endpoint?${Uri(queryParameters: parameters).query}';
  }
}
