class TemplateItem {
  final int? id;
  final int templateId;
  final String label;
  final bool isRequired;
  final int sortOrder;

  TemplateItem({
    this.id,
    required this.templateId,
    required this.label,
    this.isRequired = true,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'templateId': templateId,
      'label': label.trim(),
      'isRequired': isRequired ? 1 : 0,
      'sortOrder': sortOrder,
    };
  }

  factory TemplateItem.fromMap(Map<String, dynamic> map) {
    return TemplateItem(
      id: map['id'] as int?,
      templateId: map['templateId'] as int? ?? 0,
      label: map['label'] as String? ?? '',
      isRequired: (map['isRequired'] as int? ?? 1) == 1,
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  TemplateItem copyWith({
    int? id,
    int? templateId,
    String? label,
    bool? isRequired,
    int? sortOrder,
  }) {
    return TemplateItem(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      label: label ?? this.label,
      isRequired: isRequired ?? this.isRequired,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
