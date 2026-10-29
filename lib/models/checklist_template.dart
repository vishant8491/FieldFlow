import 'template_item.dart';

class ChecklistTemplate {
  final int? id;
  final String name;
  final String description;
  final DateTime createdAt;
  final List<TemplateItem> items;

  ChecklistTemplate({
    this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name.trim(),
      'description': description.trim(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChecklistTemplate.fromMap(
    Map<String, dynamic> map, {
    List<TemplateItem> items = const [],
  }) {
    return ChecklistTemplate(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      items: items,
    );
  }

  ChecklistTemplate copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? createdAt,
    List<TemplateItem>? items,
  }) {
    return ChecklistTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}
