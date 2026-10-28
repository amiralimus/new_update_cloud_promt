class CoachExercise {
  const CoachExercise({
    required this.externalId,
    required this.name,
    this.databaseId,
    this.englishName = '',
    this.category = '',
    this.categoryKey = '',
    this.bodyPart = '',
    this.bodyPartKey = '',
    this.equipment = '',
    this.equipmentKey = '',
    this.target = '',
    this.muscleGroup = '',
    this.secondaryMuscles = const [],
    this.instructions = '',
    this.steps = const [],
    this.gifUrl,
    this.thumbnailUrl,
    this.source = '',
    this.brand = '',
    this.attribution = '',
  });

  final int? databaseId;
  final String externalId;
  final String name;
  final String englishName;
  final String category;
  final String categoryKey;
  final String bodyPart;
  final String bodyPartKey;
  final String equipment;
  final String equipmentKey;
  final String target;
  final String muscleGroup;
  final List<String> secondaryMuscles;
  final String instructions;
  final List<String> steps;
  final String? gifUrl;
  final String? thumbnailUrl;
  final String source;
  final String brand;
  final String attribution;

  bool get isCoachOwned => source.toLowerCase() == 'coach';

  String? get preferredMediaUrl {
    final gif = gifUrl?.trim();
    if (gif != null && gif.isNotEmpty) return gif;
    final thumbnail = thumbnailUrl?.trim();
    return thumbnail == null || thumbnail.isEmpty ? null : thumbnail;
  }

  factory CoachExercise.fromJson(Map<String, dynamic> json) {
    final persianName = _text(json['name_fa']);
    final englishName = _text(json['name']);
    return CoachExercise(
      databaseId: _integer(json['id']),
      externalId: _text(json['external_id'], fallback: _text(json['id'])),
      name: persianName.isNotEmpty ? persianName : englishName,
      englishName: englishName,
      category: _text(json['category_fa'], fallback: _text(json['category'])),
      categoryKey: _text(json['category']),
      bodyPart: _text(json['body_part_fa'], fallback: _text(json['body_part'])),
      bodyPartKey: _text(json['body_part']),
      equipment: _text(
        json['equipment_fa'],
        fallback: _text(json['equipment']),
      ),
      equipmentKey: _text(json['equipment']),
      target: _text(json['target_fa'], fallback: _text(json['target'])),
      muscleGroup: _text(
        json['muscle_group_fa'],
        fallback: _text(json['muscle_group']),
      ),
      secondaryMuscles: _stringList(
        json['secondary_muscles_fa'] ?? json['secondary_muscles'],
      ),
      instructions: _text(
        json['instructions_fa'],
        fallback: _text(json['instructions_en']),
      ),
      steps: _stringList(json['steps_fa'] ?? json['steps_en']),
      gifUrl: _nullableText(json['gif_url'] ?? json['gif']),
      thumbnailUrl: _nullableText(
        json['thumb_url'] ?? json['thumbnail_url'] ?? json['thumb'],
      ),
      source: _text(json['source']),
      brand: _text(json['brand']),
      attribution: _text(json['attribution']),
    );
  }
}

class ExercisePageResult {
  const ExercisePageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<CoachExercise> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < total;

  factory ExercisePageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['results'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) =>
                    CoachExercise.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <CoachExercise>[];
    return ExercisePageResult(
      items: items,
      total: _integer(json['count']) ?? items.length,
      page: _integer(json['page']) ?? 1,
      pageSize: _integer(json['page_size']) ?? items.length,
    );
  }
}

String _text(dynamic value, {String fallback = ''}) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}

String? _nullableText(dynamic value) {
  final result = _text(value);
  return result.isEmpty ? null : result;
}

int? _integer(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String) {
    return value
        .split(RegExp(r'[\n،,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}
