class JobNote {
  final int? id;
  final int jobId;
  final String text;
  final DateTime createdAt;

  JobNote({
    this.id,
    required this.jobId,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'text': text.trim(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory JobNote.fromMap(Map<String, dynamic> map) {
    return JobNote(
      id: map['id'] as int?,
      jobId: map['jobId'] as int? ?? 0,
      text: map['text'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  JobNote copyWith({int? id, int? jobId, String? text, DateTime? createdAt}) {
    return JobNote(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
