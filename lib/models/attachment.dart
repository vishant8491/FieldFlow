class Attachment {
  final int? id;
  final int jobId;
  final int? checklistItemId;
  final String relativePath;
  final String? caption;
  final DateTime createdAt;

  Attachment({
    this.id,
    required this.jobId,
    this.checklistItemId,
    required this.relativePath,
    this.caption,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'checklistItemId': checklistItemId,
      'relativePath': relativePath,
      'caption': caption?.trim().isEmpty == true ? null : caption?.trim(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Attachment.fromMap(Map<String, dynamic> map) {
    return Attachment(
      id: map['id'] as int?,
      jobId: map['jobId'] as int? ?? 0,
      checklistItemId: map['checklistItemId'] as int?,
      relativePath: map['relativePath'] as String? ?? '',
      caption: map['caption'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Attachment copyWith({
    int? id,
    int? jobId,
    int? checklistItemId,
    String? relativePath,
    String? caption,
    DateTime? createdAt,
  }) {
    return Attachment(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      checklistItemId: checklistItemId ?? this.checklistItemId,
      relativePath: relativePath ?? this.relativePath,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
